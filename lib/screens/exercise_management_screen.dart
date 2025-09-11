import 'package:flutter/material.dart';
import 'package:labassistant/models/excercise_model.dart';
import 'package:labassistant/services/api_services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/subject_model.dart';

class ExerciseManagementScreen extends StatefulWidget {
  const ExerciseManagementScreen({super.key});

  @override
  State<ExerciseManagementScreen> createState() => _ExerciseManagementScreenState();
}

class _ExerciseManagementScreenState extends State<ExerciseManagementScreen> {
  List<Subject> subjects = [];
  List<Exercise> exercises = [];
  Subject? selectedSubject;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() => isLoading = true);
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiService(authService);
      subjects = await apiService.getSubjects();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading subjects: $e')),
        );
      }
    }
    
    setState(() => isLoading = false);
  }

  Future<void> _loadExercises(int subjectId) async {
    setState(() => isLoading = true);
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiService(authService);
      exercises = await apiService.getExercisesBySubject(subjectId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading exercises: $e')),
        );
      }
    }
    
    setState(() => isLoading = false);
  }

  Future<void> _deleteExercise(Exercise exercise) async {
    // Show confirmation dialog
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Exercise'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to delete this exercise?'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exercise.description,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Difficulty: ${exercise.difficultyLevel}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This action cannot be undone. All student submissions for this exercise will also be deleted.',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
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
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    // If user confirmed deletion
    if (confirmDelete == true) {
      try {
        setState(() => isLoading = true);
        
        final authService = Provider.of<AuthService>(context, listen: false);
        final apiService = ApiService(authService);
        
        final success = await apiService.deleteExercise(exercise.id);
        
        if (success) {
          // Remove from local list
          setState(() {
            exercises.removeWhere((e) => e.id == exercise.id);
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Exercise "${exercise.title}" deleted successfully'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to delete exercise'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting exercise: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  void _showCreateSubjectDialog() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Subject'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Subject Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Subject Code',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty && codeController.text.isNotEmpty) {
                try {
                  final authService = Provider.of<AuthService>(context, listen: false);
                  final apiService = ApiService(authService);
                  
                  final success = await apiService.createSubject({
                    'name': nameController.text,
                    'code': codeController.text,
                  });

                  if (success) {
                    Navigator.pop(context);
                    _loadSubjects();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Subject created successfully')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating subject: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showCreateExerciseDialog() {
    if (selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a subject first')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateExerciseScreen(subject: selectedSubject!),
      ),
    ).then((_) => _loadExercises(selectedSubject!.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Subjects sidebar
                Container(
                  width: 300,
                  color: Colors.grey[100],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Text(
                              'Subjects',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: _showCreateSubjectDialog,
                              tooltip: 'Add Subject',
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: subjects.length,
                          itemBuilder: (context, index) {
                            final subject = subjects[index];
                            return ListTile(
                              title: Text(subject.name),
                              subtitle: Text(subject.code),
                              selected: selectedSubject?.id == subject.id,
                              onTap: () {
                                setState(() {
                                  selectedSubject = subject;
                                });
                                _loadExercises(subject.id);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Exercises content
                Expanded(
                  child: selectedSubject == null
                      ? const Center(
                          child: Text(
                            'Select a subject to manage exercises',
                            style: TextStyle(fontSize: 18),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Text(
                                    '${selectedSubject!.name} - Exercises',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  ElevatedButton.icon(
                                    onPressed: _showCreateExerciseDialog,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Exercise'),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: exercises.isEmpty
                                  ? const Center(
                                      child: Text('No exercises available'),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: exercises.length,
                                      itemBuilder: (context, index) {
                                        final exercise = exercises[index];
                                        return Card(
                                          child: ListTile(
                                            title: Text(exercise.title),
                                            subtitle: Text(exercise.description),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Chip(
                                                  label: Text(exercise.difficultyLevel),
                                                  backgroundColor: _getDifficultyColor(
                                                    exercise.difficultyLevel,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(Icons.edit),
                                                  onPressed: () {
                                                    // Edit exercise functionality
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('Edit functionality not implemented yet'),
                                                      ),
                                                    );
                                                  },
                                                  tooltip: 'Edit Exercise',
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete),
                                                  color: Colors.red,
                                                  onPressed: () => _deleteExercise(exercise),
                                                  tooltip: 'Delete Exercise',
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
      floatingActionButton: selectedSubject != null
          ? FloatingActionButton(
              onPressed: _showCreateExerciseDialog,
              tooltip: 'Add Exercise',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green[200]!;
      case 'medium':
        return Colors.orange[200]!;
      case 'hard':
        return Colors.red[200]!;
      default:
        return Colors.grey[200]!;
    }
  }
}

class CreateExerciseScreen extends StatefulWidget {
  final Subject subject;

  const CreateExerciseScreen({super.key, required this.subject});

  @override
  State<CreateExerciseScreen> createState() => _CreateExerciseScreenState();
}

class _CreateExerciseScreenState extends State<CreateExerciseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _inputFormatController = TextEditingController();
  final _outputFormatController = TextEditingController();
  final _constraintsController = TextEditingController();
  String _selectedDifficulty = 'medium';
  List<TestCase> _allTestCases = [];
  Set<int> _visibleTestCaseIndices = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Exercise - ${widget.subject.name}'),
        actions: [
          TextButton(
            onPressed: _saveExercise,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Exercise Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty == true ? 'Title is required' : null,
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  hintText: 'Describe what the exercise should accomplish',
                ),
                maxLines: 4,
                validator: (value) => value?.isEmpty == true ? 'Description is required' : null,
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _inputFormatController,
                decoration: const InputDecoration(
                  labelText: 'Input Format',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Two integers separated by space',
                ),
                maxLines: 2,
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _outputFormatController,
                decoration: const InputDecoration(
                  labelText: 'Output Format',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Single integer representing the sum',
                ),
                maxLines: 2,
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _constraintsController,
                decoration: const InputDecoration(
                  labelText: 'Constraints',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Input integers will be between -1000 and 1000',
                ),
                maxLines: 3,
              ),
              
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _selectedDifficulty,
                decoration: const InputDecoration(
                  labelText: 'Difficulty Level',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'easy', child: Text('Easy')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'hard', child: Text('Hard')),
                ],
                onChanged: (value) => setState(() => _selectedDifficulty = value!),
              ),
              
              const SizedBox(height: 24),
              
              Row(
                children: [
                  const Text('Test Cases', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _addTestCase,
                    child: const Text('Add Test Case'),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Test Case Visibility',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select exactly 3 test cases to be visible to students during practice. The rest will be hidden and used only for final evaluation.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              if (_allTestCases.isEmpty)
                Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'No test cases added yet.\nClick "Add Test Case" to get started.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                Container(
                  height: 400,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Test Cases (${_allTestCases.length} total, ${_visibleTestCaseIndices.length}/3 visible)',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            if (_visibleTestCaseIndices.length != 3)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Select exactly 3 visible',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '3 visible selected',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),


                      Expanded(
                        child: ListView.builder(
                          itemCount: _allTestCases.length,
                          itemBuilder: (context, index) {
                            final testCase = _allTestCases[index];
                            final isVisible = _visibleTestCaseIndices.contains(index);
                            
                            return Container(
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isVisible ? Colors.green[50] : Colors.grey[50],
                                border: Border.all(
                                  color: isVisible ? Colors.green[300]! : Colors.grey[300]!,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                leading: Checkbox(
                                  value: isVisible,
                                  onChanged: (value) => _toggleTestCaseVisibility(index, value ?? false),
                                  activeColor: Colors.green,
                                ),
                                title: Text(
                                  'Test Case ${index + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isVisible ? Colors.green[700] : Colors.grey[700],
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Input: ${testCase.input.isEmpty ? "(no input)" : testCase.input}'),
                                    Text('Expected: ${testCase.expectedOutput}'),
                                    if (isVisible)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green[200],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'VISIBLE TO STUDENTS',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'HIDDEN TEST CASE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () => _editTestCase(index),
                                      tooltip: 'Edit Test Case',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                      onPressed: () => _removeTestCase(index),
                                      tooltip: 'Delete Test Case',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleTestCaseVisibility(int index, bool isVisible) {
    setState(() {
      if (isVisible) {
        // Add to visible if less than 3 are selected
        if (_visibleTestCaseIndices.length < 3) {
          _visibleTestCaseIndices.add(index);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 3 test cases can be visible to students'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Remove from visible
        _visibleTestCaseIndices.remove(index);
      }
    });
  }

  void _addTestCase() {
    final inputController = TextEditingController();
    final outputController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Test Case'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: inputController,
              decoration: const InputDecoration(
                labelText: 'Input',
                border: OutlineInputBorder(),
                hintText: 'Enter test input (leave empty if no input needed)',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: outputController,
              decoration: const InputDecoration(
                labelText: 'Expected Output',
                border: OutlineInputBorder(),
                hintText: 'Enter expected output',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (outputController.text.isNotEmpty) {
                setState(() {
                  _allTestCases.add(TestCase(
                    input: inputController.text.trim(),
                    expectedOutput: outputController.text.trim(),
                  ));
                  
                  // Auto-select first 3 test cases as visible if less than 3 are selected
                  if (_visibleTestCaseIndices.length < 3) {
                    _visibleTestCaseIndices.add(_allTestCases.length - 1);
                  }
                });
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Expected output is required')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editTestCase(int index) {
    final testCase = _allTestCases[index];
    final inputController = TextEditingController(text: testCase.input);
    final outputController = TextEditingController(text: testCase.expectedOutput);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Test Case ${index + 1}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: inputController,
              decoration: const InputDecoration(
                labelText: 'Input',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: outputController,
              decoration: const InputDecoration(
                labelText: 'Expected Output',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (outputController.text.isNotEmpty) {
                setState(() {
                  _allTestCases[index] = TestCase(
                    input: inputController.text.trim(),
                    expectedOutput: outputController.text.trim(),
                  );
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _removeTestCase(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Test Case'),
        content: const Text('Are you sure you want to delete this test case?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _allTestCases.removeAt(index);
                // Update visible indices after removal
                Set<int> newVisibleIndices = {};
                for (int visibleIndex in _visibleTestCaseIndices) {
                  if (visibleIndex < index) {
                    newVisibleIndices.add(visibleIndex);
                  } else if (visibleIndex > index) {
                    newVisibleIndices.add(visibleIndex - 1);
                  }
                  // Skip if visibleIndex == index (the deleted one)
                }
                _visibleTestCaseIndices = newVisibleIndices;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveExercise() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_allTestCases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one test case is required')),
      );
      return;
    }

    if (_visibleTestCaseIndices.length != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select exactly 3 test cases to be visible to students'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiService(authService);

      // Separate visible and hidden test cases
      List<TestCase> visibleTestCases = [];
      List<TestCase> hiddenTestCases = [];
      
      for (int i = 0; i < _allTestCases.length; i++) {
        if (_visibleTestCaseIndices.contains(i)) {
          visibleTestCases.add(_allTestCases[i]);
        } else {
          hiddenTestCases.add(_allTestCases[i]);
        }
      }

      final success = await apiService.createExercise({
        'subject_id': widget.subject.id,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'input_format': _inputFormatController.text.isNotEmpty ? _inputFormatController.text : null,
        'output_format': _outputFormatController.text.isNotEmpty ? _outputFormatController.text : null,
        'constraints': _constraintsController.text.isNotEmpty ? _constraintsController.text : null,
        'difficulty_level': _selectedDifficulty,
        'test_cases': visibleTestCases.map((tc) => tc.toJson()).toList(),
        'hidden_test_cases': hiddenTestCases.map((tc) => tc.toJson()).toList(),
      });

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exercise created successfully!\n'
              'Visible test cases: ${visibleTestCases.length}\n'
              'Hidden test cases: ${hiddenTestCases.length}'
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating exercise: $e')),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _inputFormatController.dispose();
    _outputFormatController.dispose();
    _constraintsController.dispose();
    super.dispose();
  }
}