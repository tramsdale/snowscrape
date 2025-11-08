#!/usr/bin/env python3
# snow_forecast_scraper.py
import os, json, time, re, pathlib
from io import StringIO
from bs4 import BeautifulSoup
import pandas as pd
from dotenv import load_dotenv

from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout

load_dotenv()

SNOW_USER  = os.getenv("SNOW_USER")  # No default - must be provided
SNOW_PASS  = os.getenv("SNOW_PASS")  # No default - must be provided
TARGET_URL = os.getenv("TARGET_URL", "https://www.snow-forecast.com/resorts/Avoriaz/12day/mid")
BASE_URL = "https://www.snow-forecast.com/resorts/Avoriaz/12day"
STORAGE    = "snow_state.json"

# Mountain elevation endpoints
ELEVATIONS = {
    'top': f"{BASE_URL}/top",
    'mid': f"{BASE_URL}/mid", 
    'bot': f"{BASE_URL}/bot"
}

OUT_DIR = pathlib.Path("out_snow")
OUT_DIR.mkdir(exist_ok=True)

LOGIN_URL = "https://www.snow-forecast.com/login"

def wait_and_type(page, selector, text, timeout=15000):
    page.wait_for_selector(selector, timeout=timeout)
    page.fill(selector, text)

def ensure_login(context):
    """
    Re-uses storage_state if present; otherwise performs a fresh login.
    Returns the page object for continued use.
    """
    # Try with existing storage first
    try:
        page = context.new_page()
        page.goto(TARGET_URL, wait_until="domcontentloaded")
        print(f"After navigating to {TARGET_URL}, current URL: {page.url}")
        
        # If redirected to login or content gated, we'll see the login form.
        if "login" not in page.url.lower():
            # looks logged in
            print("Already logged in, no need to login again")
            return page

        print("Not logged in, proceeding with login...")
        # Not logged; go to dedicated login page
        page.goto(LOGIN_URL, wait_until="domcontentloaded")
        try:
            page.get_by_role("button", name=re.compile(r"accept", re.I)).click(timeout=3000)
            print("Clicked accept button")
        except PWTimeout:
            print("No accept button found or timeout")
            pass
        
        # Target specific login form fields (found from inspection)
        email_sel = 'input[name="member[user_name]"]'
        pass_sel = 'input[name="member[user_password]"]'

        # Check if the login form fields exist
        if (not page.query_selector(email_sel) or
                not page.query_selector(pass_sel)):
            raise RuntimeError("Could not locate login form fields. "
                               "UI may have changed.")

        if not SNOW_USER or not SNOW_PASS:
            raise RuntimeError("Missing SNOW_USER/SNOW_PASS environment variables.")

        print("Filling login form...")
        wait_and_type(page, email_sel, SNOW_USER)
        wait_and_type(page, pass_sel, SNOW_PASS)

        # Debug: Let's see what submit buttons are available
        all_buttons = page.query_selector_all('button')
        print(f"Found {len(all_buttons)} buttons on the page:")
        for i, btn in enumerate(all_buttons):
            btn_type = btn.get_attribute('type')
            btn_text = btn.text_content()[:50] if btn.text_content() else ''
            btn_class = btn.get_attribute('class')
            btn_id = btn.get_attribute('id')
            print(f"  Button {i+1}: type='{btn_type}' text='{btn_text}' class='{btn_class}' id='{btn_id}'")

        # Look for a submit button (prioritize the login form submit button)
        submit_candidates = [
            '#login-continue',  # The specific login submit button ID
            'button.sign-in_large--red',  # The login submit button class
            'button.js-login-submit',  # Another class for the login button
            'button[type="submit"]:has-text("Sign in")',  # Submit button with sign in text
            'form[action="/login"] button[type="submit"]',  # Submit button within login form
            'button[type="submit"]',  # Generic submit button (last resort)
            'input[type="submit"]',
            'button:has-text("Sign in")',
            'button:has-text("Log in")',
            'button:has-text("Sign In")',
            'text="Sign in"',
            'text="Log in"',
        ]
        clicked = False
        for sel in submit_candidates:
            el = page.query_selector(sel)
            if el:
                print(f"Found submit button with selector: {sel}")
                print(f"Button text: '{el.text_content()}'")
                print(f"Button visible: {el.is_visible()}")
                print(f"Button enabled: {el.is_enabled()}")
                print(f"Clicking submit button: {sel}")
                el.click()
                clicked = True
                break
            else:
                print(f"Submit button not found with selector: {sel}")
                
        if not clicked:
            print("No submit button found with any selector, pressing Enter in password field")
            # fallback: press Enter in password field
            page.press(pass_sel, "Enter")

        # Wait a bit for the form submission to process
        page.wait_for_timeout(3000)
        print(f"After form submission, current URL: {page.url}")
        
        # Check if we were redirected away from login (success indicator)
        if "/login" not in page.url.lower():
            print("Successfully redirected away from login page!")
            # Save authenticated state
            context.storage_state(path=STORAGE)
            print(f"Saved authentication state to {STORAGE}")
            
            # Now navigate to the target URL in the same page
            print(f"Navigating to target URL: {TARGET_URL}")
            page.goto(TARGET_URL, wait_until="domcontentloaded")
            print(f"Current URL after navigating to target: {page.url}")
            
            return page
        
        # If still on login page, check for errors
        print("Still on login page, checking for errors...")
        
        # Check for login errors immediately after form submission
        error_element = page.query_selector('.js-login-error')
        if error_element and error_element.is_visible():
            error_text = error_element.text_content()
            print(f"Login error found: {error_text}")
            raise RuntimeError(f"Login failed: {error_text}")
        
        # Check if form is still visible (indicates login failure)
        if page.query_selector('input[name="member[user_name]"]'):
            print("Login form still visible - login may have failed")
            # Save the page content to see what error messages are there
            debug_html = page.content()
            (OUT_DIR / "login_debug.html").write_text(debug_html, encoding="utf-8")
            print("Saved login debug HTML to out_snow/login_debug.html")
            
            # Check for logged_in status in the page
            if '"logged_in":false' in debug_html or '"loggedIn":false' in debug_html:
                print("Page indicates logged_in: false - credentials are incorrect")
                raise RuntimeError("Login failed - incorrect credentials")
            
            # Look for specific error messages
            error_selectors = [
                '.js-login-error',
                '.login__error',
                '.error',
                '.alert',
                '.message'
            ]
            for sel in error_selectors:
                error_el = page.query_selector(sel)
                if error_el and error_el.is_visible():
                    error_text = error_el.text_content().strip()
                    if error_text:
                        print(f"Found error with selector {sel}: {error_text}")
                        raise RuntimeError(f"Login failed: {error_text}")
            
            # Check the page text for common error phrases
            page_text = debug_html.lower()
            error_phrases = [
                "invalid email",
                "invalid username", 
                "incorrect password",
                "login failed",
                "authentication failed",
                "wrong password",
                "user not found"
            ]
            for phrase in error_phrases:
                if phrase in page_text:
                    print(f"Found error phrase: {phrase}")
                    raise RuntimeError(f"Login failed: {phrase}")
                    
            print("No specific error found, but login form still present")
            raise RuntimeError("Login failed - form still visible, likely invalid credentials")

        # If we get here, we should try waiting for navigation
        print("Waiting for login redirect...")
        try:
            page.wait_for_url(lambda url: "/my" in url or "/login" not in url, timeout=15000)
            print(f"Login successful! New URL: {page.url}")
        except PWTimeout:
            print(f"Timeout waiting for redirect, current URL: {page.url}")
            raise RuntimeError("Login failed - no redirect detected")

        # Save authenticated state
        context.storage_state(path=STORAGE)
        print(f"Saved authentication state to {STORAGE}")
        
        # Now navigate to the target URL in the same page
        print(f"Navigating to target URL: {TARGET_URL}")
        page.goto(TARGET_URL, wait_until="domcontentloaded")
        print(f"Current URL after navigating to target: {page.url}")
        
        return page

    except Exception as e:
        print(f"Error during login: {e}")
        raise

