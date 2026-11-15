import 'dart:convert';

class ExperienceItem {
  String title;
  String company;
  String period;
  String description;

  ExperienceItem({
    this.title = '',
    this.company = '',
    this.period = '',
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'company': company,
        'period': period,
        'description': description,
      };

  factory ExperienceItem.fromJson(Map<String, dynamic> j) => ExperienceItem(
        title: j['title'] ?? '',
        company: j['company'] ?? '',
        period: j['period'] ?? '',
        description: j['description'] ?? '',
      );
}

class EducationItem {
  String degree;
  String school;
  String period;

  EducationItem({this.degree = '', this.school = '', this.period = ''});

  Map<String, dynamic> toJson() =>
      {'degree': degree, 'school': school, 'period': period};

  factory EducationItem.fromJson(Map<String, dynamic> j) => EducationItem(
        degree: j['degree'] ?? '',
        school: j['school'] ?? '',
        period: j['period'] ?? '',
      );
}

class CvData {
  CvData();

  String fullName = '';
  String jobTitle = '';
  String email = '';
  String phone = '';
  String address = '';
  String website = '';
  String summary = '';
  String photoPath = '';

  /// 0 = كلاسيكي، 1 = عصري، 2 = أنيق
  int template = 0;

  /// true = سيرة عربية (من اليمين لليسار)، false = English
  bool rtl = true;
  int accent = 0xFF1E5AA8;

  List<ExperienceItem> experiences = [];
  List<EducationItem> education = [];
  List<String> skills = [];
  List<String> languages = [];
  List<String> certificates = [];

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'jobTitle': jobTitle,
        'email': email,
        'phone': phone,
        'address': address,
        'website': website,
        'summary': summary,
        'photoPath': photoPath,
        'template': template,
        'rtl': rtl,
        'accent': accent,
        'experiences': experiences.map((e) => e.toJson()).toList(),
        'education': education.map((e) => e.toJson()).toList(),
        'skills': skills,
        'languages': languages,
        'certificates': certificates,
      };

  factory CvData.fromJson(Map<String, dynamic> j) {
    final cv = CvData();
    cv.fullName = j['fullName'] ?? '';
    cv.jobTitle = j['jobTitle'] ?? '';
    cv.email = j['email'] ?? '';
    cv.phone = j['phone'] ?? '';
    cv.address = j['address'] ?? '';
    cv.website = j['website'] ?? '';
    cv.summary = j['summary'] ?? '';
    cv.photoPath = j['photoPath'] ?? '';
    cv.template = j['template'] ?? 0;
    cv.rtl = j['rtl'] ?? true;
    cv.accent = j['accent'] ?? 0xFF1E5AA8;
    cv.experiences = ((j['experiences'] ?? []) as List)
        .map((e) => ExperienceItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    cv.education = ((j['education'] ?? []) as List)
        .map((e) => EducationItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    cv.skills = List<String>.from(j['skills'] ?? []);
    cv.languages = List<String>.from(j['languages'] ?? []);
    cv.certificates = List<String>.from(j['certificates'] ?? []);
    return cv;
  }

  String encode() => jsonEncode(toJson());

  static CvData decode(String s) =>
      CvData.fromJson(Map<String, dynamic>.from(jsonDecode(s)));
}
