const express = require('express');
const router = express.Router();
const { registerUser, loginUser, getUserProfile } = require('../controllers/userController');
const { protect } = require('../middleware/authMiddleware');

// Route: GET /api/users/test
router.get('/test', (req, res) => {
  res.json({ message: 'User routes working' });
});

// Route: POST /api/users/register
router.post('/register', registerUser);

// Route: POST /api/users/login
router.post('/login', loginUser);

// Route: GET /api/users/profile
router.get('/profile', protect, getUserProfile);

// Add more routes here as needed

module.exports = router; 