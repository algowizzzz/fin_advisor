const express = require('express');
const router = express.Router();
const { seedUsers } = require('../controllers/seedController');

// Route: GET /api/seed/users
router.get('/users', seedUsers);

module.exports = router; 