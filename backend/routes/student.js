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

// Get student's completed exercises
router.get('/completed-exercises', auth, async (req, res) => {
  try {
    const userId = req.user.userId;
    
    const completedExercises = await pool.query(`
      SELECT DISTINCT s.exercise_id, s.score, s.status, e.title
      FROM submissions s
      JOIN exercises e ON s.exercise_id = e.id
      WHERE s.user_id = $1 AND s.status = 'passed'
      ORDER BY s.submitted_at DESC
    `, [userId]);
    
    res.json(completedExercises.rows);
  } catch (error) {
    console.error('Error fetching completed exercises:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get student's last submission for an exercise
router.get('/last-submission/:exerciseId', auth, async (req, res) => {
  try {
    const userId = req.user.userId;
    const exerciseId = req.params.exerciseId;
    
    const submission = await pool.query(`
      SELECT code, status, score, test_cases_passed, total_test_cases, submitted_at
      FROM submissions 
      WHERE user_id = $1 AND exercise_id = $2 AND status = 'passed'
      ORDER BY submitted_at DESC
      LIMIT 1
    `, [userId, exerciseId]);
    
    if (submission.rows.length === 0) {
      return res.json({ hasSubmission: false });
    }
    
    res.json({
      hasSubmission: true,
      submission: submission.rows[0]
    });
  } catch (error) {
    console.error('Error fetching last submission:', error);
    res.status(500).json({ message: 'Server error' });
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