def fetch_html(context, url: str) -> str:
    page = context.new_page()
    print(f"Navigating to forecast page: {url}")
    page.goto(url, wait_until="domcontentloaded")
    print(f"Current URL after navigation: {page.url}")
    
    # Let dynamic content render a bit (ads/JS). Increase if needed.
    page.wait_for_timeout(1500)
    # If content loads async, try "networkidle" as a fallback:
    try:
        page.wait_for_load_state("networkidle", timeout=5000)
    except PWTimeout:
        pass

    html = page.content()
    print(f"HTML content length: {len(html)} characters")
    
    # Check if we're still on a login page
    if "login" in page.url.lower() or "member[user_name]" in html:
        print("WARNING: Still on login page or redirected to login!")
    else:
        print("Successfully loaded forecast page")
    
    # Save raw HTML for debugging
    (OUT_DIR / "raw_forecast.html").write_text(html, encoding="utf-8")
    page.close()
    return html

def extract_tables(html: str) -> list[pd.DataFrame]:
    soup = BeautifulSoup(html, "lxml")

    # Find all tables first
    all_tables = soup.find_all("table")
    print(f"Found {len(all_tables)} tables in HTML")

    # Collect all tables; Snow-Forecast often uses multiple forecast tables.
    dfs = []
    for i, tbl in enumerate(all_tables):
        # Skip layout/empty tables
        # Keep tables that contain weather terms
        txt = tbl.get_text(" ", strip=True).lower()
        print(f"Table {i+1} text preview: {txt[:200]}...")
        
        if any(k in txt for k in [
            "snow", "cm", "forecast", "rain", "wind", "temp", "freezing", "day"
        ]):
            print(f"Table {i+1} contains weather terms, attempting to parse...")
            try:
                df = pd.read_html(StringIO(str(tbl)), flavor="lxml")[0]
                if df is not None and df.shape[0] > 0:
                    print(f"Successfully parsed table {i+1}: {df.shape}")
                    dfs.append(df)
                else:
                    print(f"Table {i+1} is empty")
            except ValueError as e:
                print(f"Failed to parse table {i+1}: {e}")
                continue
        else:
            print(f"Table {i+1} does not contain weather terms, skipping")
    
    print(f"Total tables extracted: {len(dfs)}")
    return dfs

