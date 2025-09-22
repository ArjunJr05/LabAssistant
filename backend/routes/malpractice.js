const express = require('express');
const { Pool } = require('pg');
const jwt = require('jsonwebtoken');
const router = express.Router();

// Database connection
const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'labassistant',
  password: process.env.DB_PASSWORD || 'password',
  port: process.env.DB_PORT || 5432,
});

// Authentication middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key', (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    req.user = user;
    next();
  });
};

// Apply authentication middleware to all routes
router.use(authenticateToken);

// Check if student is blocked from an exercise due to malpractice
router.get('/check/:exerciseId', async (req, res) => {
  try {
    const { exerciseId } = req.params;
    const userId = req.user.id;

    console.log(`Checking malpractice status for user ${userId}, exercise ${exerciseId}`);

    const result = await pool.query(
      `SELECT COUNT(*) as count, MAX(created_at) as last_incident
       FROM malpractice_logs 
       WHERE user_id = $1 AND exercise_id = $2 AND is_blocked = true`,
      [userId, exerciseId]
    );

    const isBlocked = parseInt(result.rows[0].count) > 0;
    
    console.log(`Malpractice check result: isBlocked=${isBlocked}`);

    res.json({
      isBlocked,
      lastIncident: result.rows[0].last_incident
    });
  } catch (error) {
    console.error('Error checking malpractice status:', error);
    res.status(500).json({ 
      error: 'Failed to check malpractice status',
      message: error.message 
    });
  }
});

// Log a malpractice incident
router.post('/log', async (req, res) => {
  try {
    const { exerciseId, type, description, count } = req.body;
    const userId = req.user.id;

    console.log(`Logging malpractice for user ${userId}, exercise ${exerciseId}:`, {
      type,
      description,
      count
    });

    // Determine if this should block the user (3 or more violations)
    const isBlocked = count >= 3;

    const result = await pool.query(
      `INSERT INTO malpractice_logs 
       (user_id, exercise_id, type, description, violation_count, is_blocked, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, NOW())
       RETURNING id`,
      [userId, exerciseId, type, description, count, isBlocked]
    );

    console.log(`Malpractice logged with ID: ${result.rows[0].id}, blocked: ${isBlocked}`);

    res.status(201).json({
      success: true,
      malpracticeId: result.rows[0].id,
      isBlocked
    });
  } catch (error) {
    console.error('Error logging malpractice:', error);
    res.status(500).json({ 
      error: 'Failed to log malpractice',
      message: error.message 
    });
  }
});

// Admin: Get all malpractice incidents
router.get('/incidents', async (req, res) => {
  try {
    // Check if user is admin
    if (req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Access denied. Admin privileges required.' });
    }

    console.log('Admin fetching all malpractice incidents');

    const result = await pool.query(
      `SELECT 
         ml.id,
         ml.user_id,
         u.name as student_name,
         u.email as student_email,
         ml.exercise_id,
         e.title as exercise_title,
         s.name as subject_name,
         ml.type,
         ml.description,
         ml.violation_count,
         ml.is_blocked,
         ml.created_at
       FROM malpractice_logs ml
       JOIN users u ON ml.user_id = u.id
       JOIN exercises e ON ml.exercise_id = e.id
       JOIN subjects s ON e.subject_id = s.id
       ORDER BY ml.created_at DESC`
    );

    console.log(`Found ${result.rows.length} malpractice incidents`);

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching malpractice incidents:', error);
    res.status(500).json({ 
      error: 'Failed to fetch malpractice incidents',
      message: error.message 
    });
  }
});

// Admin: Get malpractice incidents for a specific student
router.get('/student/:studentId', async (req, res) => {
  try {
    // Check if user is admin
    if (req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Access denied. Admin privileges required.' });
    }

    const { studentId } = req.params;

    console.log(`Admin fetching malpractice incidents for student ${studentId}`);

    const result = await pool.query(
      `SELECT 
         ml.id,
         ml.exercise_id,
         e.title as exercise_title,
         s.name as subject_name,
         ml.type,
         ml.description,
         ml.violation_count,
         ml.is_blocked,
         ml.created_at
       FROM malpractice_logs ml
       JOIN exercises e ON ml.exercise_id = e.id
       JOIN subjects s ON e.subject_id = s.id
       WHERE ml.user_id = $1
       ORDER BY ml.created_at DESC`,
      [studentId]
    );

    console.log(`Found ${result.rows.length} malpractice incidents for student ${studentId}`);

    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching student malpractice incidents:', error);
    res.status(500).json({ 
      error: 'Failed to fetch student malpractice incidents',
      message: error.message 
    });
  }
});

// Admin: Unblock a student from an exercise
router.post('/unblock', async (req, res) => {
  try {
    // Check if user is admin
    if (req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Access denied. Admin privileges required.' });
    }

    const { studentId, exerciseId } = req.body;

    console.log(`Admin unblocking student ${studentId} from exercise ${exerciseId}`);

    // Update all malpractice logs for this student/exercise to unblocked
    const result = await pool.query(
      `UPDATE malpractice_logs 
       SET is_blocked = false, updated_at = NOW()
       WHERE user_id = $1 AND exercise_id = $2`,
      [studentId, exerciseId]
    );

    console.log(`Unblocked ${result.rowCount} malpractice records`);

    res.json({
      success: true,
      unblocked: result.rowCount
    });
  } catch (error) {
    console.error('Error unblocking student:', error);
    res.status(500).json({ 
      error: 'Failed to unblock student',
      message: error.message 
    });
  }
});

module.exports = router;
