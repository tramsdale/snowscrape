#!/usr/bin/env python
"""
Ski Forecast Generator using ChatGPT
Generates HTML and markdown ski forecasts from Snow API data.
"""
import json
import os
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, Any, List
import openai


class SkiForecastGenerator:
    """Generate ski forecasts using ChatGPT and Snow API data."""
    
    def __init__(self, openai_api_key: Optional[str] = None):
        """
        Initialize the forecast generator.
        
        Args:
            openai_api_key: OpenAI API key. If not provided, looks for 
                           OPENAI_API_KEY environment variable.
        """
        self.client = None
        
        # Get API key from parameter or environment
        api_key = openai_api_key or os.getenv('OPENAI_API_KEY')
        
        if api_key:
            self.client = openai.OpenAI(api_key=api_key)
            print("✅ OpenAI API configured")
        else:
            print("❌ OpenAI API not configured. Set OPENAI_API_KEY "
                  "environment variable or pass api_key parameter.")
    
    def load_hourly_forecast(self, data_dir: str = "out_snow") -> Dict[str, List[Dict]]:
        """
        Load hourly forecast data from elevation-specific JSON files.
        
        Args:
            data_dir: Directory containing forecast data files
            
        Returns:
            Dictionary with elevation keys and forecast data lists
        """
        elevation_data = {}
        elevations = ['top', 'mid', 'bot']
        
        for elevation in elevations:
            forecast_file = Path(data_dir) / f"hourly_forecast_{elevation}.json"
            
            if forecast_file.exists():
                with open(forecast_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                elevation_data[elevation] = data
                print(f"✅ Loaded {len(data)} hourly forecast entries for {elevation}")
            else:
                print(f"⚠️  No forecast file found for {elevation}: {forecast_file}")
        
        # Fallback to legacy file if no elevation-specific files found
        if not elevation_data:
            legacy_file = Path(data_dir) / "hourly_forecast.json"
            if legacy_file.exists():
                with open(legacy_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                elevation_data['mid'] = data  # Assume legacy is mid elevation
                print(f"✅ Loaded {len(data)} hourly forecast entries (legacy format)")
            else:
                raise FileNotFoundError(
                    f"No hourly forecast files found in {data_dir}"
                )
        
        return elevation_data
    
    def create_forecast_data_file(self, elevation_data: Dict[str, List[Dict]]) -> str:
        """
        Create a temporary JSON file with elevation forecast data.
        
        Args:
            elevation_data: Dictionary with elevation keys and forecast data
            
        Returns:
            Path to the temporary file
        """
        import tempfile
        temp_file = tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False)
        json.dump(elevation_data, temp_file, indent=2)
        temp_file.close()
        return temp_file.name
    
    def create_forecast_prompt(self, elevation_data: Dict[str, List[Dict]]) -> str:
        """
        Create the ChatGPT prompt for multi-elevation data (references uploaded file).
        
        Args:
            elevation_data: Dictionary with elevation keys and forecast data
            
        Returns:
            String containing the formatted prompt
        """
        # Determine if we should include "Today" based on current time
        current_hour = datetime.now().hour
        include_today = current_hour < 14  # Before 2 PM
        
        today_text = "Today, " if include_today else ""
        
        # Build elevation info text
        elevations_available = list(elevation_data.keys())
        elevation_info = f"Elevations available: {', '.join(elevations_available).upper()}"
        
        prompt = f"""Using the multi-elevation ski forecast JSON data I've uploaded, create a comprehensive {today_text}Tomorrow and next 7 days ski forecast in both HTML and Markdown formats.

{elevation_info}

The uploaded JSON contains hourly forecast data for each elevation. Use this data to provide elevation-specific recommendations and highlight differences between mountain elevations (e.g., better snow conditions at top, warmer temperatures at bottom, wind exposure at different levels).

Firstly, check whether the resort is open, and tailor your forecast accordingly.

Structure your forecast with these sections:
{f"- {today_text}" if include_today else ""}
- Tomorrow  
- Day after Tomorrow
- Next 7 Days (summary)

For each day section, include:
- Day of week and date in heading
- Conversational summary of skiing conditions with elevation-specific advice
- Temperature ranges for different elevations
- Snowfall amounts and timing, noting elevation differences  
- Wind conditions and elevation exposure
- Weather conditions at different elevations
- Elevation-specific recommendations (top for powder, mid for groomers, etc.)
- Special notes (avalanche risk, grooming status, etc.)

Use engaging ski language: pow, bluebird, corduroy, sick, etc.
Use HTML formatting elements (headings, lists, bold) for the HTML version.

Format your response exactly as:
## HTML Version
[Your complete HTML forecast here]

## Markdown Version  
[Your complete Markdown forecast here]"""
        
        return prompt
    
    def generate_forecast_with_chatgpt(
        self, 
        elevation_data: Dict[str, List[Dict]]
    ) -> Optional[Dict[str, str]]:
        """
        Generate HTML and markdown forecasts using ChatGPT.
        
        Args:
            elevation_data: Dictionary with elevation keys and forecast data
            
        Returns:
            Dictionary with 'html', 'markdown', and 'raw' keys
        """
        if not self.client:
            print("❌ OpenAI client not initialized")
            return None
        
        # Create temporary file with forecast data
        json_file_path = self.create_forecast_data_file(elevation_data)
        prompt = self.create_forecast_prompt(elevation_data)
        
        try:
            print("🤖 Generating forecast with ChatGPT...")
            print(f"📎 Uploading forecast data file: {json_file_path}")
            
            # Upload the file to OpenAI
            with open(json_file_path, 'rb') as f:
                file_upload = self.client.files.create(
                    file=f,
                    purpose="assistants"
                )
            
            print(f"✅ File uploaded with ID: {file_upload.id}")
            
            response = self.client.chat.completions.create(
                model="gpt-4o",  # Use GPT-4o for better file handling
                messages=[
                    {
                        "role": "system",
                        "content": ("You are a professional ski resort weather "
                                  "forecaster. Create accurate, detailed, and "
                                  "well-formatted forecasts that help skiers "
                                  "plan their activities. Always separate HTML "
                                  "and Markdown sections clearly with the "
                                  "exact headers requested.")
                    },
                    {
                        "role": "user", 
                        "content": [
                            {
                                "type": "text",
                                "text": prompt
                            }
                        ],
                        "attachments": [
                            {
                                "file_id": file_upload.id,
                                "tools": [{"type": "code_interpreter"}]
                            }
                        ]
                    }
                ],
                temperature=0.3,  # Lower temperature for consistent formatting
                max_tokens=3000   # More tokens for detailed forecast
            )
            
            content = response.choices[0].message.content.strip()
            
            # Parse the response into HTML and Markdown sections
            result = self.parse_chatgpt_response(content)
            
            # Clean up temporary file
            try:
                import os
                os.unlink(json_file_path)
                print(f"🧹 Cleaned up temporary file: {json_file_path}")
            except:
                pass
            
            return result
            
        except Exception as e:
            print(f"❌ ChatGPT API error: {e}")
            # Clean up temporary file even on error
            try:
                import os
                os.unlink(json_file_path)
            except:
                pass
            return None
    
    def parse_chatgpt_response(self, content: str) -> Dict[str, str]:
        """
        Parse ChatGPT response to extract HTML and Markdown sections.
        
        Args:
            content: Raw ChatGPT response
            
        Returns:
            Dictionary with 'html', 'markdown', and 'raw' keys
        """
        lines = content.split('\n')
        
        html_content = []
        markdown_content = []
        current_section = None
        
        for line in lines:
            line_lower = line.lower().strip()
            
            # Check for section headers
            if 'html version' in line_lower or line_lower == '## html':
                current_section = 'html'
                continue
            elif ('markdown version' in line_lower or 
                  line_lower == '## markdown'):
                current_section = 'markdown'
                continue
            
            # Add content to current section
            if current_section == 'html':
                html_content.append(line)
            elif current_section == 'markdown':
                markdown_content.append(line)
        
        # Clean up the content
        html_text = '\n'.join(html_content).strip()
        markdown_text = '\n'.join(markdown_content).strip()
        
        # If parsing failed, try to split by common patterns
        if not html_text or not markdown_text:
            print("⚠️  Could not parse sections clearly, attempting "
                  "alternative parsing...")
            return self.alternative_parse(content)
        
        return {
            'html': html_text,
            'markdown': markdown_text,
            'raw': content
        }
    
    def alternative_parse(self, content: str) -> Dict[str, str]:
        """
        Alternative parsing method if main parsing fails.
        
        Args:
            content: Raw ChatGPT response
            
        Returns:
            Dictionary with 'html', 'markdown', and 'raw' keys
        """
        # Try to find sections by looking for HTML and Markdown indicators
        content_lower = content.lower()
        
        # Look for HTML section
        html_start = -1
        html_end = len(content)
        
        for marker in ['html version', '## html', 'html:', '<html', '<!doctype']:
            pos = content_lower.find(marker)
            if pos != -1:
                html_start = pos
                break
        
        # Look for Markdown section
        md_start = -1
        for marker in ['markdown version', '## markdown', 'markdown:', '# ']:
            pos = content_lower.find(marker)
            if pos != -1 and pos > html_start:
                md_start = pos
                if html_start != -1:
                    html_end = pos
                break
        
        html_content = ""
        markdown_content = ""
        
        if html_start != -1:
            html_content = content[html_start:html_end].strip()
        
        if md_start != -1:
            markdown_content = content[md_start:].strip()
        
        # If we still can't parse, return the whole content for both
        if not html_content and not markdown_content:
            print("⚠️  Using full content for both HTML and Markdown")
            return {
                'html': content,
                'markdown': content,
                'raw': content
            }
        
        return {
            'html': html_content,
            'markdown': markdown_content,
            'raw': content
        }
    
    def save_forecasts(
        self, 
        forecasts: Dict[str, str], 
        output_dir: str = "generated_forecasts"
    ) -> Dict[str, str]:
        """
        Save generated forecasts to files.
        
        Args:
            forecasts: Dictionary with forecast content
            output_dir: Directory to save files
            
        Returns:
            Dictionary with file paths
        """
        # Create output directory if it doesn't exist
        output_path = Path(output_dir)
        output_path.mkdir(exist_ok=True)
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Save HTML forecast
        html_file = output_path / f'ski_forecast_{timestamp}.html'
        with open(html_file, 'w', encoding='utf-8') as f:
            # Add basic HTML structure if not present
            html_content = forecasts['html']
            if not html_content.strip().startswith('<'):
                html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ski Forecast - {datetime.now().strftime("%Y-%m-%d")}</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 40px; }}
        .forecast {{ max-width: 800px; margin: 0 auto; }}
        .day {{ margin: 20px 0; padding: 15px; border-left: 4px solid #0066cc; }}
        .temperature {{ font-weight: bold; color: #0066cc; }}
        .conditions {{ margin: 10px 0; }}
    </style>
</head>
<body>
    <div class="forecast">
        {html_content}
    </div>
</body>
</html>"""
            f.write(html_content)
        
        # Save Markdown forecast
        md_file = output_path / f'ski_forecast_{timestamp}.md'
        with open(md_file, 'w', encoding='utf-8') as f:
            f.write(forecasts['markdown'])
        
        # Save raw response for debugging
        raw_file = output_path / f'ski_forecast_raw_{timestamp}.txt'
        with open(raw_file, 'w', encoding='utf-8') as f:
            f.write(forecasts['raw'])
        
        print(f"💾 HTML forecast saved: {html_file}")
        print(f"💾 Markdown forecast saved: {md_file}")
        print(f"💾 Raw response saved: {raw_file}")
        
        return {
            'html_file': str(html_file),
            'markdown_file': str(md_file),
            'raw_file': str(raw_file)
        }
    
    def generate_forecast(
        self, 
        data_dir: str = "out_snow",
        output_dir: str = "generated_forecasts",
        save_output: bool = True
    ) -> Optional[Dict[str, Any]]:
        """
        Main method to generate ski forecast.
        
        Args:
            data_dir: Directory containing forecast data
            output_dir: Directory to save output files
            save_output: Whether to save output files
            
        Returns:
            Dictionary with generated forecasts and file paths
        """
        print("🎿 Starting ski forecast generation...")
        
        try:
            # Load elevation-specific forecast data
            print(f"📡 Loading forecast data from {data_dir}...")
            elevation_data = self.load_hourly_forecast(data_dir)
            
            # Generate forecasts with ChatGPT
            forecasts = self.generate_forecast_with_chatgpt(elevation_data)
            
            if not forecasts:
                print("❌ Failed to generate forecasts")
                return None
            
            print("✅ Forecasts generated successfully")
            
            # Save output files
            if save_output:
                file_paths = self.save_forecasts(forecasts, output_dir)
                forecasts.update(file_paths)
            
            return forecasts
            
        except FileNotFoundError as e:
            print(f"❌ Data file error: {e}")
            return None
        except Exception as e:
            print(f"❌ Unexpected error: {e}")
            return None


def main():
    """Main function to run the forecast generator."""
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Generate ski forecasts using ChatGPT'
    )
    parser.add_argument(
        '--data-dir', 
        default='out_snow',
        help='Directory containing forecast data (default: out_snow)'
    )
    parser.add_argument(
        '--output-dir', 
        default='generated_forecasts',
        help='Directory to save output files (default: generated_forecasts)'
    )
    parser.add_argument(
        '--no-save', 
        action='store_true',
        help='Don\'t save output files, just print to console'
    )
    parser.add_argument(
        '--api-key',
        help='OpenAI API key (or set OPENAI_API_KEY environment variable)'
    )
    
    args = parser.parse_args()
    
    # Create generator
    generator = SkiForecastGenerator(openai_api_key=args.api_key)
    
    if not generator.client:
        print("❌ Cannot proceed without OpenAI API key")
        return 1
    
    # Generate forecasts
    forecasts = generator.generate_forecast(
        data_dir=args.data_dir,
        output_dir=args.output_dir,
        save_output=not args.no_save
    )
    
    if forecasts:
        print("\n" + "="*60)
        print("✅ FORECAST GENERATION COMPLETE!")
        print("="*60)
        
        if not args.no_save:
            print(f"📁 Files saved to: {args.output_dir}")
            print(f"🌐 HTML: {forecasts.get('html_file', 'Not saved')}")
            print(f"📝 Markdown: {forecasts.get('markdown_file', 'Not saved')}")
        else:
            print("\n📄 MARKDOWN FORECAST:")
            print("-" * 40)
            print(forecasts['markdown'])
            print("\n🌐 HTML FORECAST:")
            print("-" * 40)
            print(forecasts['html'])
        
        return 0
    else:
        print("❌ Failed to generate forecasts")
        return 1


if __name__ == "__main__":
    exit(main())