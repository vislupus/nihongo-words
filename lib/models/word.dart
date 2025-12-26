/// Model class representing a Japanese word entry
class Word {
  final int? id;
  final String kanji;
  final String hiragana;
  final String english;
  final DateTime dateAdded;
  final DateTime? lastReviewDate;
  final int correctCount;
  final int wrongCount;
  final int totalAnswers;
  final int repetitionLevel;
  final DateTime? nextReviewDate;
  final int groupId;
  final int orderIndex;  // NEW: For ordering within group
  final bool isHidden;   // NEW: For hiding words

  Word({
    this.id,
    required this.kanji,
    required this.hiragana,
    required this.english,
    required this.dateAdded,
    this.lastReviewDate,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.totalAnswers = 0,
    this.repetitionLevel = 0,
    this.nextReviewDate,
    required this.groupId,
    this.orderIndex = 0,
    this.isHidden = false,
  });

  double get correctPercentage {
    if (totalAnswers == 0) return 0;
    return (correctCount / totalAnswers) * 100;
  }

  double get wrongPercentage {
    if (totalAnswers == 0) return 0;
    return (wrongCount / totalAnswers) * 100;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kanji': kanji,
      'hiragana': hiragana,
      'english': english,
      'date_added': dateAdded.toIso8601String(),
      'last_review_date': lastReviewDate?.toIso8601String(),
      'correct_count': correctCount,
      'wrong_count': wrongCount,
      'total_answers': totalAnswers,
      'repetition_level': repetitionLevel,
      'next_review_date': nextReviewDate?.toIso8601String(),
      'group_id': groupId,
      'order_index': orderIndex,
      'is_hidden': isHidden ? 1 : 0,
    };
  }

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as int?,
      kanji: map['kanji'] as String,
      hiragana: map['hiragana'] as String,
      english: map['english'] as String,
      dateAdded: DateTime.parse(map['date_added'] as String),
      lastReviewDate: map['last_review_date'] != null
          ? DateTime.parse(map['last_review_date'] as String)
          : null,
      correctCount: map['correct_count'] as int? ?? 0,
      wrongCount: map['wrong_count'] as int? ?? 0,
      totalAnswers: map['total_answers'] as int? ?? 0,
      repetitionLevel: map['repetition_level'] as int? ?? 0,
      nextReviewDate: map['next_review_date'] != null
          ? DateTime.parse(map['next_review_date'] as String)
          : null,
      groupId: map['group_id'] as int? ?? 0,
      orderIndex: map['order_index'] as int? ?? 0,
      isHidden: (map['is_hidden'] as int? ?? 0) == 1,
    );
  }

  Word copyWith({
    int? id,
    String? kanji,
    String? hiragana,
    String? english,
    DateTime? dateAdded,
    DateTime? lastReviewDate,
    int? correctCount,
    int? wrongCount,
    int? totalAnswers,
    int? repetitionLevel,
    DateTime? nextReviewDate,
    int? groupId,
    int? orderIndex,
    bool? isHidden,
  }) {
    return Word(
      id: id ?? this.id,
      kanji: kanji ?? this.kanji,
      hiragana: hiragana ?? this.hiragana,
      english: english ?? this.english,
      dateAdded: dateAdded ?? this.dateAdded,
      lastReviewDate: lastReviewDate ?? this.lastReviewDate,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      totalAnswers: totalAnswers ?? this.totalAnswers,
      repetitionLevel: repetitionLevel ?? this.repetitionLevel,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      groupId: groupId ?? this.groupId,
      orderIndex: orderIndex ?? this.orderIndex,
      isHidden: isHidden ?? this.isHidden,
    );
  }
}