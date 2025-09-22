// Test PostgreSQL connection
console.log('Testing PostgreSQL connection...');

try {
  console.log('Loading pg module...');
  const { Pool } = require('pg');
  console.log('✅ pg module loaded');

  console.log('Creating pool...');
  const pool = new Pool({
    host: 'localhost',
    user: 'postgres',
    password: '3513',
    database: 'lab_monitoring',
    port: 5432,
    max: 10,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
  });
  console.log('✅ Pool created');

  console.log('Testing connection...');
  pool.connect()
    .then(client => {
      console.log('✅ PostgreSQL connection successful');
      return client.query('SELECT NOW() as current_time');
    })
    .then(result => {
      console.log('✅ Query successful at:', result.rows[0].current_time);
      process.exit(0);
    })
    .catch(err => {
      console.error('❌ PostgreSQL connection failed:', err.message);
      console.error('Code:', err.code);
      process.exit(1);
    });

} catch (error) {
  console.error('❌ Error:', error.message);
  console.error('Stack:', error.stack);
  process.exit(1);
}
