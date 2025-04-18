#!/bin/bash
# Script to start both the backend and frontend of the Financial Advisor app

# Function to clean up background processes on exit
cleanup() {
  echo "Shutting down services..."
  # Kill any node processes started by this script
  pkill -f "node server.js" &>/dev/null
  # Kill any flutter web processes
  pkill -f "flutter run -d chrome" &>/dev/null
  exit 0
}

# Set up trap to catch ctrl+c and other termination signals
trap cleanup SIGINT SIGTERM

# Create necessary directories if they don't exist
mkdir -p config

# Check if the port utility exists, create if not
if [ ! -f "config/portUtils.js" ]; then
  echo "Creating port utility..."
  mkdir -p config
  cat > config/portUtils.js << 'EOF'
const net = require('net');

function isPortAvailable(port) {
  return new Promise((resolve) => {
    const server = net.createServer();
    
    server.once('error', () => {
      resolve(false);
    });
    
    server.once('listening', () => {
      server.close();
      resolve(true);
    });
    
    server.listen(port);
  });
}

async function findAvailablePort(startPort, maxPort = startPort + 10) {
  for (let port = startPort; port <= maxPort; port++) {
    if (await isPortAvailable(port)) {
      return port;
    }
  }
  throw new Error(`No available ports found between ${startPort} and ${maxPort}`);
}

module.exports = { findAvailablePort };
EOF
fi

# Start backend in background
echo "Starting backend server..."
npm run dev &
backend_pid=$!

# Wait for backend to be ready
echo "Waiting for backend to start..."
sleep 5

# Enable web support for Flutter
echo "Enabling Flutter web support..."
flutter create --platforms=web . >/dev/null 2>&1

# Find an available port for Flutter web
port=8080
max_port=8090
flutter_port=0

echo "Finding available port for Flutter web..."
while [ $port -le $max_port ]; do
  echo "Trying port $port..."
  if ! lsof -i :$port > /dev/null 2>&1; then
    flutter_port=$port
    echo "Port $port is available for Flutter web"
    break
  fi
  echo "Port $port is in use, trying next port..."
  port=$((port+1))
done

if [ $flutter_port -eq 0 ]; then
  echo "Error: Could not find an available port for Flutter web"
  cleanup
  exit 1
fi

# Start Flutter web in background
echo "Starting Flutter web on port $flutter_port..."
flutter run -d chrome --web-port=$flutter_port &
flutter_pid=$!

# Wait for both processes
echo "Financial Advisor app is starting..."
echo "Press Ctrl+C to stop all services"
wait $backend_pid $flutter_pid 