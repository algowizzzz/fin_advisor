const express = require('express');
const router = express.Router();
const { getIncomes, addIncome, updateIncome, deleteIncome } = require('../controllers/incomeController');
const { protect } = require('../middleware/authMiddleware');

// Routes that require authentication
router.route('/')
  .get(protect, getIncomes)
  .post(protect, addIncome);

router.route('/:id')
  .put(protect, updateIncome)
  .delete(protect, deleteIncome);

module.exports = router; 