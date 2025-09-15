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

// Make Socket.IO instance available to routes
app.set('socketio', io);
app.set('io', io);

// Middleware
app.use(cors());

// Request logging middleware for admin routes
app.use('/api/admin', (req, res, next) => {
  console.log(`\n=== ${req.method} ${req.path} ===`);
  console.log('Content-Type:', req.headers['content-type']);
  console.log('Content-Length:', req.headers['content-length']);
  next();
});

// Enhanced JSON parsing middleware with error handling
app.use(express.json({ 
  limit: '10mb',
  verify: (req, res, buf, encoding) => {
    try {
      JSON.parse(buf);
    } catch (e) {
      console.error('JSON Parse Error:', e.message);
      console.error('Raw body:', buf.toString());
      throw new Error('Invalid JSON in request body');
    }
  }
}));

app.use(express.urlencoded({ extended: true }));

// Trust proxy to get real IP addresses
app.set('trust proxy', true);

// Create temp directory for code compilation
const tempDir = path.join(__dirname, 'temp');
fs.ensureDirSync(tempDir);

// Routes with /api prefix to match Flutter app expectations
app.use('/api/auth', authRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/student', studentRoutes);
app.use('/api/exercises', exerciseRoutes);

// Health check endpoint with /api prefix
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'Lab Monitoring Server is running',
    timestamp: new Date().toISOString()
  });
});

// Server status endpoint for student login validation with /api prefix
app.get('/api/status', (req, res) => {
  res.json({ 
    server: 'online',
    timestamp: new Date().toISOString(),
    message: 'Admin server is running'
  });
});

// Legacy routes without /api prefix for backward compatibility
app.use('/auth', authRoutes);
app.use('/admin', adminRoutes);
app.use('/student', studentRoutes);
app.use('/exercises', exerciseRoutes);

app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'Lab Monitoring Server is running',
    timestamp: new Date().toISOString()
  });
});

app.get('/status', (req, res) => {
  res.json({ 
    server: 'online',
    timestamp: new Date().toISOString(),
    message: 'Admin server is running'
  });
});

// Enhanced Socket.IO for real-time monitoring with admin logout support
const connectedUsers = new Map(); // enrollNumber -> { socketId, userInfo, joinTime }
const connectedSockets = new Map(); // socketId -> userInfo
let serverShuttingDown = false;

