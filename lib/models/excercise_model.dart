// lib/models/exercise_model.dart - Fixed version with better JSON parsing
import 'dart:convert';

class Exercise {
  final int id;
  final String title;
  final String description;
  final String difficultyLevel;
  final List<TestCase> testCases;
  final List<TestCase>? hiddenTestCases;
  final DateTime? createdAt;
  final String? problemStatement;
  final String? inputFormat;
  final String? outputFormat;
  final String? constraints;
  final String? sampleInput;
  final String? sampleOutput;
  final String? explanation;

  Exercise({
    required this.id,
    required this.title,
    required this.description,
    required this.difficultyLevel,
    required this.testCases,
    this.hiddenTestCases,
    this.createdAt,
    this.problemStatement,
    this.inputFormat,
    this.outputFormat,
    this.constraints,
    this.sampleInput,
    this.sampleOutput,
    this.explanation,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    try {
      print('=== PARSING EXERCISE ===');
      print('Raw JSON: $json');
      print('=== CHECKING SPECIFIC FIELDS ===');
      print('inputFormat field: ${json['inputFormat']}');
      print('input_format field: ${json['input_format']}');
      print('outputFormat field: ${json['outputFormat']}');
      print('output_format field: ${json['output_format']}');
      print('constraints field: ${json['constraints']}');
      
      // Parse test cases with multiple fallback strategies
      List<TestCase> testCases = [];
      
      // Try different field names and parsing strategies
      dynamic testCasesData = json['testCases'] ?? json['test_cases'];
      
      print('Test cases raw data: $testCasesData');
      print('Test cases type: ${testCasesData.runtimeType}');
      
      if (testCasesData != null) {
        if (testCasesData is String) {
          // If it's a string, try to parse as JSON
          try {
            final decoded = jsonDecode(testCasesData);
            if (decoded is List) {
              testCases = decoded
                  .map((tc) => TestCase.fromJson(tc as Map<String, dynamic>))
                  .toList();
            }
          } catch (e) {
            print('Error parsing test cases from string: $e');
          }
        } else if (testCasesData is List) {
          // If it's already a list, use it directly
          testCases = testCasesData
              .map((tc) {
                if (tc is Map<String, dynamic>) {
                  return TestCase.fromJson(tc);
                } else if (tc is String) {
                  try {
                    return TestCase.fromJson(jsonDecode(tc));
                  } catch (e) {
                    print('Error parsing individual test case: $e');
                    return null;
                  }
                }
                return null;
              })
              .where((tc) => tc != null)
              .cast<TestCase>()
              .toList();
        }
      }
      
      print('Parsed test cases count: ${testCases.length}');
      for (int i = 0; i < testCases.length; i++) {
        print('Test case $i: input="${testCases[i].input}", output="${testCases[i].expectedOutput}"');
      }

      // Parse hidden test cases (optional)
      List<TestCase>? hiddenTestCases;
      dynamic hiddenTestCasesData = json['hiddenTestCases'] ?? json['hidden_test_cases'];
      
      if (hiddenTestCasesData != null) {
        if (hiddenTestCasesData is String) {
          try {
            final decoded = jsonDecode(hiddenTestCasesData);
            if (decoded is List) {
              hiddenTestCases = decoded
                  .map((tc) => TestCase.fromJson(tc as Map<String, dynamic>))
                  .toList();
            }
          } catch (e) {
            print('Error parsing hidden test cases from string: $e');
          }
        } else if (hiddenTestCasesData is List) {
          hiddenTestCases = hiddenTestCasesData
              .map((tc) {
                if (tc is Map<String, dynamic>) {
                  return TestCase.fromJson(tc);
                } else if (tc is String) {
                  try {
                    return TestCase.fromJson(jsonDecode(tc));
                  } catch (e) {
                    return null;
                  }
                }
                return null;
              })
              .where((tc) => tc != null)
              .cast<TestCase>()
              .toList();
        }
      }

      // Parse created_at safely
      DateTime? createdAt;
      if (json['createdAt'] != null) {
        createdAt = DateTime.tryParse(json['createdAt'].toString());
      } else if (json['created_at'] != null) {
        createdAt = DateTime.tryParse(json['created_at'].toString());
      }

      return Exercise(
        id: json['id'] as int,
        title: json['title']?.toString() ?? 'Untitled Exercise',
        description: json['description']?.toString() ?? 
                    json['problemStatement']?.toString() ?? 
                    json['problem_statement']?.toString() ?? 
                    'No description available',
        difficultyLevel: json['difficultyLevel']?.toString() ?? 
                        json['difficulty_level']?.toString() ?? 
                        'Medium',
        testCases: testCases,
        hiddenTestCases: hiddenTestCases,
        createdAt: createdAt,
        problemStatement: json['problemStatement']?.toString() ?? 
                         json['problem_statement']?.toString(),
        inputFormat: json['inputFormat']?.toString() ?? 
                    json['input_format']?.toString(),
        outputFormat: json['outputFormat']?.toString() ?? 
                     json['output_format']?.toString(),
        constraints: json['constraints']?.toString(),
        sampleInput: json['sampleInput']?.toString() ?? 
                    json['sample_input']?.toString(),
        sampleOutput: json['sampleOutput']?.toString() ?? 
                     json['sample_output']?.toString(),
        explanation: json['explanation']?.toString(),
      );
    } catch (e, stackTrace) {
      print('Error parsing Exercise from JSON: $e');
      print('Stack trace: $stackTrace');
      print('JSON data: $json');
      
      // Return a default exercise in case of parsing error
      return Exercise(
        id: json['id'] as int? ?? 0,
        title: json['title']?.toString() ?? 'Untitled Exercise',
        description: json['description']?.toString() ?? 'No description available',
        difficultyLevel: 'Medium',
        testCases: [],
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'difficultyLevel': difficultyLevel,
      'testCases': testCases.map((tc) => tc.toJson()).toList(),
      'hiddenTestCases': hiddenTestCases?.map((tc) => tc.toJson()).toList(),
      'createdAt': createdAt?.toIso8601String(),
      'problemStatement': problemStatement,
      'inputFormat': inputFormat,
      'outputFormat': outputFormat,
      'constraints': constraints,
      'sampleInput': sampleInput,
      'sampleOutput': sampleOutput,
      'explanation': explanation,
    };
  }
}

class TestCase {
  final String input;
  final String expectedOutput;

  TestCase({
    required this.input,
    required this.expectedOutput,
  });

  factory TestCase.fromJson(Map<String, dynamic> json) {
    return TestCase(
      input: json['input']?.toString() ?? '',
      expectedOutput: json['expectedOutput']?.toString() ?? 
                     json['expected_output']?.toString() ?? 
                     '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'input': input,
      'expected_output': expectedOutput,
    };
  }
}