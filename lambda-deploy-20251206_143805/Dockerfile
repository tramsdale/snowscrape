FROM public.ecr.aws/lambda/python:3.12

# Install system dependencies for Playwright
RUN dnf update -y && dnf install -y \
    nss \
    nspr \
    at-spi2-atk \
    cups-libs \
    gtk3 \
    libxkbcommon \
    xorg-x11-server-Xvfb \
    mesa-libgbm \
    alsa-lib \
    && dnf clean all

# Install uv for faster package management
RUN pip install --no-cache-dir uv

# Copy requirements and install Python dependencies with uv
# Use --only-binary to prefer pre-compiled wheels and avoid compilation
COPY requirements.txt ${LAMBDA_TASK_ROOT}
RUN uv pip install --system --no-cache --only-binary=:all: -r requirements.txt

# Install Playwright browsers for Lambda 
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright
RUN mkdir -p /opt/playwright
RUN PLAYWRIGHT_BROWSERS_PATH=/opt/playwright playwright install chromium

# Copy source code
COPY snowscrape/ ${LAMBDA_TASK_ROOT}/snowscrape/
COPY lambda_handler*.py ${LAMBDA_TASK_ROOT}/
COPY lambda_config.py ${LAMBDA_TASK_ROOT}/
COPY api_server.py ${LAMBDA_TASK_ROOT}/
COPY static/ ${LAMBDA_TASK_ROOT}/static/

# Set environment variables for Playwright and system optimization
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright
ENV PYTHONPATH=${LAMBDA_TASK_ROOT}
ENV FONTCONFIG_PATH=/usr/lib/fontconfig
ENV FONTCONFIG_FILE=/etc/fonts/fonts.conf
ENV TMPDIR=/tmp

# Create directories for Lambda with proper permissions
RUN mkdir -p /tmp/out_snow /tmp/generated_forecasts /tmp/cache /tmp/user-data /tmp/fontconfig && \
    chmod -R 755 /tmp && \
    mkdir -p /usr/lib/fontconfig/cache && \
    chmod -R 755 /usr/lib/fontconfig && \
    chown -R root:root /tmp /usr/lib/fontconfig

# Set the CMD to your handler
CMD ["lambda_handler_docker.lambda_handler"]