def guess_snow_columns(df: pd.DataFrame) -> list:
    cols = []
    for c in df.columns:
        cstr = " ".join(map(str, c)) if isinstance(c, tuple) else str(c)
        if re.search(r"\b(snow|cm|fresh)\b", cstr.lower()):
            cols.append(c)
    return cols

def extract_hourly_forecast_data(page):
    """Extract hourly forecast data by clicking the 'view hourly' button."""
    hourly_data = []
    
    try:
        # Look for the global "view hourly" button
        hourly_button_selector = 'button[data-table-expand-all]'
        hourly_button = page.query_selector(hourly_button_selector)
        
        if not hourly_button:
            print("Hourly expand button not found")
            return hourly_data
        
        print("Found 'view hourly' button, clicking to expand...")
        hourly_button.click()
        
        # Wait for the hourly data to load
        page.wait_for_timeout(2000)
        
        # Get the updated HTML with hourly data
        hourly_html = page.content()
        
        # Save the hourly HTML for debugging
        hourly_html_path = OUT_DIR / "raw_hourly_forecast.html"
        hourly_html_path.write_text(hourly_html, encoding="utf-8")
        
        # Parse the hourly data
        soup = BeautifulSoup(hourly_html, "lxml")
        hourly_data = extract_dynamic_forecast_data(soup)
        
        print(f"Extracted {len(hourly_data)} hourly forecast periods")
        
        return hourly_data
        
    except Exception as e:
        print(f"Error extracting hourly data: {e}")
        return hourly_data


