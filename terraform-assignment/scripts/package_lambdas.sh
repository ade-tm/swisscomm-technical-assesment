#!/bin/bash

# Script to package Lambda functions into zip files

set -e

echo "Packaging Lambda functions..."

# Package Lambda Trigger
echo "Packaging lambda_trigger..."
cd lambda_trigger
zip -r ../lambda_trigger.zip .
cd ..

# Package Lambda Writer
echo "Packaging lambda_writer..."
cd lambda_writer
zip -r ../lambda_writer.zip .
cd ..

# Package Lambda Security Monitor
echo "Packaging lambda_security_monitor..."
cd lambda_security_monitor
zip -r ../lambda_security_monitor.zip .
cd ..

echo "All Lambda functions packaged successfully!"