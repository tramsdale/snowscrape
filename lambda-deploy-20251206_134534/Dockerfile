FROM public.ecr.aws/lambda/python:3.11

# Install system dependencies including build tools for Python packages
RUN yum update -y && \
    yum install -y \
    wget \
    unzip \
    fontconfig \
    freetype \
    gcc \
    gcc-c++ \
    make \
    && yum clean all

# Install uv for faster package management
RUN pip install --no-cache-dir uv

# Copy requirements and install Python dependencies with uv
# Use --only-binary to prefer pre-compiled wheels
COPY requirements.txt ${LAMBDA_TASK_ROOT}
RUN uv pip install --system --no-cache --only-binary=:all: -r requirements.txt || \
    uv pip install --system --no-cache -r requirements.txt

# Install Playwright browsers
RUN playwright install chromium
RUN playwright install-deps chromium

# Copy source code
COPY src/ ${LAMBDA_TASK_ROOT}/src/
COPY lambda_handler.py ${LAMBDA_TASK_ROOT}
COPY lambda_config.py ${LAMBDA_TASK_ROOT}
COPY api_server.py ${LAMBDA_TASK_ROOT}

# Set environment variables for Playwright
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright
ENV PYTHONPATH=${LAMBDA_TASK_ROOT}:${LAMBDA_TASK_ROOT}/src

# Create directories
RUN mkdir -p /tmp/out_snow /tmp/generated_forecasts

# Set the CMD to your handler
CMD ["lambda_handler.lambda_handler"]