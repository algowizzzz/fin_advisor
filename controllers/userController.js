const User = require('../models/User');
const jwt = require('jsonwebtoken');

// @desc    Register a new user
// @route   POST /api/users/register
// @access  Public
const registerUser = async (req, res) => {
  try {
    const { email, password, fullName, phoneNumber, dateOfBirth } = req.body;
    
    // Check if email is already in use
    const existingUser = await User.findOne({ email });
    
    if (existingUser) {
      return res.status(400).json({ message: 'Email already in use' });
    }
    
    // Create new user
    const newUser = new User({
      email,
      password,
      fullName,
      phoneNumber,
      dateOfBirth
    });
    
    const savedUser = await newUser.save();
    
    // Generate JWT token
    const token = jwt.sign(
      { id: savedUser._id },
      process.env.JWT_SECRET || 'your_jwt_secret_key_here',
      { expiresIn: '30d' }
    );
    
    res.status(201).json({
      token,
      user: {
        id: savedUser._id,
        email: savedUser.email,
        fullName: savedUser.fullName
      }
    });
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Login user
// @route   POST /api/users/login
// @access  Public
const loginUser = async (req, res) => {
  try {
    const { email, password } = req.body;
    
    if (!email || !password) {
      return res.status(400).json({ message: 'Please provide email and password' });
    }
    
    // Test/mock users for development
    if ((email === 'user@example.com' && password === 'password123') ||
        (email === 'admin@example.com' && password === 'admin123')) {
      
      // Generate JWT token
      const token = jwt.sign(
        { id: 'mock123456789' },
        process.env.JWT_SECRET || 'your_jwt_secret_key_here',
        { expiresIn: '30d' }
      );
      
      return res.json({
        token,
        user: {
          id: 'mock123456789',
          email: email,
          fullName: email === 'admin@example.com' ? 'Admin User' : 'Test User'
        }
      });
    }
    
    // Try database authentication
    try {
      // Find user by email
      const user = await User.findOne({ email });
      
      if (!user) {
        return res.status(401).json({ message: 'Invalid credentials' });
      }
      
      // Check if password matches
      const isMatch = await user.isValidPassword(password);
      
      if (!isMatch) {
        return res.status(401).json({ message: 'Invalid credentials' });
      }
      
      // Generate JWT token
      const token = jwt.sign(
        { id: user._id },
        process.env.JWT_SECRET || 'your_jwt_secret_key_here',
        { expiresIn: '30d' }
      );
      
      res.json({
        token,
        user: {
          id: user._id,
          email: user.email,
          fullName: user.fullName
        }
      });
    } catch (dbError) {
      console.error('Database error:', dbError);
      
      // If database fails but using test credentials, still allow login
      if ((email === 'user@example.com' && password === 'password123') ||
          (email === 'admin@example.com' && password === 'admin123')) {
        
        const token = jwt.sign(
          { id: 'mock123456789' },
          process.env.JWT_SECRET || 'your_jwt_secret_key_here',
          { expiresIn: '30d' }
        );
        
        return res.json({
          token,
          user: {
            id: 'mock123456789',
            email: email,
            fullName: email === 'admin@example.com' ? 'Admin User' : 'Test User'
          }
        });
      }
      
      return res.status(401).json({ message: 'Invalid credentials' });
    }
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ message: 'Server error' });
  }
};

// @desc    Get user profile
// @route   GET /api/users/profile
// @access  Private
const getUserProfile = async (req, res) => {
  try {
    // For mock users
    if (req.user.id === 'mock123456789') {
      return res.json({
        id: 'mock123456789',
        email: 'user@example.com',
        fullName: 'Test User',
        phoneNumber: '555-123-4567',
        dateOfBirth: new Date('1990-01-01'),
        createdAt: new Date()
      });
    }
    
    // For real users
    const user = await User.findById(req.user.id);
    
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    res.json({
      id: user._id,
      email: user.email,
      fullName: user.fullName,
      phoneNumber: user.phoneNumber,
      dateOfBirth: user.dateOfBirth,
      createdAt: user.createdAt
    });
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ message: 'Server error' });
  }
};

module.exports = {
  registerUser,
  loginUser,
  getUserProfile
}; 