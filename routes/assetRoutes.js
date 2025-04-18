const express = require('express');
const router = express.Router();
const { getAssets, addAsset, updateAsset, deleteAsset } = require('../controllers/assetController');
const { protect } = require('../middleware/authMiddleware');

// Routes that require authentication
router.route('/')
  .get(protect, getAssets)
  .post(protect, addAsset);

router.route('/:id')
  .put(protect, updateAsset)
  .delete(protect, deleteAsset);

module.exports = router; 