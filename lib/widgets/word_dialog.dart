import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/word.dart';

/// Dialog for adding or editing a word
/// Shows three text fields: Kanji, Hiragana, English
/// Also shows a date picker for the date added
class WordDialog extends StatefulWidget {
  final Word? word; // null for adding, existing word for editing
  final Function(String kanji, String hiragana, String english, DateTime? dateAdded) onSave;

  const WordDialog({
    super.key,
    this.word,
    required this.onSave,
  });

  @override
  State<WordDialog> createState() => _WordDialogState();
}

class _WordDialogState extends State<WordDialog> {
  late TextEditingController _kanjiController;
  late TextEditingController _hiraganaController;
  late TextEditingController _englishController;
  late DateTime _selectedDate;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing data if editing
    _kanjiController = TextEditingController(text: widget.word?.kanji ?? '');
    _hiraganaController = TextEditingController(text: widget.word?.hiragana ?? '');
    _englishController = TextEditingController(text: widget.word?.english ?? '');
    // Use only date part (no time)
    final now = DateTime.now();
    _selectedDate = widget.word?.dateAdded ?? DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _kanjiController.dispose();
    _hiraganaController.dispose();
    _englishController.dispose();
    super.dispose();
  }

  /// Show date picker (date only, no time)
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select date added',
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  /// Validate and save the word
  void _handleSave() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSave(
        _kanjiController.text.trim(),
        _hiraganaController.text.trim(),
        _englishController.text.trim(),
        _selectedDate,
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.word != null;
    final dateFormat = DateFormat('MMMM d, yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dialog title
                Text(
                  isEditing ? 'Edit Word' : 'Add New Word',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 22),
                
                // Kanji field
                _buildTextField(
                  controller: _kanjiController,
                  label: 'Kanji',
                  hint: '漢字',
                  fontSize: 26,
                  theme: theme,
                ),
                
                const SizedBox(height: 16),
                
                // Hiragana field
                _buildTextField(
                  controller: _hiraganaController,
                  label: 'Hiragana',
                  hint: 'ひらがな',
                  fontSize: 22,
                  theme: theme,
                ),
                
                const SizedBox(height: 16),
                
                // English field
                _buildTextField(
                  controller: _englishController,
                  label: 'English',
                  hint: 'Translation',
                  fontSize: 20,
                  theme: theme,
                ),
                
                const SizedBox(height: 18),
                
                // Date picker (for both add and edit)
                Text(
                  'Date',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Date picker button
                InkWell(
                  onTap: () => _selectDate(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          dateFormat.format(_selectedDate),
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.edit,
                          size: 18,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Action buttons
                Row(
                  children: [
                    // Cancel button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Save button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _handleSave,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(isEditing ? 'Update' : 'Add'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build a styled text field
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required double fontSize,
    required ThemeData theme,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(fontSize: fontSize),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: fontSize,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.error,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'This field is required';
        }
        return null;
      },
    );
  }
}