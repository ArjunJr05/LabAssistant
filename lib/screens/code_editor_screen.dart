import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:labassistant/models/excercise_model.dart';
import 'package:labassistant/services/api_services.dart';
import 'package:labassistant/services/socket_services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/test_result_model.dart';


class ModernAppColors {
  // Light Theme
  static const Color lightPrimary = Color(0xFF1E40AF);
  static const Color lightSecondary = Color(0xFFF8FAFC);
  static const Color lightScaffoldBg = Color(0xFFF8FAFC);
  static const Color lightCardBg = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSuccess = Color(0xFF10B981);
  static const Color lightWarning = Color(0xFFF59E0B);
  static const Color lightError = Color(0xFFEF4444);
  static const Color lightInfo = Color(0xFF3B82F6);
  static const Color lightTextPrimary = Color(0xFF1E293B);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextTertiary = Color(0xFF94A3B8);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightDivider = Color(0xFFF1F5F9);

  // Dark Theme
  static const Color darkPrimary = Color(0xFF3B82F6);
  static const Color darkSecondary = Color(0xFF1E293B);
  static const Color darkScaffoldBg = Color(0xFF0F172A);
  static const Color darkCardBg = Color(0xFF1E293B);
  static const Color darkSurface = Color(0xFF334155);
  static const Color darkSuccess = Color(0xFF10B981);
  static const Color darkWarning = Color(0xFFF59E0B);
  static const Color darkError = Color(0xFFEF4444);
  static const Color darkInfo = Color(0xFF60A5FA);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextTertiary = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF475569);
  static const Color darkDivider = Color(0xFF334155);
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
  bool _isDarkMode = false; 
  late Stopwatch _stopwatch;
  
  String outputText = '';
  bool hasCompilationError = false;
  String statusMessage = 'Ready';

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;

  // Theme Getters
  Color get primaryColor => _isDarkMode ? ModernAppColors.darkPrimary : ModernAppColors.lightPrimary;
  Color get secondaryColor => _isDarkMode ? ModernAppColors.darkSecondary : ModernAppColors.lightSecondary;
  Color get scaffoldBgColor => _isDarkMode ? ModernAppColors.darkScaffoldBg : ModernAppColors.lightScaffoldBg;
  Color get cardBgColor => _isDarkMode ? ModernAppColors.darkCardBg : ModernAppColors.lightCardBg;
  Color get surfaceColor => _isDarkMode ? ModernAppColors.darkSurface : ModernAppColors.lightSurface;
  Color get textPrimaryColor => _isDarkMode ? ModernAppColors.darkTextPrimary : ModernAppColors.lightTextPrimary;
  Color get textSecondaryColor => _isDarkMode ? ModernAppColors.darkTextSecondary : ModernAppColors.lightTextSecondary;
  Color get textTertiaryColor => _isDarkMode ? ModernAppColors.darkTextTertiary : ModernAppColors.lightTextTertiary;
  Color get borderColor => _isDarkMode ? ModernAppColors.darkBorder : ModernAppColors.lightBorder;
  Color get dividerColor => _isDarkMode ? ModernAppColors.darkDivider : ModernAppColors.lightDivider;
  Color get successColor => _isDarkMode ? ModernAppColors.darkSuccess : ModernAppColors.lightSuccess;
  Color get warningColor => _isDarkMode ? ModernAppColors.darkWarning : ModernAppColors.lightWarning;
  Color get errorColor => _isDarkMode ? ModernAppColors.darkError : ModernAppColors.lightError;
  Color get infoColor => _isDarkMode ? ModernAppColors.darkInfo : ModernAppColors.lightInfo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _stopwatch = Stopwatch()..start();
    
    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _initializeCodeEditor();
   
    _checkForPreviousSubmission();
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
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

  Future<void> _checkForPreviousSubmission() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiService(authService);
      
      final lastSubmission = await apiService.getLastSubmission(widget.exercise.id);
      
      if (lastSubmission != null) {
        setState(() {
          _codeController.text = lastSubmission['code'] ?? '// Write your code here';
          score = lastSubmission['score'];
        });
        
        _updateOutput('\n🎉 PREVIOUSLY COMPLETED EXERCISE 🎉\n');
        _updateOutput('Your submitted solution has been loaded.\n');
        _updateOutput('Score: ${lastSubmission['score']}%\n');
        _updateOutput('Submitted: ${lastSubmission['submitted_at']}\n');
        _updateOutput('Status: PASSED ✅\n');
        _updateOutput('${"=" * 50}\n');
        _updateOutput('You can view your solution or make improvements.\n\n');
        
        // Set cursor to end of loaded code
        _codeController.selection = TextSelection.fromPosition(
          TextPosition(offset: _codeController.text.length),
        );
      }
    } catch (e) {
      print('Error checking for previous submission: $e');
      // Continue with normal initialization if there's an error
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    _outputScrollController.dispose();
    _codeFocusNode.dispose();
    _fadeController.dispose();
    _slideController.dispose();
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
        _showErrorSnackBar('Error: $e');
      }
    } finally {
      setState(() => isRunning = false);
    }
  }

  Future<void> _submitSolution() async {
    _clearOutput();
    
    // Show confirmation dialog for final submission
    final bool? confirmSubmit = await _showSubmissionDialog();

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
        _showErrorSnackBar('Submission Error: $e');
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

  Future<bool?> _showSubmissionDialog() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardBgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.send_rounded, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Final Submission', style: TextStyle(color: textPrimaryColor)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you ready to submit your solution?',
                style: TextStyle(color: textPrimaryColor),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: warningColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_rounded, color: warningColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Important:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: warningColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Your code will be tested against ALL test cases (visible + hidden)\n'
                      '• You can see results for visible test cases only\n'
                      '• Hidden test case results won\'t be shown\n'
                      '• This submission will be recorded',
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondaryColor,
                        height: 1.4,
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
              child: Text('Cancel', style: TextStyle(color: textSecondaryColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: successColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(int finalScore, int timeTaken) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.celebration_rounded, color: successColor, size: 20),
            ),
            const SizedBox(width: 12),
            Text('Perfect Score!', style: TextStyle(color: textPrimaryColor)),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                successColor.withOpacity(0.1),
                successColor.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: successColor.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: successColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.emoji_events_rounded, color: successColor, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'Congratulations!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You have successfully completed:\n"${widget.exercise.title}"',
                style: TextStyle(color: textSecondaryColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text('Score', style: TextStyle(color: textTertiaryColor, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('$finalScore%', style: TextStyle(color: successColor, fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(width: 1, height: 40, color: borderColor),
                    Column(
                      children: [
                        Text('Time', style: TextStyle(color: textTertiaryColor, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(_formatTime(timeTaken), style: TextStyle(color: textPrimaryColor, fontSize: 18, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: successColor, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'All visible test cases passed',
                      style: TextStyle(color: successColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: successColor, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'All hidden test cases passed',
                      style: TextStyle(color: successColor, fontSize: 12),
                    ),
                  ),
                ],
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
              backgroundColor: successColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
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
        backgroundColor: cardBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.feedback_rounded, color: warningColor, size: 20),
            ),
            const SizedBox(width: 12),
            Text('Keep Trying!', style: TextStyle(color: textPrimaryColor)),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: warningColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: warningColor.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Submission Results',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text('Score', style: TextStyle(color: textTertiaryColor, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('$finalScore%', style: TextStyle(
                          color: finalScore >= 70 ? successColor : warningColor,
                          fontSize: 24, 
                          fontWeight: FontWeight.bold
                        )),
                      ],
                    ),
                    Container(width: 1, height: 40, color: borderColor),
                    Column(
                      children: [
                        Text('Time', style: TextStyle(color: textTertiaryColor, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(_formatTime(timeTaken), style: TextStyle(color: textPrimaryColor, fontSize: 18, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text('Visible Tests', style: TextStyle(color: textTertiaryColor, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        '$visiblePassed/$visibleTotal',
                        style: TextStyle(
                          color: visiblePassed == visibleTotal ? successColor : errorColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text('Hidden Tests', style: TextStyle(color: textTertiaryColor, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        'Some Failed',
                        style: TextStyle(
                          color: errorColor,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (visiblePassed == visibleTotal)
                Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: successColor, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'All visible tests passed',
                            style: TextStyle(color: successColor, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.cancel_rounded, color: errorColor, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Some hidden tests failed',
                            style: TextStyle(color: errorColor, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Consider edge cases and boundary conditions',
                      style: TextStyle(color: textSecondaryColor, fontSize: 12, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cancel_rounded, color: errorColor, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Some visible tests failed',
                            style: TextStyle(color: errorColor, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.cancel_rounded, color: errorColor, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Some hidden tests failed',
                            style: TextStyle(color: errorColor, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Review your logic and try again',
                      style: TextStyle(color: textSecondaryColor, fontSize: 12, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Try Again')
          )
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
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
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (score != null)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: score! >= 70 ? successColor : warningColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (score! >= 70 ? successColor : warningColor).withOpacity(0.3),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    score! >= 70 ? Icons.check_circle_rounded : Icons.info_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Score: $score%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: _toggleTheme,
              icon: Icon(
                _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: Colors.white,
              ),
              tooltip: _isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeController,
        child: Column(
          children: [
            // Modern Tab Bar
            Container(
              decoration: BoxDecoration(
                color: cardBgColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: primaryColor,
                unselectedLabelColor: textSecondaryColor,
                indicatorColor: primaryColor,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
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
      ),
    );
  }

  Widget _buildProblemTab() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(-0.3, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      )),
      child: Container(
        color: scaffoldBgColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primaryColor, primaryColor.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.2),
                      offset: const Offset(0, 4),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.assignment_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.exercise.title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Programming Exercise',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Description Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      offset: const Offset(0, 2),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: infoColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.description_rounded, color: infoColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Problem Description',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.exercise.description,
                      style: TextStyle(
                        fontSize: 16,
                        color: textSecondaryColor,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Input/Output Format Section
              Row(
                children: [
                  Expanded(
                    child: _buildFormatCard(
                      'Input Format',
                      widget.exercise.inputFormat ?? 'No input format specified',
                      Icons.input_rounded,
                      successColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFormatCard(
                      'Output Format',
                      widget.exercise.outputFormat ?? 'No output format specified',
                      Icons.output_rounded,
                      warningColor,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Constraints Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      offset: const Offset(0, 2),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: errorColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.rule_rounded, color: errorColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Constraints',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        widget.exercise.constraints ?? 'No constraints specified',
                        style: TextStyle(
                          fontSize: 14,
                          color: textSecondaryColor,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Test Cases Section
              Text(
                'Visible Test Cases',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                ),
              ),
              const SizedBox(height: 16),
              
              // Test Cases
              ...widget.exercise.testCases.asMap().entries.map((entry) {
                int index = entry.key;
                var testCase = entry.value;
                
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryColor.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.05),
                        offset: const Offset(0, 2),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Test Case ${index + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTestCaseField(
                        'Input',
                        testCase.input.isEmpty ? '(no input)' : testCase.input,
                        successColor,
                      ),
                      const SizedBox(height: 12),
                      _buildTestCaseField(
                        'Expected Output',
                        testCase.expectedOutput,
                        infoColor,
                      ),
                    ],
                  ),
                );
              }).toList(),
              
              const SizedBox(height: 20),
              
              // Info Cards
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.info_rounded, color: primaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Visible Test Cases: ${widget.exercise.testCases.length}',
                            style: TextStyle(
                              fontSize: 16,
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Use these to test and debug your solution',
                            style: TextStyle(
                              fontSize: 14,
                              color: textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatCard(String title, String content, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              content,
              style: TextStyle(
                fontSize: 14,
                color: textSecondaryColor,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCaseField(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: textSecondaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: textPrimaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeEditorTab() {
  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    )),
    child: Container(
      color: scaffoldBgColor,
      child: Column(
        children: [
          // Modern Action Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBgColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                // Status Section
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: hasCompilationError 
                              ? errorColor.withOpacity(0.1)
                              : primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          hasCompilationError 
                              ? Icons.error_rounded 
                              : Icons.code_rounded,
                          color: hasCompilationError ? errorColor : primaryColor,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusMessage,
                            style: TextStyle(
                              color: hasCompilationError ? errorColor : textPrimaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Action Buttons
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: (isRunning || isSubmitting) ? null : _runTestCases,
                      icon: isRunning 
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _isDarkMode ? Colors.white : primaryColor,
                                ),
                              ),
                            )
                          : const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Test Visible'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: (isRunning || isSubmitting) ? null : _submitSolution,
                      icon: isSubmitting 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Final Submit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: successColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Code Editor Section with Enhanced Features
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 4),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Editor Header with Tools
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.code_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        const Text(
                          'Smart C Code Editor',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        // Editor Tools
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                'Smart',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                      ],
                    ),
                  ),
                  
                  // Code Input Area with Enhanced Features
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Line Numbers
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 50,
                              decoration: BoxDecoration(
                                color: (_isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0)).withOpacity(0.3),
                                border: Border(
                                  right: BorderSide(
                                    color: borderColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: _buildLineNumbers(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Enhanced Text Editor
                          Positioned.fill(
                            left: 50,
                            child: RawKeyboardListener(
                              focusNode: FocusNode(),
                              onKey: _handleKeyPress,
                              child: TextFormField(
                                controller: _codeController,
                                focusNode: _codeFocusNode,
                                maxLines: null,
                                expands: true,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: _isDarkMode ? Colors.white : const Color(0xFF1E293B),
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.all(20),
                                  border: InputBorder.none,
                                  hintText: _getSmartHintText(),
                                  hintStyle: TextStyle(
                                    color: _isDarkMode 
                                        ? Colors.white.withOpacity(0.3)
                                        : Colors.grey.withOpacity(0.5),
                                    fontStyle: FontStyle.italic,
                                  ),
                                  filled: false,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[\s\S]*')),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          
          
          const SizedBox(height: 12),
          
          // Output Section
          if (outputText.isNotEmpty)
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      offset: const Offset(0, 4),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Output Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: hasCompilationError ? errorColor : successColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            hasCompilationError 
                                ? Icons.error_rounded 
                                : Icons.terminal_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            hasCompilationError ? 'Compilation Error' : 'Output',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: TextButton.icon(
                              onPressed: _clearOutput,
                              icon: const Icon(Icons.clear_rounded, color: Colors.white, size: 16),
                              label: const Text(
                                'Clear',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Output Content
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                        child: SingleChildScrollView(
                          controller: _outputScrollController,
                          child: SelectableText(
                            outputText,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: _isDarkMode ? Colors.white : const Color(0xFF1E293B),
                              height: 1.4,
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
    ),
  );
}

// Enhanced helper methods for smart editing
void _handleKeyPress(RawKeyEvent event) {
  if (event is RawKeyDownEvent) {
    final isShift = event.isShiftPressed;
    final isCtrl = event.isControlPressed;
    
    // Handle Enter key for smart indentation
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _handleEnterKey();
    }
    // Handle Tab key for indentation
    else if (event.logicalKey == LogicalKeyboardKey.tab && !isShift) {
      _handleTabKey();
    }
    // Handle Shift+Tab for unindent
    else if (event.logicalKey == LogicalKeyboardKey.tab && isShift) {
      _handleShiftTab();
    }
    // Handle bracket auto-completion
    else if (event.character == '{') {
      _handleOpenBrace();
    }
    else if (event.character == '(') {
      _handleOpenParen();
    }
    else if (event.character == '[') {
      _handleOpenBracket();
    }
    // Handle Ctrl+/ for comment toggle
    else if (event.logicalKey == LogicalKeyboardKey.slash && isCtrl) {
      _toggleComment();
    }
  }
}

void _handleEnterKey() {
  final text = _codeController.text;
  final selection = _codeController.selection;
  
  if (selection.baseOffset == selection.extentOffset) {
    final cursorPos = selection.baseOffset;
    final beforeCursor = text.substring(0, cursorPos);
    final afterCursor = text.substring(cursorPos);
    
    // Get current line
    final lines = beforeCursor.split('\n');
    final currentLine = lines.isNotEmpty ? lines.last : '';
    
    // Calculate indentation
    final indentation = _getLineIndentation(currentLine);
    final needsExtraIndent = currentLine.trimRight().endsWith('{') || 
                            currentLine.trimRight().endsWith('(') ||
                            currentLine.contains('if') || 
                            currentLine.contains('for') || 
                            currentLine.contains('while');
    
    // Check if we need to add closing brace
    final needsClosingBrace = currentLine.trimRight().endsWith('{') && 
                              !afterCursor.trimLeft().startsWith('}');
    
    String newText = beforeCursor + '\n';
    
    if (needsExtraIndent) {
      newText += indentation + '    '; // Add 4 spaces for indentation
    } else {
      newText += indentation;
    }
    
    if (needsClosingBrace) {
      newText += '\n' + indentation + '}';
    }
    
    newText += afterCursor;
    
    final newCursorPos = beforeCursor.length + 1 + indentation.length + (needsExtraIndent ? 4 : 0);
    
    _codeController.text = newText;
    _codeController.selection = TextSelection.collapsed(offset: newCursorPos);
  }
}

void _handleTabKey() {
  final selection = _codeController.selection;
  final text = _codeController.text;
  
  if (selection.baseOffset == selection.extentOffset) {
    // Single cursor - insert 4 spaces
    final cursorPos = selection.baseOffset;
    final newText = text.substring(0, cursorPos) + '    ' + text.substring(cursorPos);
    _codeController.text = newText;
    _codeController.selection = TextSelection.collapsed(offset: cursorPos + 4);
  } else {
    // Selection - indent selected lines
    _indentSelection(true);
  }
}

void _handleShiftTab() {
  _indentSelection(false);
}

void _handleOpenBrace() {
  final selection = _codeController.selection;
  if (selection.baseOffset == selection.extentOffset) {
    final cursorPos = selection.baseOffset;
    final text = _codeController.text;
    final beforeCursor = text.substring(0, cursorPos);
    final afterCursor = text.substring(cursorPos);
    
    // Only insert closing brace if the opening brace was just typed
    // Check if the character before cursor is '{'
    if (cursorPos > 0 && beforeCursor[cursorPos - 1] == '{') {
      // Check if next character is not already '}'
      if (afterCursor.isEmpty || afterCursor[0] != '}') {
        final newText = beforeCursor + '}' + afterCursor;
        _codeController.text = newText;
        _codeController.selection = TextSelection.collapsed(offset: cursorPos);
      }
    }
  }
}

void _handleOpenParen() {
  final selection = _codeController.selection;
  if (selection.baseOffset == selection.extentOffset) {
    final cursorPos = selection.baseOffset;
    final text = _codeController.text;
    final beforeCursor = text.substring(0, cursorPos);
    final afterCursor = text.substring(cursorPos);
    
    // Only insert closing paren if the opening paren was just typed
    if (cursorPos > 0 && beforeCursor[cursorPos - 1] == '(') {
      // Check if next character is not already ')'
      if (afterCursor.isEmpty || afterCursor[0] != ')') {
        final newText = beforeCursor + ')' + afterCursor;
        _codeController.text = newText;
        _codeController.selection = TextSelection.collapsed(offset: cursorPos);
      }
    }
  }
}

void _handleOpenBracket() {
  final selection = _codeController.selection;
  if (selection.baseOffset == selection.extentOffset) {
    final cursorPos = selection.baseOffset;
    final text = _codeController.text;
    final beforeCursor = text.substring(0, cursorPos);
    final afterCursor = text.substring(cursorPos);
    
    // Only insert closing bracket if the opening bracket was just typed
    if (cursorPos > 0 && beforeCursor[cursorPos - 1] == '[') {
      // Check if next character is not already ']'
      if (afterCursor.isEmpty || afterCursor[0] != ']') {
        final newText = beforeCursor + ']' + afterCursor;
        _codeController.text = newText;
        _codeController.selection = TextSelection.collapsed(offset: cursorPos);
      }
    }
  }
}

void _toggleComment() {
  final selection = _codeController.selection;
  final text = _codeController.text;
  final lines = text.split('\n');
  
  final startLine = _getLineNumber(selection.start);
  final endLine = _getLineNumber(selection.end);
  
  bool shouldUncomment = true;
  for (int i = startLine; i <= endLine; i++) {
    if (i < lines.length && !lines[i].trimLeft().startsWith('//')) {
      shouldUncomment = false;
      break;
    }
  }
  
  for (int i = startLine; i <= endLine; i++) {
    if (i < lines.length) {
      if (shouldUncomment) {
        lines[i] = lines[i].replaceFirst(RegExp(r'^\s*//\s?'), '');
      } else {
        final indentation = _getLineIndentation(lines[i]);
        lines[i] = lines[i].replaceFirst(RegExp(r'^\s*'), '$indentation// ');
      }
    }
  }
  
  _codeController.text = lines.join('\n');
}

String _getLineIndentation(String line) {
  final match = RegExp(r'^(\s*)').firstMatch(line);
  return match?.group(1) ?? '';
}

int _getLineNumber(int offset) {
  final text = _codeController.text;
  final beforeOffset = text.substring(0, offset);
  return beforeOffset.split('\n').length - 1;
}

void _indentSelection(bool indent) {
  final selection = _codeController.selection;
  final text = _codeController.text;
  final lines = text.split('\n');
  
  final startLine = _getLineNumber(selection.start);
  final endLine = _getLineNumber(selection.end);
  
  for (int i = startLine; i <= endLine; i++) {
    if (i < lines.length) {
      if (indent) {
        lines[i] = '    ' + lines[i];
      } else {
        lines[i] = lines[i].replaceFirst(RegExp(r'^    '), '');
      }
    }
  }
  
  _codeController.text = lines.join('\n');
}


String _getSmartHintText() {
  if (_codeController.text.trim().isEmpty || _codeController.text.trim() == '// Write your code here') {
    return '''#include <stdio.h>

int main() {
    // Your solution here
    return 0;
}

Tip: Use Ctrl+/ to toggle comments, Tab to indent''';
  }
  return 'Type your C code... (Smart features enabled)';
}


Widget _buildLineNumbers() {
  final lines = _codeController.text.split('\n');
  return Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: List.generate(lines.length.clamp(1, 1000), (index) {
      return Container(
        height: 19.6, // Match line height
        padding: const EdgeInsets.only(right: 8),
        alignment: Alignment.centerRight,
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: (_isDarkMode ? Colors.white : Colors.black).withOpacity(0.4),
          ),
        ),
      );
    }),
  );
}

Widget _buildToolbarButton(String label, IconData icon, VoidCallback onPressed) {
  return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: primaryColor.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: primaryColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _insertText(String text) {
  final selection = _codeController.selection;
  final currentText = _codeController.text;
  final cursorPos = selection.baseOffset;
  
  final newText = currentText.substring(0, cursorPos) + text + currentText.substring(cursorPos);
  _codeController.text = newText;
  _codeController.selection = TextSelection.collapsed(offset: cursorPos + text.length);
}

void _insertBraces() {
  final selection = _codeController.selection;
  final currentText = _codeController.text;
  final cursorPos = selection.baseOffset;
  
  final newText = currentText.substring(0, cursorPos) + '{}' + currentText.substring(cursorPos);
  _codeController.text = newText;
  _codeController.selection = TextSelection.collapsed(offset: cursorPos + 1);
}

void _insertParentheses() {
  final selection = _codeController.selection;
  final currentText = _codeController.text;
  final cursorPos = selection.baseOffset;
  
  final newText = currentText.substring(0, cursorPos) + '()' + currentText.substring(cursorPos);
  _codeController.text = newText;
  _codeController.selection = TextSelection.collapsed(offset: cursorPos + 1);
}

void _insertBrackets() {
  final selection = _codeController.selection;
  final currentText = _codeController.text;
  final cursorPos = selection.baseOffset;
  
  final newText = currentText.substring(0, cursorPos) + '[]' + currentText.substring(cursorPos);
  _codeController.text = newText;
  _codeController.selection = TextSelection.collapsed(offset: cursorPos + 1);
}
}