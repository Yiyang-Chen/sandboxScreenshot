#!/bin/bash
# Run script for GodotBase template
# This script starts a local HTTP server to serve the built project

# Get the project root directory (parent of scripts/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Default port is 8000, can be overridden with parameter
PORT=${1:-8000}

echo "Starting local HTTP server on port $PORT..."
echo ""

# Check if dist directory exists
if [ ! -f "dist/index.html" ]; then
    echo "Error: Build directory not found or incomplete"
    echo "Please run dist.sh first to export the project"
    exit 1
fi

echo "Server starting at: http://localhost:$PORT"
echo "Serving directory: dist/"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Try Python first
if command -v python3 &> /dev/null; then
    echo "Using Python3 HTTP server..."
    cd dist
    python3 -m http.server $PORT
    exit 0
fi

# Try Python (2 or 3)
if command -v python &> /dev/null; then
    echo "Using Python HTTP server..."
    cd dist
    python -m http.server $PORT
    exit 0
fi

# Try Node.js http-server (with cache disabled for development)
if command -v npx &> /dev/null; then
    echo "Using npx http-server (cache disabled)..."
    npx http-server dist -p $PORT -c-1
    exit 0
fi

# No suitable server found
echo "Error: No HTTP server found"
echo ""
echo "Please install one of the following:"
echo "  - Python: https://www.python.org/"
echo "  - Node.js: https://nodejs.org/"
echo ""
echo "Then run this script again"
exit 1

