import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// يحفظ آخر الملفات التي تم فتحها.
class RecentService {
  static const _key = 'recent_files';

  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.where((p) => File(p).existsSync()).toList();
  }

  static Future<void> add(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.remove(path);
    list.insert(0, path);
    await prefs.setStringList(_key, list.take(10).toList());
  }
}
