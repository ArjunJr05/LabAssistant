// routes/auth.js - Enhanced with detailed error logging for debugging
const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { pool } = require('../config/database');
const auth = require('../middleware/auth');

const router = express.Router();
const JWT_SECRET = '1341ae2e12f9d31a0cc42a5225b885012f16583b997b49133a68d148e03e2f5c3cf74c9d0c3da7cf37dea2143040a09b3abe1ac35393ccef1e6b9f7d3f1ac9d5';

// Enhanced login route with detailed error logging
router.post('/login', async (req, res) => {
  try {
    console.log('\n=== LOGIN REQUEST RECEIVED ===');
    console.log('Request body:', req.body);
    console.log('Headers:', req.headers);
    
    const { enrollNumber, password } = req.body;

    // Validate required fields
    if (!enrollNumber || !password) {
      console.log('❌ Missing enrollNumber or password');
      return res.status(400).json({ message: 'Enrollment number and password are required' });
    }

    console.log(`🔍 Processing login for: ${enrollNumber}`);

    // Special handling for admin login
    if (enrollNumber.toUpperCase() === 'ADMIN001') {
      console.log('🔑 Admin login attempt detected');
      
      // Verify admin password directly
      if (password !== 'Admin_aids@smvec') {
        console.log('❌ Admin password incorrect');
        return res.status(400).json({ message: 'Invalid admin credentials' });
      }

      console.log('✅ Admin password verified');
      
      try {
        // Check if admin user exists in database
        console.log('🔍 Checking if admin exists in database...');
        let adminUser = await pool.query(
          'SELECT * FROM users WHERE enroll_number = $1 AND role = $2',
          ['ADMIN001', 'admin']
        );

        console.log(`📊 Admin query result: ${adminUser.rows.length} rows found`);

        // Create admin user if doesn't exist
        if (adminUser.rows.length === 0) {
          console.log('🔧 Creating admin user in database...');
          const hashedPassword = await bcrypt.hash('Admin_aids@smvec', 10);
          
          adminUser = await pool.query(
            'INSERT INTO users (name, enroll_number, year, section, batch, password, role, is_online, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW(), NOW()) RETURNING id, name, enroll_number, role, year, section, batch, is_online',
            ['Administrator', 'ADMIN001', 'ADMIN', 'ADM', '2024', hashedPassword, 'admin', true]
          );
          
          console.log('✅ Admin user created successfully');
        }

        const user = adminUser.rows[0];
        console.log('👤 Admin user data:', {
          id: user.id,
          name: user.name,
          enroll_number: user.enroll_number,
          role: user.role
        });

        // Get client IP address for admin with enhanced detection
        const adminForwardedFor = req.headers['x-forwarded-for'];
        const adminRealIp = req.headers['x-real-ip'];
        const adminIp = adminForwardedFor?.split(',')[0]?.trim() || 
                       adminRealIp || 
                       req.ip || 
                       req.connection?.remoteAddress || 
                       req.socket?.remoteAddress || 
                       (req.connection?.socket ? req.connection.socket.remoteAddress : null) ||
                       'unknown';
        
        console.log(`📍 Admin IP Detection Details:`);
        console.log(`   - x-forwarded-for: ${adminForwardedFor}`);
        console.log(`   - x-real-ip: ${adminRealIp}`);
        console.log(`   - req.ip: ${req.ip}`);
        console.log(`   - connection.remoteAddress: ${req.connection?.remoteAddress}`);
        console.log(`   - Final Admin IP: ${adminIp}`);

        // Update last active, online status, and IP address
        console.log('🔄 Updating admin online status...');
        await pool.query(
          'UPDATE users SET last_active = NOW(), is_online = true, ip_address = $2, updated_at = NOW() WHERE id = $1',
          [user.id, adminIp]
        );

        // Create session
        console.log('📝 Creating admin session...');
        await pool.query(
          'INSERT INTO user_sessions (user_id, session_start, is_active) VALUES ($1, NOW(), $2)',
          [user.id, true]
        );

        // Generate JWT token
        console.log('🎫 Generating JWT token...');
        const token = jwt.sign(
          { userId: user.id, role: user.role, enrollNumber: user.enroll_number },
          JWT_SECRET,
          { expiresIn: '24h' }
        );

        console.log('✅ Admin login successful - sending response');
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
            isOnline: true,
            ipAddress: adminIp
          }
        });

      } catch (dbError) {
        console.error('💥 Database error during admin login:', dbError);
        console.error('Error details:', {
          message: dbError.message,
          code: dbError.code,
          detail: dbError.detail,
          hint: dbError.hint
        });
        return res.status(500).json({ 
          message: 'Database error during admin login',
          error: dbError.message 
        });
      }
    }

    // Regular student login
    console.log('👨‍🎓 Processing student login...');
    
    try {
      const result = await pool.query(
        'SELECT * FROM users WHERE enroll_number = $1 AND role = $2',
        [enrollNumber, 'student']
      );

      if (result.rows.length === 0) {
        console.log('❌ Student not found:', enrollNumber);
        return res.status(400).json({ message: 'Invalid credentials' });
      }

      const user = result.rows[0];
      console.log('👤 Found student:', user.name);

      // Check password
      const isMatch = await bcrypt.compare(password, user.password);
      if (!isMatch) {
        console.log('❌ Password mismatch for student:', enrollNumber);
        return res.status(400).json({ message: 'Invalid credentials' });
      }

      // Get client IP address with enhanced detection
      const forwardedFor = req.headers['x-forwarded-for'];
      const realIp = req.headers['x-real-ip'];
      const clientIp = forwardedFor?.split(',')[0]?.trim() || 
                      realIp || 
                      req.ip || 
                      req.connection?.remoteAddress || 
                      req.socket?.remoteAddress || 
                      (req.connection?.socket ? req.connection.socket.remoteAddress : null) ||
                      'unknown';
      
      console.log(`📍 IP Detection Details:`);
      console.log(`   - x-forwarded-for: ${forwardedFor}`);
      console.log(`   - x-real-ip: ${realIp}`);
      console.log(`   - req.ip: ${req.ip}`);
      console.log(`   - connection.remoteAddress: ${req.connection?.remoteAddress}`);
      console.log(`   - Final IP: ${clientIp}`);

      // Update last active, online status, and IP address
      await pool.query(
        'UPDATE users SET last_active = NOW(), is_online = true, ip_address = $2, updated_at = NOW() WHERE id = $1',
        [user.id, clientIp]
      );

      // Create session
      await pool.query(
        'INSERT INTO user_sessions (user_id, session_start, is_active) VALUES ($1, NOW(), $2)',
        [user.id, true]
      );

      const token = jwt.sign(
        { userId: user.id, role: user.role, enrollNumber: user.enroll_number },
        JWT_SECRET,
        { expiresIn: '24h' }
      );

      console.log('✅ Student login successful:', user.name);
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
          isOnline: true,
          ipAddress: clientIp
        }
      });

    } catch (dbError) {
      console.error('💥 Database error during student login:', dbError);
      return res.status(500).json({ 
        message: 'Database error during student login',
        error: dbError.message 
      });
    }

  } catch (error) {
    console.error('💥 Unexpected error during login:', error);
    console.error('Error stack:', error.stack);
    res.status(500).json({ 
      message: 'Server error during login',
      error: error.message,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
});

// Register (only for students) - with enhanced logging
router.post('/register', async (req, res) => {
  try {
    console.log('\n=== REGISTRATION REQUEST RECEIVED ===');
    console.log('Request body:', req.body);
    
    const { name, enrollNumber, year, section, batch, password } = req.body;
    
    // Validate required fields
    if (!name || !enrollNumber || !year || !section || !batch || !password) {
      console.log('❌ Missing required fields for registration');
      return res.status(400).json({ message: 'All fields are required' });
    }
    
    // Prevent admin registration through this route
    if (enrollNumber.toUpperCase() === 'ADMIN001' || enrollNumber.toLowerCase().includes('admin')) {
      console.log('❌ Attempted admin registration through student route');
      return res.status(400).json({ message: 'Invalid enrollment number. Use admin login for admin access.' });
    }
    
    try {
      // Check if user already exists
      const userExists = await pool.query(
        'SELECT * FROM users WHERE enroll_number = $1',
        [enrollNumber]
      );

      if (userExists.rows.length > 0) {
        console.log('❌ User already exists:', enrollNumber);
        return res.status(400).json({ message: 'User already exists with this enrollment number' });
      }

      // Hash password
      const hashedPassword = await bcrypt.hash(password, 10);

      // Insert user (always as student)
      const result = await pool.query(
        'INSERT INTO users (name, enroll_number, year, section, batch, password, role, is_online, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW(), NOW()) RETURNING id, name, enroll_number, role, year, section, batch, is_online',
        [name, enrollNumber, year, section, batch, hashedPassword, 'student', true]
      );

      const user = result.rows[0];

      // Create session
      await pool.query(
        'INSERT INTO user_sessions (user_id, session_start, is_active) VALUES ($1, NOW(), $2)',
        [user.id, true]
      );

      const token = jwt.sign(
        { userId: user.id, role: user.role, enrollNumber: user.enroll_number },
        JWT_SECRET,
        { expiresIn: '24h' }
      );

      console.log('✅ Student registered successfully:', user.name);
      res.status(201).json({
        message: 'User registered successfully',
        token,
        user: {
          id: user.id,
          name: user.name,
          enrollNumber: user.enroll_number,
          role: user.role,
          year: user.year,
          section: user.section,
          batch: user.batch,
          isOnline: user.is_online
        }
      });

    } catch (dbError) {
      console.error('💥 Database error during registration:', dbError);
      return res.status(500).json({ 
        message: 'Database error during registration',
        error: dbError.message 
      });
    }

  } catch (error) {
    console.error('💥 Unexpected error during registration:', error);
    res.status(500).json({ 
      message: 'Server error during registration',
      error: error.message 
    });
  }
});

// Admin Registration - with enhanced logging
router.post('/register-admin', async (req, res) => {
  try {
    console.log('\n=== ADMIN REGISTRATION REQUEST RECEIVED ===');
    console.log('Request body (passwords hidden):', {
      name: req.body.name,
      username: req.body.username,
      hasPassword: !!req.body.password,
      hasMasterPassword: !!req.body.masterPassword
    });
    
    const { name, username, password, masterPassword } = req.body;
    
    // Validate required fields
    if (!name || !username || !password || !masterPassword) {
      console.log('❌ Missing required fields for admin registration');
      return res.status(400).json({ message: 'All fields are required' });
    }
    
    // Validate master password
    if (masterPassword !== 'Admin_aids@smvec') {
      console.log('❌ Invalid master password provided');
      return res.status(400).json({ message: 'Invalid master password' });
    }
    
    try {
      // Check if admin username already exists
      const adminExists = await pool.query(
        'SELECT * FROM users WHERE enroll_number = $1',
        [username]
      );

      if (adminExists.rows.length > 0) {
        console.log('❌ Admin username already exists:', username);
        return res.status(400).json({ message: 'Admin username already exists' });
      }

      // Hash password
      const hashedPassword = await bcrypt.hash(password, 10);

      // Insert admin user
      const result = await pool.query(
        'INSERT INTO users (name, enroll_number, year, section, batch, password, role, is_online, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW(), NOW()) RETURNING id, name, enroll_number, role, year, section, batch, is_online',
        [name, username, 'ADMIN', 'ADM', '2024', hashedPassword, 'admin', true]
      );

      const user = result.rows[0];

      // Create session
      await pool.query(
        'INSERT INTO user_sessions (user_id, session_start, is_active) VALUES ($1, NOW(), $2)',
        [user.id, true]
      );

      const token = jwt.sign(
        { userId: user.id, role: user.role, enrollNumber: user.enroll_number },
        JWT_SECRET,
        { expiresIn: '24h' }
      );

      console.log('✅ Admin registered successfully:', user.name);
      res.status(201).json({
        message: 'Admin registered successfully',
        token,
        user: {
          id: user.id,
          name: user.name,
          enrollNumber: user.enroll_number,
          role: user.role,
          year: user.year,
          section: user.section,
          batch: user.batch,
          isOnline: user.is_online
        }
      });

    } catch (dbError) {
      console.error('💥 Database error during admin registration:', dbError);
      return res.status(500).json({ 
        message: 'Database error during admin registration',
        error: dbError.message 
      });
    }

  } catch (error) {
    console.error('💥 Unexpected error during admin registration:', error);
    res.status(500).json({ 
      message: 'Server error during admin registration',
      error: error.message 
    });
  }
});

// Enhanced logout endpoint with detailed logging
router.post('/logout', auth, async (req, res) => {
  try {
    console.log('\n=== LOGOUT REQUEST RECEIVED ===');
    console.log('User from token:', req.user);
    console.log('Request body:', req.body);
    
    const userId = req.user.userId;
    const { enrollNumber } = req.body;
    
    // Use enroll number from token if not provided in body
    const targetEnrollNumber = enrollNumber || req.user.enrollNumber;
    
    console.log('🎯 Target enroll number:', targetEnrollNumber);
    
    try {
      // Update user's online status to false
      const updateQuery = `
        UPDATE users 
        SET is_online = false, 
            last_active = NOW(), 
            updated_at = NOW() 
        WHERE id = $1
        RETURNING id, name, enroll_number, is_online, last_active
      `;
      
      const result = await pool.query(updateQuery, [userId]);
      
      if (result.rows.length === 0) {
        console.log('❌ User not found for logout:', userId);
        return res.status(404).json({ 
          success: false, 
          message: 'User not found' 
        });
      }
      
      const updatedUser = result.rows[0];
      console.log('✅ User offline status updated:', updatedUser);
      
      // Mark active sessions as inactive
      await pool.query(
        'UPDATE user_sessions SET is_active = false, session_end = NOW() WHERE user_id = $1 AND is_active = true',
        [userId]
      );
      
      console.log('✅ User sessions marked inactive');
      
      // Emit socket event to notify other users if io is available
      if (req.app && req.app.get('io')) {
        req.app.get('io').emit('user-status-changed', {
          enrollNumber: targetEnrollNumber,
          name: updatedUser.name,
          isOnline: false,
          lastActive: updatedUser.last_active,
          reason: 'logout'
        });
        console.log('📡 Socket event emitted: user-status-changed');
      }
      
      console.log('✅ Logout completed successfully for:', updatedUser.name);
      res.json({
        success: true,
        message: 'User logged out successfully',
        user: {
          id: updatedUser.id,
          name: updatedUser.name,
          enrollNumber: updatedUser.enroll_number,
          isOnline: updatedUser.is_online,
          lastActive: updatedUser.last_active
        }
      });

    } catch (dbError) {
      console.error('💥 Database error during logout:', dbError);
      return res.status(500).json({ 
        success: false,
        message: 'Database error during logout',
        error: dbError.message 
      });
    }
    
  } catch (error) {
    console.error('💥 Unexpected error during logout:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Internal server error during logout',
      error: error.message 
    });
  }
});

