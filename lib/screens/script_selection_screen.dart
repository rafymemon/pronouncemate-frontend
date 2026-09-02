// lib/screens/script_selection_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'active_session_screen.dart';

// ─────────────────────────────────────────────────────────
//  DATA MODELS
// ─────────────────────────────────────────────────────────

enum ScriptMode {
  publicSpeaking('public_speaking', 'Public Speaking', Icons.record_voice_over),
  dailyConversation(
      'daily_conversation', 'Daily Conversation', Icons.chat_bubble_outline),
  scriptBased('script_based', 'Script-Based', Icons.article_outlined);

  final String value;
  final String label;
  final IconData icon;
  const ScriptMode(this.value, this.label, this.icon);

  static ScriptMode fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => scriptBased);
}

enum ProficiencyLevel {
  beginner('beginner', 'Beginner', AppColors.accentLight),
  intermediate('intermediate', 'Intermediate', AppColors.accent),
  expert('expert', 'Expert', AppColors.primaryDark);

  final String value;
  final String label;
  final Color color;
  const ProficiencyLevel(this.value, this.label, this.color);

  static ProficiencyLevel fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => beginner);
}

// ─────────────────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────────────────

class ScriptSelectionScreen extends StatefulWidget {
  final String? preselectedMode;
  final String? preselectedLevel;

  const ScriptSelectionScreen({
    super.key,
    this.preselectedMode,
    this.preselectedLevel,
  });

  static Widget withFilters({
    required String preselectedMode,
    String? preselectedLevel, // now optional — Script-Based won't pass one
  }) {
    return ScriptSelectionScreen(
      preselectedMode: preselectedMode,
      preselectedLevel: preselectedLevel,
    );
  }

  @override
  State<ScriptSelectionScreen> createState() => _ScriptSelectionState();
}

class _ScriptSelectionState extends State<ScriptSelectionScreen> {
  // ── Colors ────────────────────────────────────────────
  static const _primary = AppColors.primary;
  static const _bg = AppColors.screenBackground;
  static const _cardBg = AppColors.surface;
  static const _textDark = AppColors.textPrimary;
  static const _textGrey = AppColors.textSecondary;
  static const _border = AppColors.softBorder;

  // ── State ─────────────────────────────────────────────
  int _currentStep = 0;
  ScriptMode? _selectedMode;
  ProficiencyLevel? _selectedLevel;

  bool get _isScriptBasedMode => _selectedMode == ScriptMode.scriptBased;

  // Data
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _builtinScripts = [];
  List<Map<String, dynamic>> _uploadedScripts = [];

  // Filters & Search
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  // Upload controllers
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  String _uploadLevel = 'intermediate';

