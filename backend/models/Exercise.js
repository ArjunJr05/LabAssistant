class Exercise {
  constructor(pool) {
    this.pool = pool;
  }

  async create(exerciseData) {
    const { 
      subject_id, 
      title, 
      description, 
      input_format,
      output_format,
      constraints,
      test_cases, 
      hidden_test_cases, 
      difficulty_level = 'medium' 
    } = exerciseData;
    
    const query = `
      INSERT INTO exercises (subject_id, title, description, input_format, output_format, constraints, test_cases, hidden_test_cases, difficulty_level)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING *
    `;
    
    const values = [
      subject_id, 
      title, 
      description, 
      input_format || null,
      output_format || null,
      constraints || null,
      JSON.stringify(test_cases), 
      JSON.stringify(hidden_test_cases || []), 
      difficulty_level
    ];
    
    const result = await this.pool.query(query, values);
    return result.rows[0];
  }

  async findById(id, includeHidden = false) {
    const query = 'SELECT * FROM exercises WHERE id = $1';
    const result = await this.pool.query(query, [id]);
    
    if (result.rows.length === 0) return null;
    
    const exercise = result.rows[0];
    
    // Parse JSON fields
    exercise.test_cases = JSON.parse(exercise.test_cases || '[]');
    if (includeHidden) {
      exercise.hidden_test_cases = JSON.parse(exercise.hidden_test_cases || '[]');
    } else {
      delete exercise.hidden_test_cases;
    }
    
    return exercise;
  }

  async findBySubjectId(subjectId, includeHidden = false) {
    const query = `
      SELECT * FROM exercises 
      WHERE subject_id = $1 
      ORDER BY created_at ASC
    `;
    
    const result = await this.pool.query(query, [subjectId]);
    
    return result.rows.map(exercise => {
      exercise.test_cases = JSON.parse(exercise.test_cases || '[]');
      if (includeHidden) {
        exercise.hidden_test_cases = JSON.parse(exercise.hidden_test_cases || '[]');
      } else {
        delete exercise.hidden_test_cases;
      }
      return exercise;
    });
  }

  async findAll(includeHidden = false) {
    const query = `
      SELECT e.*, s.name as subject_name, s.code as subject_code
      FROM exercises e
      JOIN subjects s ON e.subject_id = s.id
      ORDER BY s.name, e.created_at ASC
    `;
    
    const result = await this.pool.query(query);
    
    return result.rows.map(exercise => {
      exercise.test_cases = JSON.parse(exercise.test_cases || '[]');
      if (includeHidden) {
        exercise.hidden_test_cases = JSON.parse(exercise.hidden_test_cases || '[]');
      } else {
        delete exercise.hidden_test_cases;
      }
      return exercise;
    });
  }

  async update(id, exerciseData) {
    const { 
      title, 
      description, 
      input_format,
      output_format,
      constraints,
      test_cases, 
      hidden_test_cases, 
      difficulty_level 
    } = exerciseData;
    
    const query = `
      UPDATE exercises 
      SET title = $1, description = $2, input_format = $3, output_format = $4, 
          constraints = $5, test_cases = $6, hidden_test_cases = $7, 
          difficulty_level = $8, updated_at = CURRENT_TIMESTAMP
      WHERE id = $9
      RETURNING *
    `;
    
    const values = [
      title, 
      description, 
      input_format || null,
      output_format || null,
      constraints || null,
      JSON.stringify(test_cases), 
      JSON.stringify(hidden_test_cases || []), 
      difficulty_level, 
      id
    ];
    
    const result = await this.pool.query(query, values);
    return result.rows[0];
  }

  async delete(id) {
    const query = 'DELETE FROM exercises WHERE id = $1 RETURNING *';
    const result = await this.pool.query(query, [id]);
    return result.rows[0];
  }

  async getSubmissionCount(exerciseId) {
    const query = 'SELECT COUNT(*) FROM submissions WHERE exercise_id = $1';
    const result = await this.pool.query(query, [exerciseId]);
    return parseInt(result.rows[0].count);
  }

  async getSuccessRate(exerciseId) {
    const query = `
      SELECT 
        COUNT(*) as total_submissions,
        COUNT(CASE WHEN status = 'passed' THEN 1 END) as passed_submissions
      FROM submissions 
      WHERE exercise_id = $1
    `;
    
    const result = await this.pool.query(query, [exerciseId]);
    const { total_submissions, passed_submissions } = result.rows[0];
    
    if (total_submissions === 0) return 0;
    return (passed_submissions / total_submissions) * 100;
  }
}

module.exports = Exercise;