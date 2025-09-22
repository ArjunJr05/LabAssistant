// utils/compiler.js - Simple version with fixed MinGW path
const { spawn, exec } = require('child_process');
const fs = require('fs-extra');
const path = require('path');
const os = require('os');
const { promisify } = require('util');

const execAsync = promisify(exec);

// Fixed MinGW path as requested
const MINGW_PATH = 'C:\\Users\\user\\LabAssistant\\MinGW\\bin\\gcc.exe';

async function executeCode(code, testCases) {
  const tempDir = os.tmpdir();
  const timestamp = Date.now();
  const random = Math.random().toString(36).substring(2, 8);
  
  const fileName = `program_${timestamp}_${random}.c`;
  const execName = `program_${timestamp}_${random}.exe`;
  const filePath = path.join(tempDir, fileName);
  const executablePath = path.join(tempDir, execName);

  try {
    console.log('=== USING MINGW COMPILER ===');
    console.log('MinGW path:', MINGW_PATH);
    
    // Check if MinGW exists
    const mingwExists = await fs.pathExists(MINGW_PATH);
    console.log('MinGW exists:', mingwExists);
    if (!mingwExists) {
      throw new Error(`GCC compiler not found at ${MINGW_PATH}. Please ensure MinGW is installed at this location.`);
    }

    // Test GCC version
    try {
      const { stdout } = await execAsync(`"${MINGW_PATH}" --version`);
      console.log('GCC version test successful:', stdout.split('\n')[0]);
    } catch (versionError) {
      console.error('GCC version test failed:', versionError.message);
      throw new Error(`GCC is installed but not working correctly: ${versionError.message}`);
    }

    console.log('=== CODE VALIDATION ===');
    console.log('Code length:', code.length);
    console.log('Code content preview:', code.substring(0, 200) + (code.length > 200 ? '...' : ''));
    
    // Basic code validation
    if (!code.includes('main')) {
      throw new Error('Code must contain a main function');
    }

    // Write code to file
    try {
      await fs.writeFile(filePath, code, 'utf8');
      console.log('Code written to file:', filePath);
      
      // Verify file exists and has content
      const fileExists = await fs.pathExists(filePath);
      const fileStats = await fs.stat(filePath);
      console.log('File created successfully:', fileExists, 'Size:', fileStats.size, 'bytes');
    } catch (writeError) {
      throw new Error(`Failed to write code to file: ${writeError.message}`);
    }

    // Compile
    console.log('=== COMPILATION ===');
    const compilationResult = await compileCode(filePath, executablePath);
    
    if (!compilationResult.success) {
      return {
        compilationSuccess: false,
        compilationError: compilationResult.error,
        results: []
      };
    }

    // Verify executable was created
    const execExists = await fs.pathExists(executablePath);
    if (!execExists) {
      throw new Error('Compilation reported success but executable was not created');
    }

    console.log('=== RUNNING TEST CASES ===');
    console.log('Number of test cases:', testCases.length);

    // Run test cases
    const results = [];
    for (let i = 0; i < testCases.length; i++) {
      const testCase = testCases[i];
      try {
        console.log(`\n--- Test Case ${i + 1} ---`);
        console.log('Input:', JSON.stringify(testCase.input || ''));
        console.log('Expected:', JSON.stringify(testCase.expected_output));
        
        const startTime = Date.now();
        const output = await runExecutableWithInput(executablePath, testCase.input || '', 5000);
        const executionTime = Date.now() - startTime;
        
        console.log('Actual output:', JSON.stringify(output));
        
        const passed = output.trim() === testCase.expected_output.trim();
        console.log('Test passed:', passed);

        results.push({
          input: testCase.input || '',
          expected: testCase.expected_output,
          actual: output.trim(),
          passed: passed,
          execution_time: executionTime
        });
      } catch (error) {
        console.error(`Test case ${i + 1} failed:`, error.message);
        results.push({
          input: testCase.input || '',
          expected: testCase.expected_output,
          actual: `Runtime error: ${error.message}`,
          passed: false,
          execution_time: null
        });
      }
    }

    console.log('=== FINAL RESULTS ===');
    console.log('Total test cases:', results.length);
    console.log('Passed:', results.filter(r => r.passed).length);

    return {
      compilationSuccess: true,
      results: results
    };

  } catch (error) {
    console.error('=== EXECUTION ERROR ===');
    console.error('Error:', error.message);
    
    return {
      compilationSuccess: false,
      compilationError: error.message,
      results: []
    };
  } finally {
    // Cleanup files
    await cleanupFiles(filePath, executablePath);
  }
}

