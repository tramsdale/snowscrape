#!/usr/bin/env python3
"""
Snow Data API Server
Serves snow forecast data as JSON API endpoints
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pathlib import Path
import json
import uvicorn
from datetime import datetime
from typing import Dict, Any, List

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
    meta_info = get_file_info("meta.json")
    return {
        "status": "healthy",
        "data_available": meta_info["exists"],
        "last_updated": meta_info.get("modified"),
        "timestamp": datetime.now().isoformat()
    }

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
    """Get hourly forecast data"""
    return load_json_file("hourly_forecast.json")

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
    uvicorn.run(
        "api_server:app",
        host="0.0.0.0",
        port=8001,
        reload=True,
        log_level="info"
    )