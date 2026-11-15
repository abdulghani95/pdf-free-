import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cv_data.dart';
import '../services/pdf_service.dart';
import '../services/recent_service.dart';
import 'reader_screen.dart';

class CvScreen extends StatefulWidget {
  const CvScreen({super.key});

  @override
  State<CvScreen> createState() => _CvScreenState();
}

class _CvScreenState extends State<CvScreen> {
  static const _draftKey = 'cv_draft';
  static const _colors = [
    0xFF1E5AA8,
    0xFF0F766E,
    0xFF7C3AED,
    0xFFB91C1C,
    0xFFC2410C,
    0xFF111827,
  ];
  static const _templateNames = ['كلاسيكي', 'عصري', 'أنيق'];

  CvData _cv = CvData();
  final _name = TextEditingController();
  final _title = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _website = TextEditingController();
  final _summary = TextEditingController();

  bool _loading = true;
  bool _busy = false;

  List<TextEditingController> get _ctrls =>
      [_name, _title, _email, _phone, _address, _website, _summary];

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void dispose() {
    _saveDraft(); // الجزء المتزامن منه يقرأ الحقول قبل التخلص منها
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_draftKey);
    if (s != null) {
      try {
        _cv = CvData.decode(s);
      } catch (_) {}
    }
    _name.text = _cv.fullName;
    _title.text = _cv.jobTitle;
    _email.text = _cv.email;
    _phone.text = _cv.phone;
    _address.text = _cv.address;
    _website.text = _cv.website;
    _summary.text = _cv.summary;
    for (final c in _ctrls) {
      c.addListener(_onChanged);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _sync() {
    _cv.fullName = _name.text.trim();
    _cv.jobTitle = _title.text.trim();
    _cv.email = _email.text.trim();
    _cv.phone = _phone.text.trim();
    _cv.address = _address.text.trim();
    _cv.website = _website.text.trim();
    _cv.summary = _summary.text.trim();
  }

  Future<void> _saveDraft() async {
    _sync();
    final data = _cv.encode();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, data);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ───────────────────────── اكتمال السيرة ─────────────────────────

  double get _progress {
    var score = 0;
    if (_name.text.trim().isNotEmpty) score += 15;
    if (_title.text.trim().isNotEmpty) score += 10;
    if (_email.text.trim().isNotEmpty || _phone.text.trim().isNotEmpty) {
      score += 10;
    }
    if (_summary.text.trim().length >= 40) score += 15;
    if (_cv.experiences.isNotEmpty) score += 20;
    if (_cv.education.isNotEmpty) score += 10;
    if (_cv.skills.length >= 3) score += 10;
    if (_cv.languages.isNotEmpty) score += 5;
    if (_cv.photoPath.isNotEmpty) score += 5;
    return score / 100;
  }

  String get _hint {
    if (_name.text.trim().isEmpty) return 'ابدأ بكتابة اسمك الكامل';
    if (_title.text.trim().isEmpty) return 'أضف مسماك الوظيفي';
    if (_email.text.trim().isEmpty && _phone.text.trim().isEmpty) {
      return 'أضف وسيلة تواصل (بريد أو هاتف)';
    }
    if (_summary.text.trim().length < 40) {
      return 'اكتب نبذة قصيرة عنك (سطرين أو ثلاثة)';
    }
    if (_cv.experiences.isEmpty) return 'أضف خبرة عملية واحدة على الأقل';
    if (_cv.education.isEmpty) return 'أضف مؤهلك الدراسي';
    if (_cv.skills.length < 3) return 'أضف 3 مهارات على الأقل';
    if (_cv.languages.isEmpty) return 'أضف اللغات التي تتقنها';
    if (_cv.photoPath.isEmpty) return 'يمكنك إضافة صورة شخصية';
    return 'سيرتك مكتملة، جاهزة للتصدير';
  }

  // ───────────────────────── إجراءات ─────────────────────────

  Future<void> _pickPhoto() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image);
    final src = res?.files.single.path;
    if (src == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final ext = src.contains('.') ? src.substring(src.lastIndexOf('.')) : '.jpg';
    final dest = await File(src)
        .copy('${dir.path}/photo_${DateTime.now().millisecondsSinceEpoch}$ext');
    setState(() => _cv.photoPath = dest.path);
  }

