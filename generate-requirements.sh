#!/bin/bash

# Generate requirements.txt files from pyproject.toml using uv
set -e

echo "🔧 Generating requirements files with uv..."

# Check if uv is installed
if ! command -v uv &> /dev/null; then
    echo "❌ uv is not installed. Installing..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source ~/.bashrc
fi

# Generate full requirements (including lambda dependencies)
echo "📝 Generating requirements.txt..."
uv pip compile pyproject.toml --extra lambda --output-file requirements.txt

# Generate simple requirements (no playwright, no lambda extras)
echo "📝 Generating requirements-simple.txt..."
cat > temp-simple.toml << EOF
[project]
name = "snowscrape-simple"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = [
  "beautifulsoup4>=4.12.3",
  "lxml>=5.3.0", 
  "pandas>=2.2.3",
  "python-dotenv>=1.0.1",
  "openai>=1.52.0",
  "fastapi>=0.120.0",
  "uvicorn>=0.32.0",
  "python-multipart>=0.0.20",
  "mangum>=0.19.0",
  "requests>=2.32.0",
]
EOF

uv pip compile temp-simple.toml --output-file requirements-simple.txt
rm temp-simple.toml

echo "✅ Requirements files updated!"
echo "   - requirements.txt (full with Playwright)"
echo "   - requirements-simple.txt (without Playwright)"