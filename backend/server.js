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
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

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
    message: 'Admin server is running',
    socketConnections: io.sockets.sockets.size
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

// Enhanced Socket.IO with proper database synchronization
let serverShuttingDown = false;

io.on('connection', (socket) => {
  console.log(`New client connected: ${socket.id}`);

  // Handle student login with immediate database update
  socket.on('student-login', async (userData) => {
    try {
      console.log('Student login event:', userData);
      
      const { enrollNumber, name, role } = userData;
      
      if (!enrollNumber || !name) {
        console.error('Invalid student login data:', userData);
        socket.emit('error', { message: 'Invalid login data' });
        return;
      }

      // Update database immediately
      const updateResult = await pool.query(
        `UPDATE users 
         SET is_online = true, last_active = NOW(), updated_at = NOW()
         WHERE enroll_number = $1 AND role = 'student'
         RETURNING id, name, enroll_number, year, section, batch, role, is_online, last_active`,
        [enrollNumber]
      );

      if (updateResult.rows.length > 0) {
        const user = updateResult.rows[0];
        console.log(`Database updated: ${user.name} is now online`);

        // Store user info in socket session
        socket.userData = {
          id: user.id,
          enrollNumber: user.enroll_number,
          name: user.name,
          role: user.role
        };

        // Broadcast to all clients (especially admin)
        socket.broadcast.emit('user-connected', {
          id: user.id,
          name: user.name,
          enrollNumber: user.enroll_number,
          year: user.year,
          section: user.section,
          batch: user.batch,
          role: user.role,
          isOnline: true,
          lastActive: user.last_active
        });

        socket.broadcast.emit('student-login', {
          id: user.id,
          name: user.name,
          enrollNumber: user.enroll_number,
          year: user.year,
          section: user.section,
          batch: user.batch,
          role: user.role,
          isOnline: true,
          lastActive: user.last_active
        });

        // Send current online users to all clients
        await broadcastOnlineUsers();

      } else {
        console.error(`Student not found in database: ${enrollNumber}`);
        socket.emit('error', { message: 'Student not found or not registered' });
      }

    } catch (error) {
      console.error('Error handling student login:', error);
      socket.emit('error', { message: 'Login failed' });
    }
  });

  // Handle generic user login
  socket.on('user-login', async (userData) => {
    try {
      console.log('User login event:', userData);
      
      if (!userData.enrollNumber || !userData.role) {
        return;
      }

      if (userData.role === 'student') {
        // Handle same as student-login
        socket.emit('student-login', userData);
      } else if (userData.role === 'admin') {
        // Admin login
        socket.userData = {
          enrollNumber: userData.enrollNumber,
          name: userData.name,
          role: 'admin'
        };
        console.log(`Admin connected: ${userData.name}`);
        
        // Send current online users to admin
        await sendOnlineUsersToSocket(socket);
      }

    } catch (error) {
      console.error('Error handling user login:', error);
    }
  });

  // Handle student logout
  socket.on('student-logout', async (userData) => {
    try {
      console.log('Student logout event:', userData);
      
      if (!userData.enrollNumber) {
        return;
      }

      // Update database immediately
      const updateResult = await pool.query(
        `UPDATE users 
         SET is_online = false, last_active = NOW(), updated_at = NOW()
         WHERE enroll_number = $1 AND role = 'student'
         RETURNING name, enroll_number`,
        [userData.enrollNumber]
      );

      if (updateResult.rows.length > 0) {
        const user = updateResult.rows[0];
        console.log(`Database updated: ${user.name} is now offline`);

        // Broadcast to all clients
        socket.broadcast.emit('user-disconnected', {
          enrollNumber: user.enroll_number,
          name: user.name,
          isOnline: false
        });

        socket.broadcast.emit('student-logout', {
          enrollNumber: user.enroll_number,
          name: user.name,
          isOnline: false
        });

        // Send updated online users
        await broadcastOnlineUsers();
      }

    } catch (error) {
      console.error('Error handling student logout:', error);
    }
  });

  // Handle generic user logout
  socket.on('user-logout', async (userData) => {
    try {
      console.log('User logout event:', userData);
      
      if (userData.role === 'student' && userData.enrollNumber) {
        socket.emit('student-logout', userData);
      }

    } catch (error) {
      console.error('Error handling user logout:', error);
    }
  });

  // Handle admin login
  socket.on('admin-login', async (adminData) => {
    try {
      console.log('Admin login event:', adminData);
      
      const { enrollNumber, name, role } = adminData;
      
      if (role === 'admin') {
        socket.userData = {
          enrollNumber: enrollNumber,
          name: name,
          role: 'admin'
        };

        // Update admin online status in database
        await pool.query(
          'UPDATE users SET is_online = true, last_active = NOW(), updated_at = NOW() WHERE enroll_number = $1',
          [enrollNumber]
        );

        // Send current online users to this admin
        await sendOnlineUsersToSocket(socket);
        
        console.log(`Admin ${name} registered and received online users`);

        // Broadcast to all clients that admin is online
        io.emit('admin-connected', {
          message: 'Server is now online. Admin has logged in.',
          timestamp: new Date().toISOString()
        });
      }
    } catch (error) {
      console.error('Error handling admin login:', error);
    }
  });

  // Handle admin logout - CRITICAL: This triggers server shutdown
  socket.on('admin-logout', async (adminData) => {
    try {
      console.log('ADMIN LOGOUT VIA SOCKET - INITIATING SHUTDOWN:', adminData);
      
      if (serverShuttingDown) {
        console.log('Server already shutting down, ignoring duplicate admin logout');
        return;
      }
      
      serverShuttingDown = true;
      
      const { enrollNumber, name } = adminData;
      
      console.log('Setting all students offline in database...');
      
      // Set all students offline in database
      const result = await pool.query(
        'UPDATE users SET is_online = false, last_active = NOW(), updated_at = NOW() WHERE role = $1 RETURNING name, enroll_number',
        ['student']
      );
      
      console.log(`Set ${result.rows.length} students offline in database`);
      
      // End all active sessions
      await pool.query(
        'UPDATE user_sessions SET is_active = false, session_end = NOW() WHERE is_active = true'
      );
      
      // Broadcast shutdown notification to all connected clients
      const shutdownMessage = {
        message: 'Admin has logged out. Server is shutting down.',
        adminName: name,
        timestamp: new Date().toISOString(),
        studentsAffected: result.rows.length,
        reason: 'admin_logout'
      };
      
      console.log('Broadcasting admin shutdown to all clients...');
      io.emit('admin-shutdown', shutdownMessage);
      
      // Force disconnect all client sockets after delay
      setTimeout(() => {
        console.log('Force disconnecting all client sockets...');
        
        // Get all connected sockets and disconnect them
        const sockets = io.sockets.sockets;
        sockets.forEach((clientSocket) => {
          if (clientSocket.id !== socket.id) { // Don't disconnect admin socket yet
            console.log(`Disconnecting socket: ${clientSocket.id}`);
            clientSocket.emit('force-disconnect', {
              reason: 'admin_logout',
              message: 'Server is shutting down due to admin logout',
              timestamp: new Date().toISOString()
            });
            clientSocket.disconnect(true);
          }
        });
        
        // Set admin offline in database
        pool.query(
          'UPDATE users SET is_online = false, last_active = NOW(), updated_at = NOW() WHERE enroll_number = $1',
          [enrollNumber]
        ).then(() => {
          console.log('Admin marked offline in database');
        }).catch(err => {
          console.error('Error marking admin offline:', err);
        });
        
        console.log('ADMIN LOGOUT COMPLETED - SERVER SHUTDOWN SEQUENCE FINISHED');
        
        // Optional: Terminate server process after delay
        setTimeout(() => {
          console.log('TERMINATING SERVER PROCESS DUE TO ADMIN LOGOUT...');
          process.exit(0);
        }, 3000);
        
      }, 2000);
      
    } catch (error) {
      console.error('Error handling admin logout:', error);
      serverShuttingDown = false;
    }
  });

  // Get online users request
  socket.on('get-online-users', async () => {
    try {
      console.log('Online users requested by socket:', socket.id);
      await sendOnlineUsersToSocket(socket);
    } catch (error) {
      console.error('Error sending online users:', error);
    }
  });

  // Handle heartbeat/ping with database update
  socket.on('ping', async (data) => {
    socket.emit('pong', { 
      timestamp: new Date().toISOString(),
      received: data.timestamp 
    });

    // Update last active if user data exists
    if (socket.userData && socket.userData.enrollNumber && socket.userData.role === 'student') {
      try {
        await pool.query(
          `UPDATE users 
           SET last_active = NOW() 
           WHERE enroll_number = $1 AND role = 'student'`,
          [socket.userData.enrollNumber]
        );
      } catch (error) {
        console.error('Error updating last active:', error);
      }
    }
  });

  // Handle socket disconnection with proper cleanup
  socket.on('disconnect', async (reason) => {
    try {
      console.log(`Client disconnected: ${socket.id}, reason: ${reason}`);
      
      // If student disconnects, mark as offline
      if (socket.userData && socket.userData.role === 'student' && socket.userData.enrollNumber) {
        console.log(`Marking student ${socket.userData.name} as offline due to disconnect`);
        
        const updateResult = await pool.query(
          `UPDATE users 
           SET is_online = false, last_active = NOW(), updated_at = NOW()
           WHERE enroll_number = $1 AND role = 'student'
           RETURNING name, enroll_number`,
          [socket.userData.enrollNumber]
        );

        if (updateResult.rows.length > 0) {
          const user = updateResult.rows[0];
          
          // Broadcast disconnect to admin
          socket.broadcast.emit('user-disconnected', {
            enrollNumber: user.enroll_number,
            name: user.name,
            isOnline: false,
            reason: 'socket_disconnect'
          });

          // Update online users for admin
          await broadcastOnlineUsers();
        }
        
      } else if (socket.userData && socket.userData.role === 'admin') {
        console.log('ADMIN DISCONNECTED UNEXPECTEDLY');
        
        if (!serverShuttingDown) {
          console.log('ADMIN UNEXPECTED DISCONNECT - INITIATING EMERGENCY SHUTDOWN');
          
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
          
          // Shutdown server after delay
          setTimeout(() => {
            console.log('EMERGENCY SERVER SHUTDOWN DUE TO ADMIN DISCONNECT');
            process.exit(1);
          }, 3000);
        }
      }
    } catch (error) {
      console.error('Error handling disconnect:', error);
    }
  });

  // Legacy event handlers for compatibility
  socket.on('code-execution', (data) => {
    const user = socket.userData;
    if (user) {
      console.log('Code execution from:', user.enrollNumber);
      
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
    const user = socket.userData;
    if (user) {
      io.emit('student-screen', {
        userId: user.enrollNumber,
        userName: user.name,
        screenData: screenData,
        timestamp: new Date().toISOString()
      });
    }
  });

  socket.on('user-activity', async (activityData) => {
    const user = socket.userData;
    if (user && user.role === 'student') {
      // Update last active time
      try {
        await pool.query(
          `UPDATE users 
           SET last_active = NOW() 
           WHERE enroll_number = $1 AND role = 'student'`,
          [user.enrollNumber]
        );
      } catch (error) {
        console.error('Error updating activity:', error);
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
});

// Helper function to get online users from database
async function getOnlineUsersFromDB() {
  try {
    const result = await pool.query(`
      SELECT 
        id, name, enroll_number, year, section, batch, role, 
        is_online, last_active
      FROM users
      WHERE role = 'student' 
        AND is_online = true
        AND last_active > NOW() - INTERVAL '10 minutes'
      ORDER BY last_active DESC
    `);

    return result.rows.map(user => ({
      id: user.id,
      name: user.name,
      enrollNumber: user.enroll_number,
      enroll_number: user.enroll_number, // Both formats for compatibility
      year: user.year,
      section: user.section,
      batch: user.batch,
      role: user.role,
      isOnline: user.is_online,
      is_online: user.is_online, // Both formats for compatibility
      lastActive: user.last_active,
      last_active: user.last_active // Both formats for compatibility
    }));
  } catch (error) {
    console.error('Error getting online users from DB:', error);
    return [];
  }
}

// Helper function to send online users to a specific socket
async function sendOnlineUsersToSocket(socket) {
  try {
    const onlineUsers = await getOnlineUsersFromDB();
    console.log(`Sending ${onlineUsers.length} online users to socket ${socket.id}`);
    
    socket.emit('online-users', onlineUsers);
    socket.emit('online-users-bulk', onlineUsers); // Also emit bulk version
    
  } catch (error) {
    console.error('Error sending online users to socket:', error);
  }
}

// Helper function to broadcast online users to all clients
async function broadcastOnlineUsers() {
  try {
    const onlineUsers = await getOnlineUsersFromDB();
    console.log(`Broadcasting ${onlineUsers.length} online users to all clients`);
    
    io.emit('online-users', onlineUsers);
    io.emit('online-users-bulk', onlineUsers);
    io.emit('user-status-update', onlineUsers);
    
  } catch (error) {
    console.error('Error broadcasting online users:', error);
  }
}

// Periodic cleanup of stale connections
setInterval(async () => {
  if (serverShuttingDown) return;
  
  try {
    console.log('Running periodic stale user cleanup...');
    
    const cleanupResult = await pool.query(`
      UPDATE users 
      SET is_online = false, updated_at = NOW()
      WHERE is_online = true 
      AND role = 'student'
      AND last_active < NOW() - INTERVAL '10 minutes'
      RETURNING name, enroll_number
    `);

    if (cleanupResult.rows.length > 0) {
      console.log(`Periodic cleanup: marked ${cleanupResult.rows.length} stale users offline`);
      
      // Broadcast updates
      cleanupResult.rows.forEach(user => {
        io.emit('user-disconnected', {
          enrollNumber: user.enroll_number,
          name: user.name,
          isOnline: false,
          reason: 'periodic_cleanup'
        });
      });

      // Send updated online users
      await broadcastOnlineUsers();
    }

  } catch (error) {
    console.error('Error in periodic cleanup:', error);
  }
}, 5 * 60 * 1000); // 5 minutes

// Database initialization
async function initDatabase() {
  try {
    // Test database connection
    const client = await pool.connect();
    console.log('Database connection successful');
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

    // Add student_activities table for monitoring
    await pool.query(`
      CREATE TABLE IF NOT EXISTS student_activities (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        exercise_id INTEGER REFERENCES exercises(id) ON DELETE CASCADE,
        activity_type VARCHAR(50) NOT NULL,
        code TEXT,
        status VARCHAR(20),
        score INTEGER DEFAULT 0,
        test_results JSONB,
        tests_passed INTEGER DEFAULT 0,
        total_tests INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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
    
    console.log('Database tables initialized successfully');
    
    // Insert default admin if doesn't exist
    const adminCheck = await pool.query("SELECT * FROM users WHERE role = 'admin' LIMIT 1");
    if (adminCheck.rows.length === 0) {
      const bcrypt = require('bcryptjs');
      const hashedPassword = await bcrypt.hash('Admin_aids@smvec', 10);
      await pool.query(
        "INSERT INTO users (name, enroll_number, year, section, batch, password, role) VALUES ($1, $2, $3, $4, $5, $6, $7)",
        ['Administrator', 'ADMIN001', 'ADMIN', 'ADM', '2024', hashedPassword, 'admin']
      );
      console.log('Default admin created');
    }

    // Insert default subject if doesn't exist
    const subjectCheck = await pool.query("SELECT * FROM subjects WHERE code = 'CS101'");
    if (subjectCheck.rows.length === 0) {
      await pool.query(
        "INSERT INTO subjects (name, code) VALUES ($1, $2)",
        ['C Programming', 'CS101']
      );
      console.log('Default subject created');
    }

    // Clear all online statuses on server start
    await pool.query('UPDATE users SET is_online = false WHERE role = $1', ['student']);
    console.log('Cleared all online statuses on server start');

  } catch (error) {
    console.error('Database initialization error:', error.message);
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
      '/api/status',
      '/api/auth/login',
      '/api/auth/register', 
      '/api/exercises/subjects',
      '/api/admin/*',
      '/api/student/*'
    ]
  });
});

// Graceful shutdown handlers
process.on('SIGTERM', async () => {
  console.log('SIGTERM received - shutting down gracefully');
  
  // Mark all users as offline
  try {
    await pool.query('UPDATE users SET is_online = false WHERE role = $1', ['student']);
    console.log('All users marked offline');
  } catch (error) {
    console.error('Error marking users offline:', error);
  }
  
  server.close(() => {
    console.log('HTTP server closed');
    process.exit(0);
  });
});

process.on('SIGINT', async () => {
  console.log('SIGINT received - shutting down gracefully');
  
  // Mark all users as offline
  try {
    await pool.query('UPDATE users SET is_online = false WHERE role = $1', ['student']);
    console.log('All users marked offline');
  } catch (error) {
    console.error('Error marking users offline:', error);
  }
  
  server.close(() => {
    console.log('HTTP server closed');
    process.exit(0);
  });
});

const PORT = process.env.PORT || 3000;

server.listen(PORT, '0.0.0.0', async () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Admin Panel: http://0.0.0.0:${PORT}/api/health`);
  console.log(`Socket.IO enabled for real-time monitoring`);
  console.log(`Server accessible from any device on the network`);
  console.log(`Enhanced with proper database sync and admin logout handling`);
  console.log(`API endpoints available with /api prefix`);
  
  await initDatabase();
  
  console.log('Lab Monitoring System is ready!');
  console.log('\nDefault Admin Credentials:');
  console.log('   Username: ADMIN001');
  console.log('   Password: Admin_aids@smvec\n');
});

// Export for testing or external use
module.exports = { app, server, io };