# AWS Lambda Deployment Guide

This guide explains how to deploy the Snow Forecast API to AWS Lambda using three different approaches.

## Prerequisites

1. **AWS CLI**: Install and configure with your credentials
   ```bash
   pip install awscli
   aws configure
   ```

2. **SAM CLI**: For serverless application deployment
   ```bash
   pip install aws-sam-cli
   ```

3. **OpenAI API Key**: Required for forecast generation
   - Set in `.env` file or environment variable `OPENAI_API_KEY`

## Deployment Options

### Option 1: Simple API (No Web Scraping)
- **Purpose**: Quick test deployment
- **Features**: Basic API endpoints, health checks
- **No Dependencies**: No Playwright, no web scraping
- **Memory**: 512MB, 30s timeout

### Option 2: Full API with ZIP Package
- **Purpose**: Complete functionality with ZIP deployment
- **Features**: Full API + web scraping + AI forecasts
- **Limitations**: Playwright may have browser issues in Lambda
- **Memory**: 2GB, 5min timeout

### Option 3: Full API with Docker (Recommended)
- **Purpose**: Production-ready deployment
- **Features**: Complete functionality with Docker container
- **Advantages**: Full Playwright browser support
- **Memory**: 2GB, 5min timeout

## Quick Start

1. **Clone and prepare**:
   ```bash
   git clone <your-repo>
   cd snowscrape
   ```

2. **Set up environment**:
   ```bash
   cp .env.example .env
   # Edit .env with your OPENAI_API_KEY
   ```

3. **Deploy**:
   ```bash
   ./deploy-aws-lambda.sh
   ```

4. **Choose deployment type** when prompted (1, 2, or 3)

## Environment Variables

The deployment automatically configures:
- `OPENAI_API_KEY`: Your OpenAI API key
- `PLAYWRIGHT_BROWSERS_PATH`: Browser cache location
- `PYTHONPATH`: Python module paths

## API Endpoints

After deployment, your API will be available at:
- `GET /`: API information
- `GET /health`: Health check
- `GET /forecast/html`: HTML forecast (Full deployment only)
- `POST /forecast/generate`: Generate new forecast (Full deployment only)

## Troubleshooting

### Common Issues

1. **"Playwright browsers not found"**
   - Use Docker deployment (Option 3)
   - Check CloudWatch logs for browser installation errors

2. **"OpenAI API key not configured"**
   - Verify API key in deployment parameters
   - Check environment variables in Lambda console

3. **Timeout errors during scraping**
   - Increase Lambda timeout in template.yaml
   - Monitor CloudWatch metrics

### Monitoring

- **CloudWatch Logs**: Check function logs for errors
- **CloudWatch Metrics**: Monitor duration, memory usage
- **API Gateway**: Check request/response patterns

## Cost Optimization

- **Simple deployment**: Minimal cost for basic API
- **Full deployment**: Higher cost due to memory and timeout requirements
- **Docker deployment**: Similar cost to ZIP but more reliable

## Development Workflow

1. **Test locally** first with `python api_server.py`
2. **Deploy simple** version for API testing
3. **Deploy full** version when scraping is needed
4. **Monitor** CloudWatch logs for issues

## Files Structure

```
├── deploy-aws-lambda.sh          # Main deployment script
├── lambda_handler.py             # Full Lambda handler
├── lambda_handler_simple.py      # Simple Lambda handler
├── template.yaml                 # ZIP deployment template
├── template-simple.yaml          # Simple deployment template
├── template-docker.yaml          # Docker deployment template
├── Dockerfile                    # Docker container definition
├── requirements.txt              # Full dependencies
├── requirements-simple.txt       # Simple dependencies
└── lambda_config.py             # Lambda-specific configuration
```

## Next Steps

After successful deployment:
1. Test the API endpoints
2. Monitor CloudWatch logs
3. Set up CloudWatch alarms for production
4. Configure custom domain (optional)
5. Set up CI/CD pipeline (optional)

For issues or questions, check the CloudWatch logs first, then refer to the AWS Lambda and SAM documentation.