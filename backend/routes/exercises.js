// Updated routes/exercises.js - Enhanced with visible/hidden test case logic
const express = require('express');
const { pool } = require('../config/database');
const { executeCode } = require('../utils/compiler');
const auth = require('../middleware/auth');

const router = express.Router();

// Get all subjects
router.get('/subjects', auth, async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM subjects ORDER BY name');
    console.log('Fetched subjects:', result.rows);
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching subjects:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get exercises by subject - Only show visible test cases to students
router.get('/subject/:subjectId', auth, async (req, res) => {
  try {
    const { subjectId } = req.params;
    console.log(`Fetching exercises for subject ID: ${subjectId}`);
    
    if (!subjectId || isNaN(parseInt(subjectId))) {
      return res.status(400).json({ message: 'Invalid subject ID' });
    }

    const result = await pool.query(
      `SELECT 
         id, 
         title, 
         description, 
         difficulty_level, 
         created_at,
         input_format,
         output_format,
         constraints,
         test_cases
       FROM exercises 
       WHERE subject_id = $1 
       ORDER BY created_at ASC`,
      [subjectId]
    );
    
    console.log(`Found ${result.rows.length} exercises for subject ${subjectId}`);
    
    const exercises = result.rows.map((exercise, index) => {
      // Handle test_cases (JSONB field - only visible test cases)
      let visibleTestCases = [];
      if (exercise.test_cases) {
        if (Array.isArray(exercise.test_cases)) {
          visibleTestCases = exercise.test_cases;
        } else if (typeof exercise.test_cases === 'string') {
          try {
            visibleTestCases = JSON.parse(exercise.test_cases);
          } catch (e) {
            console.error('Error parsing test_cases string:', e);
            visibleTestCases = [];
          }
        }
      }
      
      // Transform test cases to match Flutter model format
      const formattedTestCases = visibleTestCases.map(tc => ({
        input: tc.input || '',
        expectedOutput: tc.expected_output || tc.expectedOutput || ''
      }));
      
      const exerciseData = {
        id: exercise.id,
        title: exercise.title || 'Untitled Exercise',
        description: exercise.description || 'No description available',
        difficultyLevel: exercise.difficulty_level || 'Medium',
        createdAt: exercise.created_at,
        inputFormat: exercise.input_format || null,
        outputFormat: exercise.output_format || null,
        constraints: exercise.constraints || null,
        testCases: formattedTestCases // Only visible test cases
      };

      console.log(`\nExercise ${index + 1}: ${exercise.title}`);
      console.log(`Visible test cases: ${formattedTestCases.length}`);

      return exerciseData;
    });
    
    console.log(`Sending ${exercises.length} exercises to Flutter app`);
    res.json(exercises);
    
  } catch (error) {
    console.error('Error fetching exercises:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get specific exercise - Only show visible test cases to students
router.get('/:exerciseId', auth, async (req, res) => {
  try {
    const { exerciseId } = req.params;
    
    console.log(`=== FETCHING EXERCISE ${exerciseId} ===`);
    
    if (!exerciseId || isNaN(parseInt(exerciseId))) {
      return res.status(400).json({ message: 'Invalid exercise ID' });
    }

    const result = await pool.query(
      'SELECT id, title, description, test_cases, difficulty_level, input_format, output_format, constraints FROM exercises WHERE id = $1',
      [exerciseId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Exercise not found' });
    }

    const exercise = result.rows[0];
    console.log('Raw exercise from DB:', {
      id: exercise.id,
      title: exercise.title,
      visible_test_cases_count: Array.isArray(exercise.test_cases) ? exercise.test_cases.length : 0
    });
    
    // Handle visible test_cases only (JSONB field is automatically parsed)
    let visibleTestCases = [];
    if (exercise.test_cases) {
      if (Array.isArray(exercise.test_cases)) {
        visibleTestCases = exercise.test_cases;
      } else if (typeof exercise.test_cases === 'string') {
        try {
          visibleTestCases = JSON.parse(exercise.test_cases);
        } catch (e) {
          console.error('Error parsing test_cases string:', e);
          visibleTestCases = [];
        }
      }
    }
    
    // Transform test cases to match Flutter model format
    const formattedTestCases = visibleTestCases.map(tc => ({
      input: tc.input || '',
      expectedOutput: tc.expected_output || tc.expectedOutput || ''
    }));
    
    const response = {
      id: exercise.id,
      title: exercise.title || 'Untitled Exercise',
      description: exercise.description || 'No description available',
      testCases: formattedTestCases, // Only visible test cases
      difficultyLevel: exercise.difficulty_level || 'Medium',
      inputFormat: exercise.input_format || null,
      outputFormat: exercise.output_format || null,
      constraints: exercise.constraints || null
    };

    console.log(`Sending exercise with ${formattedTestCases.length} visible test cases`);
    res.json(response);
  } catch (error) {
    console.error('Error fetching exercise:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Test run - Only visible test cases
router.post('/:exerciseId/test', auth, async (req, res) => {
  try {
    const { exerciseId } = req.params;
    const { code } = req.body;
    const userId = req.user.userId;

    console.log(`\n=== TEST RUN ===`);
    console.log(`User: ${userId}, Exercise: ${exerciseId}`);

    if (!code || code.trim() === '') {
      return res.json({ 
        compilationSuccess: false,
        compilationError: 'Code is required',
        results: []
      });
    }

    // Get exercise with only visible test cases
    const exerciseResult = await pool.query(
      'SELECT test_cases FROM exercises WHERE id = $1',
      [exerciseId]
    );

    if (exerciseResult.rows.length === 0) {
      return res.json({ 
        compilationSuccess: false,
        compilationError: 'Exercise not found',
        results: []
      });
    }

    const exercise = exerciseResult.rows[0];
    const visibleTestCases = Array.isArray(exercise.test_cases) ? exercise.test_cases : [];
    
    console.log(`Running against ${visibleTestCases.length} visible test cases only`);

    if (visibleTestCases.length === 0) {
      return res.json({
        compilationSuccess: false,
        compilationError: 'No visible test cases available',
        results: []
      });
    }

    // Execute code against visible test cases only
    const executionResult = await executeCode(code, visibleTestCases);
    
    if (!executionResult.compilationSuccess) {
      // Save failed test run
      try {
        await pool.query(
          `INSERT INTO student_activities (
            user_id, exercise_id, activity_type, code, status, 
            test_results, created_at
          ) VALUES ($1, $2, $3, $4, $5, $6, NOW())`,
          [userId, exerciseId, 'test_run', code, 'compilation_error', JSON.stringify({ error: executionResult.compilationError })]
        );
      } catch (dbError) {
        console.error('Error saving failed test run:', dbError);
      }

      return res.json({
        compilationSuccess: false,
        compilationError: executionResult.compilationError,
        results: []
      });
    }

    const results = executionResult.results;
    const passedTests = results.filter(r => r.passed).length;

    console.log(`Visible test results: ${passedTests}/${results.length} passed`);

    // Save successful test run
    try {
      await pool.query(
        `INSERT INTO student_activities (
          user_id, exercise_id, activity_type, code, status, 
          test_results, tests_passed, total_tests, created_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())`,
        [
          userId, exerciseId, 'test_run', code, 'completed',
          JSON.stringify(results), passedTests, results.length
        ]
      );
    } catch (dbError) {
      console.error('Error saving test run:', dbError);
    }

    res.json({
      compilationSuccess: true,
      results: results,
      passedTests: passedTests,
      totalTests: results.length,
      message: passedTests === results.length ? 'All visible test cases passed!' : 'Some visible test cases failed'
    });

  } catch (error) {
    console.error('Test run error:', error);
    res.json({ 
      compilationSuccess: false,
      compilationError: `Server error: ${error.message}`,
      results: []
    });
  }
});

// Final submission - All test cases (visible + hidden)
router.post('/:exerciseId/submit', auth, async (req, res) => {
  try {
    const { exerciseId } = req.params;
    const { code } = req.body;
    const userId = req.user.userId;

    console.log(`\n=== FINAL SUBMISSION ===`);
    console.log(`User: ${userId}, Exercise: ${exerciseId}`);

    if (!code || code.trim() === '') {
      return res.json({ 
        compilationSuccess: false,
        compilationError: 'Code is required',
        results: [],
        score: 0,
        passed: false
      });
    }

    // Get exercise with both visible and hidden test cases
    const exerciseResult = await pool.query(
      'SELECT test_cases, hidden_test_cases FROM exercises WHERE id = $1',
      [exerciseId]
    );

    if (exerciseResult.rows.length === 0) {
      return res.json({ 
        compilationSuccess: false,
        compilationError: 'Exercise not found',
        results: [],
        score: 0,
        passed: false
      });
    }

    const exercise = exerciseResult.rows[0];
    
    // Get both visible and hidden test cases
    const visibleTestCases = Array.isArray(exercise.test_cases) ? exercise.test_cases : [];
    const hiddenTestCases = Array.isArray(exercise.hidden_test_cases) ? exercise.hidden_test_cases : [];
    const allTestCases = [...visibleTestCases, ...hiddenTestCases];
    
    console.log(`Final evaluation:
    - Visible test cases: ${visibleTestCases.length}
    - Hidden test cases: ${hiddenTestCases.length}
    - Total test cases: ${allTestCases.length}`);

    if (allTestCases.length === 0) {
      return res.json({
        compilationSuccess: false,
        compilationError: 'No test cases available',
        results: [],
        score: 0,
        passed: false
      });
    }

    // Execute code against ALL test cases (visible + hidden)
    const executionResult = await executeCode(code, allTestCases);
    
    if (!executionResult.compilationSuccess) {
      // Save failed submission
      try {
        await pool.query(
          `INSERT INTO submissions (
            user_id, exercise_id, code, language, status, score, 
            test_cases_passed, total_test_cases, created_at
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())`,
          [userId, exerciseId, code, 'c', 'compilation_error', 0, 0, allTestCases.length]
        );
      } catch (dbError) {
        console.error('Error saving failed submission:', dbError);
      }

      return res.json({
        compilationSuccess: false,
        compilationError: executionResult.compilationError,
        results: [],
        score: 0,
        passed: false
      });
    }

    const allResults = executionResult.results;
    const totalPassedTests = allResults.filter(r => r.passed).length;
    const totalTests = allResults.length;
    const score = totalTests > 0 ? Math.round((totalPassedTests / totalTests) * 100) : 0;
    const allTestsPassed = totalPassedTests === totalTests;

    // Separate results for visible and hidden test cases
    const visibleResults = allResults.slice(0, visibleTestCases.length);
    const hiddenResults = allResults.slice(visibleTestCases.length);
    
    const visiblePassed = visibleResults.filter(r => r.passed).length;
    const hiddenPassed = hiddenResults.filter(r => r.passed).length;

    console.log(`Final submission results:
    - Visible tests: ${visiblePassed}/${visibleTestCases.length} passed
    - Hidden tests: ${hiddenPassed}/${hiddenTestCases.length} passed
    - Overall: ${totalPassedTests}/${totalTests} passed
    - Score: ${score}%`);

    // Save submission with complete results
    try {
      await pool.query(
        `INSERT INTO submissions (
          user_id, exercise_id, code, language, status, score, 
          test_cases_passed, total_test_cases, created_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())`,
        [
          userId, exerciseId, code, 'c', 
          allTestsPassed ? 'passed' : 'failed', 
          score, totalPassedTests, totalTests
        ]
      );
      console.log('Final submission saved successfully');

      // Also save to student activities for detailed tracking
      await pool.query(
        `INSERT INTO student_activities (
          user_id, exercise_id, activity_type, code, status, score,
          test_results, tests_passed, total_tests, created_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())`,
        [
          userId, exerciseId, 'submission', code, 
          allTestsPassed ? 'passed' : 'failed', score,
          JSON.stringify({
            visible: visibleResults,
            hidden_passed: hiddenPassed,
            hidden_total: hiddenTestCases.length
          }), totalPassedTests, totalTests
        ]
      );
    } catch (dbError) {
      console.error('Error saving submission:', dbError);
    }

    // Determine submission result message
    let message;
    if (allTestsPassed) {
      message = 'Congratulations! All test cases passed!';
    } else if (visiblePassed === visibleTestCases.length && hiddenPassed < hiddenTestCases.length) {
      message = `All visible test cases passed, but ${hiddenTestCases.length - hiddenPassed} hidden test case(s) failed. Keep improving!`;
    } else if (visiblePassed < visibleTestCases.length) {
      message = 'Some visible test cases failed. Please review your solution.';
    } else {
      message = 'Some test cases failed. Keep trying!';
    }

    // Return results - only show visible test case results to students
    const response = {
      compilationSuccess: true,
      results: visibleResults, // Only show results for visible test cases
      score: score, // Overall score based on ALL tests (visible + hidden)
      passed: allTestsPassed, // Pass/fail based on ALL tests
      totalTests: visibleTestCases.length, // Only show visible count in UI
      passedTests: visiblePassed, // Only show visible passed count in UI
      message: message,
      // Additional info for debugging (remove in production)
      debug: {
        visibleTestsPassed: visiblePassed,
        visibleTestsTotal: visibleTestCases.length,
        hiddenTestsPassed: hiddenPassed,
        hiddenTestsTotal: hiddenTestCases.length,
        overallPassed: totalPassedTests,
        overallTotal: totalTests
      }
    };

    console.log('Final submission response prepared');
    res.json(response);

  } catch (error) {
    console.error('Final submission error:', error);
    
    // Save error submission
    try {
      await pool.query(
        `INSERT INTO submissions (
          user_id, exercise_id, code, language, status, score, 
          test_cases_passed, total_test_cases, created_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())`,
        [req.user.userId, req.params.exerciseId, req.body.code || '', 'c', 'error', 0, 0, 0]
      );
    } catch (dbError) {
      console.error('Error saving error submission:', dbError);
    }

    res.json({ 
      compilationSuccess: false,
      compilationError: `Server error: ${error.message}`,
      results: [],
      score: 0,
      passed: false
    });
  }
});

module.exports = router;