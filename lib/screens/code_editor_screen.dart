import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:labassistant/models/excercise_model.dart';
import 'package:labassistant/services/api_services.dart';
import 'package:labassistant/services/socket_services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/test_result_model.dart';

class DarkAppColors {
  static const Color primaryColor = Color(0xFF26BDCF);
  static const Color secondaryColor = Color(0xFF1E1E1E);
  static const Color scaffoldBgLightColor = Color(0xFF121212);
  static const Color scaffoldWorkOutBgDarkColor = Color(0xFF2D2D2D);
  static const Color ThemeRedColor = Color(0xFFEE4443);
  static const Color ThemeGreenColor = Color(0xFF23C45E);
  static const Color ThemelightGreenColor = Color(0xFFA8CC12);
  static const Color tipsBgColor = Color(0xFF1A2B2E);
  static const Color tipsBorderColor = Color(0xFF26BDCF);
  static const Color titleColor = Color(0xFFE0E0E0);
  static const Color subTitleColor = Color(0xFF8D8D8D);
}

class LightAppColors {
  static const Color primaryColor = Color(0xFF1976D2);
  static const Color secondaryColor = Color(0xFFFFFFFF);
  static const Color scaffoldBgLightColor = Color(0xFFF5F5F5);
  static const Color scaffoldWorkOutBgDarkColor = Color(0xFFE0E0E0);
  static const Color ThemeRedColor = Color(0xFFE53935);
  static const Color ThemeGreenColor = Color(0xFF43A047);
  static const Color ThemelightGreenColor = Color(0xFF7CB342);
  static const Color tipsBgColor = Color(0xFFE3F2FD);
  static const Color tipsBorderColor = Color(0xFF1976D2);
  static const Color titleColor = Color(0xFF212121);
  static const Color subTitleColor = Color(0xFF757575);
}

class CodeEditorScreen extends StatefulWidget {
  final Exercise exercise;

  const CodeEditorScreen({super.key, required this.exercise});

  @override
  State<CodeEditorScreen> createState() => _CodeEditorScreenState();
}

