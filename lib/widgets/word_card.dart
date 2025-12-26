import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/word.dart';
import '../utils/spaced_repetition.dart';
import '../widgets/top_menu_bar.dart';
import '../config.dart';

enum AnswerResult {
  none,
  correct,
  wrong,
}

class WordCard extends StatefulWidget {
  final Word word;
  final ViewMode mode;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final bool isRevealed;
  final bool hasAnswered;
  final AnswerResult answerResult;
  final VoidCallback onCorrect;
  final VoidCallback onWrong;
  final VoidCallback onReveal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onToggleHidden;

  const WordCard({
    super.key,
    required this.word,
    required this.mode,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.isRevealed,
    required this.hasAnswered,
    this.answerResult = AnswerResult.none,
    required this.onCorrect,
    required this.onWrong,
    required this.onReveal,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onToggleHidden,
  });

  @override
  State<WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<WordCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _blurAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _blurAnimation = Tween<double>(begin: 8.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    if (widget.isRevealed) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(WordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.mode != widget.mode) {
      if (widget.mode == ViewMode.play && !widget.isRevealed) {
        _animationController.reset();
      }
    }
    
    if (!oldWidget.isRevealed && widget.isRevealed) {
      _animationController.forward();
    }
    
    if (oldWidget.isRevealed && !widget.isRevealed) {
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleReveal() {
    if (!widget.isRevealed && widget.mode == ViewMode.play) {
      widget.onReveal();
    }
  }

  Color? _getBorderColor(ThemeData theme) {
    if (widget.mode == ViewMode.play && widget.hasAnswered) {
      switch (widget.answerResult) {
        case AnswerResult.correct:
          return Colors.green;
        case AnswerResult.wrong:
          return Colors.red;
        case AnswerResult.none:
          return null;
      }
    }
    
    if (widget.mode == ViewMode.stats) {
      final status = SpacedRepetition.getReviewStatus(widget.word.nextReviewDate);
      switch (status) {
        case ReviewStatus.onTrack:
          return Colors.green;
        case ReviewStatus.dueSoon:
          return Colors.orange;
        case ReviewStatus.overdue:
          return Colors.red;
        case ReviewStatus.newWord:
          return theme.colorScheme.outline;
      }
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = _getBorderColor(theme);
    final isHidden = widget.word.isHidden;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        top: widget.isFirstInGroup ? 4 : 2,
        bottom: widget.isLastInGroup ? 4 : 2,
      ),
      decoration: BoxDecoration(
        color: isHidden 
            ? theme.colorScheme.surface.withValues(alpha: 0.5)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(widget.isFirstInGroup ? 16 : 4),
          topRight: Radius.circular(widget.isFirstInGroup ? 16 : 4),
          bottomLeft: Radius.circular(widget.isLastInGroup ? 16 : 4),
          bottomRight: Radius.circular(widget.isLastInGroup ? 16 : 4),
        ),
        border: Border.all(
          color: isHidden 
              ? theme.colorScheme.outlineVariant.withValues(alpha: 0.3)
              : (borderColor ?? theme.colorScheme.outlineVariant),
          width: borderColor != null ? 2.5 : 1,
        ),
        boxShadow: isHidden ? null : [
          BoxShadow(
            color: (borderColor ?? Colors.black).withValues(alpha: borderColor != null ? 0.15 : 0.05),
            blurRadius: borderColor != null ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Opacity(
        opacity: isHidden ? 0.4 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildWordContent(theme),
            
            if (widget.mode == ViewMode.play && widget.isRevealed && !widget.hasAnswered)
              _buildPlayModeButtons(theme),
            
            if (widget.mode == ViewMode.stats)
              _buildCompactStats(theme),
            
            if (widget.mode == ViewMode.edit)
              _buildEditButtons(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildWordContent(ThemeData theme) {
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 1,
              child: Text(
                widget.word.kanji,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.visible,
              ),
            ),
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              color: theme.colorScheme.outlineVariant,
            ),
            Expanded(
              flex: 1,
              child: Text(
                widget.word.hiragana,
                style: TextStyle(
                  fontSize: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.visible,
              ),
            ),
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              color: theme.colorScheme.outlineVariant,
            ),
            Expanded(
              flex: 1,
              child: Text(
                widget.word.english,
                style: TextStyle(
                  fontSize: 18,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.mode == ViewMode.play) {
      return GestureDetector(
        onTap: _handleReveal,
        child: AnimatedBuilder(
          animation: _blurAnimation,
          builder: (context, child) {
            final blurValue = widget.isRevealed ? _blurAnimation.value : 8.0;
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: blurValue,
                  sigmaY: blurValue,
                ),
                child: Container(
                  color: widget.isRevealed 
                      ? Colors.transparent 
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  child: content,
                ),
              ),
            );
          },
        ),
      );
    }

    return content;
  }

  Widget _buildPlayModeButtons(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAnswerButton(
            icon: Icons.check_rounded,
            color: Colors.green,
            onTap: widget.onCorrect,
          ),
          const SizedBox(width: 70),
          _buildAnswerButton(
            icon: Icons.close_rounded,
            color: Colors.red,
            onTap: widget.onWrong,
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.all(AppConfig.answerButtonPadding),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, color: color, size: AppConfig.answerButtonSize),
        ),
      ),
    );
  }

  Widget _buildCompactStats(ThemeData theme) {
    final word = widget.word;
    final dateFormat = DateFormat('MM/dd');
    
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCompactStatItem(
            icon: Icons.check,
            value: '${word.correctPercentage.toStringAsFixed(0)}%',
            color: Colors.green,
          ),
          _buildCompactStatItem(
            icon: Icons.close,
            value: '${word.wrongPercentage.toStringAsFixed(0)}%',
            color: Colors.red,
          ),
          _buildCompactStatItem(
            icon: Icons.repeat,
            value: '${word.totalAnswers}',
            color: theme.colorScheme.primary,
          ),
          Container(height: 24, width: 1, color: theme.colorScheme.outlineVariant),
          _buildDateItem(
            label: 'Last',
            date: word.lastReviewDate,
            dateFormat: dateFormat,
            theme: theme,
          ),
          _buildDateItem(
            label: 'Next',
            date: word.nextReviewDate,
            dateFormat: dateFormat,
            theme: theme,
            highlightOverdue: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatItem({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildDateItem({
    required String label,
    required DateTime? date,
    required DateFormat dateFormat,
    required ThemeData theme,
    bool highlightOverdue = false,
  }) {
    Color textColor = theme.colorScheme.onSurface.withValues(alpha: 0.7);
    
    if (highlightOverdue && date != null) {
      final difference = date.difference(DateTime.now()).inDays;
      if (difference < 0) {
        textColor = Colors.red;
      } else if (difference <= 3) {
        textColor = Colors.orange;
      } else {
        textColor = Colors.green;
      }
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
        Text(
          date != null ? dateFormat.format(date) : '--',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
        ),
      ],
    );
  }

  Widget _buildEditButtons(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Move up
          _buildSmallEditButton(
            icon: Icons.arrow_upward,
            color: theme.colorScheme.primary,
            onTap: widget.onMoveUp,
            tooltip: 'Move up',
          ),
          const SizedBox(width: 8),
          
          // Move down
          _buildSmallEditButton(
            icon: Icons.arrow_downward,
            color: theme.colorScheme.primary,
            onTap: widget.onMoveDown,
            tooltip: 'Move down',
          ),
          const SizedBox(width: 16),
          
          // Hide/Show
          _buildSmallEditButton(
            icon: widget.word.isHidden ? Icons.visibility : Icons.visibility_off,
            color: Colors.orange,
            onTap: widget.onToggleHidden,
            tooltip: widget.word.isHidden ? 'Show' : 'Hide',
          ),
          const SizedBox(width: 16),
          
          // Edit
          _buildSmallEditButton(
            icon: Icons.edit_outlined,
            color: theme.colorScheme.primary,
            onTap: widget.onEdit,
            tooltip: 'Edit',
          ),
          const SizedBox(width: 8),
          
          // Delete
          _buildSmallEditButton(
            icon: Icons.delete_outline,
            color: Colors.red,
            onTap: () => _showDeleteConfirmation(context),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  Widget _buildSmallEditButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Word'),
        content: Text('Are you sure you want to delete "${widget.word.kanji}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}