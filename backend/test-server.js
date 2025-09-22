// Simple test to identify the problematic module
console.log('Starting module loading test...');

try {
  console.log('1. Loading express...');
  const express = require('express');
  console.log('✅ Express loaded');

  console.log('2. Loading http...');
  const http = require('http');
  console.log('✅ HTTP loaded');

  console.log('3. Loading socket.io...');
  const socketIo = require('socket.io');
  console.log('✅ Socket.IO loaded');

  console.log('4. Loading cors...');
  const cors = require('cors');
  console.log('✅ CORS loaded');

  console.log('5. Loading database config...');
  const { pool } = require('./config/database');
  console.log('✅ Database config loaded');

  console.log('6. Loading auth routes...');
  const authRoutes = require('./routes/auth');
  console.log('✅ Auth routes loaded');

  console.log('7. Loading admin routes...');
  const adminRoutes = require('./routes/admin');
  console.log('✅ Admin routes loaded');

  console.log('8. Loading student routes...');
  const studentRoutes = require('./routes/student');
  console.log('✅ Student routes loaded');

  console.log('9. Loading exercise routes...');
  const exerciseRoutes = require('./routes/exercises');
  console.log('✅ Exercise routes loaded');

  console.log('10. Loading malpractice routes...');
  const malpracticeRoutes = require('./routes/malpractice');
  console.log('✅ Malpractice routes loaded');

  console.log('🎉 All modules loaded successfully!');
} catch (error) {
  console.error('❌ Error loading module:');
  console.error('Message:', error.message);
  console.error('Stack:', error.stack);
  process.exit(1);
}
