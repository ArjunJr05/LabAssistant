// Test auth middleware and routes separately
console.log('Testing auth components...');

try {
  console.log('1. Testing middleware/auth.js...');
  const authMiddleware = require('./middleware/auth');
  console.log('✅ Auth middleware loaded');
  console.log('Type:', typeof authMiddleware);

  console.log('2. Testing database import in auth context...');
  const { pool } = require('./config/database');
  console.log('✅ Database pool loaded in auth context');

  console.log('3. Testing auth routes...');
  const authRoutes = require('./routes/auth');
  console.log('✅ Auth routes loaded');

  console.log('🎉 All auth components loaded successfully!');
} catch (error) {
  console.error('❌ Error loading auth components:', error.message);
  console.error('Stack:', error.stack);
  process.exit(1);
}