io.on('connection', (socket) => {
  console.log(`🔌 New client connected: ${socket.id}`);

  // Handle user login (students)
  socket.on('user-login', async (userData) => {
    try {
      console.log('👤 Student login via socket:', userData);
      
      const { enrollNumber, name, role } = userData;
      
      if (role === 'student') {
        // Store user connection info
        connectedUsers.set(enrollNumber, {
          socketId: socket.id,
          userInfo: userData,
          joinTime: new Date(),
          lastActivity: new Date()
        });
        
        connectedSockets.set(socket.id, {
          enrollNumber,
          name,
          role
        });

        // Update database to mark user online
        await pool.query(
          'UPDATE users SET is_online = true, last_active = NOW(), updated_at = NOW() WHERE enroll_number = $1',
          [enrollNumber]
        );

        console.log(`✅ Student ${name} (${enrollNumber}) connected and marked online`);

        // Broadcast to all clients that a new user is online
        io.emit('user-connected', {
          enrollNumber,
          name,
          role,
          timestamp: new Date().toISOString()
        });

        // Send current online users list to all clients
        const onlineUsers = Array.from(connectedUsers.values())
          .filter(conn => conn.userInfo.role === 'student')
          .map(conn => conn.userInfo);
        io.emit('online-users', onlineUsers);
        io.emit('user-status-update', onlineUsers);
      }
    } catch (error) {
      console.error('Error handling user login:', error);
    }
  });

  // Handle admin login
  socket.on('admin-login', async (adminData) => {
    try {
      console.log('🔑 Admin login via socket:', adminData);
      
      const { enrollNumber, name, role } = adminData;
      
      if (role === 'admin') {
        // Store admin connection info
        connectedUsers.set(enrollNumber, {
          socketId: socket.id,
          userInfo: adminData,
          joinTime: new Date(),
          lastActivity: new Date()
        });
        
        connectedSockets.set(socket.id, {
          enrollNumber,
          name,
          role: 'admin'
        });

        // Update database to mark admin online
        await pool.query(
          'UPDATE users SET is_online = true, last_active = NOW(), updated_at = NOW() WHERE enroll_number = $1',
          [enrollNumber]
        );

        console.log(`✅ Admin ${name} (${enrollNumber}) connected and server is now online`);

        // Broadcast to all clients that admin is online (server is available)
        io.emit('admin-connected', {
          message: 'Server is now online. Admin has logged in.',
          timestamp: new Date().toISOString()
        });
      }
    } catch (error) {
      console.error('Error handling admin login:', error);
    }
  });

  // Handle user logout (students)
  socket.on('user-logout', async (userData) => {
    try {
      console.log('👋 Student logout via socket:', userData);
      
      const { enrollNumber, name } = userData;
      
      // Remove from connected users
      connectedUsers.delete(enrollNumber);
      connectedSockets.delete(socket.id);

      // Update database to mark user offline
      await pool.query(
        'UPDATE users SET is_online = false, last_active = NOW(), updated_at = NOW() WHERE enroll_number = $1',
        [enrollNumber]
      );

      console.log(`✅ Student ${name} (${enrollNumber}) disconnected and marked offline`);

      // Broadcast to all clients that user is offline
      io.emit('user-disconnected', {
        enrollNumber,
        name,
        timestamp: new Date().toISOString()
      });

      // Send updated online users list
      const onlineUsers = Array.from(connectedUsers.values())
        .filter(conn => conn.userInfo.role === 'student')
        .map(conn => conn.userInfo);
      io.emit('online-users', onlineUsers);
      io.emit('user-status-update', onlineUsers);
      
    } catch (error) {
      console.error('Error handling user logout:', error);
    }
  });

  // Handle admin logout - CRITICAL: This triggers server shutdown
  socket.on('admin-logout', async (adminData) => {
    try {
      console.log('🔴 ADMIN LOGOUT VIA SOCKET - INITIATING SHUTDOWN:', adminData);
      
      if (serverShuttingDown) {
        console.log('⚠️ Server already shutting down, ignoring duplicate admin logout');
        return;
      }
      
      serverShuttingDown = true;
      
      const { enrollNumber, name, onlineStudentCount } = adminData;
      
      // Get all currently connected student sockets
      const connectedStudents = Array.from(connectedUsers.values())
        .filter(conn => conn.userInfo.role === 'student');
      
      console.log(`📊 Found ${connectedStudents.length} connected students to disconnect`);
      
      // 1. Set all students offline in database
      const result = await pool.query(
        'UPDATE users SET is_online = false, last_active = NOW(), updated_at = NOW() WHERE role = $1 RETURNING name, enroll_number',
        ['student']
      );
      
      console.log(`✅ Set ${result.rows.length} students offline in database`);
      
      // 2. End all active sessions
      await pool.query(
        'UPDATE user_sessions SET is_active = false, session_end = NOW() WHERE is_active = true'
      );
      
      // 3. Broadcast shutdown notification to all connected clients
      const shutdownMessage = {
        message: 'Admin has logged out. Server is shutting down.',
        adminName: name,
        timestamp: new Date().toISOString(),
        studentsAffected: connectedStudents.length,
        reason: 'admin_logout'
      };
      
      console.log('📡 Broadcasting admin shutdown to all clients...');
      io.emit('admin-shutdown', shutdownMessage);
      
      // 4. Send individual disconnection notices and force disconnect students
      setTimeout(() => {
        console.log('🔌 Force disconnecting all student sockets...');
        
        connectedStudents.forEach(studentConn => {
          const studentSocket = io.sockets.sockets.get(studentConn.socketId);
          if (studentSocket) {
            console.log(`   Disconnecting student: ${studentConn.userInfo.name}`);
            studentSocket.emit('force-disconnect', {
              reason: 'admin_logout',
              message: 'Server is shutting down due to admin logout',
              timestamp: new Date().toISOString()
            });
            studentSocket.disconnect(true);
          }
          // Remove from our tracking
          connectedUsers.delete(studentConn.userInfo.enrollNumber);
          connectedSockets.delete(studentConn.socketId);
        });
        
        console.log('✅ All student sockets disconnected');
        
        // 5. Remove admin from connected users
        connectedUsers.delete(enrollNumber);
        connectedSockets.delete(socket.id);
        
        // 6. Set admin offline in database
        pool.query(
          'UPDATE users SET is_online = false, last_active = NOW(), updated_at = NOW() WHERE enroll_number = $1',
          [enrollNumber]
        ).then(() => {
          console.log('✅ Admin marked offline in database');
        }).catch(err => {
          console.error('❌ Error marking admin offline:', err);
        });
        
        console.log('🔴 ADMIN LOGOUT COMPLETED - SERVER SHUTDOWN SEQUENCE FINISHED');
        
        // 7. Optional: Actually terminate the server process after a delay
        setTimeout(() => {
          console.log('🔴 TERMINATING SERVER PROCESS DUE TO ADMIN LOGOUT...');
          process.exit(0);
        }, 3000); // 3 second delay to ensure all cleanup is done
        
      }, 2000); // 2 second delay to ensure messages are delivered
      
    } catch (error) {
      console.error('💥 Error handling admin logout:', error);
      serverShuttingDown = false; // Reset flag on error
    }
  });

  // Legacy socket events (keeping for compatibility)
  socket.on('code-execution', (data) => {
    const user = connectedSockets.get(socket.id);
    if (user) {
      console.log('Code execution from:', user.enrollNumber);
      
      // Update last activity
      const userConnection = connectedUsers.get(user.enrollNumber);
      if (userConnection) {
        userConnection.lastActivity = new Date();
      }
      
      // Broadcast code execution to admins
      io.emit('student-activity', {
        userId: user.enrollNumber,
        userName: user.name,
        activity: 'code-execution',
        data: data,
        timestamp: new Date().toISOString()
      });
    }
  });

  socket.on('screen-share', (screenData) => {
    const user = connectedSockets.get(socket.id);
    if (user) {
      // Handle screen sharing for admin monitoring
      io.emit('student-screen', {
        userId: user.enrollNumber,
        userName: user.name,
        screenData: screenData,
        timestamp: new Date().toISOString()
      });
    }
  });

  // Handle user activity updates
  socket.on('user-activity', (activityData) => {
    const user = connectedSockets.get(socket.id);
    if (user) {
      const userConnection = connectedUsers.get(user.enrollNumber);
      if (userConnection) {
        userConnection.lastActivity = new Date();
      }
      
      io.emit('student-activity', {
        userId: user.enrollNumber,
        userName: user.name,
        activity: activityData.type,
        data: activityData,
        timestamp: new Date().toISOString()
      });
    }
  });

  // Handle get online users request
  socket.on('get-online-users', () => {
    try {
      const onlineUsers = Array.from(connectedUsers.values())
        .filter(conn => conn.userInfo.role === 'student')
        .map(conn => conn.userInfo);
      
      socket.emit('online-users', onlineUsers);
      console.log(`📊 Sent ${onlineUsers.length} online users to requesting client`);
    } catch (error) {
      console.error('Error sending online users:', error);
    }
  });

  // Handle socket disconnection
  socket.on('disconnect', async (reason) => {
    try {
      console.log(`🔌 Client disconnected: ${socket.id}, reason: ${reason}`);
      
      const userInfo = connectedSockets.get(socket.id);
      if (userInfo) {
        const { enrollNumber, name, role } = userInfo;
        
        // Remove from our tracking
        connectedUsers.delete(enrollNumber);
        connectedSockets.delete(socket.id);
        
        // Update database to mark user offline
        await pool.query(
          'UPDATE users SET is_online = false, last_active = NOW(), updated_at = NOW() WHERE enroll_number = $1',
          [enrollNumber]
        );
        
        console.log(`✅ ${role} ${name} (${enrollNumber}) marked offline due to disconnect`);
        
        if (role === 'student') {
          // Broadcast student disconnection
          io.emit('user-disconnected', {
            enrollNumber,
            name,
            timestamp: new Date().toISOString(),
            reason: 'socket_disconnect'
          });
          
          // Send updated online users list
          const onlineUsers = Array.from(connectedUsers.values())
            .filter(conn => conn.userInfo.role === 'student')
            .map(conn => conn.userInfo);
          io.emit('online-users', onlineUsers);
          io.emit('user-status-update', onlineUsers);
          
        } else if (role === 'admin') {
          console.log('🔴 ADMIN DISCONNECTED UNEXPECTEDLY');
          
          if (!serverShuttingDown) {
            // If admin disconnects unexpectedly, notify all students and initiate shutdown
            console.log('🚨 ADMIN UNEXPECTED DISCONNECT - INITIATING EMERGENCY SHUTDOWN');
            
            // Set all students offline
            await pool.query(
              'UPDATE users SET is_online = false, last_active = NOW(), updated_at = NOW() WHERE role = $1',
              ['student']
            );
            
            // End all active sessions
            await pool.query(
              'UPDATE user_sessions SET is_active = false, session_end = NOW() WHERE is_active = true'
            );
            
            // Notify all students
            io.emit('admin-shutdown', {
              message: 'Admin connection lost unexpectedly. Server is shutting down.',
              timestamp: new Date().toISOString(),
              reason: 'admin_disconnect'
            });
            
            // Disconnect all remaining sockets and shutdown server
            setTimeout(() => {
              console.log('🔴 EMERGENCY SERVER SHUTDOWN DUE TO ADMIN DISCONNECT');
              process.exit(1);
            }, 3000);
          }
        }
      }
    } catch (error) {
      console.error('Error handling disconnect:', error);
    }
  });

  // Handle heartbeat/ping to keep connections alive
  socket.on('ping', (data) => {
    socket.emit('pong', data);
  });
});

