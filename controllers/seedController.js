const User = require('../models/User');
const bcrypt = require('bcrypt');

// @desc    Seed test users
// @route   GET /api/seed/users
// @access  Public
const seedUsers = async (req, res) => {
  try {
    // Clear existing users
    await User.deleteMany({});
    
    // Create test users
    const testUser = new User({
      email: 'user@example.com',
      password: 'password123',
      fullName: 'Test User',
      phoneNumber: '555-123-4567',
      dateOfBirth: new Date('1990-01-01')
    });
    
    const adminUser = new User({
      email: 'admin@example.com',
      password: 'admin123',
      fullName: 'Admin User',
      phoneNumber: '555-987-6543',
      dateOfBirth: new Date('1985-05-15')
    });
    
    await testUser.save();
    await adminUser.save();
    
    res.status(201).json({ 
      message: 'Test users created successfully',
      users: [
        { email: 'user@example.com', password: 'password123' },
        { email: 'admin@example.com', password: 'admin123' }
      ]
    });
  } catch (error) {
    console.error('Seed users error:', error);
    res.status(500).json({ message: 'Server error' });
  }
};

module.exports = {
  seedUsers
}; 