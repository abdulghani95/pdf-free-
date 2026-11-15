import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart' show Printing;

/// عنصر في جدول المحتويات (فهرس الكتاب)
class _TocItem {
  final String title;
  final int? page;
  final int depth;
  const _TocItem(this.title, this.page, this.depth);
}

class ReaderScreen extends StatefulWidget {
  final String path;
  const ReaderScreen({super.key, required this.path});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final PdfViewerController _controller = PdfViewerController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ValueNotifier<int> _page = ValueNotifier<int>(1);

  List<_TocItem>? _toc; // null = جارٍ التحميل
  int _pageCount = 0;

  String get _name => widget.path.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();
    _loadToc();
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _loadToc() async {
    try {
      final doc = await PdfDocument.openFile(widget.path);
      final outline = await doc.loadOutline();
      final count = doc.pages.length;
      doc.dispose();
      final items = <_TocItem>[];
      _flatten(outline, 0, items);
      if (mounted) {
        setState(() {
          _toc = items;
          _pageCount = count;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _toc = []);
    }
  }

  void _flatten(List<PdfOutlineNode> nodes, int depth, List<_TocItem> out) {
    for (final n in nodes) {
      out.add(_TocItem(n.title, n.dest?.pageNumber, depth));
      _flatten(n.children, depth + 1, out);
    }
  }

  Future<void> _goTo(int page) async {
    try {
      await _controller.goToPage(pageNumber: page);
    } catch (_) {}
  }

  Future<void> _askPage() async {
    final ctrl = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الانتقال إلى صفحة'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: _pageCount > 0 ? 'من 1 إلى $_pageCount' : 'رقم الصفحة',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
            child: const Text('انتقال'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null) return;
    var p = result;
    if (p < 1) p = 1;
    if (_pageCount > 0 && p > _pageCount) p = _pageCount;
    await _goTo(p);
  }

  Future<void> _share() async {
    final bytes = await File(widget.path).readAsBytes();
    await Printing.sharePdf(bytes: bytes, filename: _name);
  }

  Future<void> _print() async {
    final bytes = await File(widget.path).readAsBytes();
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: _name);
  }

  Widget _tocDrawer() {
    final toc = _toc;
    Widget content;
    if (toc == null) {
      content = const Center(child: CircularProgressIndicator());
    } else if (toc.isEmpty) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined,
                  size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                'لا يحتوي هذا الملف على فهرس مضمّن',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _askPage();
                },
                icon: const Icon(Icons.pin_outlined),
                label: const Text('الانتقال إلى صفحة'),
              ),
            ],
          ),
        ),
      );
    } else {
      content = ListView.separated(
        itemCount: toc.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (_, i) {
          final item = toc[i];
          return ListTile(
            dense: true,
            contentPadding: EdgeInsetsDirectional.only(
              start: 16.0 + item.depth * 16.0,
              end: 14,
            ),
            title: Text(
              item.title.isEmpty ? '—' : item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: item.depth == 0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            trailing: item.page == null
                ? null
                : Text('${item.page}',
                    style: TextStyle(color: Colors.grey.shade600)),
            onTap: item.page == null
                ? null
                : () {
                    Navigator.pop(context);
                    _goTo(item.page!);
                  },
          );
        },
      );
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.toc),
                  const SizedBox(width: 10),
                  const Text('فهرس الكتاب',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (_pageCount > 0)
                    Text('$_pageCount صفحة',
                        style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_name, style: const TextStyle(fontSize: 15)),
        actions: [
          IconButton(
            tooltip: 'الفهرس',
            icon: const Icon(Icons.toc),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          IconButton(
            tooltip: 'الانتقال إلى صفحة',
            icon: const Icon(Icons.pin_outlined),
            onPressed: _askPage,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'share') _share();
              if (v == 'print') _print();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'share', child: Text('مشاركة')),
              PopupMenuItem(value: 'print', child: Text('طباعة')),
            ],
          ),
        ],
      ),
      endDrawer: _tocDrawer(),
      body: Stack(
        children: [
          PdfViewer.file(
            widget.path,
            controller: _controller,
            params: PdfViewerParams(
              backgroundColor: const Color(0xFFE5E7EB),
              onPageChanged: (page) {
                if (page != null) _page.value = page;
              },
            ),
          ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: ValueListenableBuilder<int>(
                valueListenable: _page,
                builder: (_, p, __) => GestureDetector(
                  onTap: _askPage,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _pageCount > 0 ? 'صفحة $p / $_pageCount' : 'صفحة $p',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
