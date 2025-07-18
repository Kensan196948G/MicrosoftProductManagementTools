"""CSV report generator."""

import csv
import logging
from typing import List, Dict, Any
from pathlib import Path


class CSVGenerator:
    """CSV report generator with UTF8-BOM encoding for Excel compatibility."""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
    
    def generate(self, data: List[Dict[str, Any]], output_path: str) -> bool:
        """
        Generate CSV report from data.
        
        Args:
            data: List of dictionaries containing report data
            output_path: Path to save the CSV file
            
        Returns:
            True if successful, False otherwise
        """
        try:
            if not data:
                self.logger.warning("No data provided for CSV generation")
                return False
            
            # Ensure output directory exists
            Path(output_path).parent.mkdir(parents=True, exist_ok=True)
            
            # Get all unique keys from all records for headers
            headers = set()
            for record in data:
                headers.update(record.keys())
            headers = sorted(list(headers))
            
            # Write CSV with UTF8-BOM encoding for Excel compatibility
            with open(output_path, 'w', newline='', encoding='utf-8-sig') as csvfile:
                writer = csv.DictWriter(csvfile, fieldnames=headers)
                writer.writeheader()
                
                for record in data:
                    # Ensure all fields have values
                    clean_record = {}
                    for header in headers:
                        value = record.get(header, '')
                        # Convert complex objects to string
                        if isinstance(value, (list, dict)):
                            value = str(value)
                        clean_record[header] = value
                    
                    writer.writerow(clean_record)
            
            self.logger.info(f"CSV report generated successfully: {output_path}")
            self.logger.info(f"Records written: {len(data)}")
            
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to generate CSV report: {e}")
            return False
    
    def generate_summary_csv(self, data: List[Dict[str, Any]], output_path: str, 
                           group_by_field: str = None) -> bool:
        """
        Generate summary CSV report.
        
        Args:
            data: Source data
            output_path: Output file path
            group_by_field: Field to group by for summary
            
        Returns:
            True if successful
        """
        try:
            if not data:
                return False
            
            summary_data = []
            
            if group_by_field and group_by_field in data[0]:
                # Group by specified field
                groups = {}
                for record in data:
                    key = record.get(group_by_field, 'Unknown')
                    if key not in groups:
                        groups[key] = []
                    groups[key].append(record)
                
                for group_name, group_records in groups.items():
                    summary_data.append({
                        'カテゴリ': group_name,
                        '件数': len(group_records),
                        '割合': f"{len(group_records) / len(data) * 100:.1f}%"
                    })
            else:
                # Simple count summary
                summary_data.append({
                    '項目': 'レポート総件数',
                    '値': len(data),
                    '生成日時': str(Path(output_path).stem)
                })
            
            return self.generate(summary_data, output_path)
            
        except Exception as e:
            self.logger.error(f"Failed to generate summary CSV: {e}")
            return False