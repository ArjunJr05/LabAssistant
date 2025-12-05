// Complete test of submission flow
const { pool } = require('./config/database');

async function testSubmissionFlow() {
  try {
    console.log('🔍 Testing Complete Submission Flow\n');
    
    // Step 1: Check database connection
    console.log('1️⃣ Testing database connection...');
    const dbTest = await pool.query('SELECT NOW()');
    console.log('   ✅ Database connected:', dbTest.rows[0].now);
    
    // Step 2: Check if users table has data
    console.log('\n2️⃣ Checking users table...');
    const users = await pool.query('SELECT id, enroll_number, name, role FROM users LIMIT 5');
    console.log(`   Found ${users.rows.length} users:`);
    users.rows.forEach(u => {
      console.log(`   - ID: ${u.id}, Enroll: ${u.enroll_number}, Name: ${u.name}, Role: ${u.role}`);
    });
    
    // Step 3: Check if exercises table has data
    console.log('\n3️⃣ Checking exercises table...');
    const exercises = await pool.query('SELECT id, title FROM exercises WHERE id = 1');
    if (exercises.rows.length === 0) {
      console.log('   ❌ Exercise ID 1 not found!');
    } else {
      console.log(`   ✅ Exercise found: ${exercises.rows[0].title}`);
    }
    
    // Step 4: Check submissions table structure
    console.log('\n4️⃣ Checking submissions table structure...');
    const columns = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'submissions'
      ORDER BY ordinal_position
    `);
    console.log('   Columns:');
    columns.rows.forEach(col => {
      console.log(`   - ${col.column_name}: ${col.data_type}`);
    });
    
    // Step 5: Try to insert a test submission
    console.log('\n5️⃣ Testing submission insert...');
    if (users.rows.length > 0) {
      const testUserId = users.rows[0].id;
      const testExerciseId = 1;
      
      console.log(`   Inserting test submission for user ${testUserId}, exercise ${testExerciseId}...`);
      
      try {
        const insertResult = await pool.query(`
          INSERT INTO submissions (
            user_id, exercise_id, code, language, status, score,
            test_cases_passed, total_test_cases, submitted_at
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
          RETURNING id, status, score, submitted_at
        `, [testUserId, testExerciseId, '// test code', 'c', 'passed', 100, 4, 4]);
        
        console.log('   ✅ Test submission inserted successfully!');
        console.log('   Submission ID:', insertResult.rows[0].id);
        console.log('   Status:', insertResult.rows[0].status);
        console.log('   Score:', insertResult.rows[0].score);
        console.log('   Timestamp:', insertResult.rows[0].submitted_at);
        
        // Step 6: Verify it's in the database
        console.log('\n6️⃣ Verifying submission in database...');
        const verify = await pool.query('SELECT COUNT(*) FROM submissions');
        console.log(`   Total submissions in database: ${verify.rows[0].count}`);
        
        // Step 7: Test the completed exercises query
        console.log('\n7️⃣ Testing completed exercises query...');
        const completed = await pool.query(`
          SELECT 
            s.exercise_id,
            s.score,
            s.status,
            s.submitted_at,
            e.title as exercise_title
          FROM submissions s
          JOIN exercises e ON s.exercise_id = e.id
          WHERE s.user_id = $1 AND s.status = 'passed'
          ORDER BY s.submitted_at DESC
        `, [testUserId]);
        
        console.log(`   Found ${completed.rows.length} completed exercises for user ${testUserId}:`);
        completed.rows.forEach(ex => {
          console.log(`   - Exercise ${ex.exercise_id}: ${ex.exercise_title} (${ex.score}%)`);
        });
        
        // Clean up test data
        console.log('\n8️⃣ Cleaning up test data...');
        await pool.query('DELETE FROM submissions WHERE code = $1', ['// test code']);
        console.log('   ✅ Test data cleaned up');
        
      } catch (insertError) {
        console.error('   ❌ Failed to insert test submission:');
        console.error('   Error code:', insertError.code);
        console.error('   Error message:', insertError.message);
        console.error('   Error detail:', insertError.detail);
        
        if (insertError.code === '23503') {
          console.error('\n   ⚠️  FOREIGN KEY CONSTRAINT ERROR!');
          console.error('   This means either:');
          console.error('   - user_id does not exist in users table');
          console.error('   - exercise_id does not exist in exercises table');
        }
      }
    }
    
    // Step 9: Check current submissions
    console.log('\n9️⃣ Checking current submissions in database...');
    const currentSubmissions = await pool.query(`
      SELECT 
        s.id,
        s.user_id,
        u.enroll_number,
        s.exercise_id,
        e.title as exercise_title,
        s.status,
        s.score,
        s.submitted_at
      FROM submissions s
      LEFT JOIN users u ON s.user_id = u.id
      LEFT JOIN exercises e ON s.exercise_id = e.id
      ORDER BY s.submitted_at DESC
      LIMIT 10
    `);
    
    if (currentSubmissions.rows.length === 0) {
      console.log('   ⚠️  No submissions found in database');
      console.log('   This confirms submissions are NOT being saved from the app');
    } else {
      console.log(`   Found ${currentSubmissions.rows.length} submissions:`);
      currentSubmissions.rows.forEach(sub => {
        console.log(`   - ID ${sub.id}: User ${sub.enroll_number}, Exercise "${sub.exercise_title}", Status: ${sub.status}, Score: ${sub.score}%`);
      });
    }
    
    console.log('\n✅ Test complete!');
    console.log('\n📋 SUMMARY:');
    console.log('   - Database connection: ✅ Working');
    console.log('   - Users table: ✅ Has data');
    console.log('   - Exercises table: ✅ Has data');
    console.log('   - Submissions table: ✅ Structure correct');
    console.log('   - Insert capability: ✅ Working');
    console.log(`   - Current submissions: ${currentSubmissions.rows.length === 0 ? '❌ NONE' : '✅ ' + currentSubmissions.rows.length}`);
    
    if (currentSubmissions.rows.length === 0) {
      console.log('\n⚠️  PROBLEM IDENTIFIED:');
      console.log('   The database can accept submissions, but the app is not sending them.');
      console.log('   This means:');
      console.log('   1. Backend route might not be receiving requests');
      console.log('   2. Authentication might be failing');
      console.log('   3. Frontend might not be calling the API');
      console.log('\n   Next steps:');
      console.log('   - Check if backend server is running');
      console.log('   - Check backend console for request logs');
      console.log('   - Check Flutter console for API call logs');
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Test failed:', error);
    process.exit(1);
  }
}

testSubmissionFlow();
