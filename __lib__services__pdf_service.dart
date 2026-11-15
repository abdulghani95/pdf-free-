import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/cv_data.dart';

class PdfService {
  /// مجلد الملفات المحفوظة داخل التطبيق (سير ذاتية + مستندات).
  static Future<Directory> cvDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/CVs');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> _save(
      Uint8List bytes, String rawName, String fallback) async {
    final dir = await cvDir();
    final raw = rawName.trim().isEmpty ? fallback : rawName.trim();
    var safe = raw.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
    if (safe.length > 40) safe = safe.substring(0, 40);
    final file =
        File('${dir.path}/${safe}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    return file.writeAsBytes(bytes);
  }

  /// يبني ملف PDF للسيرة ويحفظه ويرجع الملف.
  static Future<File> generateAndSave(CvData cv) async {
    final bytes = await buildPdf(cv);
    return _save(bytes, cv.fullName, 'CV');
  }

  /// يبني ملف PDF من نص مكتوب ويحفظه.
  static Future<File> generateTextAndSave({
    required String title,
    required String body,
    required bool rtl,
    required double fontSize,
    required int accent,
  }) async {
    final bytes = await buildTextPdf(
      title: title,
      body: body,
      rtl: rtl,
      fontSize: fontSize,
      accent: accent,
    );
    return _save(bytes, title, 'Document');
  }

  /// الخط (Tajawal) مضمّن داخل التطبيق، فيعمل بدون إنترنت.
  static Future<pw.ThemeData> _theme() async {
    final base =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
    final bold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    return pw.ThemeData.withFont(base: base, bold: bold);
  }

  // ───────────────────────── السيرة الذاتية ─────────────────────────

  static Future<Uint8List> buildPdf(CvData cv) async {
    final theme = await _theme();
    final b = _CvBuilder(cv);

    final pw.EdgeInsets margin;
    switch (cv.template) {
      case 1:
        margin = pw.EdgeInsets.fromLTRB(
            cv.rtl ? 32 : 46, 32, cv.rtl ? 46 : 32, 32);
        break;
      case 2:
        margin = const pw.EdgeInsets.all(40);
        break;
      default:
        margin = const pw.EdgeInsets.all(28);
    }

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: margin,
      textDirection: b.dir,
      theme: theme,
      buildBackground: (ctx) => cv.template == 1 ? b.sideBar() : pw.SizedBox(),
    );

    final doc = pw.Document(title: cv.fullName, author: cv.fullName);
    doc.addPage(pw.MultiPage(pageTheme: pageTheme, build: (ctx) => b.build()));
    return doc.save();
  }

  // ───────────────────────── مستند نصي ─────────────────────────

  static Future<Uint8List> buildTextPdf({
    required String title,
    required String body,
    required bool rtl,
    required double fontSize,
    required int accent,
  }) async {
    final theme = await _theme();
    final dir = rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final align = rtl ? pw.TextAlign.right : pw.TextAlign.left;
    final color = PdfColor.fromInt(accent);

    pw.Widget text(String s,
        {required double size,
        bool bold = false,
        PdfColor c = PdfColors.grey900}) {
      return pw.Text(
        s,
        textDirection: dir,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: size,
          color: c,
          lineSpacing: 3,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      );
    }

    final widgets = <pw.Widget>[];

    if (title.trim().isNotEmpty) {
      widgets.add(text(title.trim(),
          size: fontSize + 10, bold: true, c: color));
      widgets.add(pw.Divider(color: color, thickness: 1.5, height: 14));
      widgets.add(pw.SizedBox(height: 6));
    }

    for (final raw in body.split(RegExp(r'\r?\n'))) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        widgets.add(pw.SizedBox(height: fontSize * 0.8));
      } else if (line.startsWith('## ')) {
        widgets.add(pw.SizedBox(height: 4));
        widgets.add(text(line.substring(3),
            size: fontSize + 3, bold: true, c: PdfColors.grey800));
      } else if (line.startsWith('# ')) {
        widgets.add(pw.SizedBox(height: 6));
        widgets.add(
            text(line.substring(2), size: fontSize + 6, bold: true, c: color));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(text('•  ${line.substring(2)}', size: fontSize));
      } else {
        widgets.add(text(line, size: fontSize));
      }
    }

    final doc = pw.Document(title: title, author: '');
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 36),
          textDirection: dir,
          theme: theme,
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            '${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) => widgets,
      ),
    );
    return doc.save();
  }
}

