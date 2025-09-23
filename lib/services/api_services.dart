// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:labassistant/models/excercise_model.dart';
import '../models/subject_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'config_service.dart';

class ApiService {
  final AuthService authService;
  String? _cachedBaseUrl;

  ApiService(this.authService);

  Future<String> get baseUrl async {
    _cachedBaseUrl ??= await ConfigService.getApiBaseUrl();
    return _cachedBaseUrl!;
  }

  // Debug method to test database connection and content
  Future<Map<String, dynamic>> debugDatabase() async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/exercises/debug/database'),
        headers: authService.authHeaders,
      );

      print('Debug response status: ${response.statusCode}');
      print('Debug response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get debug info: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching debug info: $e');
      throw Exception('Error fetching debug info: $e');
    }
  }

  // Get online users
  Future<List<User>> getOnlineUsers() async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/admin/online-users'),
        headers: authService.authHeaders,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((user) => User.fromJson(user)).toList();
      } else {
        print('Failed to fetch online users: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching online users: $e');
      return [];
    }
  }

  // Admin shutdown notification method
  Future<bool> sendAdminShutdownNotification() async {
    try {
      print('🚨 Sending admin shutdown notification...');
      
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/admin/shutdown-notification'),
        headers: authService.authHeaders,
      );

      print('Shutdown notification response status: ${response.statusCode}');
      print('Shutdown notification response body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Shutdown notification sent successfully');
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. Admin privileges required.');
      } else {
        print('❌ Failed to send shutdown notification: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending shutdown notification: $e');
      return false;
    }
  }

  // Seed sample data for testing
  Future<bool> seedSampleData() async {
    try {
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/exercises/debug/seed'),
        headers: authService.authHeaders,
      );

      print('Seed response status: ${response.statusCode}');
      print('Seed response body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('Error seeding data: $e');
      return false;
    }
  }

  Future<List<Subject>> getSubjects() async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/exercises/subjects'),
        headers: authService.authHeaders,
      );

      print('Subjects response status: ${response.statusCode}');
      print('Subjects response body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        
        // Handle null response
        if (data == null) {
          print('Received null response for subjects');
          return [];
        }
        
        if (data is List) {
          return data
              .map((json) => Subject.fromJson(json as Map<String, dynamic>))
              .toList();
        } else if (data is Map && data.containsKey('subjects')) {
          // Handle wrapped response
          final subjects = data['subjects'];
          if (subjects is List) {
            return subjects
                .map((json) => Subject.fromJson(json as Map<String, dynamic>))
                .toList();
          }
        } else {
          print('Expected List but got: ${data.runtimeType}');
          print('Data content: $data');
          return [];
        }
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        print('HTTP Error ${response.statusCode}: ${response.body}');
        throw Exception('Failed to load subjects: ${response.statusCode}');
      }
      
      return [];
    } catch (e) {
      print('Error fetching subjects: $e');
      if (e.toString().contains('Authentication')) {
        rethrow;
      }
      // Return empty list instead of throwing to prevent app crashes
      return [];
    }
  }

  Future<List<Exercise>> getExercisesBySubject(int subjectId) async {
    try {
      print('Fetching exercises for subject ID: $subjectId');
      
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/exercises/subject/$subjectId'),
        headers: authService.authHeaders,
      );

      print('Exercises response status: ${response.statusCode}');
      print('Exercises response body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        
        if (data == null) {
          print('Received null response for exercises');
          return [];
        }

        if (data is List) {
          final exercises = <Exercise>[];
          for (final item in data) {
            try {
              if (item is Map<String, dynamic>) {
                exercises.add(Exercise.fromJson(item));
              } else {
                print('Invalid exercise item: $item');
              }
            } catch (e) {
              print('Error parsing exercise: $e');
              print('Exercise data: $item');
            }
          }
          return exercises;
        } else if (data is Map) {
          print('Received Map instead of List: $data');
          // Check if it's an error response
          if (data.containsKey('message') || data.containsKey('error')) {
            print('Error from server: ${data['message'] ?? data['error']}');
          }
          return [];
        } else {
          print('Expected List but got: ${data.runtimeType}');
          print('Data content: $data');
          return [];
        }
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 404) {
        print('Subject not found or no exercises available');
        return [];
      } else {
        print('HTTP Error ${response.statusCode}: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching exercises: $e');
      if (e.toString().contains('Authentication')) {
        rethrow;
      }
      return [];
    }
  }

  Future<Exercise?> getExercise(int exerciseId) async {
    try {
      print('=== FETCHING EXERCISE $exerciseId ===');
      
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/exercises/$exerciseId'),
        headers: authService.authHeaders,
      );

      print('Exercise response status: ${response.statusCode}');
      print('Exercise response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Decoded exercise data: $data');
        
        if (data is Map<String, dynamic>) {
          final exercise = Exercise.fromJson(data);
          print('Successfully parsed exercise: ${exercise.title}');
          print('Test cases count: ${exercise.testCases.length}');
          
          return exercise;
        } else {
          print('Expected Map but got: ${data.runtimeType}');
          return null;
        }
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 404) {
        throw Exception('Exercise not found');
      } else {
        throw Exception('Failed to load exercise: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching exercise: $e');
      if (e.toString().contains('Authentication') || 
          e.toString().contains('not found')) {
        rethrow;
      }
      return null;
    }
  }

  Future<bool> deleteExercise(int exerciseId) async {
    try {
      print('🗑️ DELETE EXERCISE ATTEMPT');
      print('Exercise ID: $exerciseId');
      final url = await baseUrl;
      print('URL: $url/admin/exercises/$exerciseId');
      print('Headers: ${authService.authHeaders}');
      
      final response = await http.delete(
        Uri.parse('$url/admin/exercises/$exerciseId'),
        headers: authService.authHeaders,
      );

      print('🌐 DELETE Response Status: ${response.statusCode}');
      print('🌐 DELETE Response Headers: ${response.headers}');
      print('🌐 DELETE Response Body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Exercise deleted successfully');
        return true;
      } else if (response.statusCode == 401) {
        print('❌ Authentication failed');
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        print('❌ Access denied');
        throw Exception('Access denied. Admin privileges required.');
      } else if (response.statusCode == 404) {
        print('❌ Exercise not found');
        throw Exception('Exercise not found.');
      } else {
        print('❌ Unknown error');
        try {
          final errorData = json.decode(response.body);
          throw Exception('Failed to delete exercise: ${errorData['message'] ?? response.body}');
        } catch (e) {
          throw Exception('Failed to delete exercise: ${response.body}');
        }
      }
    } catch (e) {
      print('💥 Error deleting exercise: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> runTestCases(int exerciseId, String code) async {
    try {
      print('Running test cases for exercise $exerciseId');
      print('Code length: ${code.length} characters');
      
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/exercises/$exerciseId/test'),
        headers: authService.authHeaders,
        body: json.encode({
          'code': code,
          'testOnly': true // Flag to run only visible test cases
        }),
      );

      print('Test run response status: ${response.statusCode}');
      print('Test run response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          return data;
        } else {
          throw Exception('Invalid response format');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        final errorData = json.decode(response.body);
        throw Exception('Failed to run test cases: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('Error running test cases: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> submitCode(int exerciseId, String code) async {
    try {
      print('Submitting code for exercise $exerciseId');
      print('Code length: ${code.length} characters');
      
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/exercises/$exerciseId/submit'),
        headers: authService.authHeaders,
        body: json.encode({
          'code': code,
          'finalSubmission': true // Flag for final submission
        }),
      );

      print('Submit response status: ${response.statusCode}');
      print('Submit response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          return data;
        } else {
          throw Exception('Invalid response format');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        final errorData = json.decode(response.body);
        throw Exception('Failed to submit code: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('Error submitting code: $e');
      rethrow;
    }
  }

  Future<bool> markExerciseCompleted(int exerciseId) async {
  try {
    print('🔄 Marking exercise $exerciseId as completed via API');
    
    final url = await baseUrl;
    final response = await http.post(
      Uri.parse('$url/student/mark-completed'),
      headers: authService.authHeaders,
      body: json.encode({
        'exerciseId': exerciseId,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );

    print('Mark completed response status: ${response.statusCode}');
    print('Mark completed response body: ${response.body}');

    if (response.statusCode == 200) {
      print('✅ Exercise $exerciseId marked as completed successfully');
      return true;
    } else if (response.statusCode == 401) {
      throw Exception('Authentication failed. Please login again.');
    } else {
      print('❌ Failed to mark exercise as completed: ${response.statusCode}');
      return false;
    }
  } catch (e) {
    print('❌ Error marking exercise as completed: $e');
    return false;
  }
}

  // NEW METHOD: Remove completion status (for testing purposes)
  Future<bool> unmarkExerciseCompleted(int exerciseId) async {
    try {
      print('🔄 Removing completion status for exercise $exerciseId');
      
      final url = await baseUrl;
      final response = await http.delete(
        Uri.parse('$url/student/complete-exercise/$exerciseId'),
        headers: authService.authHeaders,
      );

      print('Unmark completed response status: ${response.statusCode}');
      print('Unmark completed response body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Exercise completion status removed successfully');
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 404) {
        // Exercise was not completed - this is still a success
        print('ℹ️ Exercise was not marked as completed');
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception('Failed to remove completion status: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('❌ Error removing completion status: $e');
      rethrow;
    }
  }

  // Enhanced getCompletedExercises method to handle different response formats
@override
Future<List<Map<String, dynamic>>> getCompletedExercises() async {
  try {
    final url = await baseUrl;
    final response = await http.get(
      Uri.parse('$url/student/completed-exercises'),
      headers: authService.authHeaders,
    );

    print('Completed exercises response status: ${response.statusCode}');
    print('Completed exercises response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      List<Map<String, dynamic>> completedExercises = [];
      
      if (data is List) {
        // Handle direct array response
        for (var item in data) {
          if (item is Map<String, dynamic>) {
            completedExercises.add(item);
          }
        }
      } else if (data is Map<String, dynamic>) {
        // Handle wrapped response
        if (data.containsKey('completedExercises')) {
          final exercises = data['completedExercises'];
          if (exercises is List) {
            for (var item in exercises) {
              if (item is Map<String, dynamic>) {
                completedExercises.add(item);
              }
            }
          }
        } else if (data.containsKey('exercises')) {
          final exercises = data['exercises'];
          if (exercises is List) {
            for (var item in exercises) {
              if (item is Map<String, dynamic>) {
                completedExercises.add(item);
              }
            }
          }
        }
      }
      
      print('Processed completed exercises: ${completedExercises.length} items');
      for (var exercise in completedExercises) {
        print('  - Exercise ID: ${exercise['exercise_id']}, Status: ${exercise['status']}, Score: ${exercise['score']}');
      }
      
      return completedExercises;
    } else if (response.statusCode == 401) {
      throw Exception('Authentication failed. Please login again.');
    } else {
      throw Exception('Failed to load completed exercises: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching completed exercises: $e');
    if (e.toString().contains('Authentication')) {
      rethrow;
    }
    return [];
  }
}

  // ENHANCED METHOD: Check if specific exercise is completed
  Future<bool> isExerciseCompleted(int exerciseId) async {
    try {
      print('🔄 Checking if exercise $exerciseId is completed');
      
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/student/exercise-completion/$exerciseId'),
        headers: authService.authHeaders,
      );

      print('Exercise completion check response status: ${response.statusCode}');
      print('Exercise completion check response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final isCompleted = data['is_completed'] == true || data['isCompleted'] == true;
        print('✅ Exercise $exerciseId completion status: $isCompleted');
        return isCompleted;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 404) {
        print('ℹ️ Exercise completion status not found, assuming not completed');
        return false;
      } else {
        print('❌ HTTP Error ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error checking exercise completion status: $e');
      if (e.toString().contains('Authentication')) {
        rethrow;
      }
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getStudentSubmissions() async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/student/submissions'),
        headers: authService.authHeaders,
      );

      print('Submissions response status: ${response.statusCode}');
      print('Submissions response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('submissions')) {
          final submissions = data['submissions'];
          if (submissions is List) {
            return List<Map<String, dynamic>>.from(submissions);
          }
        }
        return [];
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception('Failed to load submissions: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching submissions: $e');
      if (e.toString().contains('Authentication')) {
        rethrow;
      }
      return [];
    }
  }

  Future<Map<String, dynamic>> getAdminAnalytics() async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/admin/analytics'),
        headers: authService.authHeaders,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. Admin privileges required.');
      } else {
        throw Exception('Failed to load analytics: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching analytics: $e');
      rethrow;
    }
  }

  Future<bool> createExercise(Map<String, dynamic> exerciseData) async {
    try {
      print('Creating exercise with data: $exerciseData');
      
      // Create a clean copy of the data with proper serialization
      final cleanedData = <String, dynamic>{};
      exerciseData.forEach((key, value) {
        if (value == null) {
          cleanedData[key] = null;
        } else if (value is List) {
          // Handle lists (like test_cases and hidden_test_cases)
          cleanedData[key] = value.map((item) {
            if (item is Map<String, dynamic>) {
              // Already a proper map, use as-is
              return item;
            } else if (item is Map) {
              // Convert to proper map
              return Map<String, dynamic>.from(item);
            }
            return item;
          }).toList();
        } else if (value is Map<String, dynamic>) {
          // Already a proper map, use as-is
          cleanedData[key] = value;
        } else if (value is Map) {
          // Convert to proper map
          cleanedData[key] = Map<String, dynamic>.from(value);
        } else {
          // Primitive values
          cleanedData[key] = value;
        }
      });
      
      print('Cleaned exercise data: $cleanedData');
      
      // Validate that test cases are properly formatted
      if (cleanedData['test_cases'] is List) {
        print('Test cases count: ${(cleanedData['test_cases'] as List).length}');
        for (int i = 0; i < (cleanedData['test_cases'] as List).length; i++) {
          final testCase = (cleanedData['test_cases'] as List)[i];
          print('Test case $i: $testCase (type: ${testCase.runtimeType})');
        }
      }
      
      if (cleanedData['hidden_test_cases'] is List) {
        print('Hidden test cases count: ${(cleanedData['hidden_test_cases'] as List).length}');
        for (int i = 0; i < (cleanedData['hidden_test_cases'] as List).length; i++) {
          final testCase = (cleanedData['hidden_test_cases'] as List)[i];
          print('Hidden test case $i: $testCase (type: ${testCase.runtimeType})');
        }
      }
      
      final jsonBody = json.encode(cleanedData);
      print('JSON body to send: $jsonBody');
      
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/admin/exercises'),
        headers: {
          ...authService.authHeaders,
          'Content-Type': 'application/json',
        },
        body: jsonBody,
      );

      print('Create exercise response status: ${response.statusCode}');
      print('Create exercise response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. Admin privileges required.');
      } else {
        final errorData = json.decode(response.body);
        throw Exception('Failed to create exercise: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('Error creating exercise: $e');
      rethrow;
    }
  }

  Future<bool> updateExercise(int exerciseId, Map<String, dynamic> exerciseData) async {
    try {
      print('Updating exercise $exerciseId with data: $exerciseData');
      
      final url = await baseUrl;
      final response = await http.put(
        Uri.parse('$url/admin/exercises/$exerciseId'),
        headers: authService.authHeaders,
        body: json.encode(exerciseData),
      );

      print('Update exercise response status: ${response.statusCode}');
      print('Update exercise response body: ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. Admin privileges required.');
      } else if (response.statusCode == 404) {
        throw Exception('Exercise not found.');
      } else {
        final errorData = json.decode(response.body);
        throw Exception('Failed to update exercise: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('Error updating exercise: $e');
      rethrow;
    }
  }

  Future<bool> createSubject(Map<String, dynamic> subjectData) async {
    try {
      print('Creating subject with data: $subjectData');
      
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/admin/subjects'),
        headers: authService.authHeaders,
        body: json.encode(subjectData),
      );

      print('Create subject response status: ${response.statusCode}');
      print('Create subject response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. Admin privileges required.');
      } else {
        final errorData = json.decode(response.body);
        throw Exception('Failed to create subject: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('Error creating subject: $e');
      rethrow;
    }
  }

  Future<bool> deleteSubject(int subjectId) async {
    try {
      print('🗑️ DELETE SUBJECT ATTEMPT');
      print('Subject ID: $subjectId');
      final url = await baseUrl;
      print('URL: $url/admin/subjects/$subjectId');
      print('Headers: ${authService.authHeaders}');
      
      final response = await http.delete(
        Uri.parse('$url/admin/subjects/$subjectId'),
        headers: authService.authHeaders,
      );

      print('🌐 DELETE Subject Response Status: ${response.statusCode}');
      print('🌐 DELETE Subject Response Headers: ${response.headers}');
      print('🌐 DELETE Subject Response Body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Subject deleted successfully');
        return true;
      } else if (response.statusCode == 401) {
        print('❌ Authentication failed');
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        print('❌ Access denied');
        throw Exception('Access denied. Admin privileges required.');
      } else if (response.statusCode == 404) {
        print('❌ Subject not found');
        throw Exception('Subject not found.');
      } else {
        print('❌ Unknown error');
        try {
          final errorData = json.decode(response.body);
          throw Exception('Failed to delete subject: ${errorData['message'] ?? response.body}');
        } catch (e) {
          throw Exception('Failed to delete subject: ${response.body}');
        }
      }
    } catch (e) {
      print('💥 Error deleting subject: $e');
      rethrow;
    }
  }

  // Get last submission for an exercise
  Future<Map<String, dynamic>?> getLastSubmission(int exerciseId) async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/student/last-submission/$exerciseId'),
        headers: authService.authHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['hasSubmission'] == true) {
          return data['submission'];
        }
        return null;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception('Failed to load last submission: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching last submission: $e');
      if (e.toString().contains('Authentication')) {
        rethrow;
      }
      return null;
    }
  }

  // Admin: Get student exercises with completion status
  Future<List<Map<String, dynamic>>> getStudentExercises(int studentId) async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/admin/student-exercises/$studentId'),
        headers: authService.authHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        return [];
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. Admin privileges required.');
      } else {
        throw Exception('Failed to load student exercises: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching student exercises: $e');
      rethrow;
    }
  }

  // Admin: Get student progress for specific exercise
  Future<Map<String, dynamic>> getStudentProgress(int studentId, int exerciseId) async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/admin/student-progress/$studentId/$exerciseId'),
        headers: authService.authHeaders,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. Admin privileges required.');
      } else {
        throw Exception('Failed to load student progress: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching student progress: $e');
      rethrow;
    }
  }

  // Admin: Get all student activities
  Future<List<Map<String, dynamic>>> getStudentActivities(int studentId) async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/admin/student-activities/$studentId'),
        headers: authService.authHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        return [];
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. Admin privileges required.');
      } else {
        throw Exception('Failed to load student activities: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching student activities: $e');
      rethrow;
    }
  }

  // Malpractice detection methods
  Future<bool> checkMalpracticeStatus(int exerciseId) async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/malpractice/check/$exerciseId'),
        headers: authService.authHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['blocked'] ?? false;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied.');
      } else {
        return false; // Default to not blocked if there's an error
      }
    } catch (e) {
      print('Error checking malpractice status: $e');
      return false; // Default to not blocked if there's an error
    }
  }

  Future<List<Map<String, dynamic>>> getMalpracticeHistory(int exerciseId) async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/malpractice/history/$exerciseId'),
        headers: authService.authHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        return [];
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. Admin privileges required.');
      } else {
        throw Exception('Failed to load malpractice history: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching malpractice history: $e');
      rethrow;
    }
  }

  Future<bool> logMalpractice(int exerciseId, String type, String description, int count) async {
    try {
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/malpractice/log'),
        headers: authService.authHeaders,
        body: json.encode({
          'exerciseId': exerciseId,
          'type': type,
          'description': description,
          'count': count,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Malpractice logged successfully');
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        print('Error logging malpractice: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error logging malpractice: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getMalpracticeIncidents() async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/malpractice/incidents'),
        headers: authService.authHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        return [];
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. Admin privileges required.');
      } else {
        throw Exception('Failed to load malpractice incidents: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching malpractice incidents: $e');
      rethrow;
    }
  }

  Future<bool> unblockStudent(int studentId, int exerciseId) async {
    try {
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/malpractice/unblock'),
        headers: authService.authHeaders,
        body: json.encode({
          'studentId': studentId,
          'exerciseId': exerciseId,
        }),
      );

      if (response.statusCode == 200) {
        print('Student unblocked successfully');
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. Admin privileges required.');
      } else {
        print('Error unblocking student: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error unblocking student: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> trackTabSwitch(int exerciseId) async {
    try {
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/malpractice/tab-switch'),
        headers: authService.authHeaders,
        body: json.encode({
          'exerciseId': exerciseId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Tab switch tracked: ${data['tabSwitches']} switches, malpractice: ${data['malpractice']}');
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied.');
      } else {
        throw Exception('Failed to track tab switch: ${response.statusCode}');
      }
    } catch (e) {
      print('Error tracking tab switch: $e');
      rethrow;
    }
  }

  // Helper method to check API connectivity
  Future<bool> checkConnectivity() async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/health'),
        headers: authService.authHeaders,
      ).timeout(Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Connectivity check failed: $e');
      return false;
    }
  }

  // Get malpractice exercises for current user
  Future<List<Map<String, dynamic>>> getMalpracticeExercises() async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/student/malpractice-exercises'),
        headers: authService.authHeaders,
      );

      print('Malpractice exercises response status: ${response.statusCode}');
      print('Malpractice exercises response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        List<Map<String, dynamic>> malpracticeExercises = [];
        
        if (data is List) {
          // Handle direct array response
          for (var item in data) {
            if (item is Map<String, dynamic>) {
              malpracticeExercises.add(item);
            }
          }
        } else if (data is Map<String, dynamic>) {
          // Handle wrapped response
          if (data.containsKey('malpracticeExercises')) {
            final exercises = data['malpracticeExercises'];
            if (exercises is List) {
              for (var item in exercises) {
                if (item is Map<String, dynamic>) {
                  malpracticeExercises.add(item);
                }
              }
            }
          }
        }
        
        print('Processed malpractice exercises: ${malpracticeExercises.length} items');
        return malpracticeExercises;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception('Failed to load malpractice exercises: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching malpractice exercises: $e');
      if (e.toString().contains('Authentication')) {
        rethrow;
      }
      return [];
    }
  }

  // Update tab switch count for malpractice tracking
  Future<bool> updateTabSwitch(int exerciseId, int switchCount) async {
    try {
      print('Updating tab switch count for exercise $exerciseId: $switchCount');
      
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/student/update-tab-switch'),
        headers: authService.authHeaders,
        body: json.encode({
          'exerciseId': exerciseId,
          'switchCount': switchCount,
        }),
      );

      print('Update tab switch response status: ${response.statusCode}');
      print('Update tab switch response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Tab switch count updated: ${data['message']}');
        return data['success'] == true;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        final errorData = json.decode(response.body);
        throw Exception('Failed to update tab switch: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('Error updating tab switch count: $e');
      rethrow;
    }
  }

  // Helper method to retry failed requests
  Future<T> retryRequest<T>(Future<T> Function() request, {int maxRetries = 3}) async {
    int retryCount = 0;
    
    while (retryCount < maxRetries) {
      try {
        return await request();
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          rethrow;
        }
        
        print('Request failed, retrying ($retryCount/$maxRetries): $e');
        await Future.delayed(Duration(seconds: retryCount));
      }
    }
    
    throw Exception('Max retries exceeded');
  }
}