// Utility function to get connection statistics
function getConnectionStats() {
  const students = Array.from(connectedUsers.values()).filter(conn => conn.userInfo.role === 'student');
  const admins = Array.from(connectedUsers.values()).filter(conn => conn.userInfo.role === 'admin');
  
  return {
    totalConnections: connectedUsers.size,
    studentConnections: students.length,
    adminConnections: admins.length,
    socketConnections: io.sockets.sockets.size,
    students: students.map(s => ({ name: s.userInfo.name, enrollNumber: s.userInfo.enrollNumber })),
    admins: admins.map(a => ({ name: a.userInfo.name, enrollNumber: a.userInfo.enrollNumber }))
  };
}

// Periodic cleanup of stale connections
setInterval(() => {
  if (serverShuttingDown) return; // Skip cleanup if shutting down
  
  const now = new Date();
  const staleThreshold = 5 * 60 * 1000; // 5 minutes
  
  connectedUsers.forEach(async (connection, enrollNumber) => {
    const timeSinceActivity = now - connection.lastActivity;
    if (timeSinceActivity > staleThreshold) {
      console.log(`🧹 Cleaning up stale connection for ${connection.userInfo.name}`);
      
      // Mark as offline in database
      try {
        await pool.query(
          'UPDATE users SET is_online = false, last_active = NOW(), updated_at = NOW() WHERE enroll_number = $1',
          [enrollNumber]
        );
        
        // Remove from tracking
        connectedUsers.delete(enrollNumber);
        connectedSockets.delete(connection.socketId);
        
        // Broadcast disconnection
        io.emit('user-disconnected', {
          enrollNumber,
          name: connection.userInfo.name,
          timestamp: now.toISOString(),
          reason: 'stale_connection'
        });
        
        // Update online users list
        const onlineUsers = Array.from(connectedUsers.values())
          .filter(conn => conn.userInfo.role === 'student')
          .map(conn => conn.userInfo);
        io.emit('online-users', onlineUsers);
        
      } catch (error) {
        console.error('Error cleaning up stale connection:', error);
      }
    }
  });
}, 60000); // Run every minute

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
        is_online BOOLEAN DEFAULT false,
        last_active TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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
        input_format TEXT,
        output_format TEXT,
        constraints TEXT,
        test_cases JSONB NOT NULL,
        hidden_test_cases JSONB DEFAULT '[]'::jsonb,
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
        language VARCHAR(20) DEFAULT 'c',
        status VARCHAR(20) NOT NULL,
        score INTEGER DEFAULT 0,
        test_cases_passed INTEGER DEFAULT 0,
        total_test_cases INTEGER DEFAULT 0,
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

    // Add columns if they don't exist
    await pool.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false`);
    await pool.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP`);
    await pool.query(`ALTER TABLE exercises ADD COLUMN IF NOT EXISTS input_format TEXT`);
    await pool.query(`ALTER TABLE exercises ADD COLUMN IF NOT EXISTS output_format TEXT`);
    await pool.query(`ALTER TABLE exercises ADD COLUMN IF NOT EXISTS constraints TEXT`);
    await pool.query(`ALTER TABLE exercises ADD COLUMN IF NOT EXISTS hidden_test_cases JSONB DEFAULT '[]'::jsonb`);
    await pool.query(`ALTER TABLE submissions ADD COLUMN IF NOT EXISTS language VARCHAR(20) DEFAULT 'c'`);
    await pool.query(`ALTER TABLE submissions ADD COLUMN IF NOT EXISTS test_cases_passed INTEGER DEFAULT 0`);
    await pool.query(`ALTER TABLE submissions ADD COLUMN IF NOT EXISTS total_test_cases INTEGER DEFAULT 0`);
    
    console.log('✅ Database tables initialized successfully');
    
    // Insert default admin if doesn't exist
    const adminCheck = await pool.query("SELECT * FROM users WHERE role = 'admin' LIMIT 1");
    if (adminCheck.rows.length === 0) {
      const bcrypt = require('bcryptjs');
      const hashedPassword = await bcrypt.hash('Admin_aids@smvec', 10);
      await pool.query(
        "INSERT INTO users (name, enroll_number, year, section, batch, password, role) VALUES ($1, $2, $3, $4, $5, $6, $7)",
        ['Administrator', 'ADMIN001', 'ADMIN', 'ADM', '2024', hashedPassword, 'admin']
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
      '/api/student/*',
      // Legacy routes
      '/health',
      '/auth/login',
      '/auth/register',
      '/exercises/subjects',
      '/admin/*',
      '/student/*'
    ]
  });
});

