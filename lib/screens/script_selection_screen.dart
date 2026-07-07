// lib/screens/script_selection_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import 'active_session_screens.dart';

class ScriptSelectionScreen extends StatefulWidget {
  // 1. Declare the variables we need to receive from the Home Screen
  final int initialTabIndex;
  final bool openUploadOptions;

  const ScriptSelectionScreen({
    super.key,
    this.initialTabIndex = 0,
    this.openUploadOptions = false,
  });

  @override
  State<ScriptSelectionScreen> createState() => _ScriptSelectionState();
}

class _ScriptSelectionState extends State<ScriptSelectionScreen>
    with SingleTickerProviderStateMixin {

  // ── State ──────────────────────────────────────────────
  late TabController _tabs;
  bool    _loading      = true;
  String? _errorMessage;
  String  _selectedLevel = 'all';
  String  _searchQuery   = '';

  List<Map<String, dynamic>> _builtin  = [];
  List<Map<String, dynamic>> _uploaded = [];

  // Controllers for manual text entry
  final _titleCtrl   = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _searchCtrl  = TextEditingController();
  String _uploadLevel = 'intermediate';

  @override
  void initState() {
    super.initState();
    
    // 2. Initialize the tabs using the starting index passed in the constructor
    _tabs = TabController(
      length: 3, 
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    
    _loadScripts();

    // 3. Automatically trigger the upload flow if requested
    if (widget.openUploadOptions) {
      // We must wait for the screen to render its first frame before showing dialogs
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Call whatever method you use to show the upload options here!
        // Example: _showUploadDialog(); 
      });
    }
  }

  // ── Load from backend ──────────────────────────────────
  Future<void> _loadScripts({bool showRefreshIndicator = false}) async {
    if (!showRefreshIndicator) {
      setState(() { _loading = true; _errorMessage = null; });
    }

    final data = await ApiService.getScripts();

    if (!mounted) return;

    if (data['error'] != null) {
      setState(() {
        _loading      = false;
        _errorMessage = data['error'].toString();
      });
      return;
    }

    setState(() {
      _loading = false;
      _builtin = List<Map<String, dynamic>>.from(
          (data['builtin'] as List? ?? []).map((e) => Map<String, dynamic>.from(e))
      );
      _uploaded = List<Map<String, dynamic>>.from(
          (data['uploaded'] as List? ?? []).map((e) => Map<String, dynamic>.from(e))
      );
    });
  }

  // ── Filtered lists ─────────────────────────────────────
  List<Map<String, dynamic>> get _filteredBuiltin {
    var list = _builtin;
    if (_selectedLevel != 'all') {
      list = list.where((s) => s['level'] == _selectedLevel).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list.where((s) =>
        s['title'].toString().toLowerCase().contains(_searchQuery) ||
        s['description'].toString().toLowerCase().contains(_searchQuery)
      ).toList();
    }
    return list;
  }

  List<Map<String, dynamic>> get _filteredUploaded {
    if (_searchQuery.isEmpty) return _uploaded;
    return _uploaded.where((s) =>
      s['title'].toString().toLowerCase().contains(_searchQuery)
    ).toList();
  }

  // ── Navigate to practice ───────────────────────────────
  void _startScript(Map<String, dynamic> script) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ActiveSessionScreen(
        scriptText:   script['content'].toString(),
        sessionTitle: script['title'].toString(),
      ),
    ));
  }

  // ── Upload: paste text ─────────────────────────────────
  Future<void> _saveTextScript() async {
    final title   = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();

    if (title.isEmpty) {
      _showError('Please enter a title'); return;
    }
    if (content.split(' ').length < 5) {
      _showError('Script must contain at least 5 words'); return;
    }

    Navigator.pop(context); // close dialog
    _showLoading('Saving script...');

    final result = await ApiService.uploadScriptText(
      title:   title,
      content: content,
      level:   _uploadLevel,
    );

    if (!mounted) return;
    Navigator.pop(context); // close loading

    if (result['id'] != null) {
      _titleCtrl.clear();
      _contentCtrl.clear();
      await _loadScripts(showRefreshIndicator: true);
      _tabs.animateTo(1); // switch to My Scripts
      _showSuccess('Script saved successfully');
    } else {
      _showError(result['error']?.toString() ?? 'Failed to save script');
    }
  }

  // ── Upload: pick file ──────────────────────────────────
  Future<void> _pickAndUploadFile() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type:             FileType.custom,
        allowedExtensions: ['txt', 'docx'],
        allowMultiple:    false,
      );
    } catch (e) {
      _showError('File picker error: $e'); return;
    }

    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.first;
    final file       = File(pickedFile.path!);
    final rawName    = pickedFile.name
        .replaceAll(RegExp(r'\.\w+$'), '')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim();

    // Ask for level before uploading
    final level = await _showLevelPicker();
    if (level == null) return;

    _showLoading('Uploading ${pickedFile.name}...');

    final uploadResult = await ApiService.uploadScriptFile(
      file,
      title: rawName,
      level: level,
    );

    if (!mounted) return;
    Navigator.pop(context); // close loading

    if (uploadResult['id'] != null) {
      await _loadScripts(showRefreshIndicator: true);
      _tabs.animateTo(1);
      _showSuccess('File uploaded — "${uploadResult['title']}" ready to practice');
    } else {
      _showError(uploadResult['error']?.toString() ?? 'Upload failed');
    }
  }

  Future<String?> _showLevelPicker() async {
    String selected = 'intermediate';
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Select Difficulty Level'),
          content: Column(mainAxisSize: MainAxisSize.min,
            children: ['beginner', 'intermediate', 'advanced'].map((l) =>
              RadioListTile<String>(
                title: Text(l[0].toUpperCase() + l.substring(1)),
                value: l,
                groupValue: selected,
                activeColor: const Color(0xFF1A3A6B),
                onChanged: (v) => setLocal(() => selected = v!),
              )
            ).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A3A6B)),
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('Confirm',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Upload dialog: paste text ──────────────────────────
  void _showTextDialog() {
    _uploadLevel = 'intermediate';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add Custom Script'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Title', style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecoration('e.g. Job Interview Practice'),
                ),
                const SizedBox(height: 16),
                const Text('Script Content',
                    style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                const SizedBox(height: 6),
                TextField(
                  controller: _contentCtrl,
                  maxLines: 6,
                  decoration: _inputDecoration('Paste or type your script here...'),
                ),
                const SizedBox(height: 16),
                const Text('Difficulty Level',
                    style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _uploadLevel,
                  decoration: _inputDecoration(''),
                  items: const [
                    DropdownMenuItem(value: 'beginner',
                        child: Text('Beginner')),
                    DropdownMenuItem(value: 'intermediate',
                        child: Text('Intermediate')),
                    DropdownMenuItem(value: 'advanced',
                        child: Text('Advanced')),
                  ],
                  onChanged: (v) => setLocal(() => _uploadLevel = v!),
                ),
              ],
            )),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A3A6B)),
              onPressed: _saveTextScript,
              child: const Text('Save Script',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF1A3A6B), width: 1.5),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────
  void _showLoading(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          content: Row(children: [
            const CircularProgressIndicator(color: Color(0xFF1A3A6B)),
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

  // ── Build ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Choose a Script'),
        backgroundColor: const Color(0xFF1A3A6B),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(90),
          child: Column(children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(
                    () => _searchQuery = v.toLowerCase()),
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
              labelStyle: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w600),
              tabs: [
                const Tab(text: 'Built-in'),
                Tab(text: 'My Scripts (${_uploaded.length})'),
                const Tab(text: 'Browse Files'),
              ],
            ),
          ]),
        ),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator(
              color: Color(0xFF1A3A6B)))
          : _errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _buildBuiltinTab(),
                    _buildMyScriptsTab(),
                    _buildBrowseTab(),
                  ],
                ),
    );
  }

  // ── Error view ─────────────────────────────────────────
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Icon(Icons.wifi_off, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('Could not load scripts',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(_errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadScripts,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A3A6B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
      ),
    );
  }

  // ══ TAB 1 — Built-in Scripts ════════════════════════════
  Widget _buildBuiltinTab() {
    return Column(children: [
      // Level filter chips
      SizedBox(
        height: 52,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          scrollDirection: Axis.horizontal,
          children: ['all', 'beginner', 'intermediate', 'advanced']
              .map((l) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        l == 'all' ? 'All Levels'
                            : l[0].toUpperCase() + l.substring(1),
                        style: TextStyle(
                          fontSize: 12,
                          color: _selectedLevel == l
                              ? Colors.white
                              : const Color(0xFF475569),
                        ),
                      ),
                      selected: _selectedLevel == l,
                      onSelected: (_) =>
                          setState(() => _selectedLevel = l),
                      selectedColor: const Color(0xFF1A3A6B),
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: _selectedLevel == l
                            ? Colors.transparent
                            : const Color(0xFFCBD5E1),
                      ),
                      showCheckmark: false,
                    ),
                  ))
              .toList(),
        ),
      ),

      // Script list
      Expanded(
        child: RefreshIndicator(
          onRefresh: () => _loadScripts(showRefreshIndicator: true),
          color: const Color(0xFF1A3A6B),
          child: _filteredBuiltin.isEmpty
              ? _buildEmptyView(
                  icon: Icons.library_books_outlined,
                  message: _builtin.isEmpty
                      ? 'No built-in scripts found.\nCheck server connection.'
                      : 'No scripts match this filter.',
                  hint: _builtin.isEmpty
                      ? 'Run: python manage.py seed_scripts'
                      : 'Try selecting a different level.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: _filteredBuiltin.length,
                  itemBuilder: (ctx, i) =>
                      _scriptCard(_filteredBuiltin[i], isBuiltin: true),
                ),
        ),
      ),
    ]);
  }

  // ══ TAB 2 — My Uploaded Scripts ════════════════════════
  Widget _buildMyScriptsTab() {
    return RefreshIndicator(
      onRefresh: () => _loadScripts(showRefreshIndicator: true),
      color: const Color(0xFF1A3A6B),
      child: _filteredUploaded.isEmpty
          ? _buildEmptyView(
              icon: Icons.folder_open_outlined,
              message: 'No custom scripts yet',
              hint: 'Use Browse Files tab to upload a .txt or .docx file,\n'
                  'or use the + button to type a script',
              showAddButton: true,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: _filteredUploaded.length,
              itemBuilder: (ctx, i) =>
                  _scriptCard(_filteredUploaded[i], isBuiltin: false),
            ),
    );
  }

  // ══ TAB 3 — Browse Files ════════════════════════════════
  Widget _buildBrowseTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [

        // Header
        const Text('Add Your Own Script',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                color: Color(0xFF1A3A6B))),
        const SizedBox(height: 6),
        const Text(
          'Upload a file from your device or type the script manually.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 28),

        // Option A — Upload file
        _browseOptionCard(
          icon: Icons.upload_file_outlined,
          iconColor: const Color(0xFF0F6E56),
          iconBg: const Color(0xFFE0F7F7),
          title: 'Upload a File',
          subtitle: 'Supports .txt and .docx formats',
          bullets: const [
            'Text file (.txt) — plain text, one paragraph',
            'Word document (.docx) — any Word document',
            'Text is extracted automatically',
          ],
          buttonLabel: 'Choose File',
          buttonColor: const Color(0xFF0F6E56),
          onTap: _pickAndUploadFile,
        ),

        const SizedBox(height: 16),

        // Option B — Type manually
        _browseOptionCard(
          icon: Icons.edit_note_outlined,
          iconColor: const Color(0xFF1A3A6B),
          iconBg: const Color(0xFFEBF4FF),
          title: 'Type or Paste Text',
          subtitle: 'Write your own script directly in the app',
          bullets: const [
            'Paste any English text',
            'Good for job interview answers',
            'Good for presentation scripts',
          ],
          buttonLabel: 'Open Editor',
          buttonColor: const Color(0xFF1A3A6B),
          onTap: _showTextDialog,
        ),

        const SizedBox(height: 28),

        // Format note
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline,
                  color: Color(0xFFD97706), size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tips for best results',
                        style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E))),
                    SizedBox(height: 4),
                    Text(
                      '• Use clear, complete English sentences\n'
                      '• Avoid bullet points or numbered lists\n'
                      '• Recommended length: 30 to 100 words\n'
                      '• Avoid abbreviations like "etc." or "govt."',
                      style: TextStyle(fontSize: 12,
                          color: Color(0xFF78350F), height: 1.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _browseOptionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required List<String> bullets,
    required String buttonLabel,
    required Color buttonColor,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B))),
            Text(subtitle, style: const TextStyle(
                fontSize: 12, color: Color(0xFF94A3B8))),
          ])),
        ]),
        const SizedBox(height: 14),
        ...bullets.map((b) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Icon(Icons.check_circle_outline, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Text(b, style: const TextStyle(
                fontSize: 12, color: Color(0xFF475569))),
          ]),
        )),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text(buttonLabel,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  // ══ Script Card (shared by Tab 1 and Tab 2) ═════════════
  Widget _scriptCard(Map<String, dynamic> script,
      {required bool isBuiltin}) {

    final level     = script['level']?.toString() ?? 'beginner';
    final wordCount = script['word_count'] as int? ?? 0;
    final preview   = script['preview']?.toString() ??
        script['content']?.toString().substring(0,
            (script['content'].toString().length).clamp(0, 100)) ??
        '';

    final levelColor = _levelColor(level);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _startScript(script),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Top row: title + level badge
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(script['title'] ?? 'Untitled',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B))),
              ),
              const SizedBox(width: 8),
              _levelBadge(level, levelColor),
            ]),

            // Description
            if (script['description'] != null &&
                script['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(script['description'],
                  style: const TextStyle(fontSize: 12,
                      color: Color(0xFF64748B))),
            ],

            const SizedBox(height: 10),

            // Preview text
            Text(preview,
                style: const TextStyle(fontSize: 13,
                    color: Color(0xFF94A3B8), height: 1.45)),

            const SizedBox(height: 12),

            // Footer row
            Row(children: [
              Icon(Icons.text_fields_rounded, size: 13,
                  color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text('$wordCount words',
                  style: TextStyle(fontSize: 11,
                      color: Colors.grey.shade400)),
              const SizedBox(width: 12),
              if (isBuiltin) ...[
                Icon(Icons.verified_rounded, size: 13,
                    color: Colors.blue.shade400),
                const SizedBox(width: 4),
                Text('PronounceMate',
                    style: TextStyle(fontSize: 11,
                        color: Colors.blue.shade400)),
              ] else ...[
                Icon(Icons.person_outline_rounded, size: 13,
                    color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text('Your script',
                    style: TextStyle(fontSize: 11,
                        color: Colors.grey.shade400)),
              ],
              const Spacer(),
              TextButton(
                onPressed: () => _startScript(script),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF1A3A6B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(80, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Practice',
                    style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _levelBadge(String level, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        level[0].toUpperCase() + level.substring(1),
        style: TextStyle(fontSize: 11, color: color,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'beginner':     return const Color(0xFF16A34A);
      case 'intermediate': return const Color(0xFFD97706);
      case 'advanced':     return const Color(0xFF7C3AED);
      default:             return const Color(0xFF64748B);
    }
  }

  // ── Empty state view ───────────────────────────────────
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
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text(hint,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12,
                        color: Colors.grey.shade400)),
                if (showAddButton) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _tabs.animateTo(2),
                    icon: const Icon(Icons.add),
                    label: const Text('Add a Script'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A3A6B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }
}