// Debug server - adding components one by one
console.log('Starting debug server...');

try {
  const express = require('express');
  const http = require('http');
  console.log('✅ Basic modules loaded');
  
  const socketIo = require('socket.io');
  const cors = require('cors');
  const path = require('path');
  const fs = require('fs-extra');
  console.log('✅ Additional modules loaded');

  const { pool } = require('./config/database');
  console.log('✅ Database config loaded');

  const app = express();
  const server = http.createServer(app);
  const io = socketIo(server, {
    cors: {
      origin: "*",
      methods: ["GET", "POST"]
    }
  });
  console.log('✅ Server and Socket.IO setup complete');

  // Make Socket.IO instance available to routes
  app.set('socketio', io);
  app.set('io', io);

  // Middleware
  app.use(cors());
  app.use(express.json({ limit: '50mb' }));
  app.use(express.urlencoded({ extended: true, limit: '50mb' }));
  console.log('✅ Middleware configured');

  // Try loading routes one by one
  console.log('Loading auth routes...');
  const authRoutes = require('./routes/auth');
  app.use('/api/auth', authRoutes);
  console.log('✅ Auth routes loaded');

  console.log('Loading admin routes...');
  const adminRoutes = require('./routes/admin');
  app.use('/api/admin', adminRoutes);
  console.log('✅ Admin routes loaded');

  console.log('Loading student routes...');
  const studentRoutes = require('./routes/student');
  app.use('/api/student', studentRoutes);
  console.log('✅ Student routes loaded');

  console.log('Loading exercise routes...');
  const exerciseRoutes = require('./routes/exercises');
  app.use('/api/exercises', exerciseRoutes);
  console.log('✅ Exercise routes loaded');

  console.log('Loading malpractice routes...');
  const malpracticeRoutes = require('./routes/malpractice');
  app.use('/api/malpractice', malpracticeRoutes);
  console.log('✅ Malpractice routes loaded');

  // Health check endpoint
  app.get('/api/health', (req, res) => {
    res.json({ status: 'OK', timestamp: new Date().toISOString() });
  });

  const PORT = process.env.PORT || 3000;
  server.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Debug server running on http://0.0.0.0:${PORT}`);
    console.log('✅ All components loaded successfully!');
  });

} catch (error) {
  console.error('❌ Error in debug server:', error.message);
  console.error('Stack:', error.stack);
  process.exit(1);
}
