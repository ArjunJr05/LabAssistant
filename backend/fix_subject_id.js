// Fix subject_id for all exercises
const { pool } = require('./config/database');

async function fixSubjectId() {
  try {
    console.log('Fixing subject_id for exercises...\n');
    
    // Update all exercises with subject_id = 1 to subject_id = 11
    const updateResult = await pool.query(
      'UPDATE exercises SET subject_id = 11 WHERE subject_id = 1'
    );
    
    console.log(`✅ Updated ${updateResult.rowCount} exercises`);
    
    // Verify the fix
    const verifyResult = await pool.query(
      `SELECT 
        s.id as subject_id, 
        s.name as subject_name, 
        COUNT(e.id) as exercise_count
       FROM subjects s
       LEFT JOIN exercises e ON s.id = e.subject_id
       GROUP BY s.id, s.name
       ORDER BY s.id`
    );
    
    console.log('\n📊 Exercises per subject after fix:');
    verifyResult.rows.forEach(row => {
      console.log(`  Subject "${row.subject_name}" (ID: ${row.subject_id}): ${row.exercise_count} exercises`);
    });
    
    console.log('\n✅ Fix completed successfully!');
    console.log('👉 Now refresh your Flutter app to see the exercises.');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

fixSubjectId();
