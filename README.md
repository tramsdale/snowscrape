# Snow Scraper

A Python application that scrapes snow forecast data and serves it via a REST API.

## Features

- Automated snow forecast data scraping
- JSON and CSV data export
- RESTful API server with FastAPI
- Automated deployment with cron job scheduling
- Comprehensive logging and monitoring

## Quick Start

### 1. Deploy the application
```bash
./scripts/deploy.sh
```

### 2. Access the API
- API endpoints: http://localhost:8001
- Interactive docs: http://localhost:8001/docs
- Health check: http://localhost:8001/health

### 3. View data
```bash
# List available data files
curl http://localhost:8001/files

# Get snow summary
curl http://localhost:8001/snow/summary

# Get dynamic forecast
curl http://localhost:8001/forecast/dynamic
```

## Manual Operations

### Run scraper manually
```bash
source .venv/bin/activate
python main.py
```

### Start/stop API server
```bash
./scripts/start_api.sh
./scripts/stop_api.sh
```

### Setup cron job
```bash
./scripts/setup_cron.sh
```

## Development

### Requirements
- Python 3.8+
- uv package manager

### Setup development environment
```bash
# Clone repository
git clone <your-repo-url>
cd snowscrape

# Deploy in development mode
./scripts/deploy.sh --env development
```

## API Endpoints

- `GET /` - API information
- `GET /health` - Health check
- `GET /meta` - Scraper metadata
- `GET /forecast/dynamic` - Dynamic forecast data
- `GET /forecast/hourly` - Hourly forecast data
- `GET /snow/summary` - Snow summary
- `GET /files` - List all data files
- `GET /files/{filename}` - Download specific file
- `GET /logs` - Recent log entries

## Production Deployment

```bash
./scripts/deploy.sh --env production
```

This will:
- Set up systemd service
- Configure automatic startup
- Enable production monitoring

## Monitoring

### View logs
```bash
# Scraper logs
tail -f logs/scraper_$(date +%Y%m%d).log

# API logs  
tail -f logs/api_$(date +%Y%m%d).log

# System service logs (production)
sudo journalctl -u snowscrape -f
```

### Check status
```bash
# API health
curl http://localhost:8001/health

# Cron jobs
crontab -l

# Service status (production)
sudo systemctl status snowscrape
```

## Directory Structure

```
snowscrape/
├── main.py              # Main scraper script
├── api_server.py        # FastAPI server
├── pyproject.toml       # Project dependencies
├── README.md           # This file
├── scripts/            # Deployment and utility scripts
│   ├── deploy.sh       # Main deployment script
│   ├── setup_cron.sh   # Cron job setup
│   ├── start_api.sh    # Start API server
│   ├── stop_api.sh     # Stop API server
│   └── update_snow_data.sh # Cron job script
├── out_snow/           # Generated data files
│   ├── *.json         # JSON data exports
│   └── *.csv          # CSV data exports
└── logs/              # Application logs
```

## License

[Add your license here]
