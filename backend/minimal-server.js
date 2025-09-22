// Minimal server to test basic functionality
console.log('Starting minimal server...');

try {
  const express = require('express');
  console.log('✅ Express loaded');
  
  const app = express();
  console.log('✅ Express app created');
  
  const { pool, testConnection } = require('./config/database');
  console.log('✅ Database config loaded');
  
  // Test database connection
  testConnection()
    .then(() => {
      console.log('✅ Database connection successful');
      
      // Start server
      const PORT = 3000;
      app.listen(PORT, '0.0.0.0', () => {
        console.log(`🚀 Minimal server running on http://0.0.0.0:${PORT}`);
      });
    })
    .catch(err => {
      console.error('❌ Database connection failed:', err.message);
      process.exit(1);
    });
    
} catch (error) {
  console.error('❌ Error starting minimal server:', error.message);
  console.error('Stack:', error.stack);
  process.exit(1);
}
