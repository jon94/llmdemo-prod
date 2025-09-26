#!/bin/bash

echo "🚀 Setting up Multi-User Browser Automation for LLM Testing"
echo "=========================================================="

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3 first."
    exit 1
fi

# Check if Chrome is installed (macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ ! -d "/Applications/Google Chrome.app" ]; then
        echo "❌ Google Chrome is not installed."
        echo "💡 Please install Chrome from: https://www.google.com/chrome/"
        exit 1
    fi
    echo "✅ Chrome found"
fi

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip3 install -r requirements.txt

# Install ChromeDriver using webdriver-manager (automatic)
echo "🔧 ChromeDriver will be automatically managed by webdriver-manager"

# Make scripts executable
chmod +x multi_user_browser_automation.py

echo ""
echo "✅ Setup complete!"
echo ""
echo "🎯 Usage:"
echo "  python3 multi_user_browser_automation.py"
echo ""
echo "📋 Features:"
echo "  • Multi-user concurrent testing"
echo "  • Proper login flow on / page"
echo "  • Fixed CTF challenge (clicks Attempt Challenge button)"
echo "  • Security challenge testing"
echo "  • Screenshot capture"
echo "  • Detailed reporting"
echo ""
echo "🚀 Ready to test!"