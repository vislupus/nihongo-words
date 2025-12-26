import 'package:flutter/material.dart';
import '../config.dart';

enum ViewMode {
  normal,
  play,
  stats,
  edit,
}

class TopMenuBar extends StatelessWidget {
  final int wordCount;
  final ViewMode currentMode;
  final Function(ViewMode) onModeChanged;
  final bool isSearchActive;
  final VoidCallback onSearchToggle;
  final bool isFilterActive;
  final VoidCallback onFilterToggle;
  final VoidCallback onExportImport;

  const TopMenuBar({
    super.key,
    required this.wordCount,
    required this.currentMode,
    required this.onModeChanged,
    required this.isSearchActive,
    required this.onSearchToggle,
    required this.isFilterActive,
    required this.onFilterToggle,
    required this.onExportImport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: AppConfig.menuBarBackgroundOpacity),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildWordCounter(theme),
            _buildModeButtons(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildWordCounter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 20,
            color: theme.colorScheme.onPrimary,
          ),
          const SizedBox(width: 8),
          Text(
            '$wordCount',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButtons(ThemeData theme) {
    return Row(
      children: [
        _buildIconButton(
          icon: Icons.search,
          isSelected: isSearchActive,
          onTap: onSearchToggle,
          tooltip: 'Search',
          theme: theme,
        ),
        const SizedBox(width: 6),
        
        // NEW: Filter button
        _buildIconButton(
          icon: Icons.filter_list,
          isSelected: isFilterActive,
          onTap: onFilterToggle,
          tooltip: 'Filter',
          theme: theme,
        ),
        const SizedBox(width: 6),
        
        _buildIconButton(
          icon: Icons.folder_outlined,
          isSelected: false,
          onTap: onExportImport,
          tooltip: 'Export/Import',
          theme: theme,
        ),
        const SizedBox(width: 6),
        
        _buildModeButton(
          icon: Icons.play_arrow_rounded,
          mode: ViewMode.play,
          tooltip: 'Practice Mode',
          theme: theme,
        ),
        const SizedBox(width: 6),
        
        _buildModeButton(
          icon: Icons.visibility_outlined,
          mode: ViewMode.stats,
          tooltip: 'View Statistics',
          theme: theme,
        ),
        const SizedBox(width: 6),
        
        _buildModeButton(
          icon: Icons.edit_outlined,
          mode: ViewMode.edit,
          tooltip: 'Edit Mode',
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required ViewMode mode,
    required String tooltip,
    required ThemeData theme,
  }) {
    final isSelected = currentMode == mode;
    
    return _buildIconButton(
      icon: icon,
      isSelected: isSelected,
      onTap: () {
        if (isSelected) {
          onModeChanged(ViewMode.normal);
        } else {
          onModeChanged(mode);
        }
      },
      tooltip: tooltip,
      theme: theme,
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required String tooltip,
    required ThemeData theme,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.primary.withValues(alpha: AppConfig.menuButtonOpacity),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 22,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}