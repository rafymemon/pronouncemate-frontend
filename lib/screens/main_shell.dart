// lib/screens/main_shell.dart

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'script_selection_screen.dart';
import 'active_session_screen.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

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
              color: AppColors.primary.withValues(alpha: 0.12),
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

// ── Practice Tab (Shimmer Subtitle + Mode Cards + Bottom Sheet) ──
class _PracticeTab extends StatefulWidget {
  const _PracticeTab();

  @override
  State<_PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<_PracticeTab>
    with TickerProviderStateMixin {
  String? _selectedMode;
  String? _selectedProficiency;

  late final AnimationController _staggerController;
  late final List<Animation<double>> _fadeAnimations;
  late final List<Animation<Offset>> _slideAnimations;

  // Animation index map (8 staggered slots):
  // 0 hero · 1 generate-with-AI card · 2 "Practice Mode" header ·
  // 3,4,5 mode cards · 6 proficiency section · 7 info card + begin button
  static const int _animationSlotCount = 8;

  static const _primary = AppColors.primary;

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
    'Expert',
    'Intermediate',
    'Beginner',
  ];

  // ── NEW: Script-Based mode doesn't need a proficiency level upfront ──
  bool get _isScriptBased => _selectedMode == 'Script-Based';

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimations = List.generate(_animationSlotCount, (i) {
      final start = i * 0.1;
      final end = start + 0.4;
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(start.clamp(0, 1), end.clamp(0, 1),
              curve: Curves.easeOut),
        ),
      );
    });

    _slideAnimations = List.generate(_animationSlotCount, (i) {
      final start = i * 0.1;
      final end = start + 0.5;
      return Tween<Offset>(
        begin: const Offset(0, 24),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(start.clamp(0, 1), end.clamp(0, 1),
              curve: Curves.easeOutCubic),
        ),
      );
    });

    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  String? _getModeValue(String? modeName) {
    const map = {
      'Public Speaking': 'public_speaking',
      'Daily Conversation': 'daily_conversation',
      'Script-Based': 'script_based',
    };
    return map[modeName];
  }

  String? _getLevelValue(String? levelName) {
    if (levelName == null) return null;
    return levelName.toLowerCase().replaceAll(' ', '_');
  }

  void _selectMode(String mode) {
    setState(() {
      _selectedMode = _selectedMode == mode ? null : mode;
      // Clear any stale proficiency pick when hopping into/out of
      // Script-Based so the CTA state stays accurate.
      if (_isScriptBased) {
        _selectedProficiency = null;
      }
    });
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

  void _beginPractice() {
    if (_selectedMode == null) return;
    if (!_isScriptBased && _selectedProficiency == null) return;

    final modeValue = _getModeValue(_selectedMode);
    final levelValue =
        _isScriptBased ? null : _getLevelValue(_selectedProficiency);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScriptSelectionScreen.withFilters(
          preselectedMode: modeValue!,
          preselectedLevel: levelValue,
        ),
      ),
    );
  }

  bool get _canStart =>
      _selectedMode != null && (_isScriptBased || _selectedProficiency != null);

  // ── Generate with AI (standalone — own topic/mode/level/word-limit) ──
  void _showGenerateAiDialog() {
    final topicCtrl = TextEditingController();
    final wordLimitCtrl = TextEditingController(text: '60');
    ScriptMode dialogMode = ScriptMode.dailyConversation;
    ProficiencyLevel dialogLevel = ProficiencyLevel.intermediate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.auto_awesome_rounded, color: _primary, size: 20),
              SizedBox(width: 8),
              Text('Generate with AI'),
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dialogLabel('Topic'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: topicCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration:
                        _inputDecoration('e.g. Ordering coffee at a cafe'),
                  ),
                  const SizedBox(height: 16),
                  _dialogLabel('Practice Mode'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<ScriptMode>(
                    value: dialogMode,
                    decoration: _inputDecoration(''),
                    isExpanded: true,
                    items: ScriptMode.values
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(m.icon, size: 16, color: _primary),
                                  const SizedBox(width: 8),
                                  Text(m.label),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setLocal(() => dialogMode = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  _dialogLabel('Difficulty Level'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<ProficiencyLevel>(
                    value: dialogLevel,
                    decoration: _inputDecoration(''),
                    isExpanded: true,
                    items: ProficiencyLevel.values
                        .map((l) => DropdownMenuItem(
                              value: l,
                              child: Text(l.label),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setLocal(() => dialogLevel = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  _dialogLabel('Word Limit'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: wordLimitCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('20 – 400 words'),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primary),
              onPressed: () {
                final topic = topicCtrl.text.trim();
                final wordLimit = int.tryParse(wordLimitCtrl.text.trim());

                if (topic.isEmpty) {
                  _showSnack('Please enter a topic', error: true);
                  return;
                }
                if (wordLimit == null || wordLimit < 20 || wordLimit > 400) {
                  _showSnack('Word limit must be between 20 and 400',
                      error: true);
                  return;
                }

                Navigator.pop(ctx);
                _generateAiScript(
                  topic: topic,
                  wordLimit: wordLimit,
                  mode: dialogMode.value,
                  level: dialogLevel.value,
                );
              },
              child: const Text('Generate',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAiScript({
    required String topic,
    required int wordLimit,
    required String mode,
    required String level,
  }) async {
    _showLoadingDialog('Writing your script...');

    final result = await ApiService.generateAiScript(
      topic: topic,
      wordLimit: wordLimit,
      mode: mode,
      level: level,
    );

    if (!mounted) return;
    Navigator.pop(context); // close loading dialog

    if (result['id'] == null) {
      _showSnack(result['error']?.toString() ?? 'Failed to generate script',
          error: true);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveSessionScreen(
          scriptText: result['content'].toString(),
          scriptId: result['id']?.toString(),
          sessionTitle: result['title'].toString(),
        ),
      ),
    );
  }

  void _showLoadingDialog(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(children: [
            const CircularProgressIndicator(color: _primary),
            const SizedBox(width: 16),
            Expanded(child: Text(msg)),
          ]),
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle,
            color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: error ? AppColors.error : AppColors.success,
      duration: const Duration(seconds: 4),
    ));
  }

  Widget _dialogLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSlate,
        ),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textFaint),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Practice'),
        elevation: 0,
        backgroundColor: AppColors.background,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Text with Shimmer Subtitle ─────────────────
            _AnimatedItem(
              fade: _fadeAnimations[0],
              slide: _slideAnimations[0],
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
                  const SizedBox(height: 6),
                  ShimmerText(
                    text: 'Configure your session below and start speaking',
                    baseStyle: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                    shimmerColors: [
                      AppColors.textSecondary,
                      AppColors.primary,
                      const Color(0xFF8B5CF6),
                      AppColors.textSecondary,
                    ],
                    duration: const Duration(milliseconds: 2800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Generate with AI (standalone entry point) ─────────
            _AnimatedItem(
              fade: _fadeAnimations[1],
              slide: _slideAnimations[1],
              child: _GenerateAiCard(onTap: _showGenerateAiDialog),
            ),
            const SizedBox(height: 12),
            _AnimatedItem(
              fade: _fadeAnimations[1],
              slide: _slideAnimations[1],
              child: Row(
                children: const [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR CHOOSE MANUALLY',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppColors.textMuted)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Practice Mode Section ─────────────────────────────
            _AnimatedItem(
              fade: _fadeAnimations[2],
              slide: _slideAnimations[2],
              child: _SectionHeader(title: 'Practice Mode'),
            ),
            const SizedBox(height: 14),

            // ── Mode Cards ────────────────────────────────────────
            ..._modes.asMap().entries.map((entry) {
              final i = entry.key;
              final mode = entry.value;
              return _AnimatedItem(
                fade: _fadeAnimations[3 + i],
                slide: _slideAnimations[3 + i],
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ModeCard(
                    mode: mode,
                    isSelected: _selectedMode == mode['name'],
                    onTap: () => _selectMode(mode['name'] as String),
                  ),
                ),
              );
            }),

            const SizedBox(height: 28),

            // ── Proficiency Section (hidden for Script-Based) ─────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _isScriptBased
                  ? _AnimatedItem(
                      key: const ValueKey('script_note'),
                      fade: _fadeAnimations[6],
                      slide: _slideAnimations[6],
                      child: _ScriptBasedNoticeCard(),
                    )
                  : Column(
                      key: const ValueKey('proficiency_picker'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AnimatedItem(
                          fade: _fadeAnimations[6],
                          slide: _slideAnimations[6],
                          child: _SectionHeader(title: 'Proficiency Level'),
                        ),
                        const SizedBox(height: 14),
                        _AnimatedItem(
                          fade: _fadeAnimations[6],
                          slide: _slideAnimations[6],
                          child: _SelectorButton(
                            label: _selectedProficiency ?? 'Select your level',
                            subtitle: _selectedProficiency != null
                                ? 'Your selected English proficiency'
                                : 'Tap to choose your English level',
                            icon: Icons.signal_cellular_alt_rounded,
                            isSelected: _selectedProficiency != null,
                            onTap: _showProficiencySelector,
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 28),

            // ── Info / CTA ────────────────────────────────────────
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 350),
              crossFadeState: _canStart
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: _AnimatedItem(
                fade: _fadeAnimations[7],
                slide: _slideAnimations[7],
                child: _InfoCard(),
              ),
              secondChild: const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            _AnimatedItem(
              fade: _fadeAnimations[7],
              slide: _slideAnimations[7],
              child: _BeginButton(
                canStart: _canStart,
                onPressed: _beginPractice,
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

// ── Generate with AI Card ────────────────────────────────────────
class _GenerateAiCard extends StatelessWidget {
  final VoidCallback onTap;
  const _GenerateAiCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFF8B5CF6)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Generate with AI',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Give us a topic — we\'ll write a custom script instantly',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SHIMMER TEXT WIDGET
// ═══════════════════════════════════════════════════════════════
class ShimmerText extends StatefulWidget {
  final String text;
  final TextStyle baseStyle;
  final List<Color> shimmerColors;
  final Duration duration;

  const ShimmerText({
    super.key,
    required this.text,
    required this.baseStyle,
    required this.shimmerColors,
    this.duration = const Duration(milliseconds: 2500),
  });

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: widget.shimmerColors,
              stops: [
                _animation.value - 0.5,
                _animation.value,
                _animation.value + 0.3,
                _animation.value + 0.8,
              ],
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: Text(
            widget.text,
            style: widget.baseStyle,
          ),
        );
      },
    );
  }
}

// ── Animated List Item Wrapper ───────────────────────────────────
class _AnimatedItem extends StatelessWidget {
  final Animation<double> fade;
  final Animation<Offset> slide;
  final Widget child;

  const _AnimatedItem({
    super.key,
    required this.fade,
    required this.slide,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: fade,
      builder: (context, _) {
        return Opacity(
          opacity: fade.value,
          child: Transform.translate(
            offset: slide.value,
            child: child,
          ),
        );
      },
    );
  }
}

// ── Section Header ───────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ── Mode Card with Selection Animations ──────────────────────────
class _ModeCard extends StatelessWidget {
  final Map<String, dynamic> mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = mode['color'] as Color;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.divider,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  const BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? color
                    : color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                mode['icon'] as IconData,
                color: isSelected ? Colors.white : color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode['name'] as String,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? color : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    mode['desc'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : AppColors.divider,
                  width: 2,
                ),
              ),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 250),
                scale: isSelected ? 1 : 0,
                curve: Curves.elasticOut,
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Selector Button (for Proficiency) ────────────────────────────
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
              ? AppColors.primary.withValues(alpha: 0.07)
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
                    ? AppColors.primary.withValues(alpha: 0.12)
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

// ── Proficiency Bottom Sheet ─────────────────────────────────────
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

// ── Info Tip Card ────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Select a practice mode and your English proficiency level to begin.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF8D6E1F),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── NEW: Notice shown instead of proficiency picker for Script-Based ──
class _ScriptBasedNoticeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.upload_file_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              "You'll upload your own script (text or document) on the next screen — no proficiency level needed here.",
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Begin Button with Gradient & Press Animation ─────────────────
class _BeginButton extends StatelessWidget {
  final bool canStart;
  final VoidCallback onPressed;

  const _BeginButton({
    required this.canStart,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: canStart
            ? const LinearGradient(
                colors: [AppColors.primary, Color(0xFF8B5CF6)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: canStart ? null : AppColors.surfaceVariant,
        boxShadow: canStart
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: canStart ? onPressed : null,
          borderRadius: BorderRadius.circular(18),
          splashColor: Colors.white.withValues(alpha: 0.2),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mic_rounded,
                  color: canStart ? Colors.white : AppColors.textHint,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Begin Practice Session',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: canStart ? Colors.white : AppColors.textHint,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}