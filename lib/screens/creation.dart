import 'package:flutter/material.dart';
import 'package:labassistant/models/excercise_model.dart';
import 'package:labassistant/models/subject_model.dart';
import 'package:labassistant/services/api_services.dart';
import 'package:labassistant/services/auth_service.dart';
import 'package:provider/provider.dart';

class CreateExerciseScreen extends StatefulWidget {
  final Subject subject;
  final Exercise? exercise; // For editing existing exercises

  const CreateExerciseScreen({super.key, required this.subject, this.exercise});

  @override
  State<CreateExerciseScreen> createState() => _CreateExerciseScreenState();
}

class _CreateExerciseScreenState extends State<CreateExerciseScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _inputFormatController = TextEditingController();
  final _outputFormatController = TextEditingController();
  final _constraintsController = TextEditingController();
  String _selectedDifficulty = 'medium';
  List<TestCase> _allTestCases = [];
  Set<int> _visibleTestCaseIndices = {};
  bool _isLoading = false;

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
    
    // If editing an existing exercise, populate the fields
    if (widget.exercise != null) {
      _populateFieldsForEditing();
    }
    
    _fadeController.forward();
    _slideController.forward();
  }

  void _populateFieldsForEditing() {
    final exercise = widget.exercise!;
    _titleController.text = exercise.title;
    _descriptionController.text = exercise.description;
    _inputFormatController.text = exercise.inputFormat ?? '';
    _outputFormatController.text = exercise.outputFormat ?? '';
    _constraintsController.text = exercise.constraints ?? '';
    _selectedDifficulty = exercise.difficultyLevel;
    
    // Populate test cases
    _allTestCases = [...exercise.testCases];
    if (exercise.hiddenTestCases != null) {
      _allTestCases.addAll(exercise.hiddenTestCases!);
    }
    
    // Mark first 3 as visible (assuming they were the original visible ones)
    for (int i = 0; i < exercise.testCases.length && i < 3; i++) {
      _visibleTestCaseIndices.add(i);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _inputFormatController.dispose();
    _outputFormatController.dispose();
    _constraintsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            )
          : FadeTransition(
              opacity: _fadeController,
              child: Column(
                children: [
                  // Modern Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
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
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.add_circle_outline_rounded,
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
                                widget.exercise != null ? 'Edit Exercise' : 'Create New Exercise',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Subject: ${widget.subject.name} • ${widget.subject.code}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _saveExercise,
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Save Exercise'),
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

                  // Content Area
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: _slideController,
                          curve: Curves.easeOutCubic,
                        )),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Basic Information Card
                              Container(
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
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF3B82F6).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.info_outline_rounded,
                                              color: Color(0xFF3B82F6),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'Exercise Information',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      
                                      // Title Field
                                      _buildTextField(
                                        controller: _titleController,
                                        label: 'Exercise Title',
                                        hint: 'Enter a descriptive title for your exercise',
                                        icon: Icons.title_rounded,
                                        validator: (value) => value?.isEmpty == true ? 'Title is required' : null,
                                      ),
                                      
                                      const SizedBox(height: 20),
                                      
                                      // Description Field
                                      _buildTextField(
                                        controller: _descriptionController,
                                        label: 'Description',
                                        hint: 'Describe what the exercise should accomplish',
                                        icon: Icons.description_rounded,
                                        maxLines: 4,
                                        validator: (value) => value?.isEmpty == true ? 'Description is required' : null,
                                      ),
                                      
                                      const SizedBox(height: 20),
                                      
                                      // Difficulty Dropdown
                                      _buildDifficultyDropdown(),
                                    ],
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Format and Constraints Card
                              Container(
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
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.format_list_bulleted_rounded,
                                              color: Color(0xFF10B981),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'Format & Constraints',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildTextField(
                                              controller: _inputFormatController,
                                              label: 'Input Format',
                                              hint: 'e.g., Two integers separated by space',
                                              icon: Icons.input_rounded,
                                              maxLines: 2,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: _buildTextField(
                                              controller: _outputFormatController,
                                              label: 'Output Format',
                                              hint: 'e.g., Single integer representing the sum',
                                              icon: Icons.output_rounded,
                                              maxLines: 2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      const SizedBox(height: 20),
                                      
                                      _buildTextField(
                                        controller: _constraintsController,
                                        label: 'Constraints',
                                        hint: 'e.g., Input integers will be between -1000 and 1000',
                                        icon: Icons.rule_rounded,
                                        maxLines: 3,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Test Cases Card
                              Container(
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
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF59E0B).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.quiz_rounded,
                                              color: Color(0xFFF59E0B),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'Test Cases',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          const Spacer(),
                                          ElevatedButton.icon(
                                            onPressed: _addTestCase,
                                            icon: const Icon(Icons.add_rounded),
                                            label: const Text('Add Test Case'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF3B82F6),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      const SizedBox(height: 16),
                                      
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFF3B82F6).withOpacity(0.2),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.visibility_rounded,
                                                  color: const Color(0xFF3B82F6),
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                const Text(
                                                  'Test Case Visibility',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF3B82F6),
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Select exactly 3 test cases to be visible to students during practice. The rest will be hidden and used only for final evaluation.',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 20),
                                      
                                      // Test Cases List
                                      _buildTestCasesList(),
                                    ],
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.speed_rounded, size: 18, color: const Color(0xFF64748B)),
            const SizedBox(width: 8),
            const Text(
              'Difficulty Level',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedDifficulty,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          items: [
            DropdownMenuItem(
              value: 'easy',
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Easy'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'medium',
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Medium'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'hard',
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Hard'),
                ],
              ),
            ),
          ],
          onChanged: (value) => setState(() => _selectedDifficulty = value!),
        ),
      ],
    );
  }

  Widget _buildTestCasesList() {
    if (_allTestCases.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF64748B).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.quiz_outlined,
                  size: 32,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'No test cases added yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Click "Add Test Case" to get started',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Test Cases (${_allTestCases.length} total)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                if (_visibleTestCaseIndices.length != 3)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Select exactly 3 visible (${_visibleTestCaseIndices.length}/3)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '3 visible selected ✓',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            height: 300,
            child: ListView.builder(
              itemCount: _allTestCases.length,
              itemBuilder: (context, index) {
                final testCase = _allTestCases[index];
                final isVisible = _visibleTestCaseIndices.contains(index);
                
                return TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 400 + (index * 100)),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, animationValue, child) {
                    return Transform.scale(
                      scale: 0.8 + (0.2 * animationValue),
                      child: Opacity(
                        opacity: animationValue,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isVisible 
                                ? const Color(0xFF10B981).withOpacity(0.1)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isVisible 
                                  ? const Color(0xFF10B981).withOpacity(0.3)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isVisible 
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Checkbox(
                                value: isVisible,
                                onChanged: (value) => _toggleTestCaseVisibility(index, value ?? false),
                                activeColor: Colors.white,
                                checkColor: const Color(0xFF10B981),
                                side: const BorderSide(color: Colors.transparent),
                              ),
                            ),
                            title: Text(
                              'Test Case ${index + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isVisible 
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Input: ${testCase.input.isEmpty ? "(no input)" : testCase.input}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  'Expected: ${testCase.expectedOutput}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isVisible 
                                        ? const Color(0xFF10B981).withOpacity(0.2)
                                        : const Color(0xFF94A3B8).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isVisible ? 'VISIBLE TO STUDENTS' : 'HIDDEN TEST CASE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isVisible 
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.edit_rounded, size: 18),
                                    color: const Color(0xFF3B82F6),
                                    onPressed: () => _editTestCase(index),
                                    tooltip: 'Edit Test Case',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.delete_rounded, size: 18),
                                    color: const Color(0xFFEF4444),
                                    onPressed: () => _removeTestCase(index),
                                    tooltip: 'Delete Test Case',
                                  ),
                                ),
                              ],
                            ),
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
    );
  }

  void _toggleTestCaseVisibility(int index, bool isVisible) {
    setState(() {
      if (isVisible) {
        if (_visibleTestCaseIndices.length < 3) {
          _visibleTestCaseIndices.add(index);
        } else {
          _showErrorSnackBar('Maximum 3 test cases can be visible to students');
        }
      } else {
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Color(0xFF10B981),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Add Test Case',
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
            _buildDialogTextField(
              controller: inputController,
              label: 'Input',
              hint: 'Enter test input (leave empty if no input needed)',
              icon: Icons.input_rounded,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildDialogTextField(
              controller: outputController,
              label: 'Expected Output',
              hint: 'Enter expected output',
              icon: Icons.output_rounded,
              maxLines: 3,
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
            onPressed: () {
              if (outputController.text.isNotEmpty) {
                setState(() {
                  _allTestCases.add(TestCase(
                    input: inputController.text.trim(),
                    expectedOutput: outputController.text.trim(),
                  ));
                  // Auto-select new test case as visible if less than 3 are selected
                  if (_visibleTestCaseIndices.length < 3) {
                    _visibleTestCaseIndices.add(_allTestCases.length - 1);
                  }
                });
                Navigator.pop(context);
                _showSuccessSnackBar('Test case added successfully');
              } else {
                _showErrorSnackBar('Expected output is required');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Add Test Case'),
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
                Icons.edit_rounded,
                color: Color(0xFF3B82F6),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Edit Test Case ${index + 1}',
              style: const TextStyle(
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
            _buildDialogTextField(
              controller: inputController,
              label: 'Input',
              hint: 'Enter test input',
              icon: Icons.input_rounded,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildDialogTextField(
              controller: outputController,
              label: 'Expected Output',
              hint: 'Enter expected output',
              icon: Icons.output_rounded,
              maxLines: 3,
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
            onPressed: () {
              if (outputController.text.isNotEmpty) {
                setState(() {
                  _allTestCases[index] = TestCase(
                    input: inputController.text.trim(),
                    expectedOutput: outputController.text.trim(),
                  );
                });
                Navigator.pop(context);
                _showSuccessSnackBar('Test case updated successfully');
              } else {
                _showErrorSnackBar('Expected output is required');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _removeTestCase(int index) {
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
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFEF4444),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Test Case',
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
              'Are you sure you want to delete this test case?',
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
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test Case ${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Input: ${_allTestCases[index].input.isEmpty ? "(no input)" : _allTestCases[index].input}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Expected: ${_allTestCases[index].expectedOutput}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    color: const Color(0xFFEF4444),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
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
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
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
                }
                _visibleTestCaseIndices = newVisibleIndices;
              });
              Navigator.pop(context);
              _showSuccessSnackBar('Test case deleted successfully');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete Test Case'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveExercise() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_allTestCases.isEmpty) {
      _showErrorSnackBar('At least one test case is required');
      return;
    }

    if (_visibleTestCaseIndices.length > 3) {
      _showErrorSnackBar('Maximum 3 test cases can be visible to students');
      return;
    }

    if (_visibleTestCaseIndices.isEmpty) {
      _showErrorSnackBar('At least one test case must be visible to students');
      return;
    }

    setState(() => _isLoading = true);

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

      final exerciseData = {
        'subject_id': widget.subject.id,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'input_format': _inputFormatController.text.trim().isNotEmpty ? _inputFormatController.text.trim() : null,
        'output_format': _outputFormatController.text.trim().isNotEmpty ? _outputFormatController.text.trim() : null,
        'constraints': _constraintsController.text.trim().isNotEmpty ? _constraintsController.text.trim() : null,
        'difficulty_level': _selectedDifficulty,
        'test_cases': visibleTestCases.map((tc) => tc.toJson()).toList(),
        'hidden_test_cases': hiddenTestCases.map((tc) => tc.toJson()).toList(),
      };

      print('Creating exercise with data: $exerciseData');

      bool success;
      if (widget.exercise != null) {
        // Update existing exercise
        success = await apiService.updateExercise(widget.exercise!.id, exerciseData);
      } else {
        // Create new exercise
        success = await apiService.createExercise(exerciseData);
      }

      if (success) {
        Navigator.pop(context);
        _showSuccessSnackBar(
          widget.exercise != null 
            ? 'Exercise updated successfully!\nVisible test cases: ${visibleTestCases.length}\nHidden test cases: ${hiddenTestCases.length}'
            : 'Exercise created successfully!\nVisible test cases: ${visibleTestCases.length}\nHidden test cases: ${hiddenTestCases.length}'
        );
      } else {
        _showErrorSnackBar(widget.exercise != null ? 'Failed to update exercise' : 'Failed to create exercise');
      }
    } catch (e) {
      _showErrorSnackBar('Error ${widget.exercise != null ? 'updating' : 'creating'} exercise: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
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
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}