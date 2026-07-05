import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'home_screen.dart';
import 'practice_mode_screen.dart';
import 'script_selection_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(key: _homeKey),
          const _PracticeTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) {
            if (i == _currentIndex) return;
            setState(() => _currentIndex = i);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.mic_outlined),
              activeIcon: Icon(Icons.mic_rounded),
              label: 'Practice',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Practice Tab (Mode & Proficiency Hub) ────────────────────────
class _PracticeTab extends StatefulWidget {
  const _PracticeTab();

  @override
  State<_PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<_PracticeTab> {
  String? _selectedMode;
  String? _selectedProficiency;

  static const List<Map<String, dynamic>> _modes = [
    {
      'name': 'Public Speaking',
      'icon': Icons.campaign_rounded,
      'desc': 'Speeches, presentations & TED-style talks',
      'color': AppColors.primary,
    },
    {
      'name': 'Daily Conversation',
      'icon': Icons.chat_bubble_outline_rounded,
      'desc': 'Casual dialogues & everyday expressions',
      'color': AppColors.accent,
    },
    {
      'name': 'Script-Based',
      'icon': Icons.description_outlined,
      'desc': 'Upload your own text for analysis',
      'color': AppColors.success,
    },
  ];

  static const List<String> _proficiencyLevels = [
    'Fluent',
    'Advanced',
    'Upper Intermediate',
    'Intermediate',
    'Beginner',
  ];

  void _showModeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ModeBottomSheet(
        modes: _modes,
        selectedMode: _selectedMode,
        onSelect: (mode) {
          setState(() => _selectedMode = mode);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _showProficiencySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ProficiencyBottomSheet(
        levels: _proficiencyLevels,
        selectedLevel: _selectedProficiency,
        onSelect: (level) {
          setState(() => _selectedProficiency = level);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  IconData _modeIcon(String? mode) {
    if (mode == null) return Icons.category_outlined;
    final m =
        _modes.firstWhere((e) => e['name'] == mode, orElse: () => _modes[0]);
    return m['icon'] as IconData;
  }

  String _modeDesc(String? mode) {
    if (mode == null) return 'Tap to choose your practice mode';
    final m =
        _modes.firstWhere((e) => e['name'] == mode, orElse: () => _modes[0]);
    return m['desc'] as String;
  }

  void _beginPractice() {
    if (_selectedMode == null || _selectedProficiency == null) return;

    if (_selectedMode == 'Script-Based') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: AppColors.surface,
          title: const Text(
            'Choose Script Source',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          content: const Text(
            'Select a predefined script or browse your own script to upload.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3A6B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const ScriptSelectionScreen(initialTabIndex: 0),
                  ),
                );
              },
              child: const Text('Predefined Scripts'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ScriptSelectionScreen(
                      initialTabIndex: 1,
                      openUploadOptions: true,
                    ),
                  ),
                );
              },
              child: const Text('Browse Script'),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PracticeModeScreen(
          mode: _selectedMode!,
          level: _selectedProficiency!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canStart = _selectedMode != null && _selectedProficiency != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Practice')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Let's Practice",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Configure your session below and start speaking',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            const SectionHeader(title: 'Practice Mode'),
            const SizedBox(height: 12),
            _SelectorButton(
              label: _selectedMode ?? 'Select a mode',
              subtitle: _modeDesc(_selectedMode),
              icon: _modeIcon(_selectedMode),
              isSelected: _selectedMode != null,
              onTap: _showModeSelector,
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: 'Proficiency Level'),
            const SizedBox(height: 12),
            _SelectorButton(
              label: _selectedProficiency ?? 'Select your level',
              subtitle: _selectedProficiency != null
                  ? 'Your selected English proficiency'
                  : 'Tap to choose your English level',
              icon: Icons.signal_cellular_alt_rounded,
              isSelected: _selectedProficiency != null,
              onTap: _showProficiencySelector,
            ),
            const SizedBox(height: 36),
            if (!canStart) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded,
                        color: AppColors.warning, size: 26),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Select a practice mode and your English proficiency level to begin.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            PrimaryButton(
              label: 'Begin Practice Session',
              onPressed: canStart ? _beginPractice : null,
              icon: Icons.mic_rounded,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SelectorButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectorButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.07)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 10,
                offset: Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.12)
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon,
                  color: isSelected ? AppColors.primary : AppColors.textHint,
                  size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isSelected ? AppColors.primary : AppColors.textHint,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeBottomSheet extends StatelessWidget {
  final List<Map<String, dynamic>> modes;
  final String? selectedMode;
  final void Function(String) onSelect;

  const _ModeBottomSheet({
    required this.modes,
    required this.selectedMode,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Select Practice Mode',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'What type of practice do you want today?',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ...modes.map((mode) {
            final isSelected = selectedMode == mode['name'];
            final color = mode['color'] as Color;
            return GestureDetector(
              onTap: () => onSelect(mode['name'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.primary : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.divider,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      mode['icon'] as IconData,
                      color: isSelected ? Colors.white : color,
                      size: 20,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mode['name'] as String,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            mode['desc'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? Colors.white70
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 20),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ProficiencyBottomSheet extends StatelessWidget {
  final List<String> levels;
  final String? selectedLevel;
  final void Function(String) onSelect;

  const _ProficiencyBottomSheet({
    required this.levels,
    required this.selectedLevel,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Select Proficiency Level',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'What is your overall English level?',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ...levels.map((level) {
            final isSelected = selectedLevel == level;
            return GestureDetector(
              onTap: () => onSelect(level),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.primary : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.divider,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      level,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color:
                            isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 20),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
