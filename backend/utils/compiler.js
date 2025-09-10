// utils/compiler.js - Debug version with better error detection
const { spawn, exec } = require('child_process');
const fs = require('fs-extra');
const path = require('path');
const os = require('os');
const { promisify } = require('util');

const execAsync = promisify(exec);

// Path to MinGW GCC compiler
const MINGW_PATH = 'C:\\mingw64\\bin\\gcc.exe';

async function executeCode(code, testCases) {
  const tempDir = os.tmpdir();
  const timestamp = Date.now();
  const random = Math.random().toString(36).substring(2, 8);
  
  const fileName = `program_${timestamp}_${random}.c`;
  const execName = `program_${timestamp}_${random}.exe`;
  const filePath = path.join(tempDir, fileName);
  const executablePath = path.join(tempDir, execName);

  try {
    console.log('=== DEBUGGING COMPILATION ENVIRONMENT ===');
    
    // 1. Check if MinGW exists
    console.log('Checking MinGW path:', MINGW_PATH);
    const mingwExists = await fs.pathExists(MINGW_PATH);
    console.log('MinGW exists:', mingwExists);
    
    if (!mingwExists) {
      // Try alternative paths
      const alternativePaths = [
        'C:\\mingw64\\bin\\gcc.exe',
        'C:\\MinGW\\bin\\gcc.exe',
        'C:\\msys64\\mingw64\\bin\\gcc.exe',
        'C:\\Program Files\\mingw64\\bin\\gcc.exe'
      ];
      
      for (const altPath of alternativePaths) {
        if (await fs.pathExists(altPath)) {
          console.log('Found GCC at alternative path:', altPath);
          break;
        }
      }
      
      throw new Error(`GCC compiler not found at ${MINGW_PATH}. Please install MinGW-w64 or update the path.`);
    }

    // 2. Test GCC version
    try {
      const { stdout } = await execAsync(`"${MINGW_PATH}" --version`);
      console.log('GCC version check successful:', stdout.split('\n')[0]);
    } catch (versionError) {
      console.error('GCC version check failed:', versionError.message);
      throw new Error('GCC is installed but not working correctly. Check your MinGW installation.');
    }

    // 3. Validate and log the code
    console.log('=== CODE VALIDATION ===');
    console.log('Code length:', code.length);
    console.log('Code content:');
    console.log('---START---');
    console.log(code);
    console.log('---END---');
    
    // Basic code validation
    if (!code.includes('main')) {
      throw new Error('Code must contain a main function');
    }
    
    if (!code.includes('#include')) {
      console.warn('Warning: Code does not include any header files');
    }

    // 4. Write code to file with better error handling
    try {
      await fs.writeFile(filePath, code, 'utf8');
      console.log('Code written to file:', filePath);
      
      // Verify file was written
      const writtenContent = await fs.readFile(filePath, 'utf8');
      if (writtenContent !== code) {
        throw new Error('File content mismatch after writing');
      }
    } catch (writeError) {
      throw new Error(`Failed to write code to file: ${writeError.message}`);
    }

    // 5. Compile with detailed logging
    console.log('=== COMPILATION ===');
    const compilationResult = await compileCodeDetailed(filePath, executablePath);
    
    if (!compilationResult.success) {
      return {
        compilationSuccess: false,
        compilationError: compilationResult.error,
        results: []
      };
    }

    // 6. Verify executable
    const execExists = await fs.pathExists(executablePath);
    console.log('Executable created:', execExists);
    
    if (!execExists) {
      throw new Error('Compilation reported success but executable was not created');
    }

    // 7. Test executable with a simple run
    try {
      console.log('Testing executable...');
      const testRun = await runExecutableWithInput(executablePath, '', 2000); // 2 second timeout for test
      console.log('Test run successful, output length:', testRun.length);
    } catch (testError) {
      console.error('Test run failed:', testError.message);
      // Continue anyway, might be input-dependent
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
        console.log('Execution time:', executionTime, 'ms');
        
        const passed = output.trim() === testCase.expected_output.trim();
        console.log('Test passed:', passed);

        const result = {
          input: testCase.input || '',
          expected: testCase.expected_output,
          actual: output.trim(),
          passed: passed,
          execution_time: executionTime
        };

        results.push(result);
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
    console.error('Error type:', error.constructor.name);
    console.error('Error message:', error.message);
    console.error('Stack trace:', error.stack);
    
    return {
      compilationSuccess: false,
      compilationError: error.message,
      results: []
    };
  } finally {
    // Cleanup
    await cleanupFiles(filePath, executablePath);
  }
}

function compileCodeDetailed(filePath, executablePath) {
  return new Promise((resolve) => {
    console.log('Starting detailed compilation...');
    console.log('Command: gcc', [filePath, '-o', executablePath, '-std=c99', '-Wall']);
    
    const gcc = spawn(MINGW_PATH, [
      filePath, 
      '-o', 
      executablePath,
      '-std=c99',
      '-Wall',
      '-Wextra',
      '-v' // Verbose output for debugging
    ], {
      cwd: path.dirname(filePath),
      stdio: ['pipe', 'pipe', 'pipe'],
      env: { ...process.env, PATH: path.dirname(MINGW_PATH) + ';' + process.env.PATH }
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
      console.log('Final stdout length:', stdout.length);
      console.log('Final stderr length:', stderr.length);

      if (code !== 0) {
        let errorMessage = 'Compilation failed';
        
        if (stderr) {
          errorMessage = parseCompilationError(stderr);
        } else if (stdout) {
          errorMessage = `Compilation failed with output: ${stdout}`;
        } else {
          errorMessage = `Compilation failed with exit code ${code} but no error output`;
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
      console.error('GCC process error:', error);
      resolve({
        success: false,
        error: `Failed to start GCC: ${error.message}`
      });
    });

    // Set a timeout for compilation
    setTimeout(() => {
      gcc.kill();
      resolve({
        success: false,
        error: 'Compilation timed out after 30 seconds'
      });
    }, 30000);
  });
}

function parseCompilationError(stderr) {
  console.log('Parsing compilation error from stderr:', stderr);
  
  // Remove verbose output and focus on actual errors
  const lines = stderr.split('\n');
  const errorLines = lines.filter(line => 
    line.includes('error:') || 
    line.includes('fatal error:') ||
    (line.includes('warning:') && line.includes('error'))
  );
  
  if (errorLines.length > 0) {
    return errorLines.join('\n');
  }
  
  // If no specific errors found, return cleaned stderr
  return stderr.replace(/^#.*$/gm, '').trim() || 'Unknown compilation error';
}

function runExecutableWithInput(executablePath, input, timeout = 5000) {
  return new Promise((resolve, reject) => {
    console.log(`Running executable: ${executablePath}`);
    console.log(`Input: ${JSON.stringify(input)}`);
    console.log(`Timeout: ${timeout}ms`);

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
      
      console.log(`Program finished with exit code: ${code}`);
      console.log(`Output length: ${stdout.length}`);
      
      if (stderr) {
        console.log(`Error output: ${stderr}`);
      }
      
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
      console.error('Child process error:', error);
      reject(new Error(`Failed to run program: ${error.message}`));
    });

    // Send input
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
      console.error('Cleanup error for', file, ':', e.message);
    }
  }
}

module.exports = { executeCode };