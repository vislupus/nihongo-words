import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import '../models/word.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('japanese_words.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    String dbPath;
    
    if (kIsWeb) {
      dbPath = filePath;
    } else {
      try {
        final dbDir = await getDatabasesPath();
        dbPath = join(dbDir, filePath);
      } catch (e) {
        dbPath = filePath;
      }
    }

    return await openDatabase(
      dbPath,
      version: 2,  // Increased version for migration
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kanji TEXT NOT NULL,
        hiragana TEXT NOT NULL,
        english TEXT NOT NULL,
        date_added TEXT NOT NULL,
        last_review_date TEXT,
        correct_count INTEGER DEFAULT 0,
        wrong_count INTEGER DEFAULT 0,
        total_answers INTEGER DEFAULT 0,
        repetition_level INTEGER DEFAULT 0,
        next_review_date TEXT,
        group_id INTEGER NOT NULL,
        order_index INTEGER DEFAULT 0,
        is_hidden INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns for existing databases
      await db.execute('ALTER TABLE words ADD COLUMN order_index INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE words ADD COLUMN is_hidden INTEGER DEFAULT 0');
    }
  }

  int _calculateGroupId(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month) {
      return date.year * 10000 + date.month * 100 + date.day;
    }
    return date.year * 10000 + date.month * 100;
  }

  Future<bool> wordExistsForDate(String kanji, String hiragana, DateTime date) async {
    final db = await database;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    final result = await db.query(
      'words',
      where: 'kanji = ? AND hiragana = ? AND date_added LIKE ?',
      whereArgs: [kanji, hiragana, '$dateStr%'],
    );
    
    return result.isNotEmpty;
  }

  Future<int> _getNextOrderIndex(int groupId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(order_index) as max_order FROM words WHERE group_id = ?',
      [groupId],
    );
    final maxOrder = result.first['max_order'] as int?;
    return (maxOrder ?? -1) + 1;
  }

  Future<int> insertWord(Word word, {bool checkDuplicate = false}) async {
    final db = await database;
    
    if (checkDuplicate) {
      final exists = await wordExistsForDate(
        word.kanji, 
        word.hiragana, 
        word.dateAdded,
      );
      if (exists) {
        return -1;
      }
    }
    
    final groupId = _calculateGroupId(word.dateAdded);
    final orderIndex = await _getNextOrderIndex(groupId);
    final wordWithGroup = word.copyWith(groupId: groupId, orderIndex: orderIndex);
    return await db.insert('words', wordWithGroup.toMap());
  }

  Future<List<Word>> getAllWords() async {
    final db = await database;
    final result = await db.query(
      'words',
      orderBy: 'group_id ASC, order_index ASC, date_added ASC',
    );
    return result.map((map) => Word.fromMap(map)).toList();
  }

  Future<int> getWordCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM words WHERE is_hidden = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> updateWord(Word word) async {
    final db = await database;
    final groupId = _calculateGroupId(word.dateAdded);
    final wordWithGroup = word.copyWith(groupId: groupId);
    return await db.update(
      'words',
      wordWithGroup.toMap(),
      where: 'id = ?',
      whereArgs: [word.id],
    );
  }

  Future<int> deleteWord(int id) async {
    final db = await database;
    return await db.delete(
      'words',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Toggle hidden status
  Future<void> toggleHidden(int wordId) async {
    final db = await database;
    final words = await db.query('words', where: 'id = ?', whereArgs: [wordId]);
    
    if (words.isNotEmpty) {
      final word = Word.fromMap(words.first);
      await db.update(
        'words',
        {'is_hidden': word.isHidden ? 0 : 1},
        where: 'id = ?',
        whereArgs: [wordId],
      );
    }
  }

  /// Move word up in order
  Future<void> moveWordUp(Word word) async {
    final db = await database;
    
    // Find the word above this one in the same group
    final aboveWords = await db.query(
      'words',
      where: 'group_id = ? AND order_index < ?',
      whereArgs: [word.groupId, word.orderIndex],
      orderBy: 'order_index DESC',
      limit: 1,
    );
    
    if (aboveWords.isNotEmpty) {
      final aboveWord = Word.fromMap(aboveWords.first);
      
      // Swap order indices
      await db.update(
        'words',
        {'order_index': aboveWord.orderIndex},
        where: 'id = ?',
        whereArgs: [word.id],
      );
      await db.update(
        'words',
        {'order_index': word.orderIndex},
        where: 'id = ?',
        whereArgs: [aboveWord.id],
      );
    }
  }

  /// Move word down in order
  Future<void> moveWordDown(Word word) async {
    final db = await database;
    
    // Find the word below this one in the same group
    final belowWords = await db.query(
      'words',
      where: 'group_id = ? AND order_index > ?',
      whereArgs: [word.groupId, word.orderIndex],
      orderBy: 'order_index ASC',
      limit: 1,
    );
    
    if (belowWords.isNotEmpty) {
      final belowWord = Word.fromMap(belowWords.first);
      
      // Swap order indices
      await db.update(
        'words',
        {'order_index': belowWord.orderIndex},
        where: 'id = ?',
        whereArgs: [word.id],
      );
      await db.update(
        'words',
        {'order_index': word.orderIndex},
        where: 'id = ?',
        whereArgs: [belowWord.id],
      );
    }
  }

  Future<void> recordCorrectAnswer(int wordId) async {
    final db = await database;
    final words = await db.query('words', where: 'id = ?', whereArgs: [wordId]);
    
    if (words.isNotEmpty) {
      final word = Word.fromMap(words.first);
      final newLevel = (word.repetitionLevel < 5) 
          ? word.repetitionLevel + 1 
          : word.repetitionLevel;
      
      final nextReview = DateTime.now().add(
        Duration(days: _getIntervalDays(newLevel)),
      );

      await db.update(
        'words',
        {
          'correct_count': word.correctCount + 1,
          'total_answers': word.totalAnswers + 1,
          'last_review_date': DateTime.now().toIso8601String(),
          'repetition_level': newLevel,
          'next_review_date': nextReview.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [wordId],
      );
    }
  }

  Future<void> recordWrongAnswer(int wordId) async {
    final db = await database;
    final words = await db.query('words', where: 'id = ?', whereArgs: [wordId]);
    
    if (words.isNotEmpty) {
      final word = Word.fromMap(words.first);
      final nextReview = DateTime.now().add(const Duration(days: 1));

      await db.update(
        'words',
        {
          'wrong_count': word.wrongCount + 1,
          'total_answers': word.totalAnswers + 1,
          'last_review_date': DateTime.now().toIso8601String(),
          'repetition_level': 0,
          'next_review_date': nextReview.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [wordId],
      );
    }
  }

  Future<void> recordView(int wordId) async {
    final db = await database;
    await db.update(
      'words',
      {'last_review_date': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [wordId],
    );
  }

  int _getIntervalDays(int level) {
    switch (level) {
      case 0: return 1;
      case 1: return 3;
      case 2: return 7;
      case 3: return 21;
      case 4: return 30;
      default: return 30;
    }
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}