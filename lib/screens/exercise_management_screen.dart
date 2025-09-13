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

class _ExerciseManagementScreenState extends State<ExerciseManagementScreen>
    with TickerProviderStateMixin {
  List<Subject> subjects = [];
  List<Exercise> exercises = [];
  Subject? selectedSubject;
  bool isLoading = false;
  late AnimationController _fadeController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _loadSubjects();
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    setState(() => isLoading = true);
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiService(authService);
      subjects = await apiService.getSubjects();
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error loading subjects: $e');
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
        _showErrorSnackBar('Error loading exercises: $e');
      }
    }
    
    setState(() => isLoading = false);
  }

  Future<void> _deleteExercise(Exercise exercise) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Delete Exercise',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to delete this exercise?',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      exercise.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getDifficultyColor(exercise.difficultyLevel).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Difficulty: ${exercise.difficultyLevel.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getDifficultyColor(exercise.difficultyLevel),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      color: const Color(0xFFDC2626),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This action cannot be undone. All student submissions will also be deleted.',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
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
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Delete Exercise'),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        setState(() => isLoading = true);
        
        final authService = Provider.of<AuthService>(context, listen: false);
        final apiService = ApiService(authService);
        
        final success = await apiService.deleteExercise(exercise.id);
        
        if (success) {
          setState(() {
            exercises.removeWhere((e) => e.id == exercise.id);
          });
          
          if (mounted) {
            _showSuccessSnackBar('Exercise "${exercise.title}" deleted successfully');
          }
        } else {
          if (mounted) {
            _showErrorSnackBar('Failed to delete exercise');
          }
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('Error deleting exercise: $e');
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Color(0xFF3B82F6),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Create New Subject',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Subject Name',
                labelStyle: const TextStyle(color: Color(0xFF64748B)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: InputDecoration(
                labelText: 'Subject Code',
                labelStyle: const TextStyle(color: Color(0xFF64748B)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
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
                    _showSuccessSnackBar('Subject created successfully');
                  }
                } catch (e) {
                  _showErrorSnackBar('Error creating subject: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Create Subject'),
          ),
        ],
      ),
    );
  }

  void _showCreateExerciseDialog() {
    if (selectedSubject == null) {
      _showErrorSnackBar('Please select a subject first');
      return;
    }

  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            )
          : FadeTransition(
              opacity: _fadeController,
              child: Row(
                children: [
                  // Modern Subjects Sidebar
                  Container(
                    width: 320,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x0A000000),
                          offset: Offset(2, 0),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E40AF),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.book_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Subjects',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                                  onPressed: _showCreateSubjectDialog,
                                  tooltip: 'Add Subject',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: subjects.length,
                            itemBuilder: (context, index) {
                              final subject = subjects[index];
                              final isSelected = selectedSubject?.id == subject.id;
                              
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(-0.3, 0),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: _slideController,
                                  curve: Interval(
                                    index * 0.1,
                                    (index * 0.1) + 0.5,
                                    curve: Curves.easeOutCubic,
                                  ),
                                )),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? const Color(0xFF3B82F6).withOpacity(0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected 
                                          ? const Color(0xFF3B82F6)
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF3B82F6)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.subject_rounded,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF64748B),
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      subject.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? const Color(0xFF3B82F6)
                                            : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    subtitle: Text(
                                      subject.code,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isSelected
                                            ? const Color(0xFF3B82F6).withOpacity(0.7)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        selectedSubject = subject;
                                      });
                                      _loadExercises(subject.id);
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Modern Exercises Content
                  Expanded(
                    child: selectedSubject == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.assignment_rounded,
                                    size: 48,
                                    color: Color(0xFF3B82F6),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Select a subject to manage exercises',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Choose a subject from the sidebar to view and manage its exercises',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.assignment_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            selectedSubject!.name,
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${exercises.length} exercises • ${selectedSubject!.code}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.white.withOpacity(0.9),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: _showCreateExerciseDialog,
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text('Add Exercise'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(0xFF1E40AF),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Exercises Grid
                              Expanded(
                                child: exercises.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(24),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF64748B).withOpacity(0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.assignment_outlined,
                                                size: 48,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            const Text(
                                              'No exercises available',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Create your first exercise to get started',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                            const SizedBox(height: 24),
                                            ElevatedButton.icon(
                                              onPressed: _showCreateExerciseDialog,
                                              icon: const Icon(Icons.add_rounded),
                                              label: const Text('Create Exercise'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF3B82F6),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 24,
                                                  vertical: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : GridView.builder(
                                        padding: const EdgeInsets.all(24),
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3,
                                          crossAxisSpacing: 20,
                                          mainAxisSpacing: 20,
                                          childAspectRatio: 1.2,
                                        ),
                                        itemCount: exercises.length,
                                        itemBuilder: (context, index) {
                                          final exercise = exercises[index];
                                          
                                          return TweenAnimationBuilder<double>(
                                            duration: Duration(milliseconds: 600 + (index * 100)),
                                            tween: Tween<double>(begin: 0, end: 1),
                                            builder: (context, animationValue, child) {
                                              return Transform.scale(
                                                scale: animationValue,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(16),
                                                    boxShadow: const [
                                                      BoxShadow(
                                                        color: Color(0x0F000000),
                                                        offset: Offset(0, 4),
                                                        blurRadius: 20,
                                                      ),
                                                    ],
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(20),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Container(
                                                              padding: const EdgeInsets.all(8),
                                                              decoration: BoxDecoration(
                                                                color: _getDifficultyColor(exercise.difficultyLevel).withOpacity(0.1),
                                                                borderRadius: BorderRadius.circular(8),
                                                              ),
                                                              child: Icon(
                                                                Icons.code_rounded,
                                                                color: _getDifficultyColor(exercise.difficultyLevel),
                                                                size: 16,
                                                              ),
                                                            ),
                                                            const Spacer(),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                              decoration: BoxDecoration(
                                                                color: _getDifficultyColor(exercise.difficultyLevel).withOpacity(0.1),
                                                                borderRadius: BorderRadius.circular(12),
                                                              ),
                                                              child: Text(
                                                                exercise.difficultyLevel.toUpperCase(),
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: _getDifficultyColor(exercise.difficultyLevel),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 16),
                                                        Text(
                                                          exercise.title,
                                                          style: const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFF1E293B),
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        const SizedBox(height: 8),
                                                        Expanded(
                                                          child: Text(
                                                            exercise.description,
                                                            style: const TextStyle(
                                                              fontSize: 14,
                                                              color: Color(0xFF64748B),
                                                            ),
                                                            maxLines: 3,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 16),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Container(
                                                                padding: const EdgeInsets.all(8),
                                                                decoration: BoxDecoration(
                                                                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                                                                  borderRadius: BorderRadius.circular(8),
                                                                ),
                                                                child: InkWell(
                                                                  onTap: () {
                                                                    _showErrorSnackBar('Edit functionality not implemented yet');
                                                                  },
                                                                  child: const Icon(
                                                                    Icons.edit_rounded,
                                                                    color: Color(0xFF3B82F6),
                                                                    size: 18,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 12),
                                                            Expanded(
                                                              child: Container(
                                                                padding: const EdgeInsets.all(8),
                                                                decoration: BoxDecoration(
                                                                  color: const Color(0xFFDC2626).withOpacity(0.1),
                                                                  borderRadius: BorderRadius.circular(8),
                                                                ),
                                                                child: InkWell(
                                                                  onTap: () => _deleteExercise(exercise),
                                                                  child: const Icon(
                                                                    Icons.delete_rounded,
                                                                    color: Color(0xFFDC2626),
                                                                    size: 18,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
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
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const Color(0xFF10B981);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'hard':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }
}