/// يبني محتوى السيرة حسب القالب المختار.
class _CvBuilder {
  final CvData cv;
  final bool rtl;
  final pw.TextDirection dir;
  final pw.TextAlign align;
  final PdfColor accent;

  _CvBuilder(this.cv)
      : rtl = cv.rtl,
        dir = cv.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        align = cv.rtl ? pw.TextAlign.right : pw.TextAlign.left,
        accent = PdfColor.fromInt(cv.accent);

  int get tpl => cv.template;

  Map<String, String> get _labels => rtl
      ? {
          'summary': 'نبذة عني',
          'experience': 'الخبرات العملية',
          'education': 'التعليم',
          'skills': 'المهارات',
          'languages': 'اللغات',
          'certificates': 'الدورات والشهادات',
        }
      : {
          'summary': 'Profile',
          'experience': 'Experience',
          'education': 'Education',
          'skills': 'Skills',
          'languages': 'Languages',
          'certificates': 'Courses & Certificates',
        };

  PdfColor tint(double t) => PdfColor(
        1 - (1 - accent.red) * t,
        1 - (1 - accent.green) * t,
        1 - (1 - accent.blue) * t,
      );

  // ── عناصر مساعدة ──

  pw.Widget txt(
    String s, {
    double size = 10.5,
    bool bold = false,
    PdfColor color = PdfColors.grey900,
    pw.TextAlign? textAlign,
  }) {
    return pw.Text(
      s,
      textDirection: dir,
      textAlign: textAlign ?? align,
      style: pw.TextStyle(
        fontSize: size,
        color: color,
        lineSpacing: 2,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    );
  }

  /// صف يراعي اتجاه اللغة (يعكس الترتيب في العربية).
  pw.Widget rw(
    List<pw.Widget> children, {
    pw.CrossAxisAlignment cross = pw.CrossAxisAlignment.start,
  }) {
    return pw.Row(
      crossAxisAlignment: cross,
      mainAxisAlignment:
          rtl ? pw.MainAxisAlignment.end : pw.MainAxisAlignment.start,
      children: rtl ? children.reversed.toList() : children,
    );
  }

  pw.MemoryImage? _photoImage() {
    if (cv.photoPath.isEmpty) return null;
    final f = File(cv.photoPath);
    if (!f.existsSync()) return null;
    return pw.MemoryImage(f.readAsBytesSync());
  }

  pw.Widget _photoWidget(pw.MemoryImage img, double size) => pw.ClipOval(
        child: pw.Image(img, width: size, height: size, fit: pw.BoxFit.cover),
      );

  /// شريط جانبي ملوّن يظهر في كل صفحات القالب العصري.
  pw.Widget sideBar() => pw.FullPage(
        ignoreMargins: true,
        child: pw.Align(
          alignment: rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          child: pw.Container(
            width: 14,
            height: PdfPageFormat.a4.height,
            color: accent,
          ),
        ),
      );

  // ── الرأس ──

  pw.Widget _header() {
    final contact = [cv.email, cv.phone, cv.address, cv.website]
        .where((e) => e.trim().isNotEmpty)
        .toList();
    final photo = _photoImage();
    switch (tpl) {
      case 1:
        return _headerModern(contact, photo);
      case 2:
        return _headerElegant(contact, photo);
      default:
        return _headerClassic(contact, photo);
    }
  }

  pw.Widget _headerClassic(List<String> contact, pw.MemoryImage? photo) {
    final info = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        txt(cv.fullName, size: 24, bold: true, color: PdfColors.white),
        if (cv.jobTitle.trim().isNotEmpty) ...[
          pw.SizedBox(height: 3),
          txt(cv.jobTitle, size: 13, color: PdfColors.white),
        ],
        if (contact.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          txt(contact.join('   |   '), size: 9.5, color: PdfColors.white),
        ],
      ],
    );
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: accent,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: rw(
        [
          if (photo != null) ...[
            _photoWidget(photo, 76),
            pw.SizedBox(width: 14),
          ],
          pw.Expanded(child: info),
        ],
        cross: pw.CrossAxisAlignment.center,
      ),
    );
  }

  pw.Widget _headerModern(List<String> contact, pw.MemoryImage? photo) {
    final info = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        txt(cv.fullName, size: 27, bold: true, color: accent),
        if (cv.jobTitle.trim().isNotEmpty) ...[
          pw.SizedBox(height: 3),
          txt(cv.jobTitle, size: 13, color: PdfColors.grey700),
        ],
      ],
    );
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        rw(
          [
            if (photo != null) ...[
              _photoWidget(photo, 78),
              pw.SizedBox(width: 16),
            ],
            pw.Expanded(child: info),
          ],
          cross: pw.CrossAxisAlignment.center,
        ),
        if (contact.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          txt(contact.join('   •   '), size: 9.5, color: PdfColors.grey700),
        ],
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.grey400, thickness: 0.8, height: 1),
      ],
    );
  }

  pw.Widget _headerElegant(List<String> contact, pw.MemoryImage? photo) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (photo != null) ...[
          pw.Center(child: _photoWidget(photo, 70)),
          pw.SizedBox(height: 8),
        ],
        txt(cv.fullName,
            size: 26, bold: true, textAlign: pw.TextAlign.center),
        if (cv.jobTitle.trim().isNotEmpty) ...[
          pw.SizedBox(height: 3),
          txt(cv.jobTitle,
              size: 12.5, color: accent, textAlign: pw.TextAlign.center),
        ],
        if (contact.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          txt(contact.join('   |   '),
              size: 9.5,
              color: PdfColors.grey700,
              textAlign: pw.TextAlign.center),
        ],
        pw.SizedBox(height: 12),
        pw.Divider(color: PdfColors.grey800, thickness: 1.2, height: 1),
      ],
    );
  }

  // ── الأقسام ──

  pw.Widget _heading(String title) {
    switch (tpl) {
      case 1:
        return rw(
          [
            pw.Container(width: 5, height: 15, color: accent),
            pw.SizedBox(width: 8),
            txt(title, size: 14, bold: true, color: accent),
          ],
          cross: pw.CrossAxisAlignment.center,
        );
      case 2:
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            txt(title, size: 12.5, bold: true),
            pw.SizedBox(height: 2),
            pw.Divider(color: PdfColors.grey500, thickness: 0.6, height: 4),
          ],
        );
      default:
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            txt(title, size: 14, bold: true, color: accent),
            pw.Divider(color: accent, thickness: 1.2, height: 6),
          ],
        );
    }
  }

  List<pw.Widget> _section(String title, List<pw.Widget> children) => [
        pw.SizedBox(height: 14),
        _heading(title),
        pw.SizedBox(height: 8),
        ...children,
      ];

  pw.Widget _entry({
    required String title,
    required String period,
    required String sub,
    required String desc,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          rw([
            pw.Expanded(child: txt(title, size: 12, bold: true)),
            if (period.isNotEmpty)
              txt(period, size: 9.5, color: PdfColors.grey700),
          ]),
          if (sub.isNotEmpty)
            txt(sub, size: 10.5, bold: true, color: accent),
          if (desc.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            txt(desc),
          ],
        ],
      ),
    );
  }

  /// قائمة قصيرة (مهارات / لغات): شرائح في القالب العصري، ونص في الباقي.
  pw.Widget _inline(List<String> items) {
    if (tpl == 1) {
      final list = rtl ? items.reversed.toList() : items;
      return pw.Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: rtl ? pw.WrapAlignment.end : pw.WrapAlignment.start,
        children: [
          for (final s in list)
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: pw.BoxDecoration(
                color: tint(0.12),
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: txt(s, size: 10, color: accent),
            ),
        ],
      );
    }
    return txt(items.join(tpl == 2 ? '   ·   ' : '   •   '));
  }

  List<pw.Widget> build() {
    final l = _labels;
    final out = <pw.Widget>[_header()];

    if (cv.summary.trim().isNotEmpty) {
      out.addAll(_section(l['summary']!, [txt(cv.summary)]));
    }
    if (cv.experiences.isNotEmpty) {
      out.addAll(_section(l['experience']!, [
        for (final e in cv.experiences)
          _entry(
            title: e.title,
            period: e.period,
            sub: e.company,
            desc: e.description,
          ),
      ]));
    }
    if (cv.education.isNotEmpty) {
      out.addAll(_section(l['education']!, [
        for (final e in cv.education)
          _entry(title: e.degree, period: e.period, sub: e.school, desc: ''),
      ]));
    }
    if (cv.skills.isNotEmpty) {
      out.addAll(_section(l['skills']!, [_inline(cv.skills)]));
    }
    if (cv.languages.isNotEmpty) {
      out.addAll(_section(l['languages']!, [_inline(cv.languages)]));
    }
    if (cv.certificates.isNotEmpty) {
      out.addAll(_section(l['certificates']!, [
        for (final c in cv.certificates)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: txt('•  $c'),
          ),
      ]));
    }
    return out;
  }
}
