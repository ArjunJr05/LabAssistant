// routes/admin.js - Complete admin routes with enhanced shutdown functionality
const express = require('express');
const { pool } = require('../config/database');
const auth = require('../middleware/auth');

const router = express.Router();

// Middleware to check admin role
const adminOnly = (req, res, next) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ message: 'Admin access required' });
  }
  next();
};

// Get dashboard analytics
router.get('/analytics', auth, adminOnly, async (req, res) => {
  try {
    console.log('Admin requesting analytics...');
    
    // Get basic counts
    const totalStudents = await pool.query('SELECT COUNT(*) FROM users WHERE role = $1', ['student']);
    const totalSubjects = await pool.query('SELECT COUNT(*) FROM subjects');
    const totalExercises = await pool.query('SELECT COUNT(*) FROM exercises');
    const totalSubmissions = await pool.query('SELECT COUNT(*) FROM submissions');
    
    // Get recent submissions
    const recentSubmissions = await pool.query(`
      SELECT s.*, u.name as user_name, u.enroll_number, 
             e.title as exercise_title, sub.name as subject_name
      FROM submissions s
      JOIN users u ON s.user_id = u.id
      JOIN exercises e ON s.exercise_id = e.id
      JOIN subjects sub ON e.subject_id = sub.id
      ORDER BY s.submitted_at DESC
      LIMIT 10
    `);
    
    // Get online student count
    const onlineStudents = await pool.query('SELECT COUNT(*) FROM users WHERE role = $1 AND is_online = true', ['student']);
    
    const analytics = {
      totalStudents: parseInt(totalStudents.rows[0].count),
      totalSubjects: parseInt(totalSubjects.rows[0].count),
      totalExercises: parseInt(totalExercises.rows[0].count),
      totalSubmissions: parseInt(totalSubmissions.rows[0].count),
      onlineStudents: parseInt(onlineStudents.rows[0].count),
      recentSubmissions: recentSubmissions.rows
    };
    
    console.log('Analytics sent:', analytics);
    res.json(analytics);
  } catch (error) {
    console.error('Error fetching analytics:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Create subject
router.post('/subjects', auth, adminOnly, async (req, res) => {
  try {
    const { name, code } = req.body;
    
    if (!name || !code) {
      return res.status(400).json({ message: 'Name and code are required' });
    }
    
    // Check if subject code already exists
    const existing = await pool.query('SELECT * FROM subjects WHERE code = $1', [code]);
    if (existing.rows.length > 0) {
      return res.status(400).json({ message: 'Subject code already exists' });
    }
    
    const result = await pool.query(
      'INSERT INTO subjects (name, code, created_at, updated_at) VALUES ($1, $2, NOW(), NOW()) RETURNING *',
      [name, code]
    );
    
    console.log('Subject created:', result.rows[0]);
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error creating subject:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Enhanced create exercise with visible/hidden test case separation
router.post('/exercises', auth, adminOnly, async (req, res) => {
  try {
    const { 
      subject_id, 
      title, 
      description, 
      input_format,
      output_format,
      constraints,
      test_cases,           // These are the VISIBLE test cases (exactly 3)
      hidden_test_cases,    // These are the HIDDEN test cases (unlimited)
      difficulty_level 
    } = req.body;
    
    console.log('\n=== CREATING EXERCISE ===');
    console.log('Title:', title);
    console.log('Visible test cases:', test_cases ? test_cases.length : 0);
    console.log('Hidden test cases:', hidden_test_cases ? hidden_test_cases.length : 0);
    
    if (!subject_id || !title || !description || !test_cases) {
      return res.status(400).json({ message: 'All required fields must be provided' });
    }
    
    // Validate that exactly 3 visible test cases are provided
    if (!Array.isArray(test_cases) || test_cases.length !== 3) {
      return res.status(400).json({ 
        message: 'Exactly 3 visible test cases are required for students to practice with' 
      });
    }
    
    // Validate that at least some test cases exist
    const totalTestCases = test_cases.length + (hidden_test_cases ? hidden_test_cases.length : 0);
    if (totalTestCases < 3) {
      return res.status(400).json({ 
        message: 'At least 3 total test cases are required (3 visible + 0 or more hidden)' 
      });
    }
    
    // Validate test case structure
    const validateTestCases = (testCases, type) => {
      for (let i = 0; i < testCases.length; i++) {
        const tc = testCases[i];
        if (!tc.hasOwnProperty('input') || !tc.hasOwnProperty('expectedOutput') && !tc.hasOwnProperty('expected_output')) {
          throw new Error(`${type} test case ${i + 1} is missing required fields (input, expectedOutput)`);
        }
      }
    };
    
    validateTestCases(test_cases, 'Visible');
    if (hidden_test_cases && hidden_test_cases.length > 0) {
      validateTestCases(hidden_test_cases, 'Hidden');
    }
    
    const result = await pool.query(`
      INSERT INTO exercises (
        subject_id, title, description, input_format, output_format, 
        constraints, test_cases, hidden_test_cases, difficulty_level, created_at, updated_at
      ) 
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW(), NOW()) RETURNING *
    `, [
      subject_id, 
      title, 
      description, 
      input_format || null,
      output_format || null,
      constraints || null,
      JSON.stringify(test_cases),                    // Visible test cases (exactly 3)
      JSON.stringify(hidden_test_cases || []),       // Hidden test cases (unlimited)
      difficulty_level || 'medium'
    ]);
    
    const createdExercise = result.rows[0];
    
    console.log('Exercise created successfully:');
    console.log('- ID:', createdExercise.id);
    console.log('- Title:', createdExercise.title);
    console.log('- Visible test cases stored:', JSON.parse(createdExercise.test_cases).length);
    console.log('- Hidden test cases stored:', JSON.parse(createdExercise.hidden_test_cases).length);
    
    res.status(201).json({
      ...createdExercise,
      summary: {
        visibleTestCases: JSON.parse(createdExercise.test_cases).length,
        hiddenTestCases: JSON.parse(createdExercise.hidden_test_cases).length,
        totalTestCases: JSON.parse(createdExercise.test_cases).length + JSON.parse(createdExercise.hidden_test_cases).length
      }
    });
  } catch (error) {
    console.error('Error creating exercise:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// DELETE EXERCISE ROUTE
router.delete('/exercises/:exerciseId', auth, adminOnly, async (req, res) => {
  try {
    const { exerciseId } = req.params;
    
    console.log(`Admin attempting to delete exercise ID: ${exerciseId}`);
    
    if (!exerciseId || isNaN(parseInt(exerciseId))) {
      return res.status(400).json({ message: 'Invalid exercise ID' });
    }

    // Check if exercise exists first and get its details
    const exerciseCheck = await pool.query(
      'SELECT id, title, test_cases, hidden_test_cases FROM exercises WHERE id = $1', 
      [exerciseId]
    );
    
    if (exerciseCheck.rows.length === 0) {
      console.log(`Exercise with ID ${exerciseId} not found`);
      return res.status(404).json({ message: 'Exercise not found' });
    }

    const exercise = exerciseCheck.rows[0];
    
    // Safely parse test cases with error handling
    let visibleCount = 0;
    let hiddenCount = 0;
    
    try {
      const testCases = exercise.test_cases;
      if (typeof testCases === 'string') {
        visibleCount = JSON.parse(testCases).length;
      } else if (Array.isArray(testCases)) {
        visibleCount = testCases.length;
      }
    } catch (e) {
      console.log('Error parsing visible test cases:', e.message);
      visibleCount = 0;
    }
    
    try {
      const hiddenTestCases = exercise.hidden_test_cases;
      if (typeof hiddenTestCases === 'string') {
        hiddenCount = JSON.parse(hiddenTestCases).length;
      } else if (Array.isArray(hiddenTestCases)) {
        hiddenCount = hiddenTestCases.length;
      }
    } catch (e) {
      console.log('Error parsing hidden test cases:', e.message);
      hiddenCount = 0;
    }
    
    console.log(`Found exercise: "${exercise.title}" (ID: ${exerciseId})`);
    console.log(`- Visible test cases: ${visibleCount}`);
    console.log(`- Hidden test cases: ${hiddenCount}`);

    // Delete the exercise (this will cascade delete submissions due to foreign key constraints)
    const result = await pool.query('DELETE FROM exercises WHERE id = $1 RETURNING id, title', [exerciseId]);
    
    if (result.rows.length > 0) {
      console.log(`Exercise "${exercise.title}" (ID: ${exerciseId}) deleted successfully`);
      
      res.json({ 
        message: 'Exercise deleted successfully',
        deletedExercise: {
          id: result.rows[0].id,
          title: result.rows[0].title,
          testCasesRemoved: {
            visible: visibleCount,
            hidden: hiddenCount,
            total: visibleCount + hiddenCount
          }
        }
      });
    } else {
      console.log(`Failed to delete exercise ID: ${exerciseId}`);
      res.status(500).json({ message: 'Failed to delete exercise' });
    }
    
  } catch (error) {
    console.error('Error deleting exercise:', error);
    res.status(500).json({ message: 'Server error while deleting exercise', error: error.message });
  }
});

// Get all exercises for admin (with full details including hidden test cases)
router.get('/exercises', auth, adminOnly, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT e.*, s.name as subject_name, s.code as subject_code
      FROM exercises e
      JOIN subjects s ON e.subject_id = s.id
      ORDER BY s.name, e.created_at ASC
    `);
    
    // Add test case counts to each exercise for admin overview
    const exercisesWithCounts = result.rows.map(exercise => {
      let visibleCount = 0;
      let hiddenCount = 0;
      
      try {
        const testCases = exercise.test_cases;
        if (typeof testCases === 'string') {
          visibleCount = JSON.parse(testCases).length;
        } else if (Array.isArray(testCases)) {
          visibleCount = testCases.length;
        }
      } catch (e) {
        console.log('Error parsing visible test cases for exercise', exercise.id, ':', e.message);
      }
      
      try {
        const hiddenTestCases = exercise.hidden_test_cases;
        if (typeof hiddenTestCases === 'string') {
          hiddenCount = JSON.parse(hiddenTestCases).length;
        } else if (Array.isArray(hiddenTestCases)) {
          hiddenCount = hiddenTestCases.length;
        }
      } catch (e) {
        console.log('Error parsing hidden test cases for exercise', exercise.id, ':', e.message);
      }
      
      return {
        ...exercise,
        testCaseSummary: {
          visible: visibleCount,
          hidden: hiddenCount,
          total: visibleCount + hiddenCount
        }
      };
    });
    
    console.log(`Admin requested ${exercisesWithCounts.length} exercises`);
    res.json(exercisesWithCounts);
  } catch (error) {
    console.error('Error fetching exercises:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

router.get('/online-users', auth, adminOnly, async (req, res) => {
  try {
    console.log('Admin requesting online users...');
    
    // Get users marked as online in database
    const result = await pool.query(`
      SELECT 
        id, name, enroll_number, year, section, batch, role, 
        is_online, last_active, created_at, ip_address
      FROM users
      WHERE role = 'student' AND is_online = true
      ORDER BY last_active DESC
    `);
    
    console.log(`Found ${result.rows.length} students marked as online in database`);
    
    const onlineUsers = result.rows.map(user => {
      console.log(`  - ${user.name} (${user.enroll_number}) - Last active: ${user.last_active} - IP: ${user.ip_address}`);
      
      return {
        id: user.id,
        name: user.name,
        enrollNumber: user.enroll_number,
        year: user.year,
        section: user.section,
        batch: user.batch,
        role: user.role,
        isOnline: user.is_online,
        lastActive: user.last_active,
        ipAddress: user.ip_address,
        status: 'online'
      };
    });
    
    // Also check socket connections for comparison
    const io = req.app.get('socketio') || req.app.get('io');
    const socketConnections = io ? io.sockets.sockets.size : 0;
    
    console.log(`Returning ${onlineUsers.length} online users. Socket connections: ${socketConnections}`);
    
    // Return the array directly (not wrapped in an object)
    res.json(onlineUsers);
    
  } catch (error) {
    console.error('Error fetching online users:', error);
    res.status(500).json({ 
      message: 'Server error',
      error: error.message 
    });
  }
});

// Optional: Add a cleanup route to fix stale online statuses
router.post('/cleanup-stale-users', auth, adminOnly, async (req, res) => {
  try {
    console.log('Cleaning up stale online users...');
    
    // Mark users as offline if they haven't been active for more than 5 minutes
    const result = await pool.query(`
      UPDATE users 
      SET is_online = false, updated_at = NOW()
      WHERE is_online = true 
      AND role = 'student'
      AND last_active < NOW() - INTERVAL '5 minutes'
      RETURNING name, enroll_number, last_active
    `);
    
    console.log(`Cleaned up ${result.rows.length} stale users`);
    
    if (result.rows.length > 0) {
      result.rows.forEach(user => {
        console.log(`  - Marked ${user.name} (${user.enroll_number}) as offline (last active: ${user.last_active})`);
      });
    }
    
    res.json({
      success: true,
      message: `Cleaned up ${result.rows.length} stale users`,
      cleanedUsers: result.rows
    });
    
  } catch (error) {
    console.error('Error cleaning up stale users:', error);
    res.status(500).json({ 
      message: 'Server error during cleanup',
      error: error.message 
    });
  }
});

// Get specific exercise for admin (with both visible and hidden test cases)
router.get('/exercises/:exerciseId', auth, adminOnly, async (req, res) => {
  try {
    const { exerciseId } = req.params;
    
    const result = await pool.query('SELECT * FROM exercises WHERE id = $1', [exerciseId]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Exercise not found' });
    }
    
    const exercise = result.rows[0];
    
    let visibleCount = 0;
    let hiddenCount = 0;
    
    try {
      const testCases = exercise.test_cases;
      if (typeof testCases === 'string') {
        visibleCount = JSON.parse(testCases).length;
      } else if (Array.isArray(testCases)) {
        visibleCount = testCases.length;
      }
    } catch (e) {
      console.log('Error parsing visible test cases for exercise', exercise.id, ':', e.message);
    }
    
    try {
      const hiddenTestCases = exercise.hidden_test_cases;
      if (typeof hiddenTestCases === 'string') {
        hiddenCount = JSON.parse(hiddenTestCases).length;
      } else if (Array.isArray(hiddenTestCases)) {
        hiddenCount = hiddenTestCases.length;
      }
    } catch (e) {
      console.log('Error parsing hidden test cases for exercise', exercise.id, ':', e.message);
    }
    
    res.json({
      ...exercise,
      testCaseSummary: {
        visible: visibleCount,
        hidden: hiddenCount,
        total: visibleCount + hiddenCount
      }
    });
  } catch (error) {
    console.error('Error fetching exercise:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Enhanced admin shutdown notification - notifies all students and disconnects them
router.post('/shutdown-notification', auth, adminOnly, async (req, res) => {
  try {
    console.log('🔴 ADMIN SHUTDOWN NOTIFICATION RECEIVED');
    console.log('🔍 Admin details:', {
      userId: req.user.userId,
      role: req.user.role,
      enrollNumber: req.user.enrollNumber
    });
    
    // 1. Get count of currently online students
    const onlineStudentsResult = await pool.query(
      'SELECT COUNT(*) as count, array_agg(name) as names FROM users WHERE role = $1 AND is_online = true',
      ['student']
    );
    
    const onlineCount = parseInt(onlineStudentsResult.rows[0].count);
    const onlineNames = onlineStudentsResult.rows[0].names || [];
    
    console.log(`📊 Found ${onlineCount} online students to disconnect`);
    console.log(`👥 Online students: ${onlineNames.join(', ')}`);
    
    // 2. Set all students offline in database
    const updateResult = await pool.query(
      'UPDATE users SET is_online = false, last_active = NOW(), updated_at = NOW() WHERE role = $1 RETURNING name, enroll_number',
      ['student']
    );
    
    console.log(`✅ Set ${updateResult.rows.length} students offline in database`);
    
    // 3. Mark all active student sessions as inactive
    const sessionResult = await pool.query(
      `UPDATE user_sessions 
       SET is_active = false, session_end = NOW() 
       WHERE user_id IN (SELECT id FROM users WHERE role = 'student') 
       AND is_active = true 
       RETURNING user_id`
    );
    
    console.log(`✅ Ended ${sessionResult.rows.length} active student sessions`);
    
    // 4. Get Socket.IO instance and emit shutdown events
    const io = req.app.get('socketio') || req.app.get('io');
    if (io) {
      console.log('📡 Broadcasting admin shutdown to all connected clients...');
      
      const shutdownData = {
        message: 'Admin has logged out. Server is shutting down.',
        timestamp: new Date().toISOString(),
        onlineStudentCount: onlineCount,
        reason: 'admin_logout'
      };
      
      // Emit to all connected sockets
      io.emit('admin-shutdown', shutdownData);
      
      // Also emit user status changes for each student
      updateResult.rows.forEach(student => {
        io.emit('user-status-changed', {
          enrollNumber: student.enroll_number,
          name: student.name,
          isOnline: false,
          lastActive: new Date(),
          reason: 'admin_shutdown'
        });
      });
      
      console.log(`📡 Shutdown notifications sent to all connected clients`);
      
      // Disconnect all client sockets after a delay to ensure messages are received
      setTimeout(() => {
        console.log('🔌 Disconnecting all client sockets...');
        
        // Get all connected sockets and disconnect them
        const sockets = io.sockets.sockets;
        sockets.forEach((socket) => {
          console.log(`   Disconnecting socket: ${socket.id}`);
          socket.emit('force-disconnect', {
            reason: 'admin_logout',
            message: 'Server is shutting down due to admin logout'
          });
          socket.disconnect(true);
        });
        
        console.log(`✅ Disconnected ${sockets.size} client socket(s)`);
        
        // Additional cleanup - force disconnect all sockets
        setTimeout(() => {
          io.disconnectSockets(true);
          console.log('🧹 Forced disconnection of all remaining sockets');
        }, 1000);
        
      }, 2000); // 2 second delay to ensure messages are delivered
      
    } else {
      console.log('⚠️  Socket.IO instance not found - cannot broadcast shutdown');
    }
    
    // 5. Prepare shutdown statistics
    const shutdownStats = {
      timestamp: new Date().toISOString(),
      adminUser: req.user.enrollNumber,
      studentsDisconnected: onlineCount,
      studentsAffected: updateResult.rows.length,
      sessionsEnded: sessionResult.rows.length,
      studentNames: onlineNames
    };
    
    console.log('📊 SHUTDOWN STATISTICS:', shutdownStats);
    
    // 6. Respond with success
    res.json({ 
      success: true,
      message: 'Admin shutdown notification sent successfully',
      stats: {
        studentsNotified: onlineCount,
        studentsSetOffline: updateResult.rows.length,
        sessionsEnded: sessionResult.rows.length,
        timestamp: new Date().toISOString()
      }
    });
    
    console.log('✅ Admin shutdown notification completed successfully');
    
  } catch (error) {
    console.error('💥 Error during admin shutdown notification:', error);
    res.status(500).json({ 
      success: false,
      message: 'Server error during shutdown notification',
      error: error.message 
    });
  }
});

// Get all students (for admin monitoring)
router.get('/students', auth, adminOnly, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        id, name, enroll_number, year, section, batch, 
        is_online, last_active, created_at
      FROM users 
      WHERE role = 'student'
      ORDER BY batch, section, name
    `);
    
    console.log(`Admin requested all students: ${result.rows.length} found`);
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching students:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get submission statistics
router.get('/submissions/stats', auth, adminOnly, async (req, res) => {
  try {
    // Get overall submission statistics
    const overallStats = await pool.query(`
      SELECT 
        COUNT(*) as total_submissions,
        COUNT(DISTINCT user_id) as unique_students,
        COUNT(CASE WHEN status = 'passed' THEN 1 END) as passed_submissions,
        AVG(score) as average_score
      FROM submissions
    `);
    
    // Get submissions by exercise
    const exerciseStats = await pool.query(`
      SELECT 
        e.id, e.title, 
        COUNT(s.id) as submission_count,
        COUNT(CASE WHEN s.status = 'passed' THEN 1 END) as passed_count,
        AVG(s.score) as average_score
      FROM exercises e
      LEFT JOIN submissions s ON e.id = s.exercise_id
      GROUP BY e.id, e.title
      ORDER BY submission_count DESC
    `);
    
    res.json({
      overall: overallStats.rows[0],
      byExercise: exerciseStats.rows
    });
  } catch (error) {
    console.error('Error fetching submission stats:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Update exercise
router.put('/exercises/:exerciseId', auth, adminOnly, async (req, res) => {
  try {
    const { exerciseId } = req.params;
    const { 
      title, 
      description, 
      input_format,
      output_format,
      constraints,
      test_cases, 
      hidden_test_cases, 
      difficulty_level 
    } = req.body;
    
    if (!title || !description || !test_cases) {
      return res.status(400).json({ message: 'Title, description, and test cases are required' });
    }
    
    const result = await pool.query(`
      UPDATE exercises 
      SET title = $1, description = $2, input_format = $3, output_format = $4, 
          constraints = $5, test_cases = $6, hidden_test_cases = $7, 
          difficulty_level = $8, updated_at = NOW()
      WHERE id = $9
      RETURNING *
    `, [
      title, 
      description, 
      input_format || null,
      output_format || null,
      constraints || null,
      JSON.stringify(test_cases), 
      JSON.stringify(hidden_test_cases || []), 
      difficulty_level || 'medium', 
      exerciseId
    ]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Exercise not found' });
    }
    
    console.log('Exercise updated:', result.rows[0].title);
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error updating exercise:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get student exercise activities for monitoring
router.get('/student-activities/:studentId', auth, adminOnly, async (req, res) => {
  try {
    const { studentId } = req.params;
    
    const activities = await pool.query(`
      SELECT 
        sa.*, e.title as exercise_title, s.name as subject_name,
        u.name as student_name, u.enroll_number
      FROM student_activities sa
      JOIN exercises e ON sa.exercise_id = e.id
      JOIN subjects s ON e.subject_id = s.id
      JOIN users u ON sa.user_id = u.id
      WHERE sa.user_id = $1
      ORDER BY sa.created_at DESC
    `, [studentId]);
    
    res.json(activities.rows);
  } catch (error) {
    console.error('Error fetching student activities:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get student exercise progress for a specific exercise
router.get('/student-progress/:studentId/:exerciseId', auth, adminOnly, async (req, res) => {
  try {
    const { studentId, exerciseId } = req.params;
    
    // Get all activities for this student and exercise
    const activities = await pool.query(`
      SELECT 
        activity_type, status, score, tests_passed, total_tests,
        test_results, code, created_at
      FROM student_activities
      WHERE user_id = $1 AND exercise_id = $2
      ORDER BY created_at ASC
    `, [studentId, exerciseId]);
    
    // Get latest submission
    const submission = await pool.query(`
      SELECT status, score, test_cases_passed, total_test_cases, code, submitted_at
      FROM submissions
      WHERE user_id = $1 AND exercise_id = $2
      ORDER BY submitted_at DESC
      LIMIT 1
    `, [studentId, exerciseId]);
    
    // Get exercise details
    const exercise = await pool.query(`
      SELECT e.title, s.name as subject_name
      FROM exercises e
      JOIN subjects s ON e.subject_id = s.id
      WHERE e.id = $1
    `, [exerciseId]);
    
    res.json({
      exercise: exercise.rows[0] || null,
      activities: activities.rows,
      latestSubmission: submission.rows[0] || null
    });
  } catch (error) {
    console.error('Error fetching student progress:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get all exercises with completion status for a student
router.get('/student-exercises/:studentId', auth, adminOnly, async (req, res) => {
  try {
    const { studentId } = req.params;
    
    const exercises = await pool.query(`
      SELECT 
        e.id, e.title, s.name as subject_name,
        CASE 
          WHEN sub.status = 'passed' THEN true 
          ELSE false 
        END as completed,
        sub.score,
        sub.submitted_at,
        COUNT(sa.id) as activity_count
      FROM exercises e
      JOIN subjects s ON e.subject_id = s.id
      LEFT JOIN submissions sub ON e.id = sub.exercise_id AND sub.user_id = $1 AND sub.status = 'passed'
      LEFT JOIN student_activities sa ON e.id = sa.exercise_id AND sa.user_id = $1
      GROUP BY e.id, e.title, s.name, sub.status, sub.score, sub.submitted_at
      ORDER BY s.name, e.created_at
    `, [studentId]);
    
    res.json(exercises.rows);
  } catch (error) {
    console.error('Error fetching student exercises:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;