// Test database connection endpoint
router.get('/test-db', async (req, res) => {
  try {
    console.log('🧪 Testing database connection...');
    const result = await pool.query('SELECT NOW() as current_time, version() as postgres_version');
    console.log('✅ Database connection test successful');
    res.json({
      success: true,
      message: 'Database connection successful',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('💥 Database connection test failed:', error);
    res.status(500).json({
      success: false,
      message: 'Database connection failed',
      error: error.message
    });
  }
});

// Get current user info
router.get('/me', auth, async (req, res) => {
  try {
    const userId = req.user.userId;
    
    const result = await pool.query(
      'SELECT id, name, enroll_number, role, year, section, batch, is_online, last_active FROM users WHERE id = $1',
      [userId]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    const user = result.rows[0];
    res.json({
      id: user.id,
      name: user.name,
      enrollNumber: user.enroll_number,
      role: user.role,
      year: user.year,
      section: user.section,
      batch: user.batch,
      isOnline: user.is_online,
      lastActive: user.last_active
    });
  } catch (error) {
    console.error('Get user info error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Verify token endpoint
router.post('/verify-token', auth, async (req, res) => {
  try {
    const userId = req.user.userId;
    
    const result = await pool.query(
      'SELECT id, name, enroll_number, role, year, section, batch, is_online FROM users WHERE id = $1',
      [userId]
    );
    
    if (result.rows.length === 0) {
      return res.status(401).json({ message: 'Invalid token' });
    }
    
    const user = result.rows[0];
    res.json({
      valid: true,
      user: {
        id: user.id,
        name: user.name,
        enrollNumber: user.enroll_number,
        role: user.role,
        year: user.year,
        section: user.section,
        batch: user.batch,
        isOnline: user.is_online
      }
    });
  } catch (error) {
    console.error('Token verification error:', error);
    res.status(401).json({ 
      valid: false, 
      message: 'Invalid token' 
    });
  }
});

module.exports = router;