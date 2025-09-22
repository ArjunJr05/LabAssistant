const express = require('express');
const router = express.Router();
const db = require('../config/database');
const { authenticateToken } = require('../middleware/auth');

// Track tab switch and update malpractice status
router.post('/tab-switch', authenticateToken, async (req, res) => {
  try {
    const { exerciseId } = req.body;
    const studentId = req.user.id;

    // Get current submission or create one
    let query = `
      SELECT id, tab_switches, malpractice 
      FROM submissions 
      WHERE student_id = ? AND exercise_id = ? AND activity_type = 'submission'
      ORDER BY created_at DESC 
      LIMIT 1
    `;
    
    let [rows] = await db.execute(query, [studentId, exerciseId]);
    
    if (rows.length === 0) {
      // Create initial submission record
      query = `
        INSERT INTO submissions (student_id, exercise_id, activity_type, tab_switches, malpractice)
        VALUES (?, ?, 'submission', 1, FALSE)
      `;
      await db.execute(query, [studentId, exerciseId]);
      
      res.json({ 
        success: true, 
        tabSwitches: 1, 
        malpractice: false,
        warning: 'First tab switch detected. You have 2 more chances before being blocked.'
      });
    } else {
      const submission = rows[0];
      const newTabSwitches = submission.tab_switches + 1;
      const isMalpractice = newTabSwitches >= 3;
      
      // Update submission with new tab switch count and malpractice status
      query = `
        UPDATE submissions 
        SET tab_switches = ?, malpractice = ?
        WHERE id = ?
      `;
      await db.execute(query, [newTabSwitches, isMalpractice, submission.id]);
      
      let message = '';
      if (isMalpractice) {
        message = 'You have been blocked from this exercise due to excessive tab switching.';
      } else {
        const remaining = 3 - newTabSwitches;
        message = `Tab switch detected. You have ${remaining} more chance${remaining !== 1 ? 's' : ''} before being blocked.`;
      }
      
      res.json({ 
        success: true, 
        tabSwitches: newTabSwitches, 
        malpractice: isMalpractice,
        warning: message
      });
    }
  } catch (error) {
    console.error('Error tracking tab switch:', error);
    res.status(500).json({ error: 'Failed to track tab switch' });
  }
});

// Check if student is blocked from exercise
router.get('/check/:exerciseId', authenticateToken, async (req, res) => {
  try {
    const { exerciseId } = req.params;
    const studentId = req.user.id;

    const query = `
      SELECT malpractice, tab_switches
      FROM submissions
      WHERE student_id = ? AND exercise_id = ? AND malpractice = TRUE
      LIMIT 1
    `;

    const [rows] = await db.execute(query, [studentId, exerciseId]);
    const isBlocked = rows.length > 0;

    res.json({ 
      blocked: isBlocked, 
      tabSwitches: rows.length > 0 ? rows[0].tab_switches : 0 
    });
  } catch (error) {
    console.error('Error checking malpractice status:', error);
    res.status(500).json({ error: 'Failed to check malpractice status' });
  }
});

// Get malpractice history for admin (specific exercise)
router.get('/history/:exerciseId', authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }

    const { exerciseId } = req.params;

    const query = `
      SELECT 
        s.id,
        s.student_id,
        s.tab_switches,
        s.malpractice,
        s.created_at,
        s.updated_at,
        u.name as student_name,
        u.enroll_number,
        e.title as exercise_title
      FROM submissions s
      JOIN users u ON s.student_id = u.id
      JOIN exercises e ON s.exercise_id = e.id
      WHERE s.exercise_id = ? AND s.malpractice = TRUE
      ORDER BY s.updated_at DESC
    `;

    const [rows] = await db.execute(query, [exerciseId]);
    res.json(rows);
  } catch (error) {
    console.error('Error fetching malpractice history:', error);
    res.status(500).json({ error: 'Failed to fetch malpractice history' });
  }
});

// Get all malpractice incidents (admin only)
router.get('/incidents', authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }

    const query = `
      SELECT 
        s.id,
        s.student_id,
        s.exercise_id,
        s.tab_switches,
        s.malpractice,
        s.created_at,
        s.updated_at,
        u.name as student_name,
        u.enroll_number,
        e.title as exercise_title,
        sub.name as subject_name
      FROM submissions s
      JOIN users u ON s.student_id = u.id
      JOIN exercises e ON s.exercise_id = e.id
      JOIN subjects sub ON e.subject_id = sub.id
      WHERE s.malpractice = TRUE
      ORDER BY s.updated_at DESC
      LIMIT 100
    `;

    const [rows] = await db.execute(query);
    res.json(rows);
  } catch (error) {
    console.error('Error fetching malpractice incidents:', error);
    res.status(500).json({ error: 'Failed to fetch malpractice incidents' });
  }
});

// Unblock student (admin only)
router.post('/unblock', authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }

    const { studentId, exerciseId } = req.body;

    const query = `
      UPDATE submissions 
      SET malpractice = FALSE, tab_switches = 0
      WHERE student_id = ? AND exercise_id = ?
    `;

    await db.execute(query, [studentId, exerciseId]);

    res.json({ success: true, message: 'Student unblocked successfully' });
  } catch (error) {
    console.error('Error unblocking student:', error);
    res.status(500).json({ error: 'Failed to unblock student' });
  }
});

module.exports = router;
