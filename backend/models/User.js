const { Pool } = require('pg');
const bcrypt = require('bcryptjs');

class User {
  constructor(pool) {
    this.pool = pool;
  }

  async create(userData) {
    const { name, enrollNumber, year, section, batch, password, role = 'student' } = userData;
    
    const hashedPassword = await bcrypt.hash(password, 10);
    
    const query = `
      INSERT INTO users (name, enroll_number, year, section, batch, password, role)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING id, name, enroll_number, year, section, batch, role, created_at
    `;
    
    const values = [name, enrollNumber, year, section, batch, hashedPassword, role];
    const result = await this.pool.query(query, values);
    return result.rows[0];
  }

  async findByEnrollNumber(enrollNumber) {
    const query = 'SELECT * FROM users WHERE enroll_number = $1';
    const result = await this.pool.query(query, [enrollNumber]);
    return result.rows[0];
  }

  async findById(id) {
    const query = 'SELECT * FROM users WHERE id = $1';
    const result = await this.pool.query(query, [id]);
    return result.rows[0];
  }

  async validatePassword(plainPassword, hashedPassword) {
    return await bcrypt.compare(plainPassword, hashedPassword);
  }

  async getAllStudents() {
    const query = `
      SELECT id, name, enroll_number, year, section, batch, created_at
      FROM users 
      WHERE role = 'student'
      ORDER BY batch, section, name
    `;
    const result = await this.pool.query(query);
    return result.rows;
  }

  async getStudentsByBatch(batch) {
    const query = `
      SELECT id, name, enroll_number, year, section, batch, created_at
      FROM users 
      WHERE role = 'student' AND batch = $1
      ORDER BY section, name
    `;
    const result = await this.pool.query(query, [batch]);
    return result.rows;
  }

  async updateLastActive(userId) {
    const query = 'UPDATE users SET last_active = CURRENT_TIMESTAMP WHERE id = $1';
    await this.pool.query(query, [userId]);
  }
}

module.exports = User;