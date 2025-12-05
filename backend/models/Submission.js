class Submission {
  constructor(pool) {
    this.pool = pool;
  }

  async create(submissionData) {
    const { 
      user_id, 
      exercise_id, 
      code, 
      status, 
      score = 0, 
      execution_time = null 
    } = submissionData;
    
    const query = `
      INSERT INTO submissions (user_id, exercise_id, code, status, score, execution_time)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *
    `;
    
    const values = [user_id, exercise_id, code, status, score, execution_time];
    const result = await this.pool.query(query, values);
    return result.rows[0];
  }

  async findById(id) {
    const query = `
      SELECT s.*, u.name as user_name, u.enroll_number, 
             e.title as exercise_title, sub.name as subject_name
      FROM submissions s
      JOIN users u ON s.user_id = u.id
      JOIN exercises e ON s.exercise_id = e.id
      JOIN subjects sub ON e.subject_id = sub.id
      WHERE s.id = $1
    `;
    
    const result = await this.pool.query(query, [id]);
    return result.rows[0];
  }

  async findByUserId(userId, limit = null) {
    let query = `
      SELECT s.*, e.title as exercise_title, sub.name as subject_name
      FROM submissions s
      JOIN exercises e ON s.exercise_id = e.id
      JOIN subjects sub ON e.subject_id = sub.id
      WHERE s.user_id = $1
      ORDER BY s.submitted_at DESC
    `;
    
    if (limit) {
      query += ` LIMIT ${limit}`;
    }
    
    const result = await this.pool.query(query, [userId]);
    return result.rows;
  }

  async findByExerciseId(exerciseId) {
    const query = `
      SELECT s.*, u.name as user_name, u.enroll_number
      FROM submissions s
      JOIN users u ON s.user_id = u.id
      WHERE s.exercise_id = $1
      ORDER BY s.submitted_at DESC
    `;
    
    const result = await this.pool.query(query, [exerciseId]);
    return result.rows;
  }

  async findLatestByUserAndExercise(userId, exerciseId) {
    const query = `
      SELECT * FROM submissions 
      WHERE user_id = $1 AND exercise_id = $2
      ORDER BY submitted_at DESC
      LIMIT 1
    `;
    
    const result = await this.pool.query(query, [userId, exerciseId]);
    return result.rows[0];
  }

  async getRecentSubmissions(limit = 50) {
    const query = `
      SELECT s.*, u.name as user_name, u.enroll_number, 
             e.title as exercise_title, sub.name as subject_name
      FROM submissions s
      JOIN users u ON s.user_id = u.id
      JOIN exercises e ON s.exercise_id = e.id
      JOIN subjects sub ON e.subject_id = sub.id
      ORDER BY s.submitted_at DESC
      LIMIT $1
    `;
    
    const result = await this.pool.query(query, [limit]);
    return result.rows;
  }

  async getUserStats(userId) {
    const query = `
      SELECT 
        COUNT(*) as total_submissions,
        COUNT(CASE WHEN status = 'passed' THEN 1 END) as passed_submissions,
        AVG(score) as average_score,
        MAX(score) as best_score
      FROM submissions 
      WHERE user_id = $1
    `;
    
    const result = await this.pool.query(query, [userId]);
    return result.rows[0];
  }

  async getExerciseStats(exerciseId) {
    const query = `
      SELECT 
        COUNT(*) as total_submissions,
        COUNT(DISTINCT user_id) as unique_users,
        COUNT(CASE WHEN status = 'passed' THEN 1 END) as passed_submissions,
        AVG(score) as average_score,
        AVG(execution_time) as average_execution_time
      FROM submissions 
      WHERE exercise_id = $1
    `;
    
    const result = await this.pool.query(query, [exerciseId]);
    return result.rows[0];
  }

  async getLeaderboard(exerciseId = null, limit = 10) {
    let query = `
      SELECT 
        u.name, u.enroll_number, u.batch, u.section,
        COUNT(s.id) as total_submissions,
        COUNT(CASE WHEN s.status = 'passed' THEN 1 END) as passed_submissions,
        AVG(s.score) as average_score,
        MAX(s.score) as best_score
      FROM users u
      JOIN submissions s ON u.id = s.user_id
    `;
    
    if (exerciseId) {
      query += ` WHERE s.exercise_id = $1`;
    }
    
    query += `
      GROUP BY u.id, u.name, u.enroll_number, u.batch, u.section
      ORDER BY best_score DESC, average_score DESC
      LIMIT $${exerciseId ? 2 : 1}
    `;
    
    const values = exerciseId ? [exerciseId, limit] : [limit];
    const result = await this.pool.query(query, values);
    return result.rows;
  }
}

module.exports = Submission;