// middleware/auth.js
const jwt = require('jsonwebtoken');

const JWT_SECRET = '1341ae2e12f9d31a0cc42a5225b885012f16583b997b49133a68d148e03e2f5c3cf74c9d0c3da7cf37dea2143040a09b3abe1ac35393ccef1e6b9f7d3f1ac9d5'; // Should match your auth.js

module.exports = (req, res, next) => {
  try {
    // Get token from Authorization header
    const authHeader = req.header('Authorization');
    
    if (!authHeader) {
      return res.status(401).json({ message: 'No token, authorization denied' });
    }

    // Extract token - handle both "Bearer token" and just "token" formats
    let token;
    if (authHeader.startsWith('Bearer ')) {
      token = authHeader.slice(7).trim();
    } else {
      token = authHeader.trim();
    }

    if (!token || token === '') {
      return res.status(401).json({ message: 'No token, authorization denied' });
    }

    // Verify token
    const decoded = jwt.verify(token, JWT_SECRET);
    
    // Add user info to request object
    req.user = decoded;
    
    // Log successful authentication (optional, remove in production)
    console.log(`Authenticated user: ${decoded.userId}, role: ${decoded.role}`);
    
    next();
  } catch (error) {
    console.error('Auth middleware error:', error);
    
    // Handle specific JWT errors
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ message: 'Invalid token format' });
    } else if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ message: 'Token has expired, please login again' });
    } else if (error.name === 'NotBeforeError') {
      return res.status(401).json({ message: 'Token not active yet' });
    } else {
      return res.status(401).json({ message: 'Token verification failed' });
    }
  }
};