// Updated routes/admin.js - Enhanced with visible/hidden test case management
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
    
    res.json({
      totalStudents: parseInt(totalStudents.rows[0].count),
      totalSubjects: parseInt(totalSubjects.rows[0].count),
      totalExercises: parseInt(totalExercises.rows[0].count),
      totalSubmissions: parseInt(totalSubmissions.rows[0].count),
      recentSubmissions: recentSubmissions.rows
    });
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
      'INSERT INTO subjects (name, code) VALUES ($1, $2) RETURNING *',
      [name, code]
    );
    
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
        constraints, test_cases, hidden_test_cases, difficulty_level
      ) 
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *
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
    const visibleCount = JSON.parse(exercise.test_cases || '[]').length;
    const hiddenCount = JSON.parse(exercise.hidden_test_cases || '[]').length;
    
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
      const visibleTestCases = JSON.parse(exercise.test_cases || '[]');
      const hiddenTestCases = JSON.parse(exercise.hidden_test_cases || '[]');
      
      return {
        ...exercise,
        testCaseSummary: {
          visible: visibleTestCases.length,
          hidden: hiddenTestCases.length,
          total: visibleTestCases.length + hiddenTestCases.length
        }
      };
    });
    
    res.json(exercisesWithCounts);
  } catch (error) {
    console.error('Error fetching exercises:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get online users for admin dashboard
router.get('/online-users', auth, adminOnly, async (req, res) => {
  try {
    // Get currently active users from database
    const result = await pool.query(`
      SELECT u.id, u.name, u.enroll_number, u.year, u.section, u.batch, u.role,
             us.session_start, us.is_active
      FROM users u
      LEFT JOIN user_sessions us ON u.id = us.user_id AND us.is_active = true
      WHERE u.role = 'student' AND us.is_active = true
      ORDER BY us.session_start DESC
    `);
    
    const onlineUsers = result.rows.map(user => ({
      id: user.id,
      name: user.name,
      enrollNumber: user.enroll_number,
      year: user.year,
      section: user.section,
      batch: user.batch,
      role: user.role,
      sessionStart: user.session_start,
      status: 'online'
    }));
    
    console.log(`📊 Admin requested online users: ${onlineUsers.length} found`);
    res.json(onlineUsers);
  } catch (error) {
    console.error('Error fetching online users:', error);
    res.status(500).json({ message: 'Server error' });
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
    const visibleTestCases = JSON.parse(exercise.test_cases || '[]');
    const hiddenTestCases = JSON.parse(exercise.hidden_test_cases || '[]');
    
    res.json({
      ...exercise,
      testCaseSummary: {
        visible: visibleTestCases.length,
        hidden: hiddenTestCases.length,
        total: visibleTestCases.length + hiddenTestCases.length
      }
    });
  } catch (error) {
    console.error('Error fetching exercise:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;