import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'active_session_screens.dart';

class ScriptSelectionScreen extends StatefulWidget {
  final int initialTabIndex;
  final bool openUploadOptions;

  const ScriptSelectionScreen({
    Key? key,
    this.initialTabIndex = 0,
    this.openUploadOptions = false,
  }) : super(key: key);

  @override
  State<ScriptSelectionScreen> createState() => _ScriptSelectionState();
}

class _ScriptSelectionState extends State<ScriptSelectionScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabs;
  String _selectedLevel = 'all';
  bool   _loading       = true;
  String? _error;
  bool _offlineMode = false;

  List<dynamic> _builtin  = [];
  List<dynamic> _uploaded = [];

  static const List<Map<String, dynamic>> _fallbackBuiltinScripts = [
    {
      'title': 'Club Introduction',
      'description': 'A simple opener for introducing yourself to a small audience.',
      'content': 'Hello everyone, my name is Maya, and I am excited to be here today. I enjoy helping people speak with more clarity and confidence. Over the next few minutes, I will share a little about my background, what I care about, and why I joined this club.',
      'level': 'beginner',
      'word_count': 48,
    },
    {
      'title': 'Coffee Order',
      'description': 'Practice everyday requests with natural rhythm and simple replies.',
      'content': 'Hi, could I get a medium coffee, please? I would also like one extra shot of espresso and a little milk on the side. Thank you. That is everything for now, and I appreciate your help.',
      'level': 'beginner',
      'word_count': 40,
    },
    {
      'title': 'Startup Pitch',
      'description': 'Present a problem, solution, and closing line without extra filler.',
      'content': 'Today, I want to introduce a simple idea that solves a very common problem. Many people lose time because their tasks are scattered across different apps and notes. Our solution brings everything into one place, making it easier to stay focused and move faster. That is why this product matters.',
      'level': 'intermediate',
      'word_count': 94,
    },
    {
      'title': 'Weekend Plans',
      'description': 'Keep the conversation moving with details, reactions, and follow-ups.',
      'content': 'This weekend I am hoping to slow down a little and spend more time outside. If the weather is nice, I want to visit a park, meet a friend for lunch, and finish a few things I have been putting off. It should be a good balance of rest and getting things done.',
      'level': 'intermediate',
      'word_count': 76,
    },
    {
      'title': 'Conference Opening',
      'description': 'A polished opening for a talk with strong presence and audience control.',
      'content': 'Good morning, and thank you for joining us. It is a privilege to open this conference and share a message that matters to all of us. In the next few minutes, I will outline where we are today, where we are headed, and what we need to do together to get there.',
      'level': 'advanced',
      'word_count': 136,
    },
    {
      'title': 'Vision Statement',
      'description': 'Deliver a persuasive message with a memorable hook and landing.',
      'content': 'We are building more than a product. We are building a clearer path for people who want to speak with confidence and be understood the first time. That vision guides every decision we make, from the smallest detail to the biggest launch.',
      'level': 'advanced',
      'word_count': 148,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.index = widget.initialTabIndex.clamp(0, 1);
    _loadScripts();

    if (widget.openUploadOptions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showUploadOptions();
      });
    }
  }

  Future<void> _loadScripts() async {
    setState(() {
      _loading = true;
      _error = null;
      _offlineMode = false;
    });
    try {
      print(' Fetching scripts from backend...');
      final data = await ApiService.getScripts();
      print(' Response received: $data');
      
      setState(() {
        _builtin  = data['builtin']  ?? [];
        _uploaded = data['uploaded'] ?? [];
        _loading  = false;
      });
      
      print(' Built-in scripts count: ${_builtin.length}');
      print(' Uploaded scripts count: ${_uploaded.length}');
      
    } catch (e, stackTrace) {
      print(' ERROR loading scripts: $e');
      print(' Stack trace: $stackTrace');
      final isNetworkFailure = e is SocketException ||
          e is HttpException ||
          e.toString().contains('ClientException');

      if (isNetworkFailure) {
        setState(() {
          _builtin = List<Map<String, dynamic>>.from(_fallbackBuiltinScripts);
          _uploaded = const [];
          _offlineMode = true;
          _loading = false;
        });
        if (mounted) {
          _showError('Backend unavailable. Showing built-in scripts only.');
        }
        return;
      }

      setState(() {
        _error = 'Failed to load scripts: ${e.toString()}';
        _loading = false;
      });
    }
  }

  List<dynamic> get _filteredBuiltin {
    if (_selectedLevel == 'all') return _builtin;
    return _builtin.where((s) => s['level'] == _selectedLevel).toList();
  }

  // ── Navigate to practice ──────────────────────────────
  void _startScript(Map script) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ActiveSessionScreen(
        scriptText:   script['content'],
        sessionTitle: script['title'],
      ),
    ));
  }

  // ── Upload text manually ──────────────────────────────
  void _showTextUploadDialog() {
    final titleCtrl   = TextEditingController();
    final contentCtrl = TextEditingController();
    String level      = 'intermediate';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add Custom Script'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Script Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                maxLines:   6,
                decoration: const InputDecoration(
                  labelText: 'Paste your text here',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: level,
                decoration: const InputDecoration(
                  labelText: 'Difficulty Level',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'beginner',     child: Text('Beginner')),
                  DropdownMenuItem(value: 'intermediate', child: Text('Intermediate')),
                  DropdownMenuItem(value: 'advanced',     child: Text('Advanced')),
                ],
                onChanged: (v) => setLocal(() => level = v!),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty ||
                    contentCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Title and content are required')));
                  return;
                }
                Navigator.pop(ctx);
                await _uploadText(
                  title:   titleCtrl.text.trim(),
                  content: contentCtrl.text.trim(),
                  level:   level,
                );
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Upload .txt or .docx file ─────────────────────────
  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'docx'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.first.path!);
    final name = result.files.first.name
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split('.')
        .first;

    _showLevelPickerDialog(
      onConfirm: (level) async {
        await _uploadFile(file: file, title: name, level: level);
      },
    );
  }

  void _showLevelPickerDialog({required Function(String) onConfirm}) {
    String level = 'intermediate';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Select Difficulty Level'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Choose the difficulty level for your uploaded script:'),
            const SizedBox(height: 16),
            ...['beginner', 'intermediate', 'advanced'].map((l) =>
              RadioListTile<String>(
                title: Text(l[0].toUpperCase() + l.substring(1)),
                value: l,
                groupValue: level,
                onChanged: (v) => setLocal(() => level = v!),
              )
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              onPressed: () { Navigator.pop(ctx); onConfirm(level); },
              child: const Text('Upload', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadText({required String title,
      required String content, required String level}) async {
    _showLoading('Saving script...');
    try {
      await ApiService.uploadScriptText(
          title: title, content: content, level: level);
      Navigator.pop(context); // close loading
      await _loadScripts();
      _tabs.animateTo(1); // switch to My Scripts tab
      _showSuccess('Script saved successfully');
    } catch (e) {
      Navigator.pop(context);
      _showError('Failed to save script');
    }
  }

  Future<void> _uploadFile({required File file,
      required String title, required String level}) async {
    _showLoading('Uploading file...');
    try {
      await ApiService.uploadScriptFile(file, title: title, level: level);
      Navigator.pop(context);
      await _loadScripts();
      _tabs.animateTo(1);
      _showSuccess('File uploaded successfully');
    } catch (e) {
      Navigator.pop(context);
      _showError('Failed to upload file. Check file format.');
    }
  }

  void _showLoading(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        content: Row(children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(width: 16),
          Text(msg),
        ]),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg),
          backgroundColor: Colors.green.shade700));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg),
          backgroundColor: Colors.red.shade700));
  }

  // ── Build ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Choose a Script'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            const Tab(text: 'Built-in Scripts'),
            Tab(text: 'My Scripts (${_uploaded.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!,
                    style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    if (_offlineMode)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        color: AppColors.primary.withOpacity(0.08),
                        child: const Text(
                          'Offline mode: built-in scripts are available, but your uploaded scripts need the backend.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          _builtinTab(),
                          _uploadedTab(),
                        ],
                      ),
                    ),
                  ],
                ),
      floatingActionButton: widget.initialTabIndex == 1
          ? FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add Script', style: TextStyle(color: Colors.white)),
              onPressed: _showUploadOptions,
            )
          : FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
              icon: const Icon(Icons.menu_book_rounded, color: Colors.white),
            label: const Text('Browse Scripts', style: TextStyle(color: Colors.white)),
              onPressed: () => _tabs.animateTo(0),
            ),
    );
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: AppColors.surface,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Add Custom Script',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              )),
          const SizedBox(height: 20),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Icon(Icons.edit, color: Colors.white),
            ),
            title: const Text('Type or Paste Text'),
            subtitle: const Text('Write your own script directly', style: TextStyle(color: AppColors.textSecondary)),
            onTap: () { Navigator.pop(context); _showTextUploadDialog(); },
          ),
          const Divider(),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.success,
              child: Icon(Icons.upload_file, color: Colors.white),
            ),
            title: const Text('Upload File'),
            subtitle: const Text('Upload a .txt or .docx document', style: TextStyle(color: AppColors.textSecondary)),
            onTap: () { Navigator.pop(context); _pickAndUploadFile(); },
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  // ── Built-in Scripts Tab ──────────────────────────────
  Widget _builtinTab() {
    return Column(children: [
      // Level filter
      Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...['all', 'beginner', 'intermediate', 'advanced'].map(
                (l) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(l == 'all' ? 'All Levels'
                        : l[0].toUpperCase() + l.substring(1)),
                    selected: _selectedLevel == l,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _selectedLevel == l ? Colors.white : Colors.black87,
                    ),
                    onSelected: (_) => setState(() => _selectedLevel = l),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Script cards
      Expanded(
        child: _filteredBuiltin.isEmpty
            ? const Center(child: Text('No scripts for this level'))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filteredBuiltin.length,
                itemBuilder: (ctx, i) =>
                    _scriptCard(_filteredBuiltin[i], isBuiltin: true),
              ),
      ),
    ]);
  }

  // ── My Scripts Tab ────────────────────────────────────
  Widget _uploadedTab() {
    if (_uploaded.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.description_outlined, size: 64,
              color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('No custom scripts yet',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Tap + Add Script to upload your own text',
              style: TextStyle(color: Colors.grey)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _uploaded.length,
      itemBuilder: (ctx, i) =>
          _scriptCard(_uploaded[i], isBuiltin: false),
    );
  }

  // ── Script Card ───────────────────────────────────────
  Widget _scriptCard(Map script, {required bool isBuiltin}) {
    final level = script['level'] as String;
    final words = script['word_count'] as int? ?? 0;

    final levelColors = {
      'beginner':     const Color(0xFF16A34A),
      'intermediate': const Color(0xFFD97706),
      'advanced':     const Color(0xFF7C3AED),
    };
    final levelColor = levelColors[level] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _startScript(script),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(children: [
                Expanded(
                  child: Text(script['title'],
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: levelColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    level[0].toUpperCase() + level.substring(1),
                    style: TextStyle(fontSize: 11, color: levelColor,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              // Description
              if (script['description'] != null &&
                  script['description'].toString().isNotEmpty)
                Text(script['description'],
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 10),
              // Content preview
              Text(
                script['content'].toString().length > 100
                    ? '${script['content'].toString().substring(0, 100)}...'
                    : script['content'].toString(),
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF94A3B8), height: 1.4),
              ),
              const SizedBox(height: 12),
              // Footer
              Row(children: [
                Icon(Icons.text_fields, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text('$words words',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const Spacer(),
                if (!isBuiltin)
                  Icon(Icons.person_outline, size: 14,
                      color: Colors.grey.shade500),
                if (!isBuiltin) const SizedBox(width: 4),
                if (!isBuiltin)
                  Text('Your script',
                      style: TextStyle(fontSize: 12,
                          color: Colors.grey.shade500)),
                if (isBuiltin) ...[
                  Icon(Icons.verified, size: 14,
                      color: Colors.blue.shade400),
                  const SizedBox(width: 4),
                  Text('PronounceMate',
                      style: TextStyle(fontSize: 12,
                          color: Colors.blue.shade400)),
                ],
                const SizedBox(width: 12),
                // Start button
                ElevatedButton(
                  onPressed: () => _startScript(script),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(80, 32),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Practice',
                      style: TextStyle(fontSize: 13)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }
}