  Future<void> _generate() async {
    _sync();
    if (_cv.fullName.isEmpty) {
      _snack('الرجاء إدخال الاسم الكامل');
      return;
    }
    setState(() => _busy = true);
    try {
      await _saveDraft();
      final file = await PdfService.generateAndSave(_cv);
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

  /// نافذة إدخال عامة (للخبرات والتعليم)
  Future<List<String>?> _showForm(
    String title,
    List<String> labels,
    List<String> initial, {
    int multiline = -1,
  }) {
    final ctrls = [
      for (var i = 0; i < labels.length; i++)
        TextEditingController(text: i < initial.length ? initial[i] : '')
    ];
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < labels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    controller: ctrls[i],
                    maxLines: i == multiline ? 4 : 1,
                    decoration: InputDecoration(
                      labelText: labels[i],
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, ctrls.map((c) => c.text.trim()).toList()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _editExperience([int? index]) async {
    final old = index == null ? null : _cv.experiences[index];
    final v = await _showForm(
      'خبرة عملية',
      ['المسمى الوظيفي', 'الشركة', 'الفترة (مثال: 2020 - 2023)', 'الوصف'],
      old == null
          ? []
          : [old.title, old.company, old.period, old.description],
      multiline: 3,
    );
    if (v == null || (v[0].isEmpty && v[1].isEmpty)) return;
    final item = ExperienceItem(
        title: v[0], company: v[1], period: v[2], description: v[3]);
    setState(() {
      if (index == null) {
        _cv.experiences.add(item);
      } else {
        _cv.experiences[index] = item;
      }
    });
  }

  Future<void> _editEducation([int? index]) async {
    final old = index == null ? null : _cv.education[index];
    final v = await _showForm(
      'التعليم',
      ['الشهادة / التخصص', 'الجامعة / المدرسة', 'الفترة'],
      old == null ? [] : [old.degree, old.school, old.period],
    );
    if (v == null || (v[0].isEmpty && v[1].isEmpty)) return;
    final item = EducationItem(degree: v[0], school: v[1], period: v[2]);
    setState(() {
      if (index == null) {
        _cv.education.add(item);
      } else {
        _cv.education[index] = item;
      }
    });
  }

  // ───────────────────────── واجهة ─────────────────────────

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType? type,
    int lines = 1,
    bool ltr = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: type,
        maxLines: lines,
        textDirection: ltr ? TextDirection.ltr : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: lines == 1 ? Icon(icon, size: 20) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade50,
          isDense: true,
        ),
      ),
    );
  }