class _CodeEditorScreenState extends State<CodeEditorScreen> with TickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  final ScrollController _outputScrollController = ScrollController();
  final FocusNode _codeFocusNode = FocusNode();
  late TabController _tabController;
  
  List<TestResult> testResults = [];
  bool isRunning = false;
  bool isSubmitting = false;
  bool showResults = false;
  int? score;
  bool _isDarkMode = true;
  bool _hasUnsavedChanges = false;
  late Stopwatch _stopwatch;
  
  String outputText = '';
  bool hasCompilationError = false;
  String statusMessage = 'Ready';

  // Theme Getters
  Color get primaryColor => _isDarkMode ? DarkAppColors.primaryColor : LightAppColors.primaryColor;
  Color get secondaryColor => _isDarkMode ? DarkAppColors.secondaryColor : LightAppColors.secondaryColor;
  Color get scaffoldBgColor => _isDarkMode ? DarkAppColors.scaffoldBgLightColor : LightAppColors.scaffoldBgLightColor;
  Color get titleColor => _isDarkMode ? DarkAppColors.titleColor : LightAppColors.titleColor;
  Color get subTitleColor => _isDarkMode ? DarkAppColors.subTitleColor : LightAppColors.subTitleColor;
  Color get tipsBgColor => _isDarkMode ? DarkAppColors.tipsBgColor : LightAppColors.tipsBgColor;
  Color get tipsBorderColor => _isDarkMode ? DarkAppColors.tipsBorderColor : LightAppColors.tipsBorderColor;
  Color get workoutBgColor => _isDarkMode ? DarkAppColors.scaffoldWorkOutBgDarkColor : LightAppColors.scaffoldWorkOutBgDarkColor;
  Color get greenColor => _isDarkMode ? DarkAppColors.ThemeGreenColor : LightAppColors.ThemeGreenColor;
  Color get lightGreenColor => _isDarkMode ? DarkAppColors.ThemelightGreenColor : LightAppColors.ThemelightGreenColor;
  Color get redColor => _isDarkMode ? DarkAppColors.ThemeRedColor : LightAppColors.ThemeRedColor;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _stopwatch = Stopwatch()..start();
    _initializeCodeEditor();
    _codeController.addListener(() {
      if (!_hasUnsavedChanges) setState(() => _hasUnsavedChanges = true);
    });
  }

  void _initializeCodeEditor() {
    // Simple initialization with just the comment
    _codeController.text = '// Write your code here';
    
    // Set cursor to end of the comment
    _codeController.selection = TextSelection.fromPosition(
      TextPosition(offset: _codeController.text.length),
    );
    
    _updateOutput('Ready to compile and run your C code...\n');
    _updateOutput('Problem: ${widget.exercise.title}\n');
    _updateOutput('Visible Test Cases: ${widget.exercise.testCases.length}\n');
    _updateOutput('${"=" * 50}\n');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    _outputScrollController.dispose();
    _codeFocusNode.dispose();
    _stopwatch.stop();
    super.dispose();
  }

  void _updateOutput(String message) {
    setState(() {
      outputText += message;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_outputScrollController.hasClients) {
        _outputScrollController.animateTo(
          _outputScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearOutput() {
    setState(() {
      outputText = '';
      hasCompilationError = false;
      showResults = false;
      testResults.clear();
    });
  }

  Future<void> _runTestCases() async {
    _clearOutput();
    
    setState(() {
      isRunning = true;
      statusMessage = 'Running Visible Test Cases...';
    });

    _updateOutput('=== RUNNING VISIBLE TEST CASES ===\n');
    _updateOutput('Testing against ${widget.exercise.testCases.length} visible test cases only...\n');
    _updateOutput('(Hidden test cases will be evaluated during final submission)\n\n');

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final socketService = Provider.of<SocketService>(context, listen: false);
      final apiService = ApiService(authService);

      socketService.socket?.emit('code-execution', {
        'exerciseId': widget.exercise.id,
        'code': _codeController.text,
        'timestamp': DateTime.now().toIso8601String(),
        'action': 'test_run_visible_only'
      });

      final result = await apiService.runTestCases(
        widget.exercise.id,
        _codeController.text,
      );

      if (result['compilationSuccess'] == false) {
        setState(() {
          hasCompilationError = true;
          statusMessage = 'Compilation Failed';
        });
        
        _updateOutput('COMPILATION ERROR:\n');
        _updateOutput('${result['compilationError']}\n\n');
        _updateOutput('Please fix the compilation errors and try again.\n');
        return;
      }

      setState(() {
        statusMessage = 'Visible Test Cases Completed';
      });

      _updateOutput('Compilation successful! ✅\n\n');
      _updateOutput('=== VISIBLE TEST RESULTS ===\n');

      if (result['results'] != null && result['results'].isNotEmpty) {
        setState(() {
          testResults = result['results']
              .map<TestResult>((r) => TestResult.fromJson(r))
              .toList();
          showResults = true;
        });

        for (int i = 0; i < testResults.length; i++) {
          final testResult = testResults[i];
          _updateOutput('\nVisible Test ${i + 1}:\n');
          _updateOutput('Input: ${testResult.input.isEmpty ? "(no input)" : testResult.input}\n');
          _updateOutput('Expected: ${testResult.expected}\n');
          _updateOutput('Your Output: ${testResult.actual}\n');
          _updateOutput('Result: ${testResult.passed ? "PASS ✅" : "FAIL ❌"}\n');
          
          if (!testResult.passed) {
            _updateOutput('💡 Tip: Check your logic for this input case.\n');
          }
          
          _updateOutput('${"=" * 40}\n');
        }

        final passedCount = testResults.where((r) => r.passed).length;
        _updateOutput('\n=== VISIBLE TEST SUMMARY ===\n');
        _updateOutput('Visible Tests Passed: $passedCount/${testResults.length}\n');
        
        if (passedCount == testResults.length) {
          _updateOutput('\n🎉 All visible test cases passed!\n');
          _updateOutput('✨ Great work! You\'re ready for final submission.\n');
          _updateOutput('⚠️ Remember: Final submission includes hidden test cases too.\n');
        } else {
          _updateOutput('\n⚠️ Some visible tests failed.\n');
          _updateOutput('💪 Fix the issues and try again before final submission.\n');
        }
      }

    } catch (e) {
      setState(() {
        hasCompilationError = true;
        statusMessage = 'Error';
      });
      
      _updateOutput('ERROR:\n');
      _updateOutput('$e\n');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: redColor,
          ),
        );
      }
    } finally {
      setState(() => isRunning = false);
    }
  }

  Future<void> _submitSolution() async {
    _clearOutput();
    
    // Show confirmation dialog for final submission
    final bool? confirmSubmit = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _isDarkMode ? DarkAppColors.secondaryColor : Colors.white,
          title: Text('Final Submission', style: TextStyle(color: titleColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you ready to submit your solution?',
                style: TextStyle(color: titleColor),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ Important:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Your code will be tested against ALL test cases (visible + hidden)\n'
                      '• You can see results for visible test cases only\n'
                      '• Hidden test case results won\'t be shown\n'
                      '• This submission will be recorded',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: greenColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (confirmSubmit != true) return;
    
    setState(() {
      isSubmitting = true;
      statusMessage = 'Submitting Final Solution...';
    });

    _updateOutput('=== FINAL SUBMISSION ===\n');
    _updateOutput('Running complete evaluation...\n');
    _updateOutput('• Testing visible test cases (results shown)\n');
    _updateOutput('• Testing hidden test cases (results not shown)\n\n');

    _stopwatch.stop();
    final timeTakenSeconds = _stopwatch.elapsed.inSeconds;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final socketService = Provider.of<SocketService>(context, listen: false);
      final apiService = ApiService(authService);

      socketService.socket?.emit('code-execution', {
        'exerciseId': widget.exercise.id,
        'code': _codeController.text,
        'timestamp': DateTime.now().toIso8601String(),
        'action': 'final_submission_all_tests',
        'timeTaken': timeTakenSeconds
      });

      final result = await apiService.submitCode(
        widget.exercise.id,
        _codeController.text,
      );

      if (result['compilationSuccess'] == false) {
        setState(() {
          hasCompilationError = true;
          statusMessage = 'Submission Failed - Compilation Error';
        });
        
        _updateOutput('COMPILATION ERROR:\n');
        _updateOutput('${result['compilationError']}\n\n');
        _updateOutput('❌ Your code has compilation errors.\n');
        _updateOutput('Please fix them and try again.\n');
        return;
      }

      setState(() {
        score = result['score'];
        showResults = true;
        statusMessage = result['passed'] ? 'All Tests Passed!' : 'Some Tests Failed';
      });

      _updateOutput('Compilation successful! ✅\n\n');
      
      // Show visible test case results
      if (result['results'] != null && result['results'].isNotEmpty) {
        setState(() {
          testResults = result['results']
              .map<TestResult>((r) => TestResult.fromJson(r))
              .toList();
        });

        _updateOutput('=== VISIBLE TEST RESULTS ===\n');
        for (int i = 0; i < testResults.length; i++) {
          final testResult = testResults[i];
          _updateOutput('Visible Test ${i + 1}: ${testResult.passed ? "PASS ✅" : "FAIL ❌"}\n');
          if (!testResult.passed) {
            _updateOutput('  Input: ${testResult.input}\n');
            _updateOutput('  Expected: ${testResult.expected}\n');
            _updateOutput('  Your Output: ${testResult.actual}\n');
          }
        }
      }

      final visiblePassed = testResults.where((r) => r.passed).length;
      final visibleTotal = testResults.length;

      _updateOutput('\n=== FINAL SUBMISSION RESULTS ===\n');
      _updateOutput('Overall Score: ${result['score']}%\n');
      _updateOutput('Time Taken: ${_formatTime(timeTakenSeconds)}\n');
      _updateOutput('Visible Tests: $visiblePassed/$visibleTotal passed\n');

      if (result['debug'] != null) {
        final debug = result['debug'];
        final hiddenPassed = debug['hiddenTestsPassed'] ?? 0;
        final hiddenTotal = debug['hiddenTestsTotal'] ?? 0;
        
        _updateOutput('Hidden Tests: $hiddenPassed/$hiddenTotal passed\n');
      }

      _updateOutput('\nStatus: ${result['passed'] ? "ACCEPTED ✅" : "NEEDS IMPROVEMENT ❌"}\n');

      if (result['passed']) {
        _updateOutput('\n🎉 CONGRATULATIONS!\n');
        _updateOutput('✨ All test cases (visible + hidden) passed!\n');
        _updateOutput('🏆 Perfect solution!\n');
        _showSuccessDialog(result['score'], timeTakenSeconds);
      } else {
        if (visiblePassed == visibleTotal) {
          _updateOutput('\n⚠️ All visible test cases passed, but some hidden test cases failed.\n');
          _updateOutput('🔍 Your solution works for the shown examples but may have edge cases.\n');
          _updateOutput('💡 Consider different input scenarios and boundary conditions.\n');
        } else {
          _updateOutput('\n⚠️ Some visible test cases failed.\n');
          _updateOutput('🔧 Review the failing test cases above and fix your logic.\n');
        }
        _showPartialSuccessDialog(
          result['score'],
          visiblePassed,
          visibleTotal,
          timeTakenSeconds
        );
      }

      setState(() => _hasUnsavedChanges = false);

    } catch (e) {
      setState(() {
        hasCompilationError = true;
        statusMessage = 'Submission Error';
      });
      
      _updateOutput('SUBMISSION ERROR:\n');
      _updateOutput('$e\n');
      _updateOutput('\n❌ There was an error processing your submission.\n');
      _updateOutput('Please try again or contact support if the issue persists.\n');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission Error: $e'),
            backgroundColor: redColor,
          ),
        );
      }
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  void _toggleTheme() => setState(() => _isDarkMode = !_isDarkMode);

  void _showSuccessDialog(int finalScore, int timeTaken) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDarkMode ? DarkAppColors.secondaryColor : Colors.white,
        title: Row(
          children: [
            Icon(Icons.celebration, color: greenColor, size: 28),
            const SizedBox(width: 8),
            Text('Perfect Score!', style: TextStyle(color: titleColor)),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: greenColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: greenColor.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🎉 Congratulations!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: greenColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You have successfully completed:\n"${widget.exercise.title}"',
                style: TextStyle(color: titleColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text('Score', style: TextStyle(color: subTitleColor, fontSize: 12)),
                      Text('$finalScore%', style: TextStyle(color: greenColor, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('Time', style: TextStyle(color: subTitleColor, fontSize: 12)),
                      Text(_formatTime(timeTaken), style: TextStyle(color: titleColor, fontSize: 16)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '✅ All visible test cases passed\n✅ All hidden test cases passed',
                style: TextStyle(color: greenColor, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: greenColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue')
          )
        ],
      ),
    );
  }

  void _showPartialSuccessDialog(int finalScore, int visiblePassed, int visibleTotal, int timeTaken) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDarkMode ? DarkAppColors.secondaryColor : Colors.white,
        title: Row(
          children: [
            Icon(Icons.feedback, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Text('Keep Trying!', style: TextStyle(color: titleColor)),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Submission Results',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text('Score', style: TextStyle(color: subTitleColor, fontSize: 12)),
                      Text('$finalScore%', style: TextStyle(
                        color: finalScore >= 70 ? greenColor : Colors.orange,
                        fontSize: 20, 
                        fontWeight: FontWeight.bold
                      )),
                    ],
                  ),
                  Column(
                    children: [
                      Text('Time', style: TextStyle(color: subTitleColor, fontSize: 12)),
                      Text(_formatTime(timeTaken), style: TextStyle(color: titleColor, fontSize: 16)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text('Visible Tests', style: TextStyle(color: subTitleColor, fontSize: 12)),
                      Text(
                        '$visiblePassed/$visibleTotal',
                        style: TextStyle(
                          color: visiblePassed == visibleTotal ? greenColor : redColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text('Hidden Tests', style: TextStyle(color: subTitleColor, fontSize: 12)),
                      Text(
                        'Some Failed',
                        style: TextStyle(
                          color: redColor,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (visiblePassed == visibleTotal)
                Text(
                  '✅ All visible tests passed\n❌ Some hidden tests failed\n\n💡 Consider edge cases and boundary conditions',
                  style: TextStyle(color: titleColor, fontSize: 12),
                  textAlign: TextAlign.center,
                )
              else
                Text(
                  '❌ Some visible tests failed\n❌ Some hidden tests failed\n\n🔧 Review your logic and try again',
                  style: TextStyle(color: titleColor, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(foregroundColor: primaryColor),
            child: const Text('Try Again')
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBgColor,
      appBar: AppBar(
        title: Text(
          widget.exercise.title,
          style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
        ),
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: _isDarkMode ? Colors.white : Colors.black),
        actions: [
          if (score != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: score! >= 70 ? greenColor : Colors.orange,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Score: $score%',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            onPressed: _toggleTheme,
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: secondaryColor,
            child: TabBar(
              controller: _tabController,
              labelColor: primaryColor,
              unselectedLabelColor: subTitleColor,
              indicatorColor: primaryColor,
              tabs: const [
                Tab(text: 'Problem'),
                Tab(text: 'Code Editor'),
              ],
            ),
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProblemTab(),
                _buildCodeEditorTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemTab() {
    return Container(
      color: scaffoldBgColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.exercise.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 16),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tipsBgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tipsBorderColor),
              ),
              child: Text(
                widget.exercise.description,
                style: TextStyle(
                  fontSize: 16,
                  color: titleColor,
                  height: 1.5,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            Text(
              'Input Format:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: workoutBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.exercise.inputFormat ?? 'No input format specified',
                style: const TextStyle(
                  fontSize: 14, 
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            Text(
              'Output Format:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: workoutBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.exercise.outputFormat ?? 'No output format specified',
                style: const TextStyle(
                  fontSize: 14, 
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            Text(
              'Constraints:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: workoutBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.exercise.constraints ?? 'No constraints specified',
                style: const TextStyle(
                  fontSize: 14, 
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Visible Test Cases:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 12),
            
            // Display only visible test cases
            ...widget.exercise.testCases.asMap().entries.map((entry) {
              int index = entry.key;
              var testCase = entry.value;
              
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: workoutBgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primaryColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Case ${index + 1}:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        children: [
                          const TextSpan(
                            text: 'Input: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                          TextSpan(
                            text: testCase.input.isEmpty ? '(no input)' : testCase.input,
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        children: [
                          const TextSpan(
                            text: 'Expected Output: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                          TextSpan(
                            text: testCase.expectedOutput,
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            
            const SizedBox(height: 20),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primaryColor.withOpacity(0.3)),
              ),
              child: Text(
                'Visible Test Cases: ${widget.exercise.testCases.length}',
                style: TextStyle(
                  fontSize: 14,
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Important Notes:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• These are visible test cases for practice and debugging\n'
                    '• Your final submission will be tested against additional hidden test cases\n'
                    '• Hidden test cases validate edge cases and boundary conditions\n'
                    '• Ensure your solution handles all possible valid inputs',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeEditorTab() {
    return Container(
      color: scaffoldBgColor,
      child: Column(
        children: [
          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            color: secondaryColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  statusMessage,
                  style: TextStyle(
                    color: hasCompilationError ? redColor : titleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: (isRunning || isSubmitting) ? null : _runTestCases,
                      icon: isRunning 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                      label: const Text('Test Visible'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: (isRunning || isSubmitting) ? null : _submitSolution,
                      icon: isSubmitting 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send),
                      label: const Text('Final Submit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: greenColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Code editor
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primaryColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'C Code Editor',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        if (_hasUnsavedChanges)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Unsaved',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _codeController,
                      focusNode: _codeFocusNode,
                      maxLines: null,
                      expands: true,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.all(16),
                        border: InputBorder.none,
                        hintText: 'Start typing your C code...',
                        hintStyle: TextStyle(color: Colors.grey),
                        filled: false,
                      ),
                      inputFormatters: [
                        // Allow all text input including backspace
                        FilteringTextInputFormatter.allow(RegExp(r'[\s\S]*')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Output area
          if (outputText.isNotEmpty)
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primaryColor.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: hasCompilationError ? redColor : primaryColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            hasCompilationError ? 'Compilation Error' : 'Output',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _clearOutput,
                            child: const Text(
                              'Clear',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        child: SingleChildScrollView(
                          controller: _outputScrollController,
                          child: SelectableText(
                            outputText,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.white,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}