FROM public.ecr.aws/lambda/python:3.12

# Install uv for faster package management
RUN pip install --no-cache-dir uv

# Copy requirements and install Python dependencies with uv
# Use --only-binary to prefer pre-compiled wheels and avoid compilation
COPY requirements.txt ${LAMBDA_TASK_ROOT}
RUN uv pip install --system --no-cache --only-binary=:all: -r requirements.txt

# Install Playwright without system dependencies (headless mode)
# Skip browser installation for now to avoid glibc issues
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

# Copy source code
COPY src/snowscrape/ ${LAMBDA_TASK_ROOT}/snowscrape/
COPY lambda_handler*.py ${LAMBDA_TASK_ROOT}/
COPY lambda_config.py ${LAMBDA_TASK_ROOT}/
COPY api_server.py ${LAMBDA_TASK_ROOT}/

# Set environment variables for Playwright
ENV PLAYWRIGHT_BROWSERS_PATH=/tmp
ENV PYTHONPATH=${LAMBDA_TASK_ROOT}

# Create directories
RUN mkdir -p /tmp/out_snow /tmp/generated_forecasts

# Set the CMD to your handler
CMD ["lambda_handler_docker.lambda_handler"]