  Widget _progressCard() {
    final p = _progress;
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: p,
                      strokeWidth: 6,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                  Text('${(p * 100).round()}%',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('اكتمال السيرة',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 16, color: cs.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_hint,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _designCard() {
    return _Section(
      title: 'التصميم',
      icon: Icons.palette_outlined,
      initiallyExpanded: true,
      children: [
        const Text('القالب', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < _templateNames.length; i++)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 14),
                  child: _TemplateCard(
                    index: i,
                    label: _templateNames[i],
                    color: Color(_cv.accent),
                    selected: _cv.template == i,
                    onTap: () => setState(() => _cv.template = i),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('اللون', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            for (final c in _colors)
              GestureDetector(
                onTap: () => setState(() => _cv.accent = c),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _cv.accent == c ? Colors.black : Colors.white,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.15), blurRadius: 4)
                    ],
                  ),
                  child: _cv.accent == c
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('لغة السيرة', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('عربي')),
            ButtonSegment(value: false, label: Text('English')),
          ],
          selected: {_cv.rtl},
          onSelectionChanged: (s) => setState(() => _cv.rtl = s.first),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final hasPhoto =
        _cv.photoPath.isNotEmpty && File(_cv.photoPath).existsSync();

    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء سيرة ذاتية')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          _progressCard(),
          const SizedBox(height: 12),
          _designCard(),
          _Section(
            title: 'المعلومات الشخصية',
            icon: Icons.person_outline,
            initiallyExpanded: true,
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage:
                      hasPhoto ? FileImage(File(_cv.photoPath)) : null,
                  child: hasPhoto
                      ? null
                      : Icon(Icons.person, size: 36, color: Colors.grey.shade500),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickPhoto,
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: Text(hasPhoto ? 'تغيير' : 'إضافة صورة'),
                      ),
                      if (hasPhoto)
                        IconButton(
                          tooltip: 'حذف الصورة',
                          onPressed: () => setState(() => _cv.photoPath = ''),
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              _field(_name, 'الاسم الكامل *', Icons.badge_outlined),
              _field(_title, 'المسمى الوظيفي', Icons.work_outline),
              _field(_email, 'البريد الإلكتروني', Icons.email_outlined,
                  type: TextInputType.emailAddress, ltr: true),
              _field(_phone, 'رقم الهاتف', Icons.phone_outlined,
                  type: TextInputType.phone, ltr: true),
              _field(_address, 'المدينة / العنوان', Icons.location_on_outlined),
              _field(_website, 'رابط (لينكدإن / موقع)', Icons.link,
                  type: TextInputType.url, ltr: true),
            ],
          ),
          _Section(
            title: 'نبذة عنك',
            icon: Icons.notes,
            children: [
              _field(_summary, 'اكتب نبذة مختصرة عن خبرتك وأهدافك',
                  Icons.notes,
                  lines: 5),
            ],
          ),
          _Section(
            title: 'الخبرات العملية',
            icon: Icons.work_history_outlined,
            badge: _cv.experiences.length,
            children: [
              for (var i = 0; i < _cv.experiences.length; i++)
                _ItemTile(
                  title: _cv.experiences[i].title.isEmpty
                      ? _cv.experiences[i].company
                      : _cv.experiences[i].title,
                  subtitle: [
                    _cv.experiences[i].company,
                    _cv.experiences[i].period
                  ].where((e) => e.isNotEmpty).join(' • '),
                  onTap: () => _editExperience(i),
                  onDelete: () => setState(() => _cv.experiences.removeAt(i)),
                ),
              OutlinedButton.icon(
                onPressed: _editExperience,
                icon: const Icon(Icons.add),
                label: const Text('إضافة خبرة'),
              ),
            ],
          ),
          _Section(
            title: 'التعليم',
            icon: Icons.school_outlined,
            badge: _cv.education.length,
            children: [
              for (var i = 0; i < _cv.education.length; i++)
                _ItemTile(
                  title: _cv.education[i].degree.isEmpty
                      ? _cv.education[i].school
                      : _cv.education[i].degree,
                  subtitle: [_cv.education[i].school, _cv.education[i].period]
                      .where((e) => e.isNotEmpty)
                      .join(' • '),
                  onTap: () => _editEducation(i),
                  onDelete: () => setState(() => _cv.education.removeAt(i)),
                ),
              OutlinedButton.icon(
                onPressed: _editEducation,
                icon: const Icon(Icons.add),
                label: const Text('إضافة مؤهل'),
              ),
            ],
          ),
          _Section(
            title: 'المهارات',
            icon: Icons.bolt_outlined,
            badge: _cv.skills.length,
            children: [
              _ChipsEditor(
                items: _cv.skills,
                hint: 'اكتب مهارة ثم اضغط إضافة',
                onChanged: _onChanged,
              ),
            ],
          ),
          _Section(
            title: 'اللغات',
            icon: Icons.language,
            badge: _cv.languages.length,
            children: [
              _ChipsEditor(
                items: _cv.languages,
                hint: 'مثال: العربية (الأم)',
                onChanged: _onChanged,
              ),
            ],
          ),
          _Section(
            title: 'الدورات والشهادات',
            icon: Icons.workspace_premium_outlined,
            badge: _cv.certificates.length,
            children: [
              _ChipsEditor(
                items: _cv.certificates,
                hint: 'مثال: دورة إدارة المشاريع 2024',
                onChanged: _onChanged,
              ),
            ],
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
            label: Text(_busy ? 'جارٍ الإنشاء...' : 'إنشاء ملف PDF'),
          ),
        ),
      ),
    );
  }
}

