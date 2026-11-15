import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/pdf_service.dart';
import '../services/recent_service.dart';
import 'reader_screen.dart';

/// شاشة كتابة مستند وتحويله إلى PDF.
class WriterScreen extends StatefulWidget {
  const WriterScreen({super.key});

  @override
  State<WriterScreen> createState() => _WriterScreenState();
}

class _WriterScreenState extends State<WriterScreen> {
  static const _draftKey = 'writer_draft';
  static const _colors = [
    0xFF1E5AA8,
    0xFF0F766E,
    0xFF7C3AED,
    0xFFB91C1C,
    0xFFC2410C,
    0xFF111827,
  ];

  final _title = TextEditingController();
  final _body = TextEditingController();

  bool _rtl = true;
  double _size = 13;
  int _accent = 0xFF1E5AA8;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void dispose() {
    _saveDraft(); // يقرأ الحقول بشكل متزامن قبل التخلص منها
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_draftKey);
    if (s != null) {
      try {
        final m = Map<String, dynamic>.from(jsonDecode(s));
        _title.text = m['title'] ?? '';
        _body.text = m['body'] ?? '';
        _rtl = m['rtl'] ?? true;
        _size = (m['size'] ?? 13).toDouble();
        _accent = m['accent'] ?? 0xFF1E5AA8;
      } catch (_) {}
    }
    _body.addListener(_onChanged);
    if (mounted) setState(() => _loading = false);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _saveDraft() async {
    final data = jsonEncode({
      'title': _title.text,
      'body': _body.text,
      'rtl': _rtl,
      'size': _size,
      'accent': _accent,
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, data);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  int get _words {
    final t = _body.text.trim();
    return t.isEmpty ? 0 : t.split(RegExp(r'\s+')).length;
  }

  /// يضيف بادئة (مثل "# ") في أول السطر الحالي.
  void _prefixLine(String prefix) {
    final text = _body.text;
    final sel = _body.selection;
    final pos = sel.isValid ? sel.start : text.length;
    final lineStart = pos <= 0 ? 0 : text.lastIndexOf('\n', pos - 1) + 1;
    final newText = text.replaceRange(lineStart, lineStart, prefix);
    _body.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + prefix.length),
    );
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مسح النص'),
        content: const Text('هل تريد مسح العنوان والنص بالكامل؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('مسح')),
        ],
      ),
    );
    if (ok == true) {
      _title.clear();
      _body.clear();
    }
  }

  Future<void> _generate() async {
    if (_body.text.trim().isEmpty) {
      _snack('اكتب نصاً أولاً');
      return;
    }
    setState(() => _busy = true);
    try {
      await _saveDraft();
      final file = await PdfService.generateTextAndSave(
        title: _title.text,
        body: _body.text,
        rtl: _rtl,
        fontSize: _size,
        accent: _accent,
      );
      await RecentService.add(file.path);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReaderScreen(path: file.path)),
      );
    } catch (e) {
      _snack('تعذّر إنشاء الملف: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('كتابة PDF'),
        actions: [
          IconButton(
            tooltip: 'مسح الكل',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _clear,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          TextField(
            controller: _title,
            textAlign: _rtl ? TextAlign.right : TextAlign.left,
            textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'عنوان المستند',
              prefixIcon: const Icon(Icons.title),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ActionChip(
                avatar: const Icon(Icons.looks_one_outlined, size: 18),
                label: const Text('عنوان'),
                onPressed: () => _prefixLine('# '),
              ),
              ActionChip(
                avatar: const Icon(Icons.looks_two_outlined, size: 18),
                label: const Text('عنوان فرعي'),
                onPressed: () => _prefixLine('## '),
              ),
              ActionChip(
                avatar: const Icon(Icons.format_list_bulleted, size: 18),
                label: const Text('نقطة'),
                onPressed: () => _prefixLine('- '),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _body,
            minLines: 14,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textAlign: _rtl ? TextAlign.right : TextAlign.left,
            textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
            style: TextStyle(fontSize: _size + 1, height: 1.6),
            decoration: InputDecoration(
              hintText:
                  'اكتب نصك هنا...\n\n# عنوان رئيسي\n## عنوان فرعي\n- نقطة في قائمة',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text('$_words كلمة',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune, color: cs.primary),
                      const SizedBox(width: 8),
                      const Text('إعدادات المستند',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('عربي')),
                      ButtonSegment(value: false, label: Text('English')),
                    ],
                    selected: {_rtl},
                    onSelectionChanged: (s) => setState(() => _rtl = s.first),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('حجم الخط'),
                      Expanded(
                        child: Slider(
                          min: 10,
                          max: 24,
                          divisions: 14,
                          label: _size.round().toString(),
                          value: _size,
                          onChanged: (v) => setState(() => _size = v),
                        ),
                      ),
                      Text('${_size.round()}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    children: [
                      for (final c in _colors)
                        GestureDetector(
                          onTap: () => setState(() => _accent = c),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Color(c),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    _accent == c ? Colors.black : Colors.white,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 4)
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _busy ? null : _generate,
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.picture_as_pdf),
            label: Text(_busy ? 'جارٍ الإنشاء...' : 'حفظ كملف PDF'),
          ),
        ),
      ),
    );
  }
}