function compileCode(filePath, executablePath) {
  return new Promise((resolve) => {
    console.log('Starting compilation...');
    console.log('Command: gcc', [filePath, '-o', executablePath, '-std=c99', '-Wall']);
    
    const gcc = spawn(MINGW_PATH, [
      filePath, 
      '-o', 
      executablePath,
      '-std=c99',
      '-Wall'
    ], {
      cwd: path.dirname(filePath),
      stdio: ['pipe', 'pipe', 'pipe']
    });

    let stdout = '';
    let stderr = '';

    gcc.stdout.on('data', (data) => {
      const chunk = data.toString();
      stdout += chunk;
      console.log('GCC stdout:', chunk);
    });

    gcc.stderr.on('data', (data) => {
      const chunk = data.toString();
      stderr += chunk;
      console.log('GCC stderr:', chunk);
    });

    gcc.on('close', (code) => {
      console.log('GCC process closed with code:', code);
      console.log('Full stdout:', stdout);
      console.log('Full stderr:', stderr);

      if (code !== 0) {
        let errorMessage = 'Compilation failed';
        
        if (stderr) {
          // Try to extract meaningful error messages
          const lines = stderr.split('\n');
          const errorLines = lines.filter(line => 
            line.includes('error:') || 
            line.includes('fatal error:') ||
            line.includes('undefined reference') ||
            line.includes('ld returned')
          );
          
          if (errorLines.length > 0) {
            errorMessage = errorLines.join('\n');
          } else {
            errorMessage = stderr.trim();
          }
        }
        
        // If still generic, add more context
        if (errorMessage === 'Compilation failed' || !errorMessage) {
          errorMessage = `Compilation failed with exit code ${code}. Full output: ${stderr || stdout || 'No output'}`;
        }
        
        resolve({
          success: false,
          error: errorMessage
        });
      } else {
        resolve({
          success: true,
          message: 'Compilation successful'
        });
      }
    });

    gcc.on('error', (error) => {
      console.error('GCC spawn error:', error);
      resolve({
        success: false,
        error: `Failed to start GCC: ${error.message}. Check if MinGW is installed at ${MINGW_PATH}`
      });
    });

    // Compilation timeout
    setTimeout(() => {
      console.log('Compilation timeout reached');
      gcc.kill();
      resolve({
        success: false,
        error: 'Compilation timed out after 30 seconds'
      });
    }, 30000);
  });
}

function runExecutableWithInput(executablePath, input, timeout = 5000) {
  return new Promise((resolve, reject) => {
    const child = spawn(executablePath, [], {
      cwd: path.dirname(executablePath),
      stdio: ['pipe', 'pipe', 'pipe']
    });

    let stdout = '';
    let stderr = '';
    let finished = false;

    const timer = setTimeout(() => {
      if (!finished) {
        finished = true;
        child.kill('SIGKILL');
        reject(new Error(`Program execution timed out after ${timeout}ms`));
      }
    }, timeout);

    child.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    child.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    child.on('close', (code) => {
      if (finished) return;
      finished = true;
      clearTimeout(timer);
      
      if (code !== 0) {
        reject(new Error(`Program exited with code ${code}${stderr ? ': ' + stderr : ''}`));
      } else {
        resolve(stdout);
      }
    });

    child.on('error', (error) => {
      if (finished) return;
      finished = true;
      clearTimeout(timer);
      reject(new Error(`Failed to run program: ${error.message}`));
    });

    // Send input to program
    try {
      if (input && input.trim()) {
        child.stdin.write(input);
        if (!input.endsWith('\n')) {
          child.stdin.write('\n');
        }
      }
      child.stdin.end();
    } catch (inputError) {
      console.error('Error sending input:', inputError);
    }
  });
}

async function cleanupFiles(filePath, executablePath) {
  const files = [filePath, executablePath];
  for (const file of files) {
    try {
      if (await fs.pathExists(file)) {
        await fs.unlink(file);
        console.log('Cleaned up:', path.basename(file));
      }
    } catch (e) {
      console.error('Cleanup error:', e.message);
    }
  }
}

module.exports = { executeCode };