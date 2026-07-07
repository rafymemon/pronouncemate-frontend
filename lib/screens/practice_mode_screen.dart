import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class PracticeModeScreen extends StatefulWidget {
  final String mode;
  final String level;
  const PracticeModeScreen({super.key, required this.mode, required this.level});

  @override
  State<PracticeModeScreen> createState() => _PracticeModeScreenState();
}

class _PracticeModeScreenState extends State<PracticeModeScreen> {
  late String _selectedLevel;
  int _selectedScript = 0;
  bool _sessionStarted = false;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _selectedLevel = _mapProficiency(widget.level);
  }

  /// Maps the 5-tier proficiency label to one of the 3 script categories.
  String _mapProficiency(String proficiency) {
    switch (proficiency) {
      case 'Fluent':
      case 'Advanced':
        return 'Advanced';
      case 'Upper Intermediate':
      case 'Intermediate':
        return 'Intermediate';
      default:
        return 'Beginner';
    }
  }

  static const Map<String, Map<String, List<Map<String, String>>>> _scripts = {
    'Public Speaking': {
      'Beginner': [
        {
          'title': 'Club Introduction',
          'summary': 'A simple opener for introducing yourself to a small audience.',
          'focus': 'Voice clarity',
          'tone': 'Warm and calm',
          'words': '48 words',
          'duration': '~2 min',
        },
        {
          'title': 'Thank You Note',
          'summary': 'A short appreciation speech with clean pauses and emphasis.',
          'focus': 'Pacing',
          'tone': 'Grateful',
          'words': '56 words',
          'duration': '~3 min',
        },
      ],
      'Intermediate': [
        {
          'title': 'Startup Pitch',
          'summary': 'Present a problem, solution, and closing line without extra filler.',
          'focus': 'Structured delivery',
          'tone': 'Confident',
          'words': '94 words',
          'duration': '~4 min',
        },
        {
          'title': 'Team Update',
          'summary': 'A concise workplace update built around transitions and key points.',
          'focus': 'Transitions',
          'tone': 'Professional',
          'words': '88 words',
          'duration': '~4 min',
        },
      ],
      'Advanced': [
        {
          'title': 'Conference Opening',
          'summary': 'A polished opening for a talk with strong presence and audience control.',
          'focus': 'Stage presence',
          'tone': 'Authoritative',
          'words': '136 words',
          'duration': '~6 min',
        },
        {
          'title': 'Vision Statement',
          'summary': 'Deliver a persuasive message with a memorable hook and landing.',
          'focus': 'Persuasion',
          'tone': 'Inspiring',
          'words': '148 words',
          'duration': '~7 min',
        },
      ],
    },
    'Daily Conversation': {
      'Beginner': [
        {
          'title': 'Coffee Order',
          'summary': 'Practice everyday requests with natural rhythm and simple replies.',
          'focus': 'Natural phrasing',
          'tone': 'Friendly',
          'words': '40 words',
          'duration': '~2 min',
        },
        {
          'title': 'Meeting a Neighbor',
          'summary': 'Use short introductions, follow-up questions, and smooth turn-taking.',
          'focus': 'Turn taking',
          'tone': 'Relaxed',
          'words': '45 words',
          'duration': '~2 min',
        },
      ],
      'Intermediate': [
        {
          'title': 'Weekend Plans',
          'summary': 'Keep the conversation moving with details, reactions, and follow-ups.',
          'focus': 'Flow',
          'tone': 'Casual',
          'words': '76 words',
          'duration': '~3 min',
        },
        {
          'title': 'Problem at a Store',
          'summary': 'Explain a problem clearly while staying polite and direct.',
          'focus': 'Clarity',
          'tone': 'Respectful',
          'words': '82 words',
          'duration': '~4 min',
        },
      ],
      'Advanced': [
        {
          'title': 'Networking Break',
          'summary': 'Handle open-ended conversation with confidence and natural transitions.',
          'focus': 'Spontaneity',
          'tone': 'Engaging',
          'words': '110 words',
          'duration': '~5 min',
        },
        {
          'title': 'Explaining a Delay',
          'summary': 'Balance detail, empathy, and confidence in a live conversation.',
          'focus': 'Repairing meaning',
          'tone': 'Composed',
          'words': '118 words',
          'duration': '~5 min',
        },
      ],
    },
    'Script-Based': {
      'Beginner': [
        {
          'title': 'Narration Practice',
          'summary': 'A short read-aloud script with easy sentence endings and pauses.',
          'focus': 'Sentence stress',
          'tone': 'Clear',
          'words': '52 words',
          'duration': '~2 min',
        },
        {
          'title': 'Simple Announcement',
          'summary': 'Build comfort reading scripted information with smooth phrasing.',
          'focus': 'Breath control',
          'tone': 'Steady',
          'words': '58 words',
          'duration': '~3 min',
        },
      ],
      'Intermediate': [
        {
          'title': 'Product Walkthrough',
          'summary': 'Read a guided product explanation with emphasis on key features.',
          'focus': 'Emphasis',
          'tone': 'Informative',
          'words': '96 words',
          'duration': '~4 min',
        },
        {
          'title': 'Training Script',
          'summary': 'Practice a structured explanation with controlled tempo.',
          'focus': 'Tempo control',
          'tone': 'Instructional',
          'words': '90 words',
          'duration': '~4 min',
        },
      ],
      'Advanced': [
        {
          'title': 'Keynote Excerpt',
          'summary': 'Refine delivery of a polished script with intentional phrasing.',
          'focus': 'Delivery polish',
          'tone': 'Executive',
          'words': '142 words',
          'duration': '~6 min',
        },
        {
          'title': 'Research Summary',
          'summary': 'Handle dense information while keeping each point easy to follow.',
          'focus': 'Precision',
          'tone': 'Formal',
          'words': '154 words',
          'duration': '~7 min',
        },
      ],
    },
  };

  List<Map<String, String>> get _currentScripts {
    final modeScripts = _scripts[widget.mode] ?? _scripts['Public Speaking']!;
    return modeScripts[_selectedLevel] ?? const [];
  }

  Color get _modeColor {
    switch (widget.mode) {
      case 'Public Speaking':
        return AppColors.primary;
      case 'Daily Conversation':
        return AppColors.accent;
      default:
        return AppColors.success;
    }
  }

  IconData get _modeIcon {
    switch (widget.mode) {
      case 'Public Speaking':
        return Icons.campaign_rounded;
      case 'Daily Conversation':
        return Icons.chat_bubble_outline_rounded;
      default:
        return Icons.description_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.mode),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _sessionStarted
          ? _buildActiveSession()
          : _buildSetupView(),
    );
  }

  // ── Setup View ───────────────────────────────────────────────
  Widget _buildSetupView() {
    final currentScript = _currentScripts[_selectedScript];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _modeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _modeColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _modeColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_modeIcon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.mode,
                          style: TextStyle(
                            
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: _modeColor,
                          )),
                      Text('Level: ${widget.level}',
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _modeColor.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _modeColor.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.tune_rounded, color: _modeColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session Focus',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                          color: _modeColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${currentScript['focus']} for ${widget.mode.toLowerCase()}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Script Selection
          SectionHeader(
            title: 'Choose Script',
            subtitle: '${_currentScripts.length} available',
          ),
          const SizedBox(height: 12),
          ..._currentScripts.asMap().entries.map((entry) {
            final i = entry.key;
            final script = entry.value;
            final selected = _selectedScript == i;
            return GestureDetector(
              onTap: () => setState(() => _selectedScript = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected
                      ? _modeColor.withValues(alpha: 0.07)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? _modeColor : AppColors.divider,
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.cardShadow,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(top: 2, right: 12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? _modeColor : Colors.transparent,
                        border: Border.all(
                          color: selected ? _modeColor : AppColors.textHint,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 13)
                          : null,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(script['title']!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              )),
                          const SizedBox(height: 5),
                          Text(script['summary']!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              )),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _detailChip(_modeColor, script['focus']!),
                              _detailChip(AppColors.accent, script['tone']!),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _chip(Icons.text_fields_rounded,
                                  script['words']!),
                              const SizedBox(width: 10),
                              _chip(Icons.access_time_rounded,
                                  script['duration']!),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 28),
          PrimaryButton(
            label: 'Start Practice Session',
            onPressed: () => setState(() => _sessionStarted = true),
            icon: Icons.mic_rounded,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textHint),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textHint,
            )),
      ],
    );
  }

  Widget _detailChip(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // ── Active Session View ──────────────────────────────────────
  Widget _buildActiveSession() {
    final script = _currentScripts[_selectedScript];
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          // Session info bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                    color: AppColors.cardShadow, blurRadius: 8, offset: Offset(0, 3))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sessionChip(Icons.timer_outlined, '00:32'),
                _sessionChip(Icons.spellcheck_rounded, '12 / 42 words'),
                _sessionChip(Icons.track_changes_rounded, '84%'),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Script text display
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                      color: AppColors.cardShadow,
                      blurRadius: 12,
                      offset: Offset(0, 4))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(script['title']!,
                      style: const TextStyle(
                        
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      )),
                  const Divider(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.9,
                            color: AppColors.textPrimary,
                          ),
                          children: [
                            // Green = correctly said, red = mistake, normal = not yet
                            const TextSpan(
                              text: 'Hello! How are you ',
                              style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text: 'today ',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                                backgroundColor:
                                    AppColors.error.withValues(alpha: 0.1),
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.error,
                              ),
                            ),
                            const TextSpan(
                              text:
                                  '? It is great to see you again. I hope you are doing well and enjoying your day...',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Feedback chip (error shown inline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.error, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'You said "todayy" — correct: "today" /tə-ˈdeɪ/',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.volume_up_rounded,
                    color: AppColors.error.withValues(alpha: 0.7), size: 20),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Controls
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _sessionStarted = false),
                  icon: const Icon(Icons.stop_circle_outlined, size: 20),
                  label: const Text('End'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      setState(() => _isRecording = !_isRecording),
                  icon: Icon(
                    _isRecording ? Icons.pause_rounded : Icons.mic_rounded,
                    size: 20,
                  ),
                  label: Text(_isRecording ? 'Pause' : 'Evaluate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isRecording ? AppColors.warning : AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _sessionChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.accent),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            )),
      ],
    );
  }
}
