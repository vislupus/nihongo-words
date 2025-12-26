import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/word.dart';
import '../widgets/top_menu_bar.dart';
import '../widgets/word_card.dart';
import '../widgets/word_dialog.dart';
import '../config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Word> _words = [];
  List<Word> _filteredWords = [];
  int _wordCount = 0;
  ViewMode _currentMode = ViewMode.normal;
  bool _isLoading = true;
  bool _isSearchActive = false;
  String _searchQuery = '';
  bool _isFilterActive = false;
  Set<int> _selectedErrorRanges = {};
  bool _filterNeedsReview = false;

  final Map<int, bool> _revealedWords = {};
  final Map<int, bool> _answeredWords = {};
  final Map<int, AnswerResult> _answerResults = {};

  Set<String> _collapsedGroups = {};
  static const String _collapsedGroupsKey = 'collapsed_groups';

  @override
  void initState() {
    super.initState();
    _loadCollapsedGroups();
    _loadWords();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCollapsedGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedGroups = prefs.getStringList(_collapsedGroupsKey);
      if (savedGroups != null) {
        setState(() {
          _collapsedGroups = savedGroups.toSet();
        });
      }
    } catch (e) {
      debugPrint('Error loading collapsed groups: $e');
    }
  }

  Future<void> _saveCollapsedGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_collapsedGroupsKey, _collapsedGroups.toList());
    } catch (e) {
      debugPrint('Error saving collapsed groups: $e');
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
      _applyFilters();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchActive = !_isSearchActive;
      if (!_isSearchActive) {
        _searchController.clear();
        _searchQuery = '';
        _applyFilters();
      }
    });
  }

  void _toggleFilter() {
    setState(() {
      _isFilterActive = !_isFilterActive;
      if (!_isFilterActive) {
        _selectedErrorRanges.clear();
        _filterNeedsReview = false;
        _applyFilters();
      }
    });
  }

  /// Apply all filters (search, error %, needs review, hidden)
  void _applyFilters() {
    List<Word> result = List.from(_words);

    // Search filter
    if (_searchQuery.isNotEmpty) {
      result = result.where((word) {
        return word.kanji.toLowerCase().contains(_searchQuery) ||
            word.hiragana.toLowerCase().contains(_searchQuery) ||
            word.english.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // Error percentage filter
    if (_selectedErrorRanges.isNotEmpty) {
      result = result.where((word) {
        if (word.totalAnswers == 0) return _selectedErrorRanges.contains(0);
        final wrongPct = word.wrongPercentage;
        final range = (wrongPct / 20).floor().clamp(0, 4);
        return _selectedErrorRanges.contains(range);
      }).toList();
    }

    // Needs review filter (orange or red)
    if (_filterNeedsReview) {
      result = result.where((word) {
        if (word.nextReviewDate == null) return true; // New words need review
        final days = word.nextReviewDate!.difference(DateTime.now()).inDays;
        return days <= 3;
      }).toList();
    }

    // In play mode, exclude hidden words
    if (_currentMode == ViewMode.play) {
      result = result.where((w) => !w.isHidden).toList();
    }

    setState(() {
      _filteredWords = result;
    });
  }

  Future<void> _loadWords() async {
    setState(() => _isLoading = true);

    try {
      final words = await _db.getAllWords();
      final count = await _db.getWordCount();

      setState(() {
        _words = words;
        _wordCount = count;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackbar('Failed to load words');
    }
  }

  void _resetPlayState() {
    _revealedWords.clear();
    _answeredWords.clear();
    _answerResults.clear();
  }

  String _getGroupKey(Word word) {
    final now = DateTime.now();
    final date = word.dateAdded;

    if (date.year == now.year && date.month == now.month) {
      return DateFormat('yyyy-MM-dd').format(date);
    }
    return DateFormat('yyyy-MM').format(date);
  }

  String _getGroupTitle(Word word) {
    final now = DateTime.now();
    final date = word.dateAdded;

    if (date.year == now.year && date.month == now.month) {
      if (date.day == now.day) {
        return 'Today';
      } else if (date.day == now.day - 1) {
        return 'Yesterday';
      }
      return DateFormat('MMMM d').format(date);
    }
    return DateFormat('MMMM yyyy').format(date);
  }

  void _toggleGroup(String groupKey) {
    setState(() {
      if (_collapsedGroups.contains(groupKey)) {
        _collapsedGroups.remove(groupKey);
      } else {
        _collapsedGroups.add(groupKey);
      }
    });
    _saveCollapsedGroups();
  }

  void _showAddWordDialog() async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => WordDialog(
        onSave: (kanji, hiragana, english, dateAdded) async {
          final word = Word(
            kanji: kanji,
            hiragana: hiragana,
            english: english,
            dateAdded: dateAdded ?? DateTime.now(),
            groupId: 0,
          );

          await _db.insertWord(word);
          _loadWords();
          _showSuccessSnackbar('Word added successfully');
        },
      ),
    );
  }

  void _showEditWordDialog(Word word) {
    showDialog(
      context: context,
      builder: (context) => WordDialog(
        word: word,
        onSave: (kanji, hiragana, english, dateAdded) async {
          final updatedWord = word.copyWith(
            kanji: kanji,
            hiragana: hiragana,
            english: english,
            dateAdded: dateAdded,
          );

          await _db.updateWord(updatedWord);
          _loadWords();
          _showSuccessSnackbar('Word updated successfully');
        },
      ),
    );
  }

  Future<void> _deleteWord(Word word) async {
    await _db.deleteWord(word.id!);
    _loadWords();
    _showSuccessSnackbar('Word deleted');
  }

  Future<void> _moveWordUp(Word word) async {
    await _db.moveWordUp(word);
    _loadWords();
  }

  Future<void> _moveWordDown(Word word) async {
    await _db.moveWordDown(word);
    _loadWords();
  }

  Future<void> _toggleHidden(Word word) async {
    await _db.toggleHidden(word.id!);
    _loadWords();
  }

  Future<void> _recordCorrect(Word word) async {
    setState(() {
      _answeredWords[word.id!] = true;
      _answerResults[word.id!] = AnswerResult.correct;
    });
    await _db.recordCorrectAnswer(word.id!);
  }

  Future<void> _recordWrong(Word word) async {
    setState(() {
      _answeredWords[word.id!] = true;
      _answerResults[word.id!] = AnswerResult.wrong;
    });
    await _db.recordWrongAnswer(word.id!);
  }

  Future<void> _recordView(Word word) async {
    setState(() {
      _revealedWords[word.id!] = true;
    });
    await _db.recordView(word.id!);
  }

  void _onModeChanged(ViewMode mode) {
    final previousMode = _currentMode;

    setState(() {
      if (mode == ViewMode.play && previousMode != ViewMode.play) {
        _resetPlayState();
      }
      _currentMode = mode;
    });

    // Reload and reapply filters when mode changes
    if (mode == ViewMode.stats ||
        mode == ViewMode.normal ||
        mode == ViewMode.play ||
        (previousMode == ViewMode.play && mode != ViewMode.play)) {
      _loadWords();
    }
  }

  void _showExportImportDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildExportImportSheet(),
    );
  }

  Widget _buildExportImportSheet() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Export / Import',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            'Export Backup',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCompactActionButton(
                  icon: Icons.share,
                  label: 'Share',
                  onTap: () {
                    Navigator.pop(context);
                    _exportToJson();
                  },
                  theme: theme,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactActionButton(
                  icon: Icons.save_alt,
                  label: 'Save',
                  onTap: () {
                    Navigator.pop(context);
                    _saveToFile();
                  },
                  theme: theme,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactActionButton(
                  icon: Icons.copy,
                  label: 'Copy',
                  onTap: () {
                    Navigator.pop(context);
                    _copyJsonToClipboard();
                  },
                  theme: theme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Import Backup',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCompactActionButton(
                  icon: Icons.file_open,
                  label: 'Open File',
                  onTap: () {
                    Navigator.pop(context);
                    _importFromFile();
                  },
                  theme: theme,
                  isSecondary: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactActionButton(
                  icon: Icons.paste,
                  label: 'Paste',
                  onTap: () {
                    Navigator.pop(context);
                    _importFromClipboard();
                  },
                  theme: theme,
                  isSecondary: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCompactActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
    bool isSecondary = false,
  }) {
    return Material(
      color: isSecondary
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: isSecondary
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSecondary
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onPrimaryContainer,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveToFile() async {
    try {
      if (_words.isEmpty) {
        _showErrorSnackbar('No words to export');
        return;
      }

      final jsonString = _generateJsonString();
      final defaultFileName =
          'nihongo_words_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';

      final bytes = utf8.encode(jsonString);

      String? selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save backup file',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(bytes),
      );

      if (selectedPath == null) return;

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        if (!selectedPath.endsWith('.json')) {
          selectedPath = '$selectedPath.json';
        }
        final file = File(selectedPath);
        await file.writeAsString(jsonString);
      }

      _showSuccessSnackbar('Saved ${_words.length} words');
    } catch (e) {
      _showErrorSnackbar('Save failed: $e');
    }
  }

  String _generateJsonString() {
    final jsonData = _words
        .map(
          (w) => {
            'kanji': w.kanji,
            'hiragana': w.hiragana,
            'english': w.english,
            'date_added': DateFormat('yyyy-MM-dd').format(w.dateAdded),
            'last_review_date': w.lastReviewDate != null
                ? DateFormat('yyyy-MM-dd').format(w.lastReviewDate!)
                : null,
            'correct_count': w.correctCount,
            'wrong_count': w.wrongCount,
            'total_answers': w.totalAnswers,
            'repetition_level': w.repetitionLevel,
            'next_review_date': w.nextReviewDate != null
                ? DateFormat('yyyy-MM-dd').format(w.nextReviewDate!)
                : null,
            'is_hidden': w.isHidden,
            'order_index': w.orderIndex,
          },
        )
        .toList();

    return const JsonEncoder.withIndent('  ').convert(jsonData);
  }

  Future<void> _exportToJson() async {
    try {
      if (_words.isEmpty) {
        _showErrorSnackbar('No words to export');
        return;
      }

      final jsonString = _generateJsonString();
      final fileName =
          'nihongo_words_${DateFormat('yyyyMMdd').format(DateTime.now())}.json';

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Nihongo Words Backup',
        text: 'My Japanese words backup - ${_words.length} words',
      );

      _showSuccessSnackbar('Exported ${_words.length} words');
    } catch (e) {
      _showErrorSnackbar('Export failed: $e');
    }
  }

  Future<void> _copyJsonToClipboard() async {
    try {
      if (_words.isEmpty) {
        _showErrorSnackbar('No words to export');
        return;
      }

      final jsonString = _generateJsonString();
      await Clipboard.setData(ClipboardData(text: jsonString));
      _showSuccessSnackbar('Copied ${_words.length} words to clipboard');
    } catch (e) {
      _showErrorSnackbar('Copy failed: $e');
    }
  }

  Future<void> _importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      String content;
      final file = result.files.first;

      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        _showErrorSnackbar('Could not read file');
        return;
      }

      await _importJsonContent(content);
    } catch (e) {
      _showErrorSnackbar('Import failed: $e');
    }
  }

  Future<void> _importFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);

      if (clipboardData == null ||
          clipboardData.text == null ||
          clipboardData.text!.isEmpty) {
        _showErrorSnackbar('Clipboard is empty');
        return;
      }

      await _importJsonContent(clipboardData.text!);
    } catch (e) {
      _showErrorSnackbar('Import failed: $e');
    }
  }

  Future<void> _importJsonContent(String content) async {
    try {
      final jsonData = jsonDecode(content);

      if (jsonData is! List) {
        _showErrorSnackbar('Invalid JSON format');
        return;
      }

      int importedCount = 0;
      int skippedCount = 0;

      for (final item in jsonData) {
        if (item is! Map) continue;

        final word = Word(
          kanji: item['kanji']?.toString() ?? '',
          hiragana: item['hiragana']?.toString() ?? '',
          english: item['english']?.toString() ?? '',
          dateAdded: _parseDate(item['date_added']),
          lastReviewDate: _parseNullableDate(item['last_review_date']),
          correctCount: _parseInt(item['correct_count']),
          wrongCount: _parseInt(item['wrong_count']),
          totalAnswers: _parseInt(item['total_answers']),
          repetitionLevel: _parseInt(item['repetition_level']),
          nextReviewDate: _parseNullableDate(item['next_review_date']),
          groupId: 0,
          isHidden: item['is_hidden'] == true,
          orderIndex: _parseInt(item['order_index']),
        );

        if (word.kanji.isNotEmpty || word.hiragana.isNotEmpty) {
          final result = await _db.insertWord(word, checkDuplicate: true);
          if (result == -1) {
            skippedCount++;
          } else {
            importedCount++;
          }
        }
      }

      _loadWords();

      String message = 'Imported $importedCount words';
      if (skippedCount > 0) {
        message += ', skipped $skippedCount duplicates';
      }
      _showSuccessSnackbar(message);
    } catch (e) {
      _showErrorSnackbar('Invalid JSON: $e');
    }
  }

  DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;

    final str = value.toString();
    try {
      return DateTime.parse(str);
    } catch (_) {
      try {
        return DateFormat('yyyy-MM-dd').parse(str);
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    try {
      return _parseDate(value);
    } catch (_) {
      return null;
    }
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  bool _isSameGroup(Word word1, Word word2) {
    return _getGroupKey(word1) == _getGroupKey(word2);
  }

  bool _isFirstInGroup(int index) {
    if (index == 0) return true;
    return !_isSameGroup(_filteredWords[index], _filteredWords[index - 1]);
  }

  bool _isLastInGroup(int index) {
    if (index == _filteredWords.length - 1) return true;
    return !_isSameGroup(_filteredWords[index], _filteredWords[index + 1]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          // Top menu bar
          TopMenuBar(
            wordCount: _wordCount,
            currentMode: _currentMode,
            onModeChanged: _onModeChanged,
            isSearchActive: _isSearchActive,
            onSearchToggle: _toggleSearch,
            isFilterActive: _isFilterActive,
            onFilterToggle: _toggleFilter,
            onExportImport: _showExportImportDialog,
          ),

          // Search bar
          if (_isSearchActive) _buildSearchBar(theme),

          // Filter bar
          if (_isFilterActive) _buildFilterBar(theme),

          // Word list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _words.isEmpty
                ? _buildEmptyState(theme)
                : _filteredWords.isEmpty
                ? _buildNoResultsState(theme)
                : _buildWordList(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      margin: EdgeInsets.only(
        top: AppConfig.searchBarTopMargin,
        bottom: AppConfig.searchBarBottomMargin,
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search kanji, hiragana, or English...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          filled: true,
          fillColor: theme.colorScheme.primary.withValues(
            alpha: AppConfig.searchBarOpacity,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Error percentage chips
          _buildFilterChip('0-20', 0, theme),
          _buildFilterChip('21-40', 1, theme),
          _buildFilterChip('41-60', 2, theme),
          _buildFilterChip('61-80', 3, theme),
          _buildFilterChip('81+', 4, theme),

          // Divider
          Container(
            height: 24,
            width: 1,
            color: theme.colorScheme.outlineVariant,
          ),

          // Needs review chip
          _buildDueChip(theme),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int range, ThemeData theme) {
    final isSelected = _selectedErrorRanges.contains(range);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedErrorRanges.remove(range);
          } else {
            _selectedErrorRanges.add(range);
          }
          _applyFilters();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red.shade400 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildDueChip(ThemeData theme) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterNeedsReview = !_filterNeedsReview;
          _applyFilters();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _filterNeedsReview ? Colors.orange : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule,
              size: 14,
              color: _filterNeedsReview ? Colors.white : Colors.orange,
            ),
            const SizedBox(width: 4),
            Text(
              'Due',
              style: TextStyle(
                fontSize: 14,
                fontWeight: _filterNeedsReview
                    ? FontWeight.w600
                    : FontWeight.normal,
                color: _filterNeedsReview
                    ? Colors.white
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 80,
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No words yet',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to add your first word',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 32),
          _buildAddButton(theme),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try different filters or search term',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordList(ThemeData theme) {
    final List<Widget> items = [];

    for (int i = 0; i < _filteredWords.length; i++) {
      final word = _filteredWords[i];
      final groupKey = _getGroupKey(word);
      final isFirstInGroup = _isFirstInGroup(i);
      final isLastInGroup = _isLastInGroup(i);
      final isCollapsed = _collapsedGroups.contains(groupKey);

      if (isFirstInGroup) {
        items.add(
          _buildGroupHeader(
            title: _getGroupTitle(word),
            groupKey: groupKey,
            isCollapsed: isCollapsed,
            theme: theme,
          ),
        );
      }

      if (!isCollapsed) {
        items.add(
          WordCard(
            key: ValueKey(word.id),
            word: word,
            mode: _currentMode,
            isFirstInGroup: isFirstInGroup,
            isLastInGroup: isLastInGroup,
            isRevealed: _revealedWords[word.id] ?? false,
            hasAnswered: _answeredWords[word.id] ?? false,
            answerResult: _answerResults[word.id] ?? AnswerResult.none,
            onCorrect: () => _recordCorrect(word),
            onWrong: () => _recordWrong(word),
            onReveal: () => _recordView(word),
            onEdit: () => _showEditWordDialog(word),
            onDelete: () => _deleteWord(word),
            onMoveUp: () => _moveWordUp(word),
            onMoveDown: () => _moveWordDown(word),
            onToggleHidden: () => _toggleHidden(word),
          ),
        );
      }
    }

    if (_currentMode == ViewMode.normal &&
        !_isSearchActive &&
        !_isFilterActive) {
      items.add(
        Padding(
          padding: EdgeInsets.symmetric(
            vertical: AppConfig.addButtonVerticalPadding,
            horizontal: 16,
          ),
          child: Center(child: _buildAddButton(theme)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: items,
    );
  }

  Widget _buildGroupHeader({
    required String title,
    required String groupKey,
    required bool isCollapsed,
    required ThemeData theme,
  }) {
    return GestureDetector(
      onTap: () => _toggleGroup(groupKey),
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isCollapsed ? Icons.chevron_right : Icons.expand_more,
              size: 24,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_countWordsInGroup(groupKey)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _countWordsInGroup(String groupKey) {
    return _filteredWords.where((w) => _getGroupKey(w) == groupKey).length;
  }

  Widget _buildAddButton(ThemeData theme) {
    return ElevatedButton.icon(
      onPressed: _showAddWordDialog,
      icon: const Icon(Icons.add),
      label: const Text('Add Word'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
      ),
    );
  }
}
