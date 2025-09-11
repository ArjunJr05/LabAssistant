// routes/auth.js - Updated with proper admin validation
const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { pool } = require('../config/database');
const auth = require('../middleware/auth');

const router = express.Router();
const JWT_SECRET = '1341ae2e12f9d31a0cc42a5225b885012f16583b997b49133a68d148e03e2f5c3cf74c9d0c3da7cf37dea2143040a09b3abe1ac35393ccef1e6b9f7d3f1ac9d5';

// Register (only for students)
router.post('/register', async (req, res) => {
  try {
    const { name, enrollNumber, year, section, batch, password } = req.body;
    
    // Validate required fields
    if (!name || !enrollNumber || !year || !section || !batch || !password) {
      return res.status(400).json({ message: 'All fields are required' });
    }
    
    // Prevent admin registration through this route
    if (enrollNumber.toUpperCase() === 'ADMIN001' || enrollNumber.toLowerCase().includes('admin')) {
      return res.status(400).json({ message: 'Invalid enrollment number. Use admin login for admin access.' });
    }
    
    // Check if user already exists
    const userExists = await pool.query(
      'SELECT * FROM users WHERE enroll_number = $1',
      [enrollNumber]
    );

    if (userExists.rows.length > 0) {
      return res.status(400).json({ message: 'User already exists with this enrollment number' });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Insert user (always as student)
    const result = await pool.query(
      'INSERT INTO users (name, enroll_number, year, section, batch, password, role, is_online) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id, name, enroll_number, role, year, section, batch, is_online',
      [name, enrollNumber, year, section, batch, hashedPassword, 'student', true]
    );

    const token = jwt.sign(
      { userId: result.rows[0].id, role: result.rows[0].role },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.status(201).json({
      message: 'User registered successfully',
      token,
      user: result.rows[0]
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ message: 'Server error during registration' });
  }
});

// Login (for both students and admin)
router.post('/login', async (req, res) => {
  try {
    const { enrollNumber, password } = req.body;

    // Validate required fields
    if (!enrollNumber || !password) {
      return res.status(400).json({ message: 'Enrollment number and password are required' });
    }

    console.log(`Login attempt for: ${enrollNumber}`);

    // Special handling for admin login
    if (enrollNumber.toUpperCase() === 'ADMIN001') {
      console.log('Admin login attempt detected');
      
      // Verify admin password directly
      if (password !== 'Admin_aids@smvec') {
        console.log('Admin password incorrect');
        return res.status(400).json({ message: 'Invalid admin credentials' });
      }

      // Check if admin user exists in database
      let adminUser = await pool.query(
        'SELECT * FROM users WHERE enroll_number = $1 AND role = $2',
        ['ADMIN001', 'admin']
      );

      // Create admin user if doesn't exist
      if (adminUser.rows.length === 0) {
        console.log('Creating admin user in database');
        const hashedPassword = await bcrypt.hash('Admin_aids@smvec', 10);
        
        adminUser = await pool.query(
          'INSERT INTO users (name, enroll_number, year, section, batch, password, role) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id, name, enroll_number, role, year, section, batch',
          ['Administrator', 'ADMIN001', 'ADMIN', 'ADM', '2024', hashedPassword, 'admin']
        );
      }

      const user = adminUser.rows[0];

      // Update last active and set online status
      await pool.query(
        'UPDATE users SET last_active = CURRENT_TIMESTAMP, is_online = true WHERE id = $1',
        [user.id]
      );

      // Create session
      await pool.query(
        'INSERT INTO user_sessions (user_id) VALUES ($1)',
        [user.id]
      );

      const token = jwt.sign(
        { userId: user.id, role: user.role },
        JWT_SECRET,
        { expiresIn: '24h' }
      );

      console.log('Admin login successful');
      return res.json({
        token,
        user: {
          id: user.id,
          name: user.name,
          enrollNumber: user.enroll_number,
          role: user.role,
          year: user.year,
          section: user.section,
          batch: user.batch,
          isOnline: true
        }
      });
    }

    // Regular student login
    const result = await pool.query(
      'SELECT * FROM users WHERE enroll_number = $1 AND role = $2',
      [enrollNumber, 'student']
    );

    if (result.rows.length === 0) {
      return res.status(400).json({ message: 'Invalid credentials' });
    }

    const user = result.rows[0];

    // Check password
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ message: 'Invalid credentials' });
    }

    // Update last active and set online status
    await pool.query(
      'UPDATE users SET last_active = CURRENT_TIMESTAMP, is_online = true WHERE id = $1',
      [user.id]
    );

    // Create session
    await pool.query(
      'INSERT INTO user_sessions (user_id) VALUES ($1)',
      [user.id]
    );

    const token = jwt.sign(
      { userId: user.id, role: user.role },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.json({
      token,
      user: {
        id: user.id,
        name: user.name,
        enrollNumber: user.enroll_number,
        role: user.role,
        year: user.year,
        section: user.section,
        batch: user.batch,
        isOnline: true
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ message: 'Server error during login' });
  }
});

// Admin Registration
router.post('/register-admin', async (req, res) => {
  try {
    const { name, username, password, masterPassword } = req.body;
    
    // Validate required fields
    if (!name || !username || !password || !masterPassword) {
      return res.status(400).json({ message: 'All fields are required' });
    }
    
    // Validate master password
    if (masterPassword !== 'Admin_aids@smvec') {
      return res.status(400).json({ message: 'Invalid master password' });
    }
    
    // Check if admin username already exists
    const adminExists = await pool.query(
      'SELECT * FROM users WHERE enroll_number = $1',
      [username]
    );

    if (adminExists.rows.length > 0) {
      return res.status(400).json({ message: 'Admin username already exists' });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Insert admin user
    const result = await pool.query(
      'INSERT INTO users (name, enroll_number, year, section, batch, password, role, is_online) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id, name, enroll_number, role, year, section, batch, is_online',
      [name, username, 'ADMIN', 'ADM', '2024', hashedPassword, 'admin', true]
    );

    const token = jwt.sign(
      { userId: result.rows[0].id, role: result.rows[0].role },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.status(201).json({
      message: 'Admin registered successfully',
      token,
      user: result.rows[0]
    });
  } catch (error) {
    console.error('Admin registration error:', error);
    res.status(500).json({ message: 'Server error during admin registration' });
  }
});

// Logout endpoint to set user offline
router.post('/logout', auth, async (req, res) => {
  try {
    const userId = req.user.userId;
    
    // Set user offline
    await pool.query(
      'UPDATE users SET is_online = false WHERE id = $1',
      [userId]
    );
    
    // Mark active sessions as inactive
    await pool.query(
      'UPDATE user_sessions SET is_active = false, session_end = CURRENT_TIMESTAMP WHERE user_id = $1 AND is_active = true',
      [userId]
    );
    
    res.json({ message: 'Logged out successfully' });
  } catch (error) {
    console.error('Error during logout:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;