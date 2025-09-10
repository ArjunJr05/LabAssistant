class Subject {
  constructor(pool) {
    this.pool = pool;
  }

  async create(subjectData) {
    const { name, code } = subjectData;
    
    const query = `
      INSERT INTO subjects (name, code)
      VALUES ($1, $2)
      RETURNING *
    `;
    
    const values = [name, code];
    const result = await this.pool.query(query, values);
    return result.rows[0];
  }

  async findAll() {
    const query = 'SELECT * FROM subjects ORDER BY name';
    const result = await this.pool.query(query);
    return result.rows;
  }

  async findById(id) {
    const query = 'SELECT * FROM subjects WHERE id = $1';
    const result = await this.pool.query(query, [id]);
    return result.rows[0];
  }

  async findByCode(code) {
    const query = 'SELECT * FROM subjects WHERE code = $1';
    const result = await this.pool.query(query, [code]);
    return result.rows[0];
  }

  async update(id, subjectData) {
    const { name, code } = subjectData;
    
    const query = `
      UPDATE subjects 
      SET name = $1, code = $2, updated_at = CURRENT_TIMESTAMP
      WHERE id = $3
      RETURNING *
    `;
    
    const values = [name, code, id];
    const result = await this.pool.query(query, values);
    return result.rows[0];
  }

  async delete(id) {
    const query = 'DELETE FROM subjects WHERE id = $1 RETURNING *';
    const result = await this.pool.query(query, [id]);
    return result.rows[0];
  }

  async getExerciseCount(subjectId) {
    const query = 'SELECT COUNT(*) FROM exercises WHERE subject_id = $1';
    const result = await this.pool.query(query, [subjectId]);
    return parseInt(result.rows[0].count);
  }
}

module.exports = Subject;