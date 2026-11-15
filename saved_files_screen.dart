import 'dart:io';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../services/pdf_service.dart';
import '../services/recent_service.dart';
import 'reader_screen.dart';

class SavedFilesScreen extends StatefulWidget {
  const SavedFilesScreen({super.key});

  @override
  State<SavedFilesScreen> createState() => _SavedFilesScreenState();
}

class _SavedFilesScreenState extends State<SavedFilesScreen> {
  late Future<List<File>> _future = _load();

  Future<List<File>> _load() async {
    final dir = await PdfService.cvDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.pdf'))
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  void _refresh() => setState(() => _future = _load());

  String _date(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  String _size(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(0)} KB'
      : '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';

  Future<void> _delete(File f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الملف'),
        content: const Text('هل تريد حذف هذا الملف نهائياً؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) {
      await f.delete();
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ملفاتي المحفوظة')),
      body: FutureBuilder<List<File>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final files = snap.data ?? [];
          if (files.isEmpty) {
            return const Center(child: Text('لا توجد ملفات محفوظة بعد، أنشئ سيرة أو مستنداً أولاً'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: files.length,
            itemBuilder: (_, i) {
              final f = files[i];
              final name = f.path.split(Platform.pathSeparator).last;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      '${_date(f.lastModifiedSync())}  •  ${_size(f.lengthSync())}'),
                  onTap: () async {
                    await RecentService.add(f.path);
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ReaderScreen(path: f.path)),
                    );
                  },
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'share') {
                        await Printing.sharePdf(
                            bytes: await f.readAsBytes(), filename: name);
                      } else {
                        _delete(f);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'share', child: Text('مشاركة')),
                      PopupMenuItem(value: 'delete', child: Text('حذف')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
