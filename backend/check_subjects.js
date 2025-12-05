// Check subjects and their exercises
const { pool } = require('./config/database');

async function checkSubjects() {
  try {
    console.log('Checking subjects and exercises...\n');
    
    // Get all subjects
    const subjectsResult = await pool.query('SELECT * FROM subjects ORDER BY id');
    console.log('📚 Subjects in database:');
    subjectsResult.rows.forEach(subject => {
      console.log(`  ID: ${subject.id}, Name: ${subject.name}`);
    });
    
    console.log('\n📊 Exercise count per subject:');
    
    // Count exercises for each subject
    for (const subject of subjectsResult.rows) {
      const countResult = await pool.query(
        'SELECT COUNT(*) FROM exercises WHERE subject_id = $1',
        [subject.id]
      );
      console.log(`  Subject "${subject.name}" (ID: ${subject.id}): ${countResult.rows[0].count} exercises`);
    }
    
    // Check if there are exercises without a valid subject_id
    const orphanResult = await pool.query(
      `SELECT COUNT(*) FROM exercises 
       WHERE subject_id NOT IN (SELECT id FROM subjects)`
    );
    
    if (parseInt(orphanResult.rows[0].count) > 0) {
      console.log(`\n⚠️  Warning: ${orphanResult.rows[0].count} exercises have invalid subject_id`);
      
      const orphanExercises = await pool.query(
        `SELECT id, title, subject_id FROM exercises 
         WHERE subject_id NOT IN (SELECT id FROM subjects)
         LIMIT 5`
      );
      console.log('Sample orphan exercises:');
      orphanExercises.rows.forEach(ex => {
        console.log(`  Exercise ID: ${ex.id}, Subject ID: ${ex.subject_id}, Title: ${ex.title}`);
      });
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

checkSubjects();
