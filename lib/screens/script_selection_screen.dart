// lib/screens/script_selection_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import 'active_session_screen.dart';

// ─────────────────────────────────────────────────────────
//  DATA MODELS
// ─────────────────────────────────────────────────────────

enum ScriptMode {
  publicSpeaking('public_speaking', 'Public Speaking', Icons.record_voice_over),
  dailyConversation('daily_conversation', 'Daily Conversation', Icons.chat_bubble_outline),
  scriptBased('script_based', 'Script-Based', Icons.article_outlined);

  final String value;
  final String label;
  final IconData icon;
  const ScriptMode(this.value, this.label, this.icon);

  static ScriptMode fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => scriptBased);
}

enum ProficiencyLevel {
  beginner('beginner', 'Beginner', Color(0xFF16A34A)),
  intermediate('intermediate', 'Intermediate', Color(0xFFD97706)),
  upperIntermediate('upper_intermediate', 'Upper Intermediate', Color(0xFFEA580C)),
  advanced('advanced', 'Advanced', Color(0xFF7C3AED)),
  fluent('fluent', 'Fluent', Color(0xFF2563EB));

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

  // Factory constructor for pre-filtered navigation
  static Widget withFilters({
    required String preselectedMode,
    required String preselectedLevel,
  }) {
    return ScriptSelectionScreen(
      preselectedMode: preselectedMode,
      preselectedLevel: preselectedLevel,
    );
  }

  @override
  State<ScriptSelectionScreen> createState() => _ScriptSelectionState();
}

