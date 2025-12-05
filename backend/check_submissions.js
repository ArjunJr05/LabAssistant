// Check submissions in database
const { pool } = require('./config/database');

async function checkSubmissions() {
  try {
    console.log('Checking submissions in database...\n');
    
    // Get all submissions
    const allSubmissions = await pool.query(`
      SELECT 
        s.id,
        s.user_id,
        u.enroll_number,
        u.name as user_name,
        s.exercise_id,
        e.title as exercise_title,
        s.status,
        s.score,
        s.test_cases_passed,
        s.total_test_cases,
        s.created_at
      FROM submissions s
      JOIN users u ON s.user_id = u.id
      JOIN exercises e ON s.exercise_id = e.id
      ORDER BY s.created_at DESC
      LIMIT 20
    `);
    
    console.log(`📊 Total submissions (last 20): ${allSubmissions.rows.length}\n`);
    
    if (allSubmissions.rows.length === 0) {
      console.log('⚠️  No submissions found in database!');
      console.log('This means code submissions are not being saved.\n');
    } else {
      console.log('Recent submissions:');
      allSubmissions.rows.forEach((sub, index) => {
        console.log(`\n${index + 1}. Submission ID: ${sub.id}`);
        console.log(`   Student: ${sub.user_name} (${sub.enroll_number})`);
        console.log(`   Exercise: ${sub.exercise_title} (ID: ${sub.exercise_id})`);
        console.log(`   Status: ${sub.status}`);
        console.log(`   Score: ${sub.score}%`);
        console.log(`   Tests: ${sub.test_cases_passed}/${sub.total_test_cases} passed`);
        console.log(`   Submitted: ${sub.created_at}`);
      });
    }
    
    // Check passed submissions
    const passedSubmissions = await pool.query(`
      SELECT 
        s.user_id,
        u.enroll_number,
        u.name as user_name,
        COUNT(DISTINCT s.exercise_id) as completed_count
      FROM submissions s
      JOIN users u ON s.user_id = u.id
      WHERE s.status = 'passed'
      GROUP BY s.user_id, u.enroll_number, u.name
      ORDER BY completed_count DESC
    `);
    
    console.log(`\n\n✅ Completed exercises by student:`);
    if (passedSubmissions.rows.length === 0) {
      console.log('   No students have completed any exercises yet.');
    } else {
      passedSubmissions.rows.forEach(student => {
        console.log(`   ${student.user_name} (${student.enroll_number}): ${student.completed_count} exercises completed`);
      });
    }
    
    // Check for triangle exercise specifically (Exercise ID 1)
    const triangleSubmissions = await pool.query(`
      SELECT 
        s.id,
        u.enroll_number,
        u.name as user_name,
        s.status,
        s.score,
        s.created_at
      FROM submissions s
      JOIN users u ON s.user_id = u.id
      WHERE s.exercise_id = 1
      ORDER BY s.created_at DESC
    `);
    
    console.log(`\n\n🔺 Triangle Area Exercise (ID: 1) submissions:`);
    if (triangleSubmissions.rows.length === 0) {
      console.log('   No submissions for triangle exercise found.');
    } else {
      triangleSubmissions.rows.forEach(sub => {
        console.log(`   ${sub.user_name} (${sub.enroll_number}): ${sub.status}, Score: ${sub.score}%, Submitted: ${sub.created_at}`);
      });
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

checkSubmissions();