def extract_dynamic_forecast_data(soup):
    """Extract data from the dynamic interactive forecast table."""
    forecast_data = []
    
    # Find the main forecast table
    forecast_table = soup.find('table', class_='forecast-table__table')
    if not forecast_table:
        print("No dynamic forecast table found")
        return forecast_data
    
    # Extract column headers (dates and times)
    date_headers = []
    time_headers = []
    
    # Get date row
    date_row = forecast_table.find('tr', {'data-row': 'days'})
    if date_row:
        for cell in date_row.find_all('td', class_='forecast-table-days__cell'):
            date_text = cell.get('data-date', '')
            day_name = cell.find('div', class_='forecast-table-days__name')
            day_num = cell.find('div', class_='forecast-table-days__date')
            if day_name and day_num:
                date_headers.append({
                    'date': date_text,
                    'day_name': day_name.get_text(strip=True),
                    'day_num': day_num.get_text(strip=True),
                    'colspan': int(cell.get('colspan', 1))
                })
    
    # Get time row
    time_row = forecast_table.find('tr', {'data-row': 'time'})
    if time_row:
        for cell in time_row.find_all('td'):
            # First try to find span with class 'en' (original format)
            time_text = cell.find('span', class_='en')
            if time_text:
                time_headers.append(time_text.get_text(strip=True))
            else:
                # Try to find any span (hourly expanded format)
                time_span = cell.find('span')
                if time_span:
                    time_headers.append(time_span.get_text(strip=True))
                else:
                    # Fallback to cell text content
                    time_content = cell.get_text(strip=True)
                    if time_content:
                        time_headers.append(time_content)
    
    # Extract weather data rows
    weather_rows = {
        'weather': forecast_table.find('tr', {'data-row': 'weather'}),
        'phrases': forecast_table.find('tr', {'data-row': 'phrases'}),
        'wind': forecast_table.find('tr', {'data-row': 'wind'}),
        'snow': forecast_table.find('tr', {'data-row': 'snow'}),
        'rain': forecast_table.find('tr', {'data-row': 'rain'}),
        'temperature-max': forecast_table.find('tr', {'data-row': 'temperature-max'}),
        'temperature-min': forecast_table.find('tr', {'data-row': 'temperature-min'}),
        'temperature-chill': forecast_table.find('tr', {'data-row': 'temperature-chill'}),
        'humidity': forecast_table.find('tr', {'data-row': 'humidity'}),
        'freezing-level': forecast_table.find('tr', {'data-row': 'freezing-level'}),
    }
    
    # Build forecast periods
    period_idx = 0
    
    for date_header in date_headers:
        for period in range(date_header['colspan']):
            if period_idx < len(time_headers):
                period_data = {
                    'date': date_header['date'],
                    'day_name': date_header['day_name'],
                    'day_num': date_header['day_num'],
                    'time_period': time_headers[period_idx],
                    'period_index': period_idx
                }
                
                # Extract data from each row
                for row_name, row in weather_rows.items():
                    if row:
                        cells = row.find_all('td')
                        if period_idx < len(cells):
                            cell = cells[period_idx]
                            
                            if row_name == 'weather':
                                img = cell.find('img', class_='weather-icon')
                                if img:
                                    period_data['weather_icon'] = img.get('alt', '')
                                    period_data['weather_icon_src'] = img.get('src', '')
                            
                            elif row_name == 'phrases':
                                phrase = cell.find('span', class_='forecast-table__phrase')
                                if phrase:
                                    period_data['weather_phrase'] = phrase.get_text(strip=True)
                            
                            elif row_name == 'wind':
                                wind_icon = cell.find('div', class_='wind-icon')
                                if wind_icon:
                                    speed = wind_icon.get('data-speed', '')
                                    direction_tooltip = wind_icon.find('div', class_='wind-icon__tooltip')
                                    speed_text = wind_icon.find('text', class_='wind-icon__val')
                                    
                                    period_data['wind_speed'] = speed
                                    if direction_tooltip:
                                        period_data['wind_direction'] = direction_tooltip.get_text(strip=True)
                                    if speed_text:
                                        period_data['wind_speed_display'] = speed_text.get_text(strip=True)
                            
                            elif row_name == 'snow':
                                snow_amount = cell.find('div', class_='snow-amount')
                                if snow_amount:
                                    snow_value = snow_amount.get('data-value', '')
                                    snow_text = snow_amount.find('span', class_='snow-amount__value')
                                    if snow_value:
                                        period_data['snow_amount'] = snow_value
                                    elif snow_text:
                                        period_data['snow_amount'] = snow_text.get_text(strip=True)
                                    else:
                                        period_data['snow_amount'] = snow_amount.get_text(strip=True)
                            
                            elif row_name == 'rain':
                                rain_amount = cell.find('div', class_='rain-amount')
                                if rain_amount:
                                    rain_value = rain_amount.get('data-value', '')
                                    rain_text = rain_amount.find('span', class_='rain-amount__value')
                                    if rain_value:
                                        period_data['rain_amount'] = rain_value
                                    elif rain_text:
                                        period_data['rain_amount'] = rain_text.get_text(strip=True)
                                    else:
                                        period_data['rain_amount'] = rain_amount.get_text(strip=True)
                            
                            elif row_name in ['temperature-max', 'temperature-min', 'temperature-chill']:
                                temp_value = cell.get('data-value', '')
                                temp_text = cell.get_text(strip=True)
                                if temp_value:
                                    period_data[row_name.replace('-', '_')] = temp_value
                                else:
                                    period_data[row_name.replace('-', '_')] = temp_text
                            
                            elif row_name == 'humidity':
                                humidity_text = cell.find('span')
                                if humidity_text:
                                    period_data['humidity'] = humidity_text.get_text(strip=True)
                            
                            elif row_name == 'freezing-level':
                                level_value = cell.find('div', class_='level-value')
                                if level_value:
                                    freeze_value = level_value.get('data-value', '')
                                    freeze_text = level_value.get_text(strip=True)
                                    period_data['freezing_level'] = freeze_value or freeze_text
                
                forecast_data.append(period_data)
                period_idx += 1
    
    return forecast_data

