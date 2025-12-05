// Quick database test script
const { pool } = require('./config/database');

async function testDatabase() {
  try {
    console.log('Testing database connection...');
    
    // Test connection
    const client = await pool.connect();
    console.log('✅ Connected to database');
    
    // Count exercises
    const countResult = await client.query('SELECT COUNT(*) FROM exercises');
    console.log(`\n📊 Total exercises in database: ${countResult.rows[0].count}`);
    
    // Get exercises for subject 1
    const exercisesResult = await client.query(
      `SELECT id, title, subject_id, difficulty_level, 
              LENGTH(test_cases::text) as test_cases_length,
              test_cases
       FROM exercises 
       WHERE subject_id = 1 
       ORDER BY id 
       LIMIT 5`
    );
    
    console.log(`\n📚 First 5 exercises for subject_id=1:`);
    exercisesResult.rows.forEach(ex => {
      console.log(`  ID: ${ex.id}, Title: ${ex.title}`);
      console.log(`  Test cases length: ${ex.test_cases_length}`);
      console.log(`  Test cases: ${JSON.stringify(ex.test_cases).substring(0, 100)}...`);
    });
    
    client.release();
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

testDatabase();
