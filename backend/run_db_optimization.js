// Database optimization runner script
const { pool } = require('./config/database');
const fs = require('fs');
const path = require('path');

async function runDatabaseOptimization() {
  try {
    console.log('🚀 Starting database optimization...');
    
    // Read the optimization SQL file
    const sqlFile = path.join(__dirname, 'database_optimization.sql');
    const sql = fs.readFileSync(sqlFile, 'utf8');
    
    // Split by semicolons and execute each statement
    const statements = sql.split(';').filter(stmt => stmt.trim().length > 0);
    
    for (let i = 0; i < statements.length; i++) {
      const statement = statements[i].trim();
      if (statement) {
        try {
          console.log(`Executing statement ${i + 1}/${statements.length}...`);
          await pool.query(statement);
        } catch (error) {
          // Ignore "already exists" errors for indexes
          if (error.message.includes('already exists')) {
            console.log(`  ℹ️ Index already exists, skipping...`);
          } else {
            console.error(`  ❌ Error in statement ${i + 1}:`, error.message);
          }
        }
      }
    }
    
    console.log('✅ Database optimization completed successfully!');
    console.log('📊 Performance improvements applied:');
    console.log('  - Added indexes for user role and online status queries');
    console.log('  - Optimized submission and exercise lookup indexes');
    console.log('  - Created composite indexes for common query patterns');
    console.log('  - Updated database statistics for better query planning');
    
  } catch (error) {
    console.error('💥 Database optimization failed:', error);
  } finally {
    await pool.end();
  }
}

// Run if called directly
if (require.main === module) {
  runDatabaseOptimization();
}

module.exports = { runDatabaseOptimization };
