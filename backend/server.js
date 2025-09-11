const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const path = require('path');
const fs = require('fs-extra');

const { pool } = require('./config/database');
const authRoutes = require('./routes/auth');
const adminRoutes = require('./routes/admin');
const studentRoutes = require('./routes/student');
const exerciseRoutes = require('./routes/exercises');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Create temp directory for code compilation
const tempDir = path.join(__dirname, 'temp');
fs.ensureDirSync(tempDir);

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/student', studentRoutes);
app.use('/api/exercises', exerciseRoutes);

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'Lab Monitoring Server is running',
    timestamp: new Date().toISOString()
  });
});

// Server status endpoint for student login validation
app.get('/api/status', (req, res) => {
  res.json({ 
    server: 'online',
    timestamp: new Date().toISOString(),
    message: 'Admin server is running'
  });
});

// Socket.IO for real-time monitoring
const activeUsers = new Map();

io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  socket.on('user-login', (userData) => {
    activeUsers.set(socket.id, {
      ...userData,
      socketId: socket.id,
      lastActive: new Date(),
      status: 'online'
    });
    
    console.log(`User ${userData.name} (${userData.enrollNumber}) connected`);
    
    // Notify admins of new user
    io.emit('user-status-update', Array.from(activeUsers.values()));
  });

  socket.on('code-execution', (data) => {
    console.log('Code execution from:', activeUsers.get(socket.id)?.enrollNumber);
    
    // Broadcast code execution to admins
    io.emit('student-activity', {
      userId: activeUsers.get(socket.id)?.enrollNumber,
      userName: activeUsers.get(socket.id)?.name,
      activity: 'code-execution',
      data: data,
      timestamp: new Date().toISOString()
    });
  });

  socket.on('screen-share', (screenData) => {
    // Handle screen sharing for admin monitoring
    io.emit('student-screen', {
      userId: activeUsers.get(socket.id)?.enrollNumber,
      screenData: screenData
    });
  });

  socket.on('disconnect', () => {
    const user = activeUsers.get(socket.id);
    if (user) {
      console.log(`User ${user.name} (${user.enrollNumber}) disconnected`);
    }
    
    activeUsers.delete(socket.id);
    io.emit('user-status-update', Array.from(activeUsers.values()));
    console.log('User disconnected:', socket.id);
  });

  // Handle user activity updates
  socket.on('user-activity', (activityData) => {
    const user = activeUsers.get(socket.id);
    if (user) {
      user.lastActive = new Date();
      io.emit('student-activity', {
        userId: user.enrollNumber,
        userName: user.name,
        activity: activityData.type,
        data: activityData,
        timestamp: new Date().toISOString()
      });
    }
  });

  // Handle request for online users
  socket.on('get-online-users', () => {
    socket.emit('online-users', Array.from(activeUsers.values()));
  });
});

// Database initialization
async function initDatabase() {
  try {
    // Test database connection
    const client = await pool.connect();
    console.log('✅ Database connection successful');
    client.release();

    // Create tables if they don't exist
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        enroll_number VARCHAR(20) UNIQUE NOT NULL,
        year VARCHAR(10) NOT NULL,
        section VARCHAR(5) NOT NULL,
        batch VARCHAR(10) NOT NULL,
        password VARCHAR(255) NOT NULL,
        role VARCHAR(20) DEFAULT 'student',
        last_active TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS subjects (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        code VARCHAR(20) UNIQUE NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS exercises (
        id SERIAL PRIMARY KEY,
        subject_id INTEGER REFERENCES subjects(id) ON DELETE CASCADE,
        title VARCHAR(200) NOT NULL,
        description TEXT NOT NULL,
        test_cases JSONB NOT NULL,
        hidden_test_cases JSONB NOT NULL,
        difficulty_level VARCHAR(20) DEFAULT 'medium',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS submissions (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        exercise_id INTEGER REFERENCES exercises(id) ON DELETE CASCADE,
        code TEXT NOT NULL,
        status VARCHAR(20) NOT NULL,
        score INTEGER DEFAULT 0,
        execution_time FLOAT,
        submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS user_sessions (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        session_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        session_end TIMESTAMP,
        is_active BOOLEAN DEFAULT TRUE
      )
    `);

    console.log('✅ Database tables initialized successfully');
    
    // Insert default admin if doesn't exist
    const adminCheck = await pool.query("SELECT * FROM users WHERE role = 'admin' LIMIT 1");
    if (adminCheck.rows.length === 0) {
      const bcrypt = require('bcryptjs');
      const hashedPassword = await bcrypt.hash('Admin_aids@smvec', 10);
      await pool.query(
        "INSERT INTO users (name, enroll_number, year, section, batch, password, role) VALUES ($1, $2, $3, $4, $5, $6, $7)",
        ['Admin', 'ADMIN001', 'ADMIN', 'ADM', '2024', hashedPassword, 'admin']
      );
      console.log('✅ Default admin created');
    }

    // Insert default subject if doesn't exist
    const subjectCheck = await pool.query("SELECT * FROM subjects WHERE code = 'CS101'");
    if (subjectCheck.rows.length === 0) {
      await pool.query(
        "INSERT INTO subjects (name, code) VALUES ($1, $2)",
        ['C Programming', 'CS101']
      );
      console.log('✅ Default subject created');
    }

  } catch (error) {
    console.error('❌ Database initialization error:', error.message);
    console.error('Please check your database configuration in config/database.js');
    process.exit(1);
  }
}

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Server error:', err.stack);
  res.status(500).json({ 
    message: 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? err.message : {}
  });
});

// Handle unhandled routes
app.use('*', (req, res) => {
  res.status(404).json({ 
    message: 'Route not found',
    availableRoutes: [
      '/api/health',
      '/api/auth/login',
      '/api/auth/register',
      '/api/exercises/subjects',
      '/api/admin/*',
      '/api/student/*'
    ]
  });
});

const PORT = process.env.PORT || 3000;

server.listen(PORT, '0.0.0.0', async () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📊 Admin Panel: http://0.0.0.0:${PORT}/api/health`);
  console.log(`💻 Socket.IO enabled for real-time monitoring`);
  console.log(`🌐 Server accessible from any device on the network`);
  
  await initDatabase();
  
  console.log('🎉 Lab Monitoring System is ready!');
  console.log('\n📝 Default Admin Credentials:');
  console.log('   Username: ADMIN001');
  console.log('   Password: Admin_aids@smvec\n');
});