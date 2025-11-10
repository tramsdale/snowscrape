#!/usr/bin/env python3
"""
Snow Data API Server
Serves snow forecast data as JSON API endpoints
"""

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse, Response
from fastapi.staticfiles import StaticFiles
from pathlib import Path
import json
import uvicorn
import os
from datetime import datetime
from typing import Dict, Any, List, Optional
from dotenv import load_dotenv
from bs4 import BeautifulSoup

# Load environment variables from multiple possible locations
load_dotenv()  # Try default locations first

# Also try to load from project directory explicitly
project_dir = Path(__file__).parent
env_file = project_dir / ".env"
if env_file.exists():
    load_dotenv(env_file)

# Manual fallback for cases where dotenv doesn't work
if not os.getenv('OPENAI_API_KEY') and env_file.exists():
    with open(env_file) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                # Remove quotes if present
                value = value.strip('\'"')
                os.environ[key] = value

app = FastAPI(
    title="Snow Forecast API",
    description="API for serving snow forecast data",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure this properly for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration
DATA_DIR = Path("out_snow")
LOG_DIR = Path("logs")
STATIC_DIR = Path("static")

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

def load_json_file(filename: str) -> Dict[str, Any]:
    """Load JSON file from data directory"""
    file_path = DATA_DIR / filename
    if not file_path.exists():
        raise HTTPException(status_code=404, detail=f"File {filename} not found")
    
    try:
        with open(file_path, 'r') as f:
            return json.load(f)
    except json.JSONDecodeError:
        raise HTTPException(status_code=500, detail=f"Invalid JSON in {filename}")

def get_file_info(filename: str) -> Dict[str, Any]:
    """Get file metadata"""
    file_path = DATA_DIR / filename
    if not file_path.exists():
        return {"exists": False}
    
    stat = file_path.stat()
    return {
        "exists": True,
        "size": stat.st_size,
        "modified": datetime.fromtimestamp(stat.st_mtime).isoformat(),
        "path": str(file_path)
    }

@app.get("/")
async def root():
    """API information and available endpoints"""
    return {
        "name": "Snow Forecast API",
        "version": "1.0.0",
        "endpoints": {
            "/meta": "Scraper metadata and file list",
            "/forecast/dynamic": "Dynamic forecast data",
            "/forecast/hourly": "Hourly forecast data",
            "/forecast/html": "Beautiful HTML forecast with ski theme",
            "/forecast/generate": "Generate HTML/Markdown ski forecast using ChatGPT",
            "/snow/summary": "Snow summary data",
            "/health": "API health check",
            "/files": "List all available files",
            "/files/{filename}": "Download specific file"
        },
        "timestamp": datetime.now().isoformat()
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        # Try to load a small file to test data access
        test_file = DATA_DIR / "meta.json"
        if test_file.exists():
            status = "healthy"
        else:
            status = "no data"
    except:
        status = "error"
    
    # Check OpenAI API key availability (without exposing it)
    has_openai_key = bool(os.getenv('OPENAI_API_KEY'))
    
    return {
        "status": status, 
        "timestamp": datetime.now().isoformat(),
        "openai_configured": has_openai_key
    }

@app.get("/debug/env")
async def debug_env():
    """Debug environment loading (for troubleshooting)"""
    project_dir = Path(__file__).parent
    env_file = project_dir / ".env"
    
    debug_info = {
        "working_directory": str(Path.cwd()),
        "project_directory": str(project_dir),
        "env_file_path": str(env_file),
        "env_file_exists": env_file.exists(),
        "openai_key_set": bool(os.getenv('OPENAI_API_KEY')),
        "environment_variables": {
            k: "***" if "key" in k.lower() or "secret" in k.lower() or "token" in k.lower()
            else v for k, v in os.environ.items() 
            if k.startswith(('OPENAI_', 'SNOW_', 'TARGET_', 'ENVIRONMENT'))
        }
    }
    
    # Try reloading environment to see if it helps
    if env_file.exists() and not os.getenv('OPENAI_API_KEY'):
        try:
            from dotenv import load_dotenv
            load_dotenv(env_file, override=True)
            debug_info["reload_attempted"] = True
            debug_info["openai_key_after_reload"] = bool(os.getenv('OPENAI_API_KEY'))
        except Exception as e:
            debug_info["reload_error"] = str(e)
    
    return debug_info

@app.get("/meta")
async def get_metadata():
    """Get scraper metadata"""
    return load_json_file("meta.json")

@app.get("/forecast/dynamic")
async def get_dynamic_forecast():
    """Get dynamic forecast data"""
    return load_json_file("dynamic_forecast.json")

@app.get("/forecast/hourly")
async def get_hourly_forecast():
    """Get hourly forecast data (mid elevation)"""
    return load_json_file("hourly_forecast_mid.json")

@app.get("/forecast/all-elevations")
async def get_all_elevations():
    """Get forecast data for all available elevations"""
    elevations = {}
    
    for elevation in ['top', 'mid', 'bot']:
        try:
            elevation_data = {
                'dynamic_forecast': load_json_file(f"dynamic_forecast_{elevation}.json"),
                'hourly_forecast': load_json_file(f"hourly_forecast_{elevation}.json"),
                'snow_summary': load_json_file(f"snow_summary_{elevation}.json"),
                'meta': load_json_file(f"meta_{elevation}.json")
            }
            elevations[elevation] = elevation_data
        except HTTPException:
            # If elevation-specific files don't exist and it's mid, try legacy
            if elevation == 'mid':
                try:
                    elevations[elevation] = {
                        'dynamic_forecast': load_json_file("dynamic_forecast.json"),
                        'hourly_forecast': load_json_file("hourly_forecast.json"),
                        'snow_summary': load_json_file("snow_summary.json"),
                        'meta': load_json_file("meta.json")
                    }
                except HTTPException:
                    pass
    
    if not elevations:
        raise HTTPException(status_code=404, 
                          detail="No elevation data available")
    
    # Also include combined metadata
    try:
        combined_meta = load_json_file("combined_meta.json")
        return {
            'elevations': elevations,
            'combined_meta': combined_meta,
            'elevations_available': list(elevations.keys())
        }
    except HTTPException:
        return {
            'elevations': elevations,
            'elevations_available': list(elevations.keys())
        }

@app.get("/forecast/html", response_class=HTMLResponse)
async def get_html_forecast(request: Request):
    """Get beautifully styled HTML forecast featuring ChatGPT analysis"""
    try:
        # Try elevation-specific files first, fallback to legacy
        try:
            hourly_data = load_json_file("hourly_forecast_mid.json")
        except HTTPException:
            hourly_data = load_json_file("hourly_forecast.json")
        
        # Try to get cached ChatGPT forecast first
        chatgpt_forecast = get_cached_or_generate_forecast(hourly_data)
        
        # Determine base URL from request
        base_url = str(request.base_url).rstrip('/')
        
        # Create beautiful ski-themed HTML with ChatGPT as the star
        html_content = create_ski_themed_forecast_html(
            hourly_data, chatgpt_forecast, base_url
        )
        
        return HTMLResponse(content=html_content)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating HTML forecast: {str(e)}")

@app.get("/forecast/generate")
async def generate_ski_forecast():
    """Generate HTML and Markdown ski forecast using ChatGPT"""
    try:
        # Import the forecast generator
        from src.snowscrape.forecast_generator import SkiForecastGenerator
        
        # Check if OpenAI API key is available
        api_key = os.getenv('OPENAI_API_KEY')
        if not api_key:
            raise HTTPException(
                status_code=500, 
                detail="OpenAI API key not configured. Set OPENAI_API_KEY environment variable."
            )
        
        # Create generator
        generator = SkiForecastGenerator(openai_api_key=api_key)
        
        if not generator.client:
            raise HTTPException(
                status_code=500,
                detail="Failed to initialize OpenAI client"
            )
        
        # Load elevation-specific forecast data
        hourly_data = generator.load_hourly_forecast(str(DATA_DIR))
        
        # Generate forecasts with ChatGPT
        forecasts = generator.generate_forecast_with_chatgpt(hourly_data)
        
        if not forecasts:
            raise HTTPException(
                status_code=500,
                detail="Failed to generate forecasts with ChatGPT"
            )
        
        return {
            'status': 'success',
            'forecasts': forecasts,
            'generated_at': datetime.now().isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error generating forecast: {str(e)}"
        )

# Elevation-specific endpoints (must come after specific routes)
@app.get("/forecast/{elevation}")
async def get_forecast_by_elevation(elevation: str):
    """Get forecast data for specific elevation (top, mid, bot)"""
    if elevation not in ['top', 'mid', 'bot']:
        raise HTTPException(status_code=400, 
                          detail="Elevation must be 'top', 'mid', or 'bot'")
    
    try:
        # Try to load elevation-specific data
        data = {
            'elevation': elevation,
            'dynamic_forecast': load_json_file(f"dynamic_forecast_{elevation}.json"),
            'hourly_forecast': load_json_file(f"hourly_forecast_{elevation}.json"),
            'snow_summary': load_json_file(f"snow_summary_{elevation}.json"),
            'meta': load_json_file(f"meta_{elevation}.json")
        }
        return data
    except HTTPException as e:
        # If elevation-specific files don't exist, check for legacy files
        if elevation == 'mid':
            return {
                'elevation': elevation,
                'dynamic_forecast': load_json_file("dynamic_forecast.json"),
                'hourly_forecast': load_json_file("hourly_forecast.json"),
                'snow_summary': load_json_file("snow_summary.json"),
                'meta': load_json_file("meta.json")
            }
        else:
            raise HTTPException(status_code=404, 
                              detail=f"No data available for {elevation} elevation")

@app.get("/forecast/{elevation}/hourly")
async def get_hourly_forecast_by_elevation(elevation: str):
    """Get hourly forecast data for specific elevation"""
    if elevation not in ['top', 'mid', 'bot']:
        raise HTTPException(status_code=400, 
                          detail="Elevation must be 'top', 'mid', or 'bot'")
    
    try:
        return load_json_file(f"hourly_forecast_{elevation}.json")
    except HTTPException:
        if elevation == 'mid':
            return load_json_file("hourly_forecast.json")
        else:
            raise HTTPException(status_code=404, 
                              detail=f"No hourly data for {elevation} elevation")

@app.get("/forecast/{elevation}/dynamic")
async def get_dynamic_forecast_by_elevation(elevation: str):
    """Get dynamic forecast data for specific elevation"""
    if elevation not in ['top', 'mid', 'bot']:
        raise HTTPException(status_code=400, 
                          detail="Elevation must be 'top', 'mid', or 'bot'")
    
    try:
        return load_json_file(f"dynamic_forecast_{elevation}.json")
    except HTTPException:
        if elevation == 'mid':
            return load_json_file("dynamic_forecast.json")
        else:
            raise HTTPException(status_code=404, 
                              detail=f"No dynamic data for {elevation} elevation")


def get_cached_or_generate_forecast(hourly_data: List[Dict]) -> str:
    """Get cached forecast if recent, otherwise generate new one"""
    # Check for recent cached forecast
    cached_forecast = get_recent_cached_forecast()
    if cached_forecast:
        print("✅ Using cached ChatGPT forecast (less than 1 hour old)")
        return cached_forecast
    
    # Generate new forecast
    print("🤖 Generating new ChatGPT forecast...")
    try:
        # Import the forecast generator
        from src.snowscrape.forecast_generator import SkiForecastGenerator
        
        # Check if OpenAI API key is available
        api_key = os.getenv('OPENAI_API_KEY')
        if api_key:
            generator = SkiForecastGenerator(openai_api_key=api_key)
            if generator.client:
                # Load multi-elevation data for the new generator
                try:
                    elevation_data = generator.load_hourly_forecast(str(DATA_DIR))
                    forecasts = generator.generate_forecast_with_chatgpt(elevation_data)
                    if forecasts:
                        return forecasts.get('html', '')
                except FileNotFoundError:
                    # Fallback to legacy single-elevation data
                    print("⚠️  No multi-elevation data found, using legacy format")
                    # Convert single elevation data to multi-elevation format
                    legacy_elevation_data = {'mid': hourly_data}
                    forecasts = generator.generate_forecast_with_chatgpt(legacy_elevation_data)
                    if forecasts:
                        return forecasts.get('html', '')
    except Exception as e:
        print(f"Could not generate ChatGPT forecast: {e}")
    
    return None


def get_recent_cached_forecast() -> str:
    """Check for recent cached forecast files (within last hour)"""
    try:
        forecasts_dir = Path("generated_forecasts")
        if not forecasts_dir.exists():
            return None
        
        # Find the most recent HTML forecast file
        html_files = list(forecasts_dir.glob("ski_forecast_*.html"))
        if not html_files:
            return None
        
        # Sort by modification time (most recent first)
        html_files.sort(key=lambda x: x.stat().st_mtime, reverse=True)
        latest_file = html_files[0]
        
        # Check if file is less than 1 hour old
        file_time = datetime.fromtimestamp(latest_file.stat().st_mtime)
        current_time = datetime.now()
        time_diff = current_time - file_time
        
        if time_diff.total_seconds() < 3600:  # 1 hour = 3600 seconds
            print(f"📁 Found recent forecast: {latest_file.name} "
                  f"({int(time_diff.total_seconds() / 60)} minutes old)")
            
            # Read and return the cached forecast content
            with open(latest_file, 'r', encoding='utf-8') as f:
                content = f.read()
                
            # Extract just the forecast content (remove HTML wrapper if present)
            if '<div class="forecast">' in content:
                start = content.find('<div class="forecast">') + len('<div class="forecast">')
                end = content.find('</div>', start)
                if end > start:
                    return content[start:end].strip()
            
            return content
        else:
            print(f"🕐 Latest forecast is {int(time_diff.total_seconds() / 60)} minutes old - generating new one")
            return None
            
    except Exception as e:
        print(f"Error checking cached forecasts: {e}")
        return None


def get_cache_timestamp_info() -> str:
    """Get timestamp info for the most recent cached forecast"""
    try:
        forecasts_dir = Path("generated_forecasts")
        if not forecasts_dir.exists():
            return ""
        
        html_files = list(forecasts_dir.glob("ski_forecast_*.html"))
        if not html_files:
            return ""
        
        html_files.sort(key=lambda x: x.stat().st_mtime, reverse=True)
        latest_file = html_files[0]
        
        file_time = datetime.fromtimestamp(latest_file.stat().st_mtime)
        current_time = datetime.now()
        time_diff = current_time - file_time
        
        minutes_old = int(time_diff.total_seconds() / 60)
        if minutes_old < 1:
            return "< 1 min ago"
        elif minutes_old < 60:
            return f"{minutes_old} min ago"
        else:
            hours = int(minutes_old / 60)
            return f"{hours}h {minutes_old % 60}m ago"
            
    except Exception:
        return ""

def create_ski_themed_forecast_html(hourly_data: List[Dict],
                                    chatgpt_forecast: str = None,
                                    base_url: str = "") -> str:
    """Create a beautiful ski-themed HTML forecast"""
    
    # Extract snow events
    snow_events = [period for period in hourly_data
                   if period.get('snow_amount') and
                   period['snow_amount'] != '—']
    rain_events = [period for period in hourly_data
                   if period.get('rain_amount') and
                   period['rain_amount'] != '—']
    
    # Load CSS content directly to avoid nginx proxy issues
    css_content = ""
    try:
        with open(STATIC_DIR / "ski-forecast.css", "r") as f:
            css_content = f.read()
    except Exception as e:
        print(f"Warning: Could not load CSS file: {e}")
    
    # Generate HTML with embedded CSS
    html = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>🎿 Avoriaz Snow Forecast</title>
        <style>
        {css_content}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🎿 Avoriaz Snow Forecast ⛷️</h1>
                <div class="subtitle">AI-Powered Ski Forecast Analysis</div>
            </div>
    """
    
    # Add ChatGPT forecast as the main feature
    if chatgpt_forecast:
        # Check if we're using cached content by looking for recent files
        cache_info = get_cache_timestamp_info()
        cache_note = f" (cached {cache_info})" if cache_info else ""
        
        html += f"""
            <div class="forecast-card" style="margin-bottom: 30px; border-left: 5px solid #e74c3c;">
                <div class="card-title">
                    🤖 Expert AI Ski Forecast Analysis{cache_note}
                </div>
                <div style="line-height: 1.6; font-size: 1.1em;">
                    {chatgpt_forecast}
                </div>
            </div>
        """
    else:
        html += """
            <div class="forecast-card" style="margin-bottom: 30px; border-left: 5px solid #f39c12; background: linear-gradient(135deg, #fef9e7 0%, #fcf3cf 100%);">
                <div class="card-title">
                    ⚠️ AI Forecast Unavailable
                </div>
                <div style="line-height: 1.6;">
                    <p>The AI-powered forecast analysis is currently unavailable. This could be due to:</p>
                    <ul>
                        <li>Missing OpenAI API key configuration</li>
                        <li>API service temporarily unavailable</li>
                        <li>Rate limiting or quota exceeded</li>
                    </ul>
                    <p>You can still view the detailed data analysis below.</p>
                </div>
            </div>
        """
    
    html += """
            <div class="forecast-grid">
                <div class="forecast-card" style="grid-column: 1 / -1; border-left: 5px solid #3498db;">
                    <div class="card-title">
                        ❄️🌧️ Precipitation Events Summary
                    </div>
    """
    
    # Combine snow and rain events with clear dates
    all_precipitation = []
    
    # Add snow events
    for event in snow_events:
        date_str = f"{event.get('day_name', '')} {event.get('day_num', '')} Nov"
        all_precipitation.append({
            'date': date_str,
            'time': event.get('time_period', ''),
            'type': 'Snow',
            'amount': f"{event.get('snow_amount', '')}cm",
            'description': event.get('weather_phrase', ''),
            'sort_key': f"{event.get('date', '')}-{event.get('period_index', 0):03d}"
        })
    
    # Add rain events
    for event in rain_events:
        date_str = f"{event.get('day_name', '')} {event.get('day_num', '')} Nov"
        all_precipitation.append({
            'date': date_str,
            'time': event.get('time_period', ''),
            'type': 'Rain',
            'amount': f"{event.get('rain_amount', '')}mm",
            'description': event.get('weather_phrase', ''),
            'sort_key': f"{event.get('date', '')}-{event.get('period_index', 0):03d}"
        })
    
    # Sort by date and time
    all_precipitation.sort(key=lambda x: x['sort_key'])
    
    if all_precipitation:
        html += """
                    <div style="overflow-x: auto;">
                        <table style="width: 100%; font-size: 0.9em;">
                            <thead>
                                <tr style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white;">
                                    <th style="padding: 8px; text-align: left;">Date</th>
                                    <th style="padding: 8px; text-align: left;">Time</th>
                                    <th style="padding: 8px; text-align: left;">Type</th>
                                    <th style="padding: 8px; text-align: left;">Amount</th>
                                    <th style="padding: 8px; text-align: left;">Conditions</th>
                                </tr>
                            </thead>
                            <tbody>
        """
        
        for event in all_precipitation:
            type_class = "snow-amount" if event['type'] == 'Snow' else "rain-amount"
            html += f"""
                                <tr style="border-bottom: 1px solid rgba(0,0,0,0.1);">
                                    <td style="padding: 8px; font-weight: bold;">{event['date']}</td>
                                    <td style="padding: 8px;">{event['time']}</td>
                                    <td style="padding: 8px;">{event['type']}</td>
                                    <td style="padding: 8px;" class="{type_class}">{event['amount']}</td>
                                    <td style="padding: 8px;">{event['description']}</td>
                                </tr>
            """
        
        html += """
                            </tbody>
                        </table>
                    </div>
        """
    else:
        html += '<div class="weather-item"><div>No precipitation events in forecast period</div></div>'
    
    html += """
                </div>
            </div>
            
            <div class="hourly-table">
                <h2>📊 Supporting Data: Detailed Hourly Forecast</h2>
                <div style="overflow-x: auto; max-height: 600px; overflow-y: auto;">
                    <table>
                        <thead style="position: sticky; top: 0; z-index: 10;">
                            <tr>
                                <th>Date</th>
                                <th>Time</th>
                                <th>Weather</th>
                                <th>Snow</th>
                                <th>Rain</th>
                                <th>Temp (°C)</th>
                                <th>Wind</th>
                                <th>Humidity</th>
                            </tr>
                        </thead>
                        <tbody>
    """
    
    # Add hourly data rows with clearer dates - show more periods for better detail
    for period in hourly_data[:40]:  # Show first 40 periods for better coverage
        snow_display = period.get('snow_amount', '—')
        if snow_display != '—':
            snow_display += 'cm'
            
        rain_display = period.get('rain_amount', '—')
        if rain_display != '—':
            rain_display += 'mm'
        
        # Create clear date display with full date
        date_display = f"{period.get('day_name', '')} {period.get('day_num', '')} Nov"
        
        html += f"""
                        <tr>
                            <td><strong>{date_display}</strong></td>
                            <td><strong>{period.get('time_period', '')}</strong></td>
                            <td>{period.get('weather_phrase', '')}</td>
                            <td class="snow-amount">{snow_display}</td>
                            <td class="rain-amount">{rain_display}</td>
                            <td>{period.get('temperature_max', '—')}°</td>
                            <td>{period.get('wind_speed_display', '')} {period.get('wind_direction', '')}</td>
                            <td>{period.get('humidity', '')}%</td>
                        </tr>
        """
    
    html += f"""
                    </tbody>
                </table>
            </div>
            
            <div class="timestamp">
                Generated on {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} UTC
            </div>
        </div>
    </body>
    </html>
    """
    
    return html

@app.get("/snow/summary")
async def get_snow_summary():
    """Get snow summary data"""
    return load_json_file("snow_summary.json")

@app.get("/files")
async def list_files():
    """List all available data files"""
    if not DATA_DIR.exists():
        return {"files": [], "message": "Data directory not found"}
    
    files = []
    for file_path in DATA_DIR.glob("*.json"):
        info = get_file_info(file_path.name)
        files.append({
            "name": file_path.name,
            "size": info["size"],
            "modified": info["modified"]
        })
    
    for file_path in DATA_DIR.glob("*.csv"):
        info = get_file_info(file_path.name)
        files.append({
            "name": file_path.name,
            "size": info["size"],
            "modified": info["modified"]
        })
    
    return {
        "files": sorted(files, key=lambda x: x["modified"], reverse=True),
        "count": len(files)
    }

@app.get("/files/{filename}")
async def download_file(filename: str):
    """Download a specific file"""
    file_path = DATA_DIR / filename
    if not file_path.exists():
        raise HTTPException(status_code=404, detail=f"File {filename} not found")
    
    return FileResponse(
        path=file_path,
        filename=filename,
        media_type='application/octet-stream'
    )


@app.get("/static/ski-forecast.css")
async def get_css():
    """Serve CSS file directly (for nginx proxy compatibility)"""
    try:
        css_path = STATIC_DIR / "ski-forecast.css"
        if css_path.exists():
            with open(css_path, 'r') as f:
                css_content = f.read()
            return Response(content=css_content, media_type="text/css")
        else:
            raise HTTPException(status_code=404, detail="CSS file not found")
    except Exception as e:
        raise HTTPException(status_code=500, 
                          detail=f"Error serving CSS: {str(e)}")

@app.get("/logs")
async def get_recent_logs():
    """Get recent log entries (last 50 lines)"""
    if not LOG_DIR.exists():
        return {"logs": [], "message": "No logs directory found"}
    
    # Find the most recent log file
    log_files = list(LOG_DIR.glob("scraper_*.log"))
    if not log_files:
        return {"logs": [], "message": "No log files found"}
    
    latest_log = max(log_files, key=lambda x: x.stat().st_mtime)
    
    try:
        with open(latest_log, 'r') as f:
            lines = f.readlines()
            recent_lines = lines[-50:] if len(lines) > 50 else lines
            
        return {
            "log_file": latest_log.name,
            "total_lines": len(lines),
            "recent_lines": len(recent_lines),
            "logs": [line.strip() for line in recent_lines]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error reading log file: {str(e)}")

if __name__ == "__main__":
    import sys
    
    # Check if running in production (basic check)
    is_production = "--production" in sys.argv or os.getenv("ENVIRONMENT") == "production"
    
    # Ensure required directories exist
    DATA_DIR.mkdir(exist_ok=True)
    STATIC_DIR.mkdir(exist_ok=True)
    LOG_DIR.mkdir(exist_ok=True)
    
    # Log startup info
    print(f"Starting Snow Forecast API server...")
    print(f"Environment: {'Production' if is_production else 'Development'}")
    print(f"Data directory: {DATA_DIR.absolute()}")
    print(f"Static directory: {STATIC_DIR.absolute()}")
    print(f"Log directory: {LOG_DIR.absolute()}")
    
    try:
        uvicorn.run(
            "api_server:app",
            host="0.0.0.0",
            port=8001,
            reload=not is_production,  # Disable reload in production
            log_level="info",
            access_log=True
        )
    except Exception as e:
        print(f"ERROR: Failed to start API server: {e}")
        sys.exit(1)