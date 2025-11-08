#!/usr/bin/env python3
"""
Main entry point for snowscrape.

This is a convenience wrapper. For actual scraping, use:
- `python -m snowscrape.cli` (direct module)  
- `scrape` (if installed via pip/uv)

For development, use the CLI module directly.
"""

def main():
    print("🎿 Snow Forecast Scraper")
    print("=" * 40)
    print("This is a convenience entry point.")
    print("To actually run the scraper, use one of:")
    print("  • python -m snowscrape.cli")
    print("  • scrape  (if installed)")
    print("")
    print("Running scraper now...")
    
    try:
        from src.snowscrape.cli import main as cli_main
        cli_main()
    except ImportError:
        print("Error: snowscrape module not found.")
        print("Make sure you're in the project root and dependencies are installed.")
        print("Try: uv sync && python -m snowscrape.cli")


if __name__ == "__main__":
    main()
