# cli.py
from .scraper import run as run_scraper
from playwright.__main__ import main as _pw_main
import sys

def playwright_install():
    # Equivalent to: playwright install chromium
    sys.argv = ["playwright", "install", "chromium"]
    _pw_main()

def main():
    # Run the scraper
    run_scraper()
