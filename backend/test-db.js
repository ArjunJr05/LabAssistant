// Test database connection only
console.log('Testing database module...');

try {
  console.log('Loading mysql2...');
  const mysql = require('mysql2/promise');
  console.log('✅ mysql2 loaded');

  console.log('Creating pool...');
  const pool = mysql.createPool({
    host: 'localhost',
    user: 'root',
    password: '3513',
    database: 'lab_monitoring',
    port: 3306,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
  });
  console.log('✅ Pool created');

  console.log('Testing connection...');
  pool.getConnection()
    .then(connection => {
      console.log('✅ Database connection successful');
      connection.release();
      process.exit(0);
    })
    .catch(err => {
      console.error('❌ Database connection failed:', err.message);
      console.error('Code:', err.code);
      process.exit(1);
    });

} catch (error) {
  console.error('❌ Error:', error.message);
  console.error('Stack:', error.stack);
  process.exit(1);
}
