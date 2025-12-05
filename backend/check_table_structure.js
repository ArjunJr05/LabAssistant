// Check submissions table structure
const { pool } = require('./config/database');

async function checkTableStructure() {
  try {
    console.log('Checking submissions table structure...\n');
    
    // Get table columns
    const columns = await pool.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_name = 'submissions'
      ORDER BY ordinal_position
    `);
    
    console.log('📋 Submissions table columns:');
    columns.rows.forEach(col => {
      console.log(`  - ${col.column_name}: ${col.data_type} (nullable: ${col.is_nullable})`);
    });
    
    // Check if table has any data
    const count = await pool.query('SELECT COUNT(*) FROM submissions');
    console.log(`\n📊 Total submissions in table: ${count.rows[0].count}`);
    
    // Get a sample submission if exists
    const sample = await pool.query('SELECT * FROM submissions LIMIT 1');
    if (sample.rows.length > 0) {
      console.log('\n📝 Sample submission:');
      console.log(JSON.stringify(sample.rows[0], null, 2));
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

checkTableStructure();
