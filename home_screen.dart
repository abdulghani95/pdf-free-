import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/recent_service.dart';
import 'cv_screen.dart';
import 'reader_screen.dart';
import 'saved_files_screen.dart';
import 'writer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> _recent = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final r = await RecentService.load();
    if (mounted) setState(() => _recent = r);
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _loadRecent();
  }

  Future<void> _pickPdf() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = res?.files.single.path;
    if (path == null) return;
    await RecentService.add(path);
    if (!mounted) return;
    await _open(ReaderScreen(path: path));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    cs.primary,
                    Color.lerp(cs.primary, Colors.black, 0.4)!,
                  ],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_stories, color: Colors.white, size: 34),
                  SizedBox(height: 12),
                  Text('سيرتي',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text(
                    'أنشئ سيرتك الذاتية، اكتب مستنداتك، واقرأ كتبك بكل سهولة',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _ActionTile(
                  icon: Icons.description_outlined,
                  color: cs.primary,
                  title: 'سيرة ذاتية',
                  subtitle: '3 قوالب احترافية',
                  onTap: () => _open(const CvScreen()),
                ),
                _ActionTile(
                  icon: Icons.edit_note,
                  color: const Color(0xFFC2410C),
                  title: 'كتابة PDF',
                  subtitle: 'اكتب نصاً وحوّله لملف',
                  onTap: () => _open(const WriterScreen()),
                ),
                _ActionTile(
                  icon: Icons.menu_book_outlined,
                  color: const Color(0xFF7C3AED),
                  title: 'قراءة PDF',
                  subtitle: 'كتبك مع الفهرس',
                  onTap: _pickPdf,
                ),
                _ActionTile(
                  icon: Icons.folder_copy_outlined,
                  color: const Color(0xFF0F766E),
                  title: 'ملفاتي',
                  subtitle: 'ما أنشأته سابقاً',
                  onTap: () => _open(const SavedFilesScreen()),
                ),
              ],
            ),
            if (_recent.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text('آخر الملفات',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              for (final p in _recent.take(6))
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading:
                        const Icon(Icons.picture_as_pdf, color: Colors.red),
                    title: Text(
                      p.split(Platform.pathSeparator).last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _open(ReaderScreen(path: p)),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const Spacer(),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text(subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }
}
