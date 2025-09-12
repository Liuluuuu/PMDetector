#!/bin/bash
# Installation script for PMDetector

set -e  # Exit on error

echo "Installing PMDetector..."

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is required but not installed."
    exit 1
fi

# Check Python version
PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 8 ]); then
    echo "Error: Python 3.8 or higher is required. Found Python $PYTHON_VERSION."
    exit 1
fi

echo "Python $PYTHON_VERSION detected."

# Create a virtual environment
echo "Creating virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install dependencies
echo "Installing dependencies..."
pip install -r requirements.txt

# Install the package in development mode
echo "Installing PMDetector..."
pip install -e .

# Check if Slither is installed
if ! command -v slither &> /dev/null; then
    echo "Warning: Slither is not in PATH. Installing Slither..."
    pip install slither-analyzer
fi

echo "Installation complete!"
echo ""
echo "To activate the virtual environment, run:"
echo "  source venv/bin/activate"
echo ""
echo "To run PMDetector, use:"
echo "  pmdetector -f path/to/contract.sol"
echo ""
echo "To run the example analysis, use:"
echo "  ./examples/analyze_example.py"