def tidy_and_export(dfs: list[pd.DataFrame], 
                    dynamic_forecast_data: list = None,
                    hourly_forecast_data: list = None,
                    elevation_suffix: str = ""):
    # Save all tables
    all_paths = []
    for i, df in enumerate(dfs, start=1):
        p = OUT_DIR / f"table_{i}{elevation_suffix}.csv"
        df.to_csv(p, index=False)
        all_paths.append(str(p))

    # Try to build a compact “snow focused” export
    snow_frames = []
    for df in dfs:
        snow_cols = guess_snow_columns(df)
        if snow_cols:
            # Always include any obvious date/day columns alongside snow
            keep = list(snow_cols)
            for c in df.columns:
                cstr = str(c).lower()
                if any(k in cstr for k in ["day", "date", "time", "period"]):
                    if c not in keep:
                        keep.append(c)
            snow_frames.append(df[keep])

    summary = {}
    if snow_frames:
        snow_cat = pd.concat(snow_frames, ignore_index=True)
        csv_path = OUT_DIR / f"snow_summary{elevation_suffix}.csv"
        json_path = OUT_DIR / f"snow_summary{elevation_suffix}.json"
        snow_cat.to_csv(csv_path, index=False)
        summary["snow_summary_csv"] = str(csv_path)
        # Also try JSON (records)
        snow_cat.to_json(json_path, orient="records", force_ascii=False)
        summary["snow_summary_json"] = str(json_path)

    # Export dynamic forecast data if available
    if dynamic_forecast_data:
        print(f"Exporting {len(dynamic_forecast_data)} periods")
        dynamic_df = pd.DataFrame(dynamic_forecast_data)
        dyn_csv = OUT_DIR / f"dynamic_forecast{elevation_suffix}.csv"
        dyn_json = OUT_DIR / f"dynamic_forecast{elevation_suffix}.json"
        dynamic_df.to_csv(dyn_csv, index=False)
        dynamic_df.to_json(dyn_json, orient="records", 
                          force_ascii=False, indent=2)
        summary["dynamic_forecast_csv"] = str(dyn_csv)
        summary["dynamic_forecast_json"] = str(dyn_json)

    # Export hourly forecast data if available
    if hourly_forecast_data:
        print(f"Exporting {len(hourly_forecast_data)} hourly periods")
        hourly_df = pd.DataFrame(hourly_forecast_data)
        hourly_csv = OUT_DIR / f"hourly_forecast{elevation_suffix}.csv"
        hourly_json = OUT_DIR / f"hourly_forecast{elevation_suffix}.json"
        hourly_df.to_csv(hourly_csv, index=False)
        hourly_df.to_json(hourly_json, orient="records", 
                         force_ascii=False, indent=2)
        summary["hourly_forecast_csv"] = str(hourly_csv)
        summary["hourly_forecast_json"] = str(hourly_json)

    meta = {
        "saved_tables": all_paths,
        "summary": summary,
    }
    meta_file = OUT_DIR / f"meta{elevation_suffix}.json"
    meta_file.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    return meta

