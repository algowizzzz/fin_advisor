const net = require('net');

/**
 * Checks if a port is available
 * @param {number} port - Port to check
 * @returns {Promise<boolean>} - True if port is available, false otherwise
 */
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

/**
 * Finds an available port starting from the given port
 * @param {number} startPort - Port to start checking from
 * @param {number} maxPort - Maximum port to check (optional)
 * @returns {Promise<number>} - Available port
 */
async function findAvailablePort(startPort, maxPort = startPort + 10) {
  for (let port = startPort; port <= maxPort; port++) {
    if (await isPortAvailable(port)) {
      return port;
    }
  }
  throw new Error(`No available ports found between ${startPort} and ${maxPort}`);
}

module.exports = { findAvailablePort }; 