const mongoose = require('mongoose');

const AssetSchema = new mongoose.Schema({
  user: { 
    type: mongoose.Schema.Types.Mixed, 
    ref: 'User', 
    required: true 
  },
  name: { 
    type: String, 
    required: true 
  },
  type: { 
    type: String, 
    required: true 
  },
  value: { 
    type: Number, 
    required: true 
  },
  purchasePrice: {
    type: Number,
    default: 0
  },
  acquisitionDate: { 
    type: Date, 
    default: Date.now 
  },
  location: { 
    type: String 
  },
  description: { 
    type: String 
  },
  isAppreciating: {
    type: Boolean,
    default: true
  },
  appreciationRate: {
    type: Number,
    default: 0
  }
}, { 
  timestamps: true 
});

const Asset = mongoose.model('Asset', AssetSchema);
module.exports = Asset; 