def scrape_elevation(page, elevation_name, elevation_url):
    """Scrape forecast data from a specific elevation"""
    print(f"Scraping {elevation_name} elevation: {elevation_url}")
    
    # Clear any existing state and navigate fresh
    try:
        # First, navigate to base snow-forecast.com to ensure session is active
        print(f"Pre-loading base domain for session persistence...")
        page.goto("https://www.snow-forecast.com/", wait_until="domcontentloaded")
        page.wait_for_timeout(1000)
        
        # Now navigate to the specific elevation
        print(f"Navigating to {elevation_name} elevation...")
        page.goto(elevation_url, wait_until="domcontentloaded")
        
        # Let dynamic content render a bit (ads/JS). Increase if needed.
        page.wait_for_timeout(3000)  # Increased timeout for full load
        
        # If content loads async, try "networkidle" as a fallback:
        try:
            page.wait_for_load_state("networkidle", timeout=10000)
        except PWTimeout:
            print(f"Network idle timeout for {elevation_name}, continuing...")
            pass
            
    except Exception as e:
        print(f"Navigation error for {elevation_name}: {e}")
        return None

    html = page.content()
    print(f"{elevation_name} HTML content length: {len(html)} characters")
    
    # Check if we have main forecast content (simplified for premium users)
    has_forecast_table = "forecast-table" in html
    has_forecast_days = '<div class="forecast-table-days"' in html
    page_size_ok = len(html) > 150000  # Lowered threshold
    
    if not (has_forecast_table or has_forecast_days) or not page_size_ok:
        print(f"WARNING: {elevation_name} page missing forecast content!")
        print(f"  Forecast table: {has_forecast_table}")
        print(f"  Forecast days: {has_forecast_days}")
        print(f"  Page size OK: {page_size_ok} ({len(html)} chars)")
        print(f"  Current URL: {page.url}")
        
        # Save debug HTML
        (OUT_DIR / f"debug_{elevation_name}_missing_content.html").write_text(html, encoding="utf-8")
        
        # Try a simple page refresh to resolve temporary issues
        print(f"Attempting page refresh for {elevation_name}...")
        try:
            page.reload(wait_until="domcontentloaded")
            page.wait_for_timeout(3000)
            html = page.content()
            
            # Check again
            if "forecast-table" in html and len(html) > 150000:
                print(f"✅ Page refresh successful for {elevation_name}")
            else:
                print(f"❌ Page refresh failed for {elevation_name}")
                return None
                
        except Exception as e:
            print(f"Page refresh error for {elevation_name}: {e}")
            return None
    else:
        print(f"✅ Successfully loaded {elevation_name} forecast page")
    
    # Save raw HTML for debugging
    (OUT_DIR / f"raw_forecast_{elevation_name}.html").write_text(
        html, encoding="utf-8")
    
    # Extract both regular tables and dynamic forecast data
    dfs = extract_tables(html)
    
    # Extract dynamic forecast data from the interactive table
    soup = BeautifulSoup(html, "lxml")
    dynamic_forecast_data = extract_dynamic_forecast_data(soup)
    print(f"Extracted {len(dynamic_forecast_data)} dynamic periods for {elevation_name}")
    
    # Extract hourly forecast data by clicking the hourly button
    hourly_forecast_data = extract_hourly_forecast_data(page)
    
    return {
        'elevation': elevation_name,
        'url': elevation_url,
        'tables': dfs,
        'dynamic_forecast': dynamic_forecast_data,
        'hourly_forecast': hourly_forecast_data,
        'html_length': len(html)
    }


