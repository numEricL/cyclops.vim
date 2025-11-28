#!/bin/bash
# Simple test runner script for cyclops.vim

set -e

cd "$(dirname "$0")/.."

echo "Running cyclops.vim tests..."
echo ""

vim -Nu test/run_tests.vim

echo ""
echo "✓ Test suite completed successfully!"
