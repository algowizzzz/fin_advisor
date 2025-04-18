const express = require('express');
const router = express.Router();
const {
  getGoals,
  getGoalById,
  createGoal,
  updateGoal,
  deleteGoal,
  updateGoalProgress
} = require('../controllers/goalController');
const { protect } = require('../middleware/authMiddleware');

// Test route
router.get('/test', (req, res) => {
  res.json({ success: true, message: 'Goal routes are working' });
});

// Test auth route
router.get('/auth-test', protect, (req, res) => {
  res.json({ success: true, message: 'Authenticated goal route is working', user: req.user });
});

// @route   GET /api/goals
// @desc    Get all goals for the logged-in user
// @access  Private
router.get('/', protect, getGoals);

// @route   GET /api/goals/:id
// @desc    Get a single goal by ID
// @access  Private
router.get('/:id', protect, getGoalById);

// @route   POST /api/goals
// @desc    Create a new goal
// @access  Private
router.post('/', protect, createGoal);

// @route   PUT /api/goals/:id
// @desc    Update a goal
// @access  Private
router.put('/:id', protect, updateGoal);

// @route   DELETE /api/goals/:id
// @desc    Delete a goal
// @access  Private
router.delete('/:id', protect, deleteGoal);

// @route   PATCH /api/goals/:id/progress
// @desc    Update goal progress (current amount)
// @access  Private
router.patch('/:id/progress', protect, updateGoalProgress);

module.exports = router; 