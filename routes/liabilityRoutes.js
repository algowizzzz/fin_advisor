const express = require('express');
const router = express.Router();
const { getLiabilities, addLiability, updateLiability, deleteLiability } = require('../controllers/liabilityController');
const { protect } = require('../middleware/authMiddleware');

// Routes that require authentication
router.route('/')
  .get(protect, getLiabilities)
  .post(protect, addLiability);

router.route('/:id')
  .put(protect, updateLiability)
  .delete(protect, deleteLiability);

module.exports = router; 