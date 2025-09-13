#!/usr/bin/env python3
"""
Dataset schema validation for OpenRCA telemetry data
"""
import os
import json
import pandas as pd
import pytz
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Any

class DatasetValidator:
    def __init__(self, base_path: str, expected_structure: Dict):
        self.base_path = Path(base_path)
        self.expected_structure = expected_structure
        self.validation_results = {
            "validation_status": "pending",
            "datasets": {},
            "errors": [],
            "warnings": [],
            "statistics": {}
        }
    
    def validate_all_datasets(self) -> Dict[str, Any]:
        """Validate all datasets in the structure"""
        print(f"Starting validation of datasets in {self.base_path}")
        
        for dataset_name, structure in self.expected_structure.items():
            if dataset_name == "Market":
                # Handle Market subdatasets
                for subname, substructure in structure.items():
                    full_name = f"Market/{subname}"
                    self.validate_dataset(full_name, substructure)
            else:
                self.validate_dataset(dataset_name, structure)
        
        # Calculate overall status
        dataset_statuses = [info["status"] for info in self.validation_results["datasets"].values()]
        if all(status == "valid" for status in dataset_statuses):
            self.validation_results["validation_status"] = "success"
        elif any(status == "valid" for status in dataset_statuses):
            self.validation_results["validation_status"] = "partial"
        else:
            self.validation_results["validation_status"] = "failed"
            
        return self.validation_results
    
    def validate_dataset(self, dataset_name: str, structure: Dict):
        """Validate a single dataset"""
        dataset_path = self.base_path / dataset_name
        dataset_result = {
            "status": "pending",
            "path": str(dataset_path),
            "files_found": [],
            "files_missing": [],
            "telemetry_validation": {},
            "schema_validation": {},
            "statistics": {}
        }
        
        print(f"Validating dataset: {dataset_name}")
        
        # Check if dataset directory exists
        if not dataset_path.exists():
            dataset_result["status"] = "missing"
            dataset_result["error"] = f"Dataset directory not found: {dataset_path}"
            self.validation_results["errors"].append(dataset_result["error"])
            self.validation_results["datasets"][dataset_name] = dataset_result
            return
        
        # Validate required files
        for required_file in structure["files"]:
            file_path = dataset_path / required_file
            if file_path.exists():
                dataset_result["files_found"].append(required_file)
                # Validate CSV schema
                try:
                    schema_result = self.validate_csv_schema(file_path, required_file)
                    dataset_result["schema_validation"][required_file] = schema_result
                except Exception as e:
                    dataset_result["schema_validation"][required_file] = {
                        "status": "error",
                        "error": str(e)
                    }
            else:
                dataset_result["files_missing"].append(required_file)
        
        # Validate telemetry structure
        telemetry_path = dataset_path / "telemetry"
        if telemetry_path.exists():
            dataset_result["telemetry_validation"] = self.validate_telemetry_structure(
                telemetry_path, structure["telemetry_dates"], structure["telemetry_types"]
            )
        else:
            dataset_result["telemetry_validation"] = {
                "status": "missing",
                "error": "Telemetry directory not found"
            }
        
        # Calculate dataset statistics
        dataset_result["statistics"] = self.calculate_dataset_statistics(dataset_path)
        
        # Determine overall dataset status
        if (not dataset_result["files_missing"] and 
            dataset_result["telemetry_validation"].get("status") == "valid"):
            dataset_result["status"] = "valid"
        elif dataset_result["files_found"]:
            dataset_result["status"] = "partial"
        else:
            dataset_result["status"] = "invalid"
        
        self.validation_results["datasets"][dataset_name] = dataset_result
    
    def validate_csv_schema(self, file_path: Path, file_type: str) -> Dict[str, Any]:
        """Validate CSV file schema"""
        try:
            df = pd.read_csv(file_path)
            
            result = {
                "status": "valid",
                "rows": len(df),
                "columns": list(df.columns),
                "memory_usage_mb": df.memory_usage(deep=True).sum() / 1024 / 1024
            }
            
            # Specific validations based on file type
            if file_type == "record.csv":
                result["timestamp_validation"] = self.validate_timestamps(df, "timestamp")
                result["unique_components"] = df["component"].nunique() if "component" in df.columns else 0
                result["unique_reasons"] = df["reason"].nunique() if "reason" in df.columns else 0
                
            elif file_type == "query.csv":
                result["unique_tasks"] = df["task_index"].nunique() if "task_index" in df.columns else 0
                
            return result
            
        except Exception as e:
            return {
                "status": "error",
                "error": str(e)
            }
    
    def validate_telemetry_structure(self, telemetry_path: Path, expected_dates: List[str], 
                                   expected_types: List[str]) -> Dict[str, Any]:
        """Validate telemetry directory structure"""
        result = {
            "status": "pending",
            "dates_found": [],
            "dates_missing": [],
            "type_validation": {}
        }
        
        # Check date directories
        for date in expected_dates:
            date_path = telemetry_path / date
            if date_path.exists():
                result["dates_found"].append(date)
                # Check telemetry types in this date
                for tel_type in expected_types:
                    type_path = date_path / tel_type
                    if type_path.exists():
                        # Count CSV files in this type directory
                        csv_files = list(type_path.glob("*.csv"))
                        if date not in result["type_validation"]:
                            result["type_validation"][date] = {}
                        result["type_validation"][date][tel_type] = {
                            "status": "found",
                            "file_count": len(csv_files),
                            "files": [f.name for f in csv_files]
                        }
                    else:
                        if date not in result["type_validation"]:
                            result["type_validation"][date] = {}
                        result["type_validation"][date][tel_type] = {
                            "status": "missing"
                        }
            else:
                result["dates_missing"].append(date)
        
        # Determine status
        if result["dates_found"] and not result["dates_missing"]:
            result["status"] = "valid"
        elif result["dates_found"]:
            result["status"] = "partial"
        else:
            result["status"] = "missing"
            
        return result
    
    def validate_timestamps(self, df: pd.DataFrame, timestamp_col: str) -> Dict[str, Any]:
        """Validate timestamp format and ranges"""
        if timestamp_col not in df.columns:
            return {"status": "missing_column"}
        
        try:
            timestamps = pd.to_numeric(df[timestamp_col])
            
            # Detect if timestamps are in seconds or milliseconds
            min_ts = timestamps.min()
            max_ts = timestamps.max()
            
            # Assume if timestamp > 1e12, it's in milliseconds
            if min_ts > 1e12:
                unit = "milliseconds"
                min_dt = pd.to_datetime(min_ts, unit='ms', utc=True)
                max_dt = pd.to_datetime(max_ts, unit='ms', utc=True)
            else:
                unit = "seconds"
                min_dt = pd.to_datetime(min_ts, unit='s', utc=True)
                max_dt = pd.to_datetime(max_ts, unit='s', utc=True)
            
            return {
                "status": "valid",
                "unit": unit,
                "min_timestamp": str(min_dt),
                "max_timestamp": str(max_dt),
                "range_days": (max_dt - min_dt).days,
                "total_records": len(timestamps)
            }
            
        except Exception as e:
            return {
                "status": "error",
                "error": str(e)
            }
    
    def calculate_dataset_statistics(self, dataset_path: Path) -> Dict[str, Any]:
        """Calculate overall dataset statistics"""
        stats = {
            "total_size_mb": 0,
            "file_count": 0,
            "csv_file_count": 0
        }
        
        try:
            for file_path in dataset_path.rglob("*"):
                if file_path.is_file():
                    stats["file_count"] += 1
                    stats["total_size_mb"] += file_path.stat().st_size / 1024 / 1024
                    if file_path.suffix == ".csv":
                        stats["csv_file_count"] += 1
        except Exception as e:
            stats["error"] = str(e)
            
        return stats


def main():
    """Main validation function"""
    import sys
    
    if len(sys.argv) != 3:
        print("Usage: python schema_validation.py <dataset_path> <sources_json>")
        sys.exit(1)
    
    dataset_path = sys.argv[1]
    sources_json = sys.argv[2]
    
    # Load expected structure
    with open(sources_json, 'r') as f:
        sources = json.load(f)
    
    expected_structure = sources["expected_structure"]
    
    # Run validation
    validator = DatasetValidator(dataset_path, expected_structure)
    results = validator.validate_all_datasets()
    
    # Output results
    print(json.dumps(results, indent=2))
    
    # Exit with appropriate code
    if results["validation_status"] == "success":
        sys.exit(0)
    elif results["validation_status"] == "partial":
        sys.exit(2)  # Partial success
    else:
        sys.exit(1)  # Failure


if __name__ == "__main__":
    main()