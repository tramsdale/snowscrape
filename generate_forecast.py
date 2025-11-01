#!/usr/bin/env python
"""
Command-line script to generate ski forecasts.
"""
import sys
import os
from pathlib import Path

# Add the src directory to Python path so we can import snowscrape modules
current_dir = Path(__file__).parent
src_dir = current_dir / "src"
sys.path.insert(0, str(src_dir))

from snowscrape.forecast_generator import SkiForecastGenerator


def main():
    """Generate ski forecast using existing data."""
    print("🎿 Ski Forecast Generator")
    print("=" * 40)
    
    # Check if API key is available
    api_key = os.getenv('OPENAI_API_KEY')
    if not api_key:
        print("❌ Please set OPENAI_API_KEY environment variable")
        print("   You can set it by adding it to your .env file:")
        print("   OPENAI_API_KEY=your_api_key_here")
        return 1
    
    # Create generator
    generator = SkiForecastGenerator()
    
    if not generator.client:
        return 1
    
    # Check if data directory exists
    data_dir = "out_snow"
    if not Path(data_dir).exists():
        print(f"❌ Data directory '{data_dir}' not found")
        print("   Please run the scraper first to generate data:")
        print("   python main.py")
        return 1
    
    # Generate forecasts
    forecasts = generator.generate_forecast()
    
    if forecasts:
        print("\n🎉 Success! Check the 'generated_forecasts' directory for:")
        print(f"   📝 {Path(forecasts['markdown_file']).name}")
        print(f"   🌐 {Path(forecasts['html_file']).name}")
        return 0
    else:
        print("❌ Failed to generate forecasts")
        return 1


if __name__ == "__main__":
    sys.exit(main())