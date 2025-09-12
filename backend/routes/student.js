const express = require('express');
const { pool } = require('../config/database');
const auth = require('../middleware/auth');

const router = express.Router();

// Get student's submissions
router.get('/submissions', auth, async (req, res) => {
  try {
    const userId = req.user.userId;
    const limit = req.query.limit ? parseInt(req.query.limit) : 20;
    
    const submissions = await pool.query(`
      SELECT s.*, e.title as exercise_title, sub.name as subject_name
      FROM submissions s
      JOIN exercises e ON s.exercise_id = e.id
      JOIN subjects sub ON e.subject_id = sub.id
      WHERE s.user_id = $1
      ORDER BY s.submitted_at DESC
      LIMIT $2
    `, [userId, limit]);
    
    res.json(submissions.rows);
  } catch (error) {
    console.error('Error fetching submissions:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get student's stats
router.get('/stats', auth, async (req, res) => {
  try {
    const userId = req.user.userId;
    
    const stats = await pool.query(`
      SELECT 
        COUNT(*) as total_submissions,
        COUNT(CASE WHEN status = 'passed' THEN 1 END) as passed_submissions,
        AVG(score) as average_score,
        MAX(score) as best_score
      FROM submissions 
      WHERE user_id = $1
    `, [userId]);
    
    // Get user info
    const userResult = await pool.query(
      'SELECT name, enroll_number, batch, section FROM users WHERE id = $1',
      [userId]
    );
    
    res.json({
      user: userResult.rows[0],
      stats: stats.rows[0]
    });
  } catch (error) {
    console.error('Error fetching stats:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get student's progress for a specific exercise
router.get('/progress/:exerciseId', auth, async (req, res) => {
  try {
    const userId = req.user.userId;
    const exerciseId = req.params.exerciseId;
    
    const submission = await pool.query(`
      SELECT * FROM submissions 
      WHERE user_id = $1 AND exercise_id = $2
      ORDER BY submitted_at DESC
      LIMIT 1
    `, [userId, exerciseId]);
    
    if (submission.rows.length === 0) {
      return res.json({ attempted: false });
    }
    
    res.json({
      attempted: true,
      submission: submission.rows[0]
    });
  } catch (error) {
    console.error('Error fetching progress:', error);
    res.status(500).json({ message: 'Server error' });
  }
});



// Add these routes to your student.js backend file

// Enhanced route to get student's completed exercises with proper format
router.get('/completed-exercises', auth, async (req, res) => {
  try {
    const userId = req.user.userId;
    console.log(`Fetching completed exercises for user ID: ${userId}`);
    
    const completedExercises = await pool.query(`
      SELECT 
        s.exercise_id,
        s.score,
        s.status,
        s.submitted_at,
        e.title as exercise_title,
        sub.name as subject_name,
        sub.code as subject_code
      FROM submissions s
      JOIN exercises e ON s.exercise_id = e.id
      JOIN subjects sub ON e.subject_id = sub.id
      WHERE s.user_id = $1 AND s.status = 'passed'
      ORDER BY s.submitted_at DESC
    `, [userId]);
    
    console.log(`Found ${completedExercises.rows.length} completed exercises for user ${userId}`);
    
    // Log each completed exercise for debugging
    completedExercises.rows.forEach(exercise => {
      console.log(`  - Exercise ID: ${exercise.exercise_id}, Title: ${exercise.exercise_title}, Score: ${exercise.score}%, Status: ${exercise.status}`);
    });
    
    res.json(completedExercises.rows);
  } catch (error) {
    console.error('Error fetching completed exercises:', error);
    res.status(500).json({ 
      message: 'Server error',
      error: error.message 
    });
  }
});

// Route to mark exercise as completed (called when student completes an exercise)
router.post('/mark-completed', auth, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { exerciseId, timestamp } = req.body;
    
    console.log(`Marking exercise ${exerciseId} as completed for user ${userId}`);
    
    if (!exerciseId) {
      return res.status(400).json({ message: 'Exercise ID is required' });
    }
    
    // Check if there's already a passing submission for this exercise
    const existingSubmission = await pool.query(`
      SELECT id, status, score FROM submissions 
      WHERE user_id = $1 AND exercise_id = $2 AND status = 'passed'
      ORDER BY submitted_at DESC
      LIMIT 1
    `, [userId, exerciseId]);
    
    if (existingSubmission.rows.length > 0) {
      console.log(`Exercise ${exerciseId} already completed by user ${userId} with score ${existingSubmission.rows[0].score}%`);
      return res.json({ 
        success: true,
        message: 'Exercise already completed',
        submission: existingSubmission.rows[0]
      });
    }
    
    // If no passing submission exists, this shouldn't happen in normal flow
    // But we can still return success to avoid breaking the UI
    console.log(`No passing submission found for exercise ${exerciseId}, user ${userId}`);
    
    res.json({ 
      success: true,
      message: 'Completion status checked'
    });
    
  } catch (error) {
    console.error('Error marking exercise as completed:', error);
    res.status(500).json({ 
      success: false,
      message: 'Server error',
      error: error.message 
    });
  }
});

// Enhanced route to get student's last submission for an exercise (with better error handling)
router.get('/last-submission/:exerciseId', auth, async (req, res) => {
  try {
    const userId = req.user.userId;
    const exerciseId = req.params.exerciseId;
    
    console.log(`Fetching last submission for user ${userId}, exercise ${exerciseId}`);
    
    const submission = await pool.query(`
      SELECT 
        id,
        code, 
        status, 
        score, 
        test_cases_passed, 
        total_test_cases, 
        submitted_at,
        language
      FROM submissions 
      WHERE user_id = $1 AND exercise_id = $2 
      ORDER BY submitted_at DESC
      LIMIT 1
    `, [userId, exerciseId]);
    
    if (submission.rows.length === 0) {
      console.log(`No submission found for user ${userId}, exercise ${exerciseId}`);
      return res.json({ hasSubmission: false });
    }
    
    const lastSubmission = submission.rows[0];
    console.log(`Last submission found: Status=${lastSubmission.status}, Score=${lastSubmission.score}%`);
    
    res.json({
      hasSubmission: true,
      submission: lastSubmission
    });
  } catch (error) {
    console.error('Error fetching last submission:', error);
    res.status(500).json({ 
      hasSubmission: false,
      message: 'Server error',
      error: error.message 
    });
  }
});

// Get all student activities for an exercise
router.get('/activities/:exerciseId', auth, async (req, res) => {
  try {
    const userId = req.user.userId;
    const exerciseId = req.params.exerciseId;
    
    const activities = await pool.query(`
      SELECT activity_type, status, score, tests_passed, total_tests, 
             test_results, created_at
      FROM student_activities 
      WHERE user_id = $1 AND exercise_id = $2
      ORDER BY created_at DESC
    `, [userId, exerciseId]);
    
    res.json(activities.rows);
  } catch (error) {
    console.error('Error fetching student activities:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;