# سيرتي وقارئ PDF

تطبيق Flutter بسيط يقوم بـ:

1. **إنشاء سيرة ذاتية** (عربي أو English، مع صورة وألوان) وتحويلها إلى ملف **PDF**.
2. **قراءة أي ملف PDF** من الجهاز (كتب، مستندات...).
3. حفظ السير المُنشأة وعرض آخر الملفات المفتوحة، مع المشاركة والطباعة.

## الهيكل

```
cv_reader_app/
├── pubspec.yaml
├── analysis_options.yaml
├── .gitignore
├── .github/workflows/build_apk.yml   ← بناء APK تلقائياً
└── lib/
    ├── main.dart
    ├── models/cv_data.dart
    ├── services/
    │   ├── pdf_service.dart
    │   └── recent_service.dart
    └── screens/
        ├── home_screen.dart
        ├── cv_screen.dart
        ├── reader_screen.dart
        └── saved_files_screen.dart
```

> مجلد `android/` غير موجود عمداً؛ يتم توليده تلقائياً داخل GitHub Actions.
> كذلك يُحمَّل الخط العربي (Tajawal) أثناء البناء ويُضمَّن داخل الـ APK، لذلك **التطبيق يعمل بالكامل بدون إنترنت**.

## بناء APK عبر GitHub

1. أنشئ مستودعاً جديداً على GitHub.
2. ارفع **كل محتويات هذا المجلد** (بما فيها مجلد `.github` المخفي).
3. افتح تبويب **Actions** ← **Build APK** ← **Run workflow** (يعمل تلقائياً مع كل push أيضاً).
4. بعد انتهائه (5–10 دقائق) افتح التشغيل ونزّل **app-release-apk** من قسم *Artifacts*.
5. فك الضغط وثبّت `app-release.apk` على هاتفك.

## التشغيل محلياً (اختياري)

```bash
flutter create --platforms=android --project-name cv_reader_app .
mkdir -p assets/fonts
# نزّل Tajawal-Regular.ttf و Tajawal-Bold.ttf من Google Fonts وضعهما في assets/fonts
flutter pub get
flutter run
```

## ملاحظات

- التطبيق لا يحتاج إنترنت إطلاقاً: إنشاء PDF (عربي وإنجليزي) وقراءة الملفات يعملان أوفلاين.
- لا يطلب التطبيق إذن الإنترنت.

## تحديث التطبيق من الهاتف

الرفع من متصفح الهاتف لا يحفظ المجلدات، لذلك اسم الملف يحمل مساره بعلامة `__`:

`lib__screens__cv_screen.dart` ← يصبح `lib/screens/cv_screen.dart` أثناء البناء.

ارفع الملفات المحدّثة بهذه الأسماء إلى جذر المستودع، وسيبدأ البناء تلقائياً.
