// utils/compiler.js - Fixed version with proper error handling and Windows MinGW support
const { spawn, exec } = require('child_process');
const fs = require('fs-extra');
const path = require('path');
const os = require('os');
const { promisify } = require('util');

const execAsync = promisify(exec);

// Update this path to match your actual MinGW location
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

    // Write code to file with UTF-8 encoding
    try {
      await fs.writeFile(filePath, code, 'utf8');
      console.log('Code written to file:', filePath);
      
      // Verify file exists and has content
      const fileExists = await fs.pathExists(filePath);
      const fileStats = await fs.stat(filePath);
      console.log('File created successfully:', fileExists, 'Size:', fileStats.size, 'bytes');
      
      // Read back and verify content
      const readBack = await fs.readFile(filePath, 'utf8');
      console.log('File content verification - matches:', readBack === code);
    } catch (writeError) {
      throw new Error(`Failed to write code to file: ${writeError.message}`);
    }

    // Compile using exec for better error capture
    console.log('=== COMPILATION ===');
    const compilationResult = await compileCodeWithExec(filePath, executablePath);
    
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
        
        const actualOutput = (output || '').toString().trim();
        console.log('Actual output:', JSON.stringify(actualOutput));
        
        const passed = actualOutput === (testCase.expected_output || '').trim();
        console.log('Test passed:', passed);

        results.push({
          input: testCase.input || '',
          expected: testCase.expected_output || '',
          actual: actualOutput,
          passed: passed,
          execution_time: executionTime
        });
      } catch (error) {
        console.error(`Test case ${i + 1} failed:`, error.message);
        results.push({
          input: testCase.input || '',
          expected: testCase.expected_output || '',
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

// New compilation function using exec for better error capture
async function compileCodeWithExec(filePath, executablePath) {
  console.log('Starting compilation with exec...');
  
  // Use quotes around paths to handle spaces
  const command = `"${MINGW_PATH}" "${filePath}" -o "${executablePath}" -std=c99 -Wall`;
  console.log('Command:', command);
  
  try {
    const { stdout, stderr } = await execAsync(command, {
      cwd: path.dirname(filePath),
      timeout: 30000,
      encoding: 'utf8'
    });
    
    console.log('Compilation stdout:', stdout || '(empty)');
    console.log('Compilation stderr:', stderr || '(empty)');
    
    // Check if executable was created
    const execExists = await fs.pathExists(executablePath);
    console.log('Executable created:', execExists);
    
    if (execExists) {
      return {
        success: true,
        message: 'Compilation successful'
      };
    } else {
      // If no executable but no error, something went wrong
      const errorMsg = stderr || stdout || 'Compilation failed - no executable created and no error output';
      return {
        success: false,
        error: errorMsg
      };
    }
    
  } catch (error) {
    console.error('Compilation failed with error:', error);
    
    // Extract meaningful error message
    let errorMessage = 'Compilation failed';
    
    if (error.stderr) {
      errorMessage = error.stderr;
    } else if (error.stdout) {
      errorMessage = error.stdout;
    } else if (error.message) {
      errorMessage = error.message;
    }
    
    // Clean up error message for common GCC errors
    if (errorMessage.includes('error:')) {
      // Extract just the error lines
      const lines = errorMessage.split('\n');
      const errorLines = lines.filter(line => 
        line.includes('error:') || 
        line.includes('warning:') ||
        line.includes('note:') ||
        (line.includes(':') && (line.includes('.c:') || line.includes('undefined')))
      );
      
      if (errorLines.length > 0) {
        errorMessage = errorLines.join('\n');
      }
    }
    
    return {
      success: false,
      error: errorMessage
    };
  }
}

// Keep the original spawn version as fallback
function compileCodeWithSpawn(filePath, executablePath) {
  return new Promise((resolve) => {
    console.log('Starting compilation with spawn...');
    console.log('Command: gcc', [filePath, '-o', executablePath, '-std=c99', '-Wall']);
    
    const gcc = spawn(MINGW_PATH, [
      filePath, 
      '-o', 
      executablePath,
      '-std=c99',
      '-Wall'
    ], {
      cwd: path.dirname(filePath),
      stdio: ['pipe', 'pipe', 'pipe'],
      windowsHide: true // Hide window on Windows
    });

    let stdout = '';
    let stderr = '';

    gcc.stdout.on('data', (data) => {
      const chunk = data.toString('utf8');
      stdout += chunk;
      console.log('GCC stdout:', chunk);
    });

    gcc.stderr.on('data', (data) => {
      const chunk = data.toString('utf8');
      stderr += chunk;
      console.log('GCC stderr:', chunk);
    });

    gcc.on('close', (code) => {
      console.log('GCC process closed with code:', code);
      console.log('Full stdout:', stdout || '(empty)');
      console.log('Full stderr:', stderr || '(empty)');

      if (code !== 0) {
        // Combine both stdout and stderr for error analysis
        const allOutput = (stderr + stdout).trim();
        let errorMessage = 'Compilation failed';
        
        if (allOutput) {
          errorMessage = allOutput;
        } else {
          errorMessage = `Compilation failed with exit code ${code}. No compiler output received.`;
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
    console.log(`Running executable: ${executablePath}`);
    console.log(`Input: ${JSON.stringify(input)}`);
    
    const child = spawn(executablePath, [], {
      cwd: path.dirname(executablePath),
      stdio: ['pipe', 'pipe', 'pipe'],
      windowsHide: true
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
      stdout += data.toString('utf8');
    });

    child.stderr.on('data', (data) => {
      stderr += data.toString('utf8');
    });

    child.on('close', (code) => {
      if (finished) return;
      finished = true;
      clearTimeout(timer);
      
      console.log(`Program exited with code: ${code}`);
      console.log(`Program stdout: ${JSON.stringify(stdout)}`);
      console.log(`Program stderr: ${JSON.stringify(stderr)}`);
      
      if (code !== 0) {
        reject(new Error(`Program exited with code ${code}${stderr ? ': ' + stderr : ''}`));
      } else {
        resolve(stdout || '');
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

// Test function to verify MinGW setup
async function testMinGWSetup() {
  try {
    console.log('=== TESTING MINGW SETUP ===');
    
    const { stdout, stderr } = await execAsync(`"${MINGW_PATH}" --version`);
    console.log('MinGW version test successful:', stdout.split('\n')[0]);
    
    // Test simple compilation
    const testCode = '#include <stdio.h>\nint main(){printf("Hello World");return 0;}';
    const testFile = path.join(os.tmpdir(), 'mingw_test.c');
    const testExe = path.join(os.tmpdir(), 'mingw_test.exe');
    
    await fs.writeFile(testFile, testCode);
    
    const compileCmd = `"${MINGW_PATH}" "${testFile}" -o "${testExe}"`;
    await execAsync(compileCmd);
    
    const runResult = await execAsync(`"${testExe}"`);
    console.log('Test program output:', runResult.stdout);
    
    // Cleanup
    await fs.unlink(testFile).catch(() => {});
    await fs.unlink(testExe).catch(() => {});
    
    return { success: true, message: 'MinGW setup verified successfully' };
    
  } catch (error) {
    console.error('MinGW test failed:', error);
    return { success: false, error: error.message };
  }
}

module.exports = { 
  executeCode, 
  testMinGWSetup 
};