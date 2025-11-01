#!/bin/bash

# Generate all architecture diagrams for Pic2PDF
# Requires: Python 3.7+, graphviz

set -e

echo "========================================="
echo "Generating Pic2PDF Architecture Diagrams"
echo "========================================="
echo ""

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install -q --upgrade pip
pip install -q -r requirements.txt

# Create output directory
mkdir -p out

echo ""
echo "Generating diagrams..."
echo ""

# Generate each diagram
echo "1/5 Generating architecture overview..."
python3 architecture_overview.py

echo "2/5 Generating AI pipeline..."
python3 ai_pipeline.py

echo "3/5 Generating ARM optimizations..."
python3 arm_optimizations.py

echo "4/5 Generating performance monitoring..."
python3 performance_monitoring.py

echo "5/5 Generating data flow..."
python3 data_flow.py

echo ""
echo "========================================="
echo "✓ All diagrams generated successfully!"
echo "========================================="
echo ""
echo "Output files:"
ls -lh out/*.svg

# Deactivate virtual environment
deactivate

