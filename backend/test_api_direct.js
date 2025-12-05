// Direct API test without authentication
const express = require('express');
const { pool } = require('./config/database');

async function testAPI() {
  try {
    console.log('Testing API query directly...\n');
    
    const subjectId = 1;
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
    
    console.log(`Found ${result.rows.length} exercises for subject ${subjectId}\n`);
    
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
        testCases: formattedTestCases
      };

      console.log(`Exercise ${index + 1}: ${exercise.title}`);
      console.log(`  ID: ${exercise.id}`);
      console.log(`  Test cases: ${formattedTestCases.length}`);

      return exerciseData;
    });
    
    console.log(`\n✅ Total exercises formatted: ${exercises.length}`);
    console.log('\nFirst exercise sample:');
    console.log(JSON.stringify(exercises[0], null, 2));
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

testAPI();