class _ScriptSelectionState extends State<ScriptSelectionScreen>
    with SingleTickerProviderStateMixin {

  // ── Colors ────────────────────────────────────────────
  static const _primary    = Color(0xFF1A3A6B);
  static const _olive      = Color(0xFF6B7C2A);
  static const _bg         = Color(0xFFF8FAFC);
  static const _cardBg     = Color(0xFFFFFFFF);
  static const _textDark   = Color(0xFF1E293B);
  static const _textGrey   = Color(0xFF64748B);
  static const _border     = Color(0xFFE2E8F0);

  // ── State ─────────────────────────────────────────────
  late TabController _tabs;

  // Step tracking
  int _currentStep = 0; // 0=Mode, 1=Level, 2=Scripts

  ScriptMode? _selectedMode;
  ProficiencyLevel? _selectedLevel;

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
    _tabs = TabController(length: 2, vsync: this);

    // Apply preselected filters if provided
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
    }

    _loadScripts();
  }

  @override
  void dispose() {
    _tabs.dispose();
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
        (data['builtin'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
      _uploadedScripts = List<Map<String, dynamic>>.from(
        (data['uploaded'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    });
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
    _loadScripts();
  }

  void _goBack() {
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

  void _resetFilters() {
    setState(() {
      _currentStep = 0;
      _selectedMode = null;
      _selectedLevel = null;
      _searchQuery = '';
      _searchCtrl.clear();
    });
    _loadScripts();
  }

  // ── Start Practice ──────────────────────────────────
  void _startScript(Map<String, dynamic> script) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ActiveSessionScreen(
        scriptText: script['content'].toString(),
        sessionTitle: script['title'].toString(),
      ),
    ));
  }

  // ── Upload: Text ────────────────────────────────────
  Future<void> _saveTextScript() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();

    if (title.isEmpty) {
      _showError('Please enter a title'); return;
    }
    if (content.split(' ').length < 5) {
      _showError('Script must contain at least 5 words'); return;
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
      _tabs.animateTo(1);
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
      _showError('File picker error: $e'); return;
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
      _tabs.animateTo(1);
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ProficiencyLevel.values.map((l) =>
              RadioListTile<String>(
                title: Text(l.label),
                value: l.value,
                groupValue: selected,
                activeColor: _primary,
                onChanged: (v) => setLocal(() => selected = v!),
              )
            ).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primary),
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
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
                    decoration: _inputDecoration('Paste or type your script here...'),
                  ),
                  const SizedBox(height: 16),
                  _dialogLabel('Difficulty Level'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _uploadLevel,
                    decoration: _inputDecoration(''),
                    items: ProficiencyLevel.values.map((l) =>
                      DropdownMenuItem(value: l.value, child: Text(l.label))
                    ).toList(),
                    onChanged: (v) => setLocal(() => _uploadLevel = v!),
                  ),
                  if (_selectedMode != null) ...[
                    const SizedBox(height: 16),
                    _dialogLabel('Mode'),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_selectedMode!.icon, size: 16, color: _primary),
                          const SizedBox(width: 8),
                          Text(_selectedMode!.label,
                              style: const TextStyle(color: _primary, fontWeight: FontWeight.w600)),
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
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primary),
              onPressed: _saveTextScript,
              child: const Text('Save Script', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogLabel(String text) => Text(
    text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
      backgroundColor: Colors.green.shade700,
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
      backgroundColor: Colors.red.shade700,
      duration: const Duration(seconds: 4),
    ));
  }

  // ── Filtered Lists ──────────────────────────────────
  List<Map<String, dynamic>> get _filteredBuiltin {
    var list = _builtinScripts;
    if (_searchQuery.isNotEmpty) {
      list = list.where((s) =>
        s['title'].toString().toLowerCase().contains(_searchQuery) ||
        s['description'].toString().toLowerCase().contains(_searchQuery)
      ).toList();
    }
    return list;
  }

  List<Map<String, dynamic>> get _filteredUploaded {
    if (_searchQuery.isEmpty) return _uploadedScripts;
    return _uploadedScripts.where((s) =>
      s['title'].toString().toLowerCase().contains(_searchQuery)
    ).toList();
  }

  // ═════════════════════════════════════════════════════
  //  BUILD
  // ═════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _currentStep == 2 ? _buildFab() : null,
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
            child: const Text('Change Mode', style: TextStyle(color: Colors.white70)),
          ),
        ];
        break;
      case 2:
        title = _selectedMode != null
            ? '${_selectedMode!.label} • ${_selectedLevel!.label}'
            : 'All Scripts';
        actions = [
          TextButton(
            onPressed: _resetFilters,
            child: const Text('Reset', style: TextStyle(color: Colors.white70)),
          ),
        ];
        break;
      default:
        title = 'Scripts';
    }

    return AppBar(
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
      bottom: _currentStep == 2
          ? PreferredSize(
              preferredSize: const Size.fromHeight(100),
              child: Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search scripts...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(Icons.search, color: Colors.white54),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white54),
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
                  // Tabs
                  TabBar(
                    controller: _tabs,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    tabs: [
                      const Tab(text: 'Built-in'),
                      Tab(text: 'My Scripts (${_uploadedScripts.length})'),
                    ],
                  ),
                ],
              ),
            )
          : null,
    );
  }

  // ── Body ──────────────────────────────────────────────
  Widget _buildBody() {
    if (_loading && _currentStep == 2) {
      return const Center(child: CircularProgressIndicator(color: _primary));
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What would you like to practice?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textDark),
          ),
          const SizedBox(height: 6),
          Text(
            'Select a practice mode to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),

          ...ScriptMode.values.map((mode) => _modeCard(mode)),

          const SizedBox(height: 24),

          // Quick access to uploaded scripts
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
                child: const Icon(Icons.folder_open_outlined, color: _primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('My Scripts', style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold, color: _textDark)),
                    Text('${_uploadedScripts.length} uploaded scripts',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentStep = 2;
                    _selectedMode = null;
                    _selectedLevel = null;
                  });
                  _loadScripts();
                },
                child: const Text('View All', style: TextStyle(color: _primary)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _modeCard(ScriptMode mode) {
    return GestureDetector(
      onTap: () => _selectMode(mode),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(children: [
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
                Text(mode.label, style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: _textDark)),
                const SizedBox(height: 4),
                Text(
                  _modeDescription(mode),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.4),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
        ]),
      ),
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
                  Text(_selectedMode!.label, style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: _primary)),
                  const Text('Select your proficiency level',
                      style: TextStyle(fontSize: 13, color: _textGrey)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 24),

          ...ProficiencyLevel.values.map((level) => _levelCard(level)),
        ],
      ),
    );
  }

  Widget _levelCard(ProficiencyLevel level) {
    return GestureDetector(
      onTap: () => _selectLevel(level),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(children: [
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
                Text(level.label, style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: _textDark)),
                const SizedBox(height: 2),
                Text(
                  _levelDescription(level),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey.shade300),
        ]),
      ),
    );
  }

  String _levelDescription(ProficiencyLevel level) {
    switch (level) {
      case ProficiencyLevel.beginner:
        return 'Simple vocabulary, short sentences, basic grammar';
      case ProficiencyLevel.intermediate:
        return 'Everyday topics, moderate complexity, common expressions';
      case ProficiencyLevel.upperIntermediate:
        return 'Complex ideas, varied vocabulary, nuanced expressions';
      case ProficiencyLevel.advanced:
        return 'Abstract topics, idiomatic language, precise articulation';
      case ProficiencyLevel.fluent:
        return 'Near-native fluency, professional and academic contexts';
    }
  }

  // ── Step 2: Script List ─────────────────────────────
  Widget _buildScriptList() {
    if (_error != null) return _buildErrorView();

    return TabBarView(
      controller: _tabs,
      children: [
        _buildBuiltinTab(),
        _buildMyScriptsTab(),
      ],
    );
  }

  Widget _buildBuiltinTab() {
    return RefreshIndicator(
      onRefresh: () => _loadScripts(silent: true),
      color: _primary,
      child: _filteredBuiltin.isEmpty
          ? _buildEmptyView(
              icon: Icons.library_books_outlined,
              message: _builtinScripts.isEmpty
                  ? 'No scripts found for this mode & level'
                  : 'No scripts match your search',
              hint: _builtinScripts.isEmpty
                  ? 'Try a different level or upload your own'
                  : 'Try a different search term',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: _filteredBuiltin.length,
              itemBuilder: (ctx, i) => _scriptCard(_filteredBuiltin[i], isBuiltin: true),
            ),
    );
  }

  Widget _buildMyScriptsTab() {
    return RefreshIndicator(
      onRefresh: () => _loadScripts(silent: true),
      color: _primary,
      child: _filteredUploaded.isEmpty
          ? _buildEmptyView(
              icon: Icons.folder_open_outlined,
              message: 'No custom scripts yet',
              hint: 'Tap the + button to upload or type a script',
              showAddButton: true,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: _filteredUploaded.length,
              itemBuilder: (ctx, i) => _scriptCard(_filteredUploaded[i], isBuiltin: false),
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
            children: [
              // Title + level badge
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(
                    script['title'] ?? 'Untitled',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold, color: _textDark),
                  ),
                ),
                const SizedBox(width: 8),
                _levelBadge(profLevel),
              ]),

              // Description
              if (script['description'] != null &&
                  script['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  script['description'],
                  style: const TextStyle(fontSize: 12, color: _textGrey),
                ),
              ],

              const SizedBox(height: 10),

              // Preview
              Text(
                preview,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF94A3B8), height: 1.45),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // Footer
              Row(children: [
                Icon(Icons.text_fields_rounded, size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text('$wordCount words',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                const SizedBox(width: 12),
                if (isBuiltin) ...[
                  Icon(Icons.verified_rounded, size: 13, color: Colors.blue.shade400),
                  const SizedBox(width: 4),
                  Text('PronounceMate',
                      style: TextStyle(fontSize: 11, color: Colors.blue.shade400)),
                ] else ...[
                  Icon(Icons.person_outline_rounded, size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text('Your script',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                ],
                const Spacer(),
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
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ]),
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
                  Icon(icon, size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text(hint,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
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
            Icon(Icons.wifi_off, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Could not load scripts',
                style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadScripts,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Add Your Script',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: _textDark)),
            const SizedBox(height: 4),
            Text(
              'Choose how you want to add a new practice script',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),
            _uploadOptionTile(
              icon: Icons.upload_file_outlined,
              iconColor: const Color(0xFF0F6E56),
              iconBg: const Color(0xFFE0F7F7),
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
              iconBg: const Color(0xFFEBF4FF),
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
                        fontSize: 15, fontWeight: FontWeight.bold, color: _textDark)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey.shade300),
        ]),
      ),
    );
  }
}