/// قسم قابل للطي
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;
  final int? badge;

  const _Section({
    required this.title,
    required this.icon,
    required this.children,
    this.initiallyExpanded = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          shape: const Border(),
          collapsedShape: const Border(),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: cs.primary, size: 22),
          ),
          title: Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              if (badge != null && badge! > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$badge',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          children: children,
        ),
      ),
    );
  }
}

/// عنصر خبرة / مؤهل في القائمة
class _ItemTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ItemTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        dense: true,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        onTap: onTap,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

/// بطاقة معاينة مصغّرة لقالب السيرة
class _TemplateCard extends StatelessWidget {
  final int index;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.index,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  Widget _bar(double w, double h, Color c) => Container(
        width: w,
        height: h,
        margin: const EdgeInsets.only(bottom: 5),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(3),
        ),
      );

  Widget _preview() {
    final grey = Colors.grey.shade300;
    switch (index) {
      case 1: // عصري
        return Row(
          children: [
            Container(width: 9, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bar(48, 8, color),
                    _bar(32, 5, grey),
                    const SizedBox(height: 6),
                    Row(children: [
                      Container(
                          width: 3,
                          height: 8,
                          margin: const EdgeInsetsDirectional.only(end: 4),
                          color: color),
                      _bar(30, 5, color.withOpacity(0.7)),
                    ]),
                    _bar(60, 4, grey),
                    _bar(52, 4, grey),
                    const SizedBox(height: 4),
                    Row(children: [
                      _bar(16, 8, color.withOpacity(0.25)),
                      const SizedBox(width: 3),
                      _bar(16, 8, color.withOpacity(0.25)),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        );
      case 2: // أنيق
        return Padding(
          padding: const EdgeInsets.all(9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _bar(46, 8, Colors.grey.shade800),
              _bar(30, 4, color),
              Container(
                  height: 1.5,
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  color: Colors.grey.shade700),
              _bar(30, 5, Colors.grey.shade600),
              Container(height: 1, color: grey),
              const SizedBox(height: 4),
              _bar(66, 4, grey),
              _bar(58, 4, grey),
              const SizedBox(height: 3),
              _bar(30, 5, Colors.grey.shade600),
              _bar(66, 4, grey),
            ],
          ),
        );
      default: // كلاسيكي
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 38,
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(46, 7, Colors.white),
                  _bar(30, 4, Colors.white70),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(36, 5, color),
                  Container(height: 1.5, color: color),
                  const SizedBox(height: 5),
                  _bar(66, 4, grey),
                  _bar(58, 4, grey),
                  _bar(62, 4, grey),
                ],
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 92,
            height: 124,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? color : Colors.grey.shade300,
                width: selected ? 2.5 : 1,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 8)]
                  : null,
            ),
            child: _preview(),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected)
                Icon(Icons.check_circle, size: 14, color: color),
              if (selected) const SizedBox(width: 3),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ],
      ),
    );
  }
}

/// محرر قائمة نصوص (مهارات / لغات / شهادات) على شكل Chips
class _ChipsEditor extends StatefulWidget {
  final List<String> items;
  final String hint;
  final VoidCallback onChanged;
  const _ChipsEditor({
    required this.items,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<_ChipsEditor> createState() => _ChipsEditorState();
}

class _ChipsEditorState extends State<_ChipsEditor> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add() {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    setState(() => widget.items.add(v));
    _ctrl.clear();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (var i = 0; i < widget.items.length; i++)
                  Chip(
                    label: Text(widget.items[i]),
                    onDeleted: () {
                      setState(() => widget.items.removeAt(i));
                      widget.onChanged();
                    },
                  ),
              ],
            ),
          ),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              onSubmitted: (_) => _add(),
              decoration: InputDecoration(
                hintText: widget.hint,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: _add, child: const Text('إضافة')),
        ]),
      ],
    );
  }
}
