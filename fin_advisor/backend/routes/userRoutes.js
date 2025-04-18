const express = require('express');
const router = express.Router();

// Route: GET /api/users/test
router.get('/test', (req, res) => {
  res.json({ message: 'User routes working' });
});

// Add more routes here as needed

module.exports = router; 