def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        # Reuse cookies if present
        context_args = {}
        if pathlib.Path(STORAGE).exists():
            context_args["storage_state"] = STORAGE
        context = browser.new_context(**context_args)

        # First, try to scrape just the mid elevation to ensure we have working data
        print("=== INITIAL LOGIN AND MID SCRAPING ===")
        page = ensure_login(context)
        
        # Save the authenticated state after successful login
        context.storage_state(path=STORAGE)
        print(f"Saved authentication state to {STORAGE}")
        
        # Verify authentication works by checking current session
        print("Verifying authentication session...")
        cookies = context.cookies()
        auth_cookies = [c for c in cookies if 'session' in c['name'].lower() or 'auth' in c['name'].lower()]
        print(f"Found {len(auth_cookies)} authentication cookies")
        
        # Test that we can navigate between elevation URLs
        print("Testing navigation between elevations...")
        for test_elevation in ['mid', 'top', 'bot']:
            test_url = ELEVATIONS[test_elevation]
            page.goto(test_url, wait_until="domcontentloaded")
            page.wait_for_timeout(1000)
            test_html = page.content()
            has_forecast = "forecast-table" in test_html
            print(f"  {test_elevation}: {'✅' if has_forecast else '❌'} forecast data present")

        # Scrape data from all three elevations, with fallback strategy
        all_elevation_data = {}
        
        # Start with mid (our baseline), then try top/bot if mid succeeds
        elevation_order = ['mid', 'top', 'bot']
        mid_success = False
        
        for elevation_name in elevation_order:
            elevation_url = ELEVATIONS[elevation_name]
            print(f"\n--- Processing {elevation_name.upper()} elevation ---")
            
            # Skip top/bot if mid failed (indicates fundamental auth issues)
            if elevation_name in ['top', 'bot'] and not mid_success:
                print(f"⏭️  Skipping {elevation_name} - mid elevation failed, likely auth issue")
                continue
                
            elevation_data = scrape_elevation(page, elevation_name, elevation_url)
            if elevation_data:
                all_elevation_data[elevation_name] = elevation_data
                if elevation_name == 'mid':
                    mid_success = True
                
                # Export individual elevation data
                meta = tidy_and_export(
                    elevation_data['tables'],
                    elevation_data['dynamic_forecast'], 
                    elevation_data['hourly_forecast'],
                    elevation_suffix=f"_{elevation_name}"
                )
                print(f"✅ Successfully exported {elevation_name} data")
            else:
                print(f"❌ Failed to scrape {elevation_name} elevation")
                
                # For top/bot, this might be normal (premium required)
                if elevation_name in ['top', 'bot']:
                    print(f"ℹ️  {elevation_name.upper()} elevation may require premium access")
                
                # For mid elevation failure, this is critical
                elif elevation_name == 'mid':
                    print("🚨 CRITICAL: Mid elevation failed - trying legacy fallback")
                    # Try legacy single-elevation approach as fallback
                    print("Trying legacy single-elevation scraping...")
                    try:
                        html = page.content()
                        dfs = extract_tables(html)
                        soup = BeautifulSoup(html, "lxml")
                        dynamic_forecast_data = extract_dynamic_forecast_data(soup)
                        hourly_forecast_data = extract_hourly_forecast_data(page)
                        
                        # Export without elevation suffix for backward compatibility
                        legacy_meta = tidy_and_export(dfs, dynamic_forecast_data, 
                                                     hourly_forecast_data)
                        print("✅ Legacy fallback successful")
                        
                        # Also create mid-specific files
                        legacy_meta_mid = tidy_and_export(dfs, dynamic_forecast_data, 
                                                         hourly_forecast_data,
                                                         elevation_suffix="_mid")
                        all_elevation_data['mid'] = {
                            'elevation': 'mid',
                            'url': elevation_url,
                            'tables': dfs,
                            'dynamic_forecast': dynamic_forecast_data,
                            'hourly_forecast': hourly_forecast_data,
                            'html_length': len(html)
                        }
                        print("✅ Legacy data converted to mid elevation format")
                        
                    except Exception as e:
                        print(f"❌ Legacy fallback also failed: {e}")
                        break
        
        # If no elevations were successfully scraped, fall back to single elevation
        if not all_elevation_data:
            print("\n🔄 FALLBACK: No elevation data found, trying simple mid-only scraping...")
            try:
                # Go back to mid URL and scrape normally
                page.goto(TARGET_URL, wait_until="domcontentloaded")
                page.wait_for_timeout(2000)
                
                html = page.content()
                dfs = extract_tables(html)
                soup = BeautifulSoup(html, "lxml")
                dynamic_forecast_data = extract_dynamic_forecast_data(soup)
                hourly_forecast_data = extract_hourly_forecast_data(page)
                
                # Export with legacy naming for compatibility
                fallback_meta = tidy_and_export(dfs, dynamic_forecast_data, 
                                               hourly_forecast_data)
                
                print("✅ Fallback scraping successful!")
                print(f"Fallback data: {json.dumps(fallback_meta, indent=2)}")
                
            except Exception as e:
                print(f"❌ Even fallback scraping failed: {e}")

        # Create combined summary
        combined_meta = {
            'scrape_time': time.strftime('%Y-%m-%d %H:%M:%S'),
            'elevations_scraped': list(all_elevation_data.keys()),
            'elevation_data': {},
            'scrape_mode': 'multi-elevation' if all_elevation_data else 'fallback'
        }
        
        for elevation, data in all_elevation_data.items():
            combined_meta['elevation_data'][elevation] = {
                'url': data['url'],
                'html_length': data['html_length'],
                'dynamic_periods': len(data['dynamic_forecast']),
                'hourly_periods': len(data['hourly_forecast']),
                'tables_found': len(data['tables'])
            }
        
        # Save combined metadata
        (OUT_DIR / "combined_meta.json").write_text(
            json.dumps(combined_meta, indent=2), encoding="utf-8")
        
        print("=== COMBINED SCRAPING SUMMARY ===")
        print(json.dumps(combined_meta, indent=2))
        
        if all_elevation_data:
            print(f"✅ Successfully scraped {len(all_elevation_data)} elevation(s)")
        else:
            print("⚠️  Multi-elevation scraping failed, check fallback results")
        
        page.close()
        context.close()
        browser.close()

if __name__ == "__main__":
    main()

def run():
    main()
