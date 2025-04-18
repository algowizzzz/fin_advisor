const Asset = require('../models/Asset');

// @desc    Get all assets for logged in user
// @route   GET /api/assets
// @access  Private
const getAssets = async (req, res) => {
  try {
    const assets = await Asset.find({ user: req.user.id });
    res.json({ success: true, data: assets });
  } catch (error) {
    console.error('Get assets error:', error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// @desc    Add new asset
// @route   POST /api/assets
// @access  Private
const addAsset = async (req, res) => {
  try {
    const { name, type, value, purchasePrice, acquisitionDate, location, description, isAppreciating, appreciationRate } = req.body;
    
    const asset = new Asset({
      user: req.user.id,
      name,
      type,
      value,
      purchasePrice,
      acquisitionDate: acquisitionDate || Date.now(),
      location,
      description,
      isAppreciating,
      appreciationRate
    });
    
    const savedAsset = await asset.save();
    res.status(201).json({ success: true, data: savedAsset });
  } catch (error) {
    console.error('Add asset error:', error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// @desc    Update asset
// @route   PUT /api/assets/:id
// @access  Private
const updateAsset = async (req, res) => {
  try {
    const asset = await Asset.findById(req.params.id);
    
    if (!asset) {
      return res.status(404).json({ success: false, message: "Asset not found" });
    }
    
    // Check if asset belongs to logged in user
    if (asset.user.toString() !== req.user.id) {
      return res.status(401).json({ success: false, message: "Not authorized" });
    }
    
    const updatedAsset = await Asset.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    );
    
    res.json({ success: true, data: updatedAsset });
  } catch (error) {
    console.error('Update asset error:', error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// @desc    Delete asset
// @route   DELETE /api/assets/:id
// @access  Private
const deleteAsset = async (req, res) => {
  try {
    const asset = await Asset.findById(req.params.id);
    
    if (!asset) {
      return res.status(404).json({ success: false, message: "Asset not found" });
    }
    
    // Check if asset belongs to logged in user
    if (asset.user.toString() !== req.user.id) {
      return res.status(401).json({ success: false, message: "Not authorized" });
    }
    
    await asset.deleteOne();
    
    res.json({ success: true, message: "Asset removed" });
  } catch (error) {
    console.error('Delete asset error:', error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

module.exports = {
  getAssets,
  addAsset,
  updateAsset,
  deleteAsset
}; 