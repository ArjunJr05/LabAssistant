// lib/models/test_result_model.dart
class TestResult {
  final String input;
  final String expected;
  final String actual;
  final bool passed;
  final Duration? executionTime;

  TestResult({
    required this.input,
    required this.expected,
    required this.actual,
    required this.passed,
    this.executionTime,
  });

  factory TestResult.fromJson(Map<String, dynamic> json) {
    return TestResult(
      input: json['input']?.toString() ?? '',
      expected: json['expected']?.toString() ?? 
               json['expected_output']?.toString() ?? '',
      actual: json['actual']?.toString() ?? 
              json['output']?.toString() ?? 
              json['user_output']?.toString() ?? '',
      passed: json['passed'] == true || json['success'] == true,
      executionTime: json['execution_time'] != null 
          ? Duration(milliseconds: (json['execution_time'] * 1000).round())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'input': input,
      'expected': expected,
      'actual': actual,
      'passed': passed,
      'execution_time': executionTime?.inMilliseconds,
    };
  }

  @override
  String toString() {
    return 'TestResult(input: $input, expected: $expected, actual: $actual, passed: $passed)';
  }
}