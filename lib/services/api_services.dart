// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:labassistant/models/excercise_model.dart';
import '../models/subject_model.dart';
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
      
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/admin/exercises'),
        headers: authService.authHeaders,
        body: json.encode(exerciseData),
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