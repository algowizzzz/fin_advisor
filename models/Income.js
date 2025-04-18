const mongoose = require('mongoose');

const IncomeSchema = new mongoose.Schema({
  user: { 
    type: mongoose.Schema.Types.Mixed, 
    ref: 'User', 
    required: true 
  },
  source: { 
    type: String, 
    required: true 
  },
  amount: { 
    type: Number, 
    required: true 
  },
  frequency: { 
    type: String, 
    enum: ['one-time', 'daily', 'weekly', 'bi-weekly', 'monthly', 'quarterly', 'annually'], 
    default: 'monthly' 
  },
  date: { 
    type: Date, 
    default: Date.now 
  },
  description: { 
    type: String 
  },
  category: { 
    type: String,
    enum: ['Employment', 'Investments', 'Side Gig', 'Rental', 'Gifts', 'Other'],
    default: 'Employment'
  },
  isRecurring: { 
    type: Boolean, 
    default: true 
  }
}, { 
  timestamps: true 
});

const Income = mongoose.model('Income', IncomeSchema);
module.exports = Income; 