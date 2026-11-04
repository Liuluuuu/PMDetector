#!/bin/bash
# Installation script for PMDetector

set -e  # Exit on error

echo "Installing PMDetector..."

if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is required but not installed."
    exit 1
fi

PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 8 ]); then
    echo "Error: Python 3.8 or higher is required. Found Python $PYTHON_VERSION."
    exit 1
fi

echo "Python $PYTHON_VERSION detected."

echo "Creating virtual environment..."
python3 -m venv venv
source venv/bin/activate

echo "Upgrading pip..."
pip install --upgrade pip

echo "Installing dependencies..."
pip install -r requirements.txt

echo "Installing PMDetector..."
pip install -e .

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
echo "  pmdetector --source-code path/to/contract.sol --llm-model gpt-4o"
echo ""
echo "See docs/REPRODUCIBILITY.md for the paper protocol and pending artifacts."
