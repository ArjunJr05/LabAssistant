# Submission Not Saving - Diagnosis

## Problem
- Student completed "Triangle Area" exercise
- Shows "0/28 Completed" instead of "1/28 Completed"
- No tick icon on completed exercise
- Database shows 0 submissions

## Root Cause
The code submission is **not being saved to the database**.

## Diagnosis Steps

### 1. Check if Backend is Receiving the Request

**Look at your backend terminal** where `npm start` is running. You should see logs like:
```
=== FINAL SUBMISSION ===
User: [user_id], Exercise: 1
Final evaluation:
  - Visible test cases: 4
  - Hidden test cases: 0
  - Total test cases: 4
```

If you DON'T see these logs, the request is not reaching the backend.

### 2. Check Database Connection

Run this to verify database connection:
```powershell
cd backend
node check_table_structure.js
```

Should show:
```
📊 Total submissions in table: 0  ← This is the problem!
```

### 3. Test the Submission Endpoint Directly

Create a test to submit code directly:

```javascript
// backend/test_submit.js
const { pool } = require('./config/database');

async function testSubmit() {
  try {
    // Insert a test submission
    const result = await pool.query(`
      INSERT INTO submissions (
        user_id, exercise_id, code, language, status, score,
        test_cases_passed, total_test_cases, submitted_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
      RETURNING *
    `, [1, 1, 'test code', 'c', 'passed', 100, 4, 4]);
    
    console.log('✅ Test submission created:');
    console.log(result.rows[0]);
    
    // Check if it's there
    const check = await pool.query('SELECT COUNT(*) FROM submissions');
    console.log(`\n📊 Total submissions: ${check.rows[0].count}`);
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

testSubmit();
```

Run: `node test_submit.js`

## Possible Causes

### Cause 1: Database Transaction Not Committing
The INSERT statement might be failing silently.

**Fix:** Check backend logs for database errors.

### Cause 2: Wrong User ID
The `req.user.userId` might be null or invalid.

**Fix:** Add logging in the submit route:
```javascript
console.log('User from token:', req.user);
console.log('User ID:', userId);
```

### Cause 3: Database Permissions
The database user might not have INSERT permissions.

**Fix:** Check PostgreSQL permissions.

### Cause 4: The Route is Not Being Called
The Flutter app might not be calling the submit endpoint.

**Fix:** Check Flutter console for:
```
Submitting code for exercise 1
Submit response status: 200
```

## Quick Fix to Test

### Step 1: Add More Logging to Backend

Edit `backend/routes/exercises.js` line 378:

```javascript
// Save submission with complete results
try {
  console.log('💾 Attempting to save submission...');
  console.log('  User ID:', userId);
  console.log('  Exercise ID:', exerciseId);
  console.log('  Status:', allTestsPassed ? 'passed' : 'failed');
  console.log('  Score:', score);
  
  const insertResult = await pool.query(
    `INSERT INTO submissions (
      user_id, exercise_id, code, language, status, score, 
      test_cases_passed, total_test_cases, submitted_at
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
    RETURNING *`,
    [
      userId, exerciseId, code, 'c', 
      allTestsPassed ? 'passed' : 'failed', 
      score, totalPassedTests, totalTests
    ]
  );
  
  console.log('✅ Submission saved! ID:', insertResult.rows[0].id);
  console.log('   Full record:', insertResult.rows[0]);
  
} catch (dbError) {
  console.error('❌ DATABASE ERROR saving submission:', dbError);
  console.error('   Error code:', dbError.code);
  console.error('   Error message:', dbError.message);
}
```

### Step 2: Restart Backend

```powershell
# Stop backend (Ctrl+C in the terminal)
cd backend
npm start
```

### Step 3: Submit Code Again

1. Open the Flutter app
2. Go to Triangle Area exercise
3. Submit code
4. Watch the backend terminal for logs

### Step 4: Check Database

```powershell
cd backend
node check_table_structure.js
```

Should now show submissions > 0.

## Expected Flow

When code is submitted successfully:

1. **Flutter App:**
   ```
   Submitting code for exercise 1
   Submit response status: 200
   Submit response body: {"passed":true,"score":100,...}
   ```

2. **Backend:**
   ```
   === FINAL SUBMISSION ===
   User: 1, Exercise: 1
   💾 Attempting to save submission...
   ✅ Submission saved! ID: 1
   ```

3. **Database:**
   ```
   SELECT * FROM submissions;
   -- Should show 1 row
   ```

4. **Flutter App (on return):**
   ```
   🔄 Returned from code editor, refreshing completion status...
   ✅ Exercise 1 completed successfully!
   🔄 Loading completed exercises for user: [enroll_number]
   ✅ Processed completed exercise IDs: {1}
   ✅ UI refreshed with 1 completed exercises
   ```

5. **UI Updates:**
   - "1/28 Completed" badge appears
   - Exercise card shows green tick icon
   - "COMPLETED" badge on exercise
   - Success snackbar shows

## If Still Not Working

1. **Check if user is authenticated:**
   ```javascript
   // In submit route
   if (!req.user || !req.user.userId) {
     console.error('❌ No user in request!');
     return res.status(401).json({ error: 'Not authenticated' });
   }
   ```

2. **Check database connection:**
   ```javascript
   // Test query before insert
   const testQuery = await pool.query('SELECT 1');
   console.log('Database connected:', testQuery.rows);
   ```

3. **Check for foreign key constraints:**
   ```sql
   -- Make sure user_id and exercise_id exist
   SELECT * FROM users WHERE id = 1;
   SELECT * FROM exercises WHERE id = 1;
   ```

## Next Steps

1. Add the enhanced logging to the backend
2. Restart the backend server
3. Submit code again
4. Share the backend console output with me
5. I'll help identify the exact issue
