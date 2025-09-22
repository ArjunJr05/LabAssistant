// config/database.js
const { Pool } = require('pg');

// Database configuration
const dbConfig = {
  host: 'localhost',
  user: 'postgres',
  password: '3513',
  database: 'lab_monitoring',
  port: 5432,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
};

// Create connection pool
const pool = new Pool(dbConfig);

// Function to test the connection
const testConnection = async () => {
  try {
    const client = await pool.connect();
    console.log('✅ Database connection test successful');
    
    // Test query
    const result = await client.query('SELECT NOW() as current_time');
    console.log('✅ Database query test successful at:', result.rows[0].current_time);
    
    client.release();
    return true;
  } catch (err) {
    console.error('❌ Database connection failed:');
    console.error('   Error:', err.message);
    console.error('   Code:', err.code);
    console.error('\n🔧 Please check:');
    console.error('   1. PostgreSQL password in config/database.js');
    console.error('   2. Database "lab_monitoring" exists');
    console.error('   3. PostgreSQL service is running');
    throw err;
  }
};

// Export pool
module.exports = { pool, testConnection };