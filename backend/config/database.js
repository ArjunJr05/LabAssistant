// config/database.js
const { Pool } = require('pg');

// Database configuration
const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'lab_monitoring',  // This must match what you create
  password: '3513',  // Use the same password from pgAdmin
  port: 5432,
});

// Test database connection on startup
pool.on('connect', () => {
  console.log('✅ Connected to PostgreSQL database');
});

pool.on('error', (err) => {
  console.error('❌ Unexpected error on idle client:', err);
  process.exit(-1);
});

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

// Export both pool and testConnection
module.exports = { 
  pool,
  testConnection
};