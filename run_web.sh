#!/bin/bash
# Script to run Flutter web with fallback ports

# First, ensure web support is enabled
flutter create --platforms=web .

# Start with port 8080
PORT=8080
MAX_PORT=8090

while [ $PORT -le $MAX_PORT ]; do
  echo "Trying port $PORT..."
  # Check if port is available
  if ! lsof -i :$PORT > /dev/null 2>&1; then
    echo "Port $PORT is available, starting Flutter..."
    flutter run -d chrome --web-port=$PORT
    exit 0
  fi
  echo "Port $PORT is in use, trying next port..."
  PORT=$((PORT+1))
done

echo "All ports from 8080 to $MAX_PORT are in use. Please free up a port or specify a different port range."
exit 1 