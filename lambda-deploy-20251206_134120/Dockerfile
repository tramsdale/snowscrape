FROM public.ecr.aws/lambda/python:3.11

# Install system dependencies for Playwright
RUN yum update -y && \
    yum install -y \
    wget \
    unzip \
    fontconfig \
    freetype \
    && yum clean all

# Copy requirements and install Python dependencies
COPY requirements.txt ${LAMBDA_TASK_ROOT}
RUN pip install --no-cache-dir -r requirements.txt

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