  // ── Lifecycle ─────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    if (widget.preselectedMode != null) {
      try {
        _selectedMode = ScriptMode.fromValue(widget.preselectedMode!);
        _currentStep = 1;
      } catch (_) {
        _selectedMode = null;
      }
    }

    if (widget.preselectedLevel != null && _selectedMode != null) {
      try {
        _selectedLevel = ProficiencyLevel.fromValue(widget.preselectedLevel!);
        _currentStep = 2;
      } catch (_) {
        _selectedLevel = null;
        _currentStep = 1;
      }
    } else if (_selectedMode == ScriptMode.scriptBased) {
      // Script-Based never needs a proficiency level — skip straight
      // to the script list (My Scripts only — no built-in library here).
      _currentStep = 2;
    }

    if (_currentStep == 2 && !_isScriptBasedMode) {
      _loadRandomScripts();
    } else {
      _loadScripts();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  // ── Data Loading ────────────────────────────────────
  Future<void> _loadScripts({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    _error = null;

    final data = await ApiService.getScripts(
      mode: _selectedMode?.value,
      level: _selectedLevel?.value,
    );

    if (!mounted) return;

    if (data['error'] != null) {
      setState(() {
        _loading = false;
        _error = data['error'].toString();
      });
      return;
    }

    setState(() {
      _loading = false;
      _builtinScripts = List<Map<String, dynamic>>.from(
        (data['builtin'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e)),
      );
      _uploadedScripts = List<Map<String, dynamic>>.from(
        (data['uploaded'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e)),
      );
    });
  }

  static const int _randomBatchSize = 5;

  Future<void> _loadRandomScripts({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final result = await ApiService.getRotatedScripts(
      mode: _selectedMode?.value,
      level: _selectedLevel?.value,
      count: _randomBatchSize,
    );

    if (!mounted) return;

    if (result['error'] != null) {
      setState(() {
        _loading = false;
        _error = result['error'].toString();
      });
      return;
    }

    setState(() {
      _loading = false;
      _error = null;
      _builtinScripts =
          List<Map<String, dynamic>>.from(result['scripts'] ?? []);
    });
  }

  Future<void> _refreshScripts() {
    if (_isScriptBasedMode) {
      return _loadScripts(silent: true);
    }
    return _loadRandomScripts(silent: true);
  }

  void _retryLoad() {
    if (_isScriptBasedMode) {
      _loadScripts();
    } else {
      _loadRandomScripts();
    }
  }

  // ── Navigation Helpers ──────────────────────────────
  void _selectMode(ScriptMode mode) {
    setState(() {
      _selectedMode = mode;
      _currentStep = 1;
    });
  }

  void _selectLevel(ProficiencyLevel level) {
    setState(() {
      _selectedLevel = level;
      _currentStep = 2;
    });

    if (_isScriptBasedMode) {
      _loadScripts();
    } else {
      _loadRandomScripts();
    }
  }

   void _goBack() {
    if (_currentStep == 2 &&
        widget.preselectedMode != null &&
        (widget.preselectedLevel != null || _isScriptBasedMode)) {
      Navigator.pop(context);
      return;
    }

    if (_currentStep > 0) {
      setState(() => _currentStep--);
      if (_currentStep == 0) {
        _selectedMode = null;
        _selectedLevel = null;
      } else if (_currentStep == 1) {
        _selectedLevel = null;
      }
    }
  }

  // ── Start Practice ──────────────────────────────────
  void _startScript(Map<String, dynamic> script) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveSessionScreen(
            scriptText: script['content'].toString(),
            scriptId: script['id']?.toString(),
            sessionTitle: script['title'].toString(),
          ),
        ));
  }

  // ── Upload: Text ────────────────────────────────────
  Future<void> _saveTextScript() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();

    if (title.isEmpty) {
      _showError('Please enter a title');
      return;
    }
    if (content.split(' ').length < 5) {
      _showError('Script must contain at least 5 words');
      return;
    }

    Navigator.pop(context);
    _showLoading('Saving script...');

    final result = await ApiService.uploadScriptText(
      title: title,
      content: content,
      level: _uploadLevel,
      mode: _selectedMode?.value,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (result['id'] != null) {
      _titleCtrl.clear();
      _contentCtrl.clear();
      await _loadScripts(silent: true);
      _showSuccess('Script saved successfully');
    } else {
      _showError(result['error']?.toString() ?? 'Failed to save');
    }
  }

  // ── Upload: File ────────────────────────────────────
  Future<void> _pickAndUploadFile() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'docx'],
        allowMultiple: false,
      );
    } catch (e) {
      _showError('File picker error: $e');
      return;
    }

    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.first;
    final file = File(pickedFile.path!);
    final rawName = pickedFile.name
        .replaceAll(RegExp(r'\.\w+$'), '')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim();

    final level = await _showLevelPicker();
    if (level == null) return;

    _showLoading('Uploading ${pickedFile.name}...');

    final uploadResult = await ApiService.uploadScriptFile(
      file,
      title: rawName,
      level: level,
      mode: _selectedMode?.value,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (uploadResult['id'] != null) {
      await _loadScripts(silent: true);
      _showSuccess('File uploaded — "${uploadResult['title']}" ready');
    } else {
      _showError(uploadResult['error']?.toString() ?? 'Upload failed');
    }
  }

  Future<String?> _showLevelPicker() async {
    String selected = _selectedLevel?.value ?? 'intermediate';
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Select Difficulty Level'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: ProficiencyLevel.values
                    .map((l) => RadioListTile<String>(
                          title: Text(l.label),
                          value: l.value,
                          groupValue: selected,
                          activeColor: _primary,
                          onChanged: (v) => setLocal(() => selected = v!),
                        ))
                    .toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primary),
              onPressed: () => Navigator.pop(ctx, selected),
              child:
                  const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Upload Dialogs ──────────────────────────────────
  void _showTextDialog() {
    _uploadLevel = _selectedLevel?.value ?? 'intermediate';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add Custom Script'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dialogLabel('Title'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _titleCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration('e.g. Job Interview Practice'),
                  ),
                  const SizedBox(height: 16),
                  _dialogLabel('Script Content'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _contentCtrl,
                    maxLines: 6,
                    decoration:
                        _inputDecoration('Paste or type your script here...'),
                  ),
                  const SizedBox(height: 16),
                  _dialogLabel('Difficulty Level'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _uploadLevel,
                    decoration: _inputDecoration(''),
                    isExpanded: true,
                    items: ProficiencyLevel.values
                        .map((l) => DropdownMenuItem(
                            value: l.value, child: Text(l.label)))
                        .toList(),
                    onChanged: (v) => setLocal(() => _uploadLevel = v!),
                  ),
                  if (_selectedMode != null) ...[
                    const SizedBox(height: 16),
                    _dialogLabel('Mode'),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: _primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_selectedMode!.icon, size: 16, color: _primary),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _selectedMode!.label,
                              style: const TextStyle(
                                  color: _primary, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
              onPressed: _saveTextScript,
              child: const Text('Save Script',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
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

  // ── Snackbars & Dialogs ─────────────────────────────
  void _showLoading(String msg) {
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

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: AppColors.success,
      duration: const Duration(seconds: 3),
    ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: AppColors.error,
      duration: const Duration(seconds: 4),
    ));
  }

  // ── Filtered List (My Scripts search) ────────────────
  List<Map<String, dynamic>> get _filteredUploaded {
    if (_searchQuery.isEmpty) return _uploadedScripts;
    return _uploadedScripts
        .where(
            (s) => s['title'].toString().toLowerCase().contains(_searchQuery))
        .toList();
  }

  // ═════════════════════════════════════════════════════
  //  RESPONSIVE HELPERS
  // ═════════════════════════════════════════════════════

  bool get _isWideScreen {
    final width = MediaQuery.of(context).size.width;
    return width > 600;
  }

  int get _modeGridCrossAxisCount {
    final width = MediaQuery.of(context).size.width;
    if (width > 900) return 3;
    if (width > 600) return 2;
    return 1;
  }

  // ═════════════════════════════════════════════════════
  //  BUILD
  // ═════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: SafeArea(child: _buildBody()),
      floatingActionButton:
          _currentStep == 2 && _isScriptBasedMode ? _buildFab() : null,
    );
  }

  // ── AppBar ────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    String title;
    List<Widget>? actions;

    switch (_currentStep) {
      case 0:
        title = 'Choose a Mode';
        break;
      case 1:
        title = '${_selectedMode!.label} — Select Level';
        actions = [
          TextButton(
            onPressed: _goBack,
            child: const Text('Change Mode',
                style: TextStyle(color: Colors.white70)),
          ),
        ];
        break;
       case 2:
        title = _isScriptBasedMode
            ? 'My Scripts'
            : (_selectedMode != null
                ? (_selectedLevel != null
                    ? '${_selectedMode!.label} • ${_selectedLevel!.label}'
                    : _selectedMode!.label)
                : 'All Scripts');
        break;
      default:
        title = 'Scripts';
    }

    return AppBar(
      title: Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis),
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: _currentStep > 0
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _goBack,
            )
          : null,
      actions: actions,
      // Script-Based mode only: search bar for "My Scripts". No tabs
      // anymore — built-in scripts were never meant to appear here.
      bottom: _currentStep == 2 && _isScriptBasedMode
          ? PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight + 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.toLowerCase()),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search your scripts...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon:
                        const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: Colors.white54),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  // ── Body ──────────────────────────────────────────────
  Widget _buildBody() {
    if (_loading && _currentStep == 2) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _primary),
            if (!_isScriptBasedMode) ...[
              const SizedBox(height: 16),
              const Text(
                'Finding fresh scripts for you...',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      );
    }

    switch (_currentStep) {
      case 0:
        return _buildModeSelection();
      case 1:
        return _buildLevelSelection();
      case 2:
        return _buildScriptList();
      default:
        return const Center(child: Text('Something went wrong'));
    }
  }

  // ── Step 0: Mode Selection ──────────────────────────
  Widget _buildModeSelection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _modeGridCrossAxisCount;
        final isGrid = crossAxisCount > 1;

        if (isGrid) {
          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 1.4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: ScriptMode.values.length,
            itemBuilder: (ctx, i) =>
                _modeCard(ScriptMode.values[i], isGrid: true),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What would you like to practice?',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _textDark),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select a practice mode to get started',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              ...ScriptMode.values
                  .map((mode) => _modeCard(mode, isGrid: false)),
              const SizedBox(height: 24),
              if (_selectedMode == ScriptMode.scriptBased) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.folder_open_outlined,
                          color: _primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('My Scripts',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: _textDark)),
                          Text('${_uploadedScripts.length} uploaded scripts',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _currentStep = 2;
                          _selectedMode = ScriptMode.scriptBased;
                          _selectedLevel = null;
                        });
                        _loadScripts();
                      },
                      child: const Text('View All',
                          style: TextStyle(color: _primary)),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _modeCard(ScriptMode mode, {required bool isGrid}) {
    final card = InkWell(
      onTap: () => _selectMode(mode),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isGrid
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(mode.icon, color: _primary, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    mode.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _textDark),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _modeDescription(mode),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted, height: 1.4),
                  ),
                ],
              )
            : Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(mode.icon, color: _primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mode.label,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _textDark)),
                      const SizedBox(height: 4),
                      Text(
                        _modeDescription(mode),
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textFaint),
              ]),
      ),
    );

    if (isGrid) return card;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: card,
    );
  }

  String _modeDescription(ScriptMode mode) {
    switch (mode) {
      case ScriptMode.publicSpeaking:
        return 'Practice speeches, presentations, and formal addresses with structured scripts';
      case ScriptMode.dailyConversation:
        return 'Improve casual dialogue, small talk, and everyday English interactions';
      case ScriptMode.scriptBased:
        return 'Follow along with movie lines, speeches, or any custom text you provide';
    }
  }

  // ── Step 1: Level Selection ───────────────────────────
  Widget _buildLevelSelection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = MediaQuery.of(context).size.width;
        final isWide = width > 600;

        if (isWide) {
          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: ProficiencyLevel.values.length,
            itemBuilder: (ctx, i) =>
                _levelCard(ProficiencyLevel.values[i], isGrid: true),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_selectedMode!.icon, color: _primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selectedMode!.label,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _primary)),
                      Text(
                        _isScriptBasedMode
                            ? 'Select your proficiency level'
                            : "Select your level — we'll pick a few fresh scripts for you",
                        style: const TextStyle(fontSize: 13, color: _textGrey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              ...ProficiencyLevel.values
                  .map((level) => _levelCard(level, isGrid: false)),
            ],
          ),
        );
      },
    );
  }

  Widget _levelCard(ProficiencyLevel level, {required bool isGrid}) {
    final card = InkWell(
      onTap: () => _selectLevel(level),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: isGrid
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: level.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    level.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _textDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _levelDescription(level),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              )
            : Row(children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: level.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(level.label,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _textDark)),
                      const SizedBox(height: 2),
                      Text(
                        _levelDescription(level),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textFaint),
              ]),
      ),
    );

    if (isGrid) return card;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: card,
    );
  }

  String _levelDescription(ProficiencyLevel level) {
    switch (level) {
      case ProficiencyLevel.beginner:
        return 'Simple vocabulary, short sentences, basic grammar';
      case ProficiencyLevel.intermediate:
        return 'Everyday topics, moderate complexity, common expressions';
      case ProficiencyLevel.expert:
        return 'Abstract topics, idiomatic language, near-native fluency';
    }
  }

  // ── Step 2: Script List ──────────────────────────────
  // Script-Based mode: "My Scripts" only — built-in scripts were never
  // meant to appear here (per product decision). Other modes: unchanged,
  // rotated built-in picks with no tabs, as before.
  Widget _buildScriptList() {
    if (_error != null) return _buildErrorView();

    if (_isScriptBasedMode) {
      return _buildMyScriptsList();
    }
    return _buildBuiltinRotationList();
  }

  Widget _buildBuiltinRotationList() {
    return RefreshIndicator(
      onRefresh: _refreshScripts,
      color: _primary,
      child: _builtinScripts.isEmpty
          ? _buildEmptyView(
              icon: Icons.library_books_outlined,
              message: 'No scripts found for this mode & level',
              hint: 'Pull down to try fetching scripts again',
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = MediaQuery.of(context).size.width;
                final isWide = width > 700;

                if (isWide) {
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: width > 1100 ? 3 : 2,
                      childAspectRatio: 1.6,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _builtinScripts.length,
                    itemBuilder: (ctx, i) =>
                        _scriptCard(_builtinScripts[i], isBuiltin: true),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: _builtinScripts.length,
                  itemBuilder: (ctx, i) =>
                      _scriptCard(_builtinScripts[i], isBuiltin: true),
                );
              },
            ),
    );
  }

  Widget _buildMyScriptsList() {
    return RefreshIndicator(
      onRefresh: () => _loadScripts(silent: true),
      color: _primary,
      child: _filteredUploaded.isEmpty
          ? _buildEmptyView(
              icon: Icons.folder_open_outlined,
              message: _uploadedScripts.isEmpty
                  ? 'No custom scripts yet'
                  : 'No scripts match your search',
              hint: _uploadedScripts.isEmpty
                  ? 'Tap the + button to upload or type a script'
                  : 'Try a different search term',
              showAddButton: _uploadedScripts.isEmpty,
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = MediaQuery.of(context).size.width;
                final isWide = width > 700;

                if (isWide) {
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: width > 1100 ? 3 : 2,
                      childAspectRatio: 1.6,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _filteredUploaded.length,
                    itemBuilder: (ctx, i) =>
                        _scriptCard(_filteredUploaded[i], isBuiltin: false),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: _filteredUploaded.length,
                  itemBuilder: (ctx, i) =>
                      _scriptCard(_filteredUploaded[i], isBuiltin: false),
                );
              },
            ),
    );
  }

  // ── Script Card ─────────────────────────────────────
  Widget _scriptCard(Map<String, dynamic> script, {required bool isBuiltin}) {
    final level = script['level']?.toString() ?? 'beginner';
    final wordCount = script['word_count'] as int? ?? 0;
    final content = script['content']?.toString() ?? '';
    final preview = script['preview']?.toString() ??
        (content.length > 100 ? '${content.substring(0, 100)}...' : content);

    final profLevel = ProficiencyLevel.fromValue(level);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _startScript(script),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title + level badge — WRAP instead of Row to prevent overflow
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.55,
                    ),
                    child: Text(
                      script['title'] ?? 'Untitled',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _textDark),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  _levelBadge(profLevel),
                ],
              ),

              // Description
              if (script['description'] != null &&
                  script['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  script['description'],
                  style: const TextStyle(fontSize: 12, color: _textGrey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 10),

              // Preview
              Text(
                preview,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textMuted, height: 1.45),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // Footer — meta info wraps on narrow screens, button stays
              // pinned to the trailing edge (Row + Expanded, not Spacer
              // inside Wrap — Spacer needs a single-axis Flex parent).
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.text_fields_rounded,
                                size: 13, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text('$wordCount words',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                        if (isBuiltin) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded,
                                  size: 13, color: AppColors.accent),
                              const SizedBox(width: 4),
                              const Text('PronounceMate',
                                  style: TextStyle(
                                      fontSize: 11, color: AppColors.accent)),
                            ],
                          ),
                        ] else ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_outline_rounded,
                                  size: 13, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              const Text('Your script',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _startScript(script),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(80, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Practice',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _levelBadge(ProficiencyLevel level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: level.color.withValues(alpha: 0.25)),
      ),
      child: Text(
        level.label,
        style: TextStyle(
            fontSize: 11, color: level.color, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── Empty State ─────────────────────────────────────
  Widget _buildEmptyView({
    required IconData icon,
    required String message,
    required String hint,
    bool showAddButton = false,
  }) {
    return LayoutBuilder(
      builder: (ctx, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 60, color: AppColors.textFaint),
                  const SizedBox(height: 16),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text(hint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                  if (showAddButton) ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _showUploadOptions,
                      icon: const Icon(Icons.add),
                      label: const Text('Add a Script'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'Could not load scripts',
              style: TextStyle(
                  fontSize: 18,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _retryLoad,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── FAB ─────────────────────────────────────────────
  Widget? _buildFab() {
    return FloatingActionButton.extended(
      onPressed: _showUploadOptions,
      backgroundColor: _primary,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text('Add Script', style: TextStyle(color: Colors.white)),
    );
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textFaint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Add Your Script',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textDark)),
              const SizedBox(height: 4),
              const Text(
                'Choose how you want to add a new practice script',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              _uploadOptionTile(
                icon: Icons.upload_file_outlined,
                iconColor: AppColors.accent,
                iconBg: AppColors.surfaceVariant,
                title: 'Upload a File',
                subtitle: 'Supports .txt and .docx formats',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadFile();
                },
              ),
              const SizedBox(height: 10),
              _uploadOptionTile(
                icon: Icons.edit_note_outlined,
                iconColor: _primary,
                iconBg: _primary.withValues(alpha: 0.1),
                title: 'Type or Paste Text',
                subtitle: 'Write your own script directly',
                onTap: () {
                  Navigator.pop(ctx);
                  _showTextDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _uploadOptionTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _textDark)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textFaint),
        ]),
      ),
    );
  }
}