// Graceful shutdown handlers
process.on('SIGTERM', () => {
  console.log('🔴 SIGTERM received - shutting down gracefully');
  server.close(() => {
    console.log('✅ HTTP server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('🔴 SIGINT received - shutting down gracefully');
  server.close(() => {
    console.log('✅ HTTP server closed');
    process.exit(0);
  });
});

const PORT = process.env.PORT || 3000;

server.listen(PORT, '0.0.0.0', async () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📊 Admin Panel: http://0.0.0.0:${PORT}/api/health`);
  console.log(`💻 Socket.IO enabled for real-time monitoring`);
  console.log(`🌐 Server accessible from any device on the network`);
  console.log(`🔴 Enhanced with admin logout and server shutdown handling`);
  console.log(`🔗 API endpoints available with /api prefix`);
  
  await initDatabase();
  
  console.log('🎉 Lab Monitoring System is ready!');
  console.log('\n📝 Default Admin Credentials:');
  console.log('   Username: ADMIN001');
  console.log('   Password: Admin_aids@smvec\n');
  console.log('📍 Available API endpoints:');
  console.log('   - /api/auth/login');
  console.log('   - /api/auth/register');
  console.log('   - /api/admin/*');
  console.log('   - /api/student/*');
  console.log('   - /api/exercises/*\n');
});

// Export for testing or external use
module.exports = { app, server, io, getConnectionStats };