"""
CSV report generator with PowerShell compatibility.
Maintains UTF8-BOM encoding and field formats for compatibility.
"""

import csv
import logging
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any, Optional
import os


class CSVGenerator:
    """
    CSV report generator with PowerShell compatibility.
    Generates CSV files with UTF8-BOM encoding for Excel compatibility.
    """
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
    
    def generate(self, data: List[Dict[str, Any]], output_path: str, 
                 title: Optional[str] = None, metadata: Optional[Dict[str, Any]] = None) -> str:
        """
        Generate CSV report from data.
        
        Args:
            data: List of dictionaries containing report data
            output_path: Path to save the CSV file
            title: Optional title for the report
            metadata: Optional metadata to include in header
            
        Returns:
            Path to generated CSV file
        """
        try:
            # Ensure output directory exists
            output_file = Path(output_path)
            output_file.parent.mkdir(parents=True, exist_ok=True)
            
            # Generate CSV with UTF8-BOM for PowerShell compatibility
            with open(output_file, 'w', encoding='utf-8-sig', newline='') as csvfile:
                if not data:
                    self.logger.warning("No data provided for CSV generation")
                    csvfile.write("# No data available\n")
                    return str(output_file)
                
                # Write metadata header if provided
                if title or metadata:
                    self._write_header(csvfile, title, metadata)
                
                # Get field names from first row
                fieldnames = list(data[0].keys())
                
                # Create CSV writer
                writer = csv.DictWriter(csvfile, fieldnames=fieldnames, 
                                      quoting=csv.QUOTE_MINIMAL, lineterminator='\n')
                
                # Write header row
                writer.writeheader()
                
                # Write data rows
                for row in data:
                    # Clean row data for CSV compatibility
                    cleaned_row = self._clean_row_data(row)
                    writer.writerow(cleaned_row)
            
            self.logger.info(f"CSV report generated: {output_file}")
            return str(output_file)
            
        except Exception as e:
            self.logger.error(f"Failed to generate CSV report: {e}")
            raise
    
    def _write_header(self, csvfile, title: Optional[str], metadata: Optional[Dict[str, Any]]):
        """Write header comments to CSV file."""
        # Add title
        if title:
            csvfile.write(f"# {title}\n")
        
        # Add generation timestamp
        csvfile.write(f"# Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        
        # Add metadata
        if metadata:
            for key, value in metadata.items():
                csvfile.write(f"# {key}: {value}\n")
        
        # Add separator
        csvfile.write("#\n")
    
    def _clean_row_data(self, row: Dict[str, Any]) -> Dict[str, Any]:
        """Clean row data for CSV compatibility."""
        cleaned = {}
        
        for key, value in row.items():
            # Convert None to empty string
            if value is None:
                cleaned[key] = ""
            
            # Convert boolean to Japanese text for compatibility
            elif isinstance(value, bool):
                cleaned[key] = "はい" if value else "いいえ"
            
            # Convert numbers with proper formatting
            elif isinstance(value, (int, float)):
                if isinstance(value, float):
                    # Format floats with appropriate decimal places
                    if value.is_integer():
                        cleaned[key] = str(int(value))
                    else:
                        cleaned[key] = f"{value:.2f}".rstrip('0').rstrip('.')
                else:
                    cleaned[key] = str(value)
            
            # Handle lists and complex types
            elif isinstance(value, (list, tuple)):
                cleaned[key] = ", ".join(str(item) for item in value)
            
            # Handle dictionaries
            elif isinstance(value, dict):
                cleaned[key] = str(value)
            
            # String values - remove newlines and excessive whitespace
            else:
                cleaned[key] = str(value).replace('\n', ' ').replace('\r', '').strip()
        
        return cleaned
    
    def generate_summary_csv(self, data: List[Dict[str, Any]], output_path: str,
                           summary_fields: List[str]) -> str:
        """
        Generate summary CSV with aggregated data.
        
        Args:
            data: Source data
            output_path: Path to save summary CSV
            summary_fields: Fields to include in summary
            
        Returns:
            Path to generated summary CSV file
        """
        try:
            # Calculate summary statistics
            summary_data = self._calculate_summary(data, summary_fields)
            
            # Generate summary CSV
            summary_path = output_path.replace('.csv', '_summary.csv')
            return self.generate(summary_data, summary_path, 
                               title="Summary Report", 
                               metadata={'Total Records': len(data)})
            
        except Exception as e:
            self.logger.error(f"Failed to generate summary CSV: {e}")
            raise
    
    def _calculate_summary(self, data: List[Dict[str, Any]], 
                          summary_fields: List[str]) -> List[Dict[str, Any]]:
        """Calculate summary statistics for specified fields."""
        if not data:
            return []
        
        summary = []
        
        for field in summary_fields:
            values = [row.get(field) for row in data if field in row and row.get(field) is not None]
            
            if not values:
                continue
            
            field_summary = {
                'フィールド名': field,
                'レコード数': len(values),
                '空でない値': len([v for v in values if v != '' and v is not None]),
            }
            
            # Numeric field analysis
            numeric_values = []
            for v in values:
                try:
                    if isinstance(v, (int, float)):
                        numeric_values.append(float(v))
                    elif isinstance(v, str) and v.replace('.', '').replace('-', '').isdigit():
                        numeric_values.append(float(v))
                except (ValueError, TypeError):
                    continue
            
            if numeric_values:
                field_summary.update({
                    '最小値': min(numeric_values),
                    '最大値': max(numeric_values),
                    '平均値': sum(numeric_values) / len(numeric_values),
                    '合計': sum(numeric_values)
                })
            
            # Text field analysis
            text_values = [str(v) for v in values if v != '']
            if text_values:
                unique_values = list(set(text_values))
                field_summary.update({
                    'ユニーク値数': len(unique_values),
                    '最頻値': max(set(text_values), key=text_values.count) if text_values else '',
                })
            
            summary.append(field_summary)
        
        return summary