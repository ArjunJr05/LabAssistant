// Test each module individually to find the problematic one
console.log('Testing individual modules...');

const modules = [
  'express',
  'http', 
  'socket.io',
  'cors',
  'path',
  'fs-extra',
  './config/database',
  './routes/auth',
  './routes/admin', 
  './routes/student',
  './routes/exercises',
  './routes/malpractice'
];

async function testModules() {
  for (const moduleName of modules) {
    try {
      console.log(`Testing: ${moduleName}...`);
      const module = require(moduleName);
      console.log(`✅ ${moduleName} loaded successfully`);
    } catch (error) {
      console.error(`❌ Failed to load ${moduleName}:`);
      console.error(`   Error: ${error.message}`);
      console.error(`   Stack: ${error.stack}`);
      process.exit(1);
    }
  }
  console.log('🎉 All modules loaded successfully!');
}

testModules();
