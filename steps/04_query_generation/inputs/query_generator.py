#!/usr/bin/env python3
"""
Query Generator for OpenRCA Pipeline
Based on main/generate.py but modularized for pipeline execution
"""
import pandas as pd
from datetime import datetime, timedelta
import random
import json
import sys
import os
import pytz
import argparse
from pathlib import Path
from typing import Dict, List, Tuple, Any

# Import prompt templates
from prompt_templates import system, user


class QueryGenerator:
    def __init__(self, api_config_path: str, task_spec_path: str):
        self.api_config = self._load_api_config(api_config_path)
        self.task_templates = self._load_task_specification(task_spec_path)
        self.timezone = pytz.timezone('Asia/Shanghai')  # UTC+8
        random.seed(42)  # Reproducible results
        
        # Initialize API client based on provider
        self._init_api_client()
        
        self.generation_stats = {
            "total_queries": 0,
            "successful_generations": 0,
            "failed_generations": 0,
            "task_distribution": {},
            "datasets_processed": [],
            "multi_failure_queries": 0
        }
    
    def _load_api_config(self, config_path: str) -> Dict[str, Any]:
        """Load API configuration"""
        import yaml
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
        
        # Substitute environment variables
        api_key = config.get('API_KEY', '')
        if api_key.startswith('${') and api_key.endswith('}'):
            env_var = api_key[2:-1]
            config['API_KEY'] = os.environ.get(env_var, '')
        
        return config
    
    def _load_task_specification(self, spec_path: str) -> Dict[str, Any]:
        """Load task specification templates"""
        with open(spec_path, 'r') as f:
            return json.load(f)
    
    def _init_api_client(self):
        """Initialize the appropriate API client"""
        provider = self.api_config.get('SOURCE')
        
        if provider == 'OpenAI':
            import openai
            self.client = openai.OpenAI(api_key=self.api_config['API_KEY'])
            self.model = self.api_config['MODEL']
        elif provider == 'Anthropic':
            import anthropic
            self.client = anthropic.Anthropic(api_key=self.api_config['API_KEY'])
            self.model = self.api_config['MODEL']
        else:
            raise ValueError(f"Unsupported provider: {provider}")
        
        self.provider = provider
    
    def get_chat_completion(self, messages: List[Dict[str, str]], temperature: float = 1.0) -> str:
        """Get chat completion from configured provider"""
        try:
            if self.provider == 'OpenAI':
                response = self.client.chat.completions.create(
                    model=self.model,
                    messages=messages,
                    temperature=temperature,
                    max_tokens=self.api_config.get('MODEL_PARAMETERS', {}).get('max_tokens', 4096)
                )
                return response.choices[0].message.content
            
            elif self.provider == 'Anthropic':
                # Convert OpenAI format to Anthropic format
                system_msg = next((msg['content'] for msg in messages if msg['role'] == 'system'), '')
                user_messages = [msg for msg in messages if msg['role'] != 'system']
                
                response = self.client.messages.create(
                    model=self.model,
                    system=system_msg,
                    messages=user_messages,
                    temperature=temperature,
                    max_tokens=self.api_config.get('MODEL_PARAMETERS', {}).get('max_tokens', 4096)
                )
                return response.content[0].text
            
        except Exception as e:
            print(f"API call failed: {e}")
            raise
    
    def timestamp2timeperiod(self, timestamp: int) -> str:
        """Convert timestamp to 30-minute time period"""
        time = datetime.fromtimestamp(timestamp, self.timezone)
        minute = time.minute
        start_time = time.replace(minute=minute - (minute % 30), second=0, microsecond=0)
        end_time = start_time + timedelta(minutes=30)
        start_time_str = start_time.strftime('%Y-%m-%d %H:%M:%S')
        end_time_str = end_time.strftime('%Y-%m-%d %H:%M:%S')
        return f"{start_time_str} to {end_time_str}"
    
    def timestamp2datetime(self, timestamp: int) -> str:
        """Convert timestamp to datetime string"""
        time = datetime.fromtimestamp(timestamp, self.timezone)
        return time.strftime('%Y-%m-%d %H:%M:%S')
    
    def get_half_hour_conflict_failure_flag(self, meta_data: pd.DataFrame) -> Dict[int, bool]:
        """Identify failures that occur within the same 30-minute window"""
        sorted_time = sorted(meta_data['timestamp'])
        half_hour_conflict_failure_flag = {}
        previous_failure_timestamp = 0
        
        for i in range(len(sorted_time)): 
            timestamp = sorted_time[i]   
            current_failure_timestamp_left = timestamp // 1800  # 30 minutes = 1800 seconds
            
            if current_failure_timestamp_left > previous_failure_timestamp:
                previous_failure_timestamp = current_failure_timestamp_left
                half_hour_conflict_failure_flag[timestamp] = False
            else:
                half_hour_conflict_failure_flag[timestamp] = True
                half_hour_conflict_failure_flag[sorted_time[i - 1]] = True 
                
        return half_hour_conflict_failure_flag
    
    def get_multi_response_dict(self, row: pd.Series, meta_data: pd.DataFrame) -> Tuple[int, Dict[str, List]]:
        """Get multiple responses for failures in the same time window"""
        num = 0
        multi_dict = {
            "datetime": [],
            "component": [],
            "reason": [],
        }
        
        cand_df = meta_data[meta_data['timestamp']//1800 == row['timestamp']//1800]
        for idx, cand in cand_df.iterrows():
            num += 1
            multi_dict["datetime"].append(self.timestamp2datetime(cand['timestamp']))
            multi_dict["component"].append(cand['component'])
            multi_dict["reason"].append(cand['reason'])
        
        return num, multi_dict
    
    def generate_queries_for_dataset(self, dataset_name: str, record_path: str, 
                                   output_path: str, extra_spec: str = None) -> Dict[str, Any]:
        """Generate queries for a single dataset"""
        print(f"Processing dataset: {dataset_name}")
        
        # Load ground truth data
        meta_data = pd.read_csv(record_path)
        
        # Identify multi-failure conflicts
        half_hour_conflict_failure_flag = self.get_half_hour_conflict_failure_flag(meta_data)
        
        # Initialize task tracking
        full_task_ID_list = list(self.task_templates.keys())
        df = pd.DataFrame(columns=["task_index", "instruction", "scoring_points"])
        
        dataset_stats = {
            "dataset_name": dataset_name,
            "total_records": len(meta_data),
            "queries_generated": 0,
            "multi_failure_queries": 0,
            "task_distribution": {task: 0 for task in full_task_ID_list},
            "generation_errors": []
        }
        
        for idx, row in meta_data.iterrows():
            print(f"  Processing record {idx + 1}/{len(meta_data)}")
            
            try:
                timestamp = row['timestamp']
                reason = row['reason']
                component = row['component']
                datetime_str = self.timestamp2datetime(timestamp)
                time_period = self.timestamp2timeperiod(timestamp)
                task_index = random.choice(full_task_ID_list)
                
                # Track task distribution
                dataset_stats["task_distribution"][task_index] += 1
                
                # Handle multi-failure scenarios
                if half_hour_conflict_failure_flag[timestamp]:
                    num, ans = self.get_multi_response_dict(row, meta_data)
                    dataset_stats["multi_failure_queries"] += 1
                    
                    scoring_points = ""
                    for i in range(num):
                        scoring_points_template = self.task_templates[task_index]['scoring_points'].copy()
                        
                        scoring_points_filled = [points.format(
                            idx = f'{i+1}-th',
                            datetime = ans['datetime'][i],
                            reason = ans['reason'][i],
                            component = ans['component'][i],
                        ) for points in scoring_points_template]
                        scoring_points += "\\n".join(scoring_points_filled)
                        scoring_points += "\\n"
                        
                    print(f"    Multi-response task with {num} root causes")
                    
                else:
                    num = 1
                    scoring_points = ""
                    for point in self.task_templates[task_index]['scoring_points']:
                        scoring_points += point.format(
                            idx='only',
                            time_period=time_period,
                            datetime=datetime_str,
                            component=component,
                            reason=reason
                        )
                        scoring_points += "\\n"
                
                # Build input specification
                input_specification = "```known\\n"
                for spec in self.task_templates[task_index]['input']:
                    input_specification += f"- "
                    input_specification += spec.format(
                        num=num,
                        time_period=time_period
                    )
                    input_specification += "\\n"
                
                if extra_spec:
                    input_specification += f"- {extra_spec}\\n"
                input_specification = input_specification.strip() + "\\n```"
                
                # Build output specification
                output_specification = "```query\\n"
                for spec in self.task_templates[task_index]['output']:
                    output_specification += f"- "
                    output_specification += spec.format(
                        time_period="**UNKNOWN**",
                        datetime="**UNKNOWN**",
                        component="**UNKNOWN**",
                        reason="**UNKNOWN**",
                    )
                    output_specification += "\\n"
                output_specification = output_specification.strip() + "\\n```"
                
                # Generate instruction using LLM
                prompt = [
                    {'role': 'system', 'content': system},
                    {'role': 'user', 'content': user.format(
                        input_specification=input_specification, 
                        output_specification=output_specification
                    )},
                ]
                
                # Retry logic for instruction generation
                instruction = None
                for attempt in range(3):
                    try:
                        response = self.get_chat_completion(messages=prompt, temperature=1.0)
                        instruction_data = json.loads(response)
                        instruction = instruction_data['issue']
                        break
                    except Exception as e:
                        print(f"    Generation attempt {attempt + 1} failed: {e}")
                        if attempt == 2:
                            dataset_stats["generation_errors"].append(f"Record {idx}: {str(e)}")
                            continue
                
                if instruction:
                    new_df = pd.DataFrame([{
                        "task_index": task_index,
                        "instruction": instruction,
                        "scoring_points": scoring_points
                    }])
                    df = pd.concat([df, new_df], ignore_index=True)
                    dataset_stats["queries_generated"] += 1
                    
                    print(f"    Generated: {task_index}")
                
            except Exception as e:
                error_msg = f"Record {idx}: {str(e)}"
                dataset_stats["generation_errors"].append(error_msg)
                print(f"    Error: {error_msg}")
                continue
        
        # Save generated queries
        df.to_csv(output_path, index=False)
        print(f"  Saved {len(df)} queries to {output_path}")
        
        return dataset_stats
    
    def generate_all_queries(self, dataset_root: str, output_dir: str) -> Dict[str, Any]:
        """Generate queries for all available datasets"""
        dataset_configs = [
            ("Telecom", "Telecom/record.csv", None),
            ("Bank", "Bank/record.csv", None),
            ("Market/cloudbed-1", "Market/cloudbed-1/record.csv", "system: cloudbed-1"),
            ("Market/cloudbed-2", "Market/cloudbed-2/record.csv", "system: cloudbed-2")
        ]
        
        os.makedirs(output_dir, exist_ok=True)
        all_stats = []
        
        for dataset_name, record_path, extra_spec in dataset_configs:
            full_record_path = os.path.join(dataset_root, record_path)
            
            if not os.path.exists(full_record_path):
                print(f"Skipping {dataset_name}: record file not found at {full_record_path}")
                continue
            
            # Generate output path
            safe_name = dataset_name.replace("/", "_")
            output_path = os.path.join(output_dir, f"{safe_name}_query.csv")
            
            # Generate queries for this dataset
            dataset_stats = self.generate_queries_for_dataset(
                dataset_name, full_record_path, output_path, extra_spec
            )
            
            all_stats.append(dataset_stats)
            self.generation_stats["datasets_processed"].append(dataset_name)
            self.generation_stats["total_queries"] += dataset_stats["queries_generated"]
            self.generation_stats["successful_generations"] += dataset_stats["queries_generated"]
            self.generation_stats["failed_generations"] += len(dataset_stats["generation_errors"])
            self.generation_stats["multi_failure_queries"] += dataset_stats["multi_failure_queries"]
            
            # Update task distribution
            for task, count in dataset_stats["task_distribution"].items():
                if task not in self.generation_stats["task_distribution"]:
                    self.generation_stats["task_distribution"][task] = 0
                self.generation_stats["task_distribution"][task] += count
        
        return {
            "generation_summary": self.generation_stats,
            "dataset_details": all_stats
        }


def main():
    """Main function for query generation"""
    parser = argparse.ArgumentParser(description='Generate queries for OpenRCA datasets')
    parser.add_argument('--dataset_root', type=str, required=True, 
                       help='Path to dataset root directory')
    parser.add_argument('--api_config', type=str, required=True,
                       help='Path to API configuration file')
    parser.add_argument('--task_spec', type=str, required=True,
                       help='Path to task specification file')
    parser.add_argument('--output_dir', type=str, required=True,
                       help='Output directory for generated queries')
    parser.add_argument('--report_file', type=str, required=True,
                       help='Path to save generation report')
    
    args = parser.parse_args()
    
    try:
        # Initialize generator
        generator = QueryGenerator(args.api_config, args.task_spec)
        
        # Generate queries for all datasets
        results = generator.generate_all_queries(args.dataset_root, args.output_dir)
        
        # Save generation report
        with open(args.report_file, 'w') as f:
            json.dump(results, f, indent=2)
        
        print(f"\\nQuery generation completed!")
        print(f"Total queries generated: {results['generation_summary']['total_queries']}")
        print(f"Datasets processed: {len(results['generation_summary']['datasets_processed'])}")
        print(f"Report saved to: {args.report_file}")
        
        # Exit code based on success
        if results['generation_summary']['failed_generations'] == 0:
            sys.exit(0)
        elif results['generation_summary']['successful_generations'] > 0:
            sys.exit(2)  # Partial success
        else:
            sys.exit(1)  # Failure
        
    except Exception as e:
        print(f"Query generation failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()