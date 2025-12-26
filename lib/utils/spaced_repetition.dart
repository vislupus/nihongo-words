/// Utility class for spaced repetition algorithm
/// Implements intervals: 1 day, 3 days, 1 week, 3 weeks, 1 month, then monthly
class SpacedRepetition {
  /// Get the interval in days for a given repetition level
  static int getIntervalDays(int level) {
    switch (level) {
      case 0:
        return 1; // After 1 day
      case 1:
        return 3; // After 3 days
      case 2:
        return 7; // After 1 week
      case 3:
        return 21; // After 3 weeks
      case 4:
        return 30; // After 1 month
      default:
        return 30; // Then monthly
    }
  }

  /// Calculate next review date based on current level
  static DateTime calculateNextReview(int currentLevel) {
    final intervalDays = getIntervalDays(currentLevel);
    return DateTime.now().add(Duration(days: intervalDays));
  }

  /// Get human-readable interval description
  static String getIntervalDescription(int level) {
    switch (level) {
      case 0:
        return 'After 1 day';
      case 1:
        return 'After 3 days';
      case 2:
        return 'After 1 week';
      case 3:
        return 'After 3 weeks';
      case 4:
        return 'After 1 month';
      default:
        return 'Monthly review';
    }
  }

  /// Determine review status color based on next review date
  /// Returns: green (>3 days), orange (<3 days), red (overdue)
  static ReviewStatus getReviewStatus(DateTime? nextReviewDate) {
    if (nextReviewDate == null) {
      return ReviewStatus.newWord;
    }

    final now = DateTime.now();
    final difference = nextReviewDate.difference(now).inDays;

    if (difference < 0) {
      return ReviewStatus.overdue; // Red - review date passed
    } else if (difference <= 3) {
      return ReviewStatus.dueSoon; // Orange - less than 3 days
    } else {
      return ReviewStatus.onTrack; // Green - more than 3 days
    }
  }
}

/// Enum representing the review status for visual feedback
enum ReviewStatus {
  newWord,  // No review date set yet
  onTrack,  // Green - more than 3 days until review
  dueSoon,  // Orange - less than 3 days until review
  overdue,  // Red - review date has passed
}