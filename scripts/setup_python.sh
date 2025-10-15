#!/bin/bash
# UV Installation and Setup Script for Quant Explorer

set -e  # Exit on any error

echo "🚀 Setting up UV and Python dependencies for Quant Explorer..."

# Check if UV is installed
if ! command -v uv &> /dev/null; then
    echo "📦 Installing UV (Fast Python package installer)..."
    
    # Install UV using the official installer
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            echo "Using Homebrew to install UV..."
            brew install uv
        else
            echo "Using curl installer..."
            curl -LsSf https://astral.sh/uv/install.sh | sh
            export PATH="$HOME/.cargo/bin:$PATH"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        echo "Using curl installer..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.cargo/bin:$PATH"
    else
        echo "❌ Unsupported OS. Please install UV manually: https://github.com/astral-sh/uv"
        exit 1
    fi
else
    echo "✅ UV is already installed: $(uv --version)"
fi

# Verify UV installation
if ! command -v uv &> /dev/null; then
    echo "❌ UV installation failed. Please install manually."
    exit 1
fi

echo "📋 Installing Python dependencies..."

# Install dependencies using UV
if [ -f "pyproject.toml" ]; then
    echo "Installing from pyproject.toml..."
    uv pip install --system -e .
elif [ -f "requirements.txt" ]; then
    echo "Installing from requirements.txt..."
    uv pip install --system -r requirements.txt
else
    echo "❌ No pyproject.toml or requirements.txt found!"
    exit 1
fi

echo "🧪 Testing Python installation..."

# Test that key packages are available
python3 -c "
import numpy as np
import pandas as pd
import yfinance as yf
print('✅ All Python dependencies are working!')
print(f'  - NumPy: {np.__version__}')
print(f'  - Pandas: {pd.__version__}')
print(f'  - yfinance: {yf.__version__}')
"

echo ""
echo "🎉 Setup complete! You can now run Python validation tests:"
echo "   mix test --include python_validation"
echo ""
echo "💡 UV is much faster than pip for installing packages:"
echo "   uv pip install <package>    # Instead of pip install <package>"
echo "   uv pip list                 # Instead of pip list"
echo "   uv pip freeze               # Instead of pip freeze"