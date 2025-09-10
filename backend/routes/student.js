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

module.exports = router;