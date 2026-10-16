import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/models/lesson.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/settings.dart';
import '../../../../core/models/teacher.dart';
import '../../../../core/models/weekly_load_policy.dart';
import '../../../../core/utils/timetable_display_utils.dart';

const double _highResFactor = 3.0;

/// نمط تصدير جدول الفصول إلى ملف PDF.
enum TimetablePdfExportMode {
  /// تصدير الجدول كاملاً (جميع الصفوف والشعب في جدول واحد موحّد).
  full,

  /// تصدير الجدول مقسماً بحيث تحتوي كل ورقة A4 على صف واحد مع جميع شعبه فقط.
  splitByGrade,
}

/// يمثل مجموعة صف دراسي واحد مع كافة الشعب التابعة له.
class ClassroomGradeGroup {
  const ClassroomGradeGroup({
    required this.key,
    required this.title,
    required this.sortOrder,
    required this.classrooms,
  });

  /// المعرّف القياسي للمجموعة (مثال: `grade:1` أو `grade:6:علمي`).
  final String key;

  /// العنوان المعروض للصف الدراسي (مثال: `الصف الأول`).
  final String title;

  /// الترتيب المنطقي للصف (1 للأول، 2 للثاني، ...).
  final int sortOrder;

  /// قائمة الشعب التابعة لهذا الصف مرتبة حسب تسلسل الشعب.
  final List<Classroom> classrooms;
}

class PdfExportUseCase {
  String getAcademicYear() {
    final now = DateTime.now();
    int startYear = now.month >= 9 ? now.year : now.year - 1;
    return '$startYear/${startYear + 1}';
  }

  /// يجمع الفصول الدراسية حسب الصف الدراسي ويرتب الصفوف والشعب ترتيباً أكاديمياً سليماً.
  ///
  /// مثال:
  /// - الأول أ، الأول ب، الأول ج -> مجموعة واحدة (الصف الأول)
  /// - الثاني أ، الثاني ب، الثاني ج -> مجموعة ثانية (الصف الثاني)
  /// - الثالث أ، الثالث ب، الثالث ج -> مجموعة ثالثة (الصف الثالث)
  static List<ClassroomGradeGroup> groupClassroomsByGrade(
    List<Classroom> classrooms,
  ) {
    if (classrooms.isEmpty) {
      return const <ClassroomGradeGroup>[];
    }

    final Map<String, _MutableGradeGroup> groupsByKey = {};
    var insertionCounter = 0;

    for (final classroom in classrooms) {
      final resolved = _resolveGradeIdentity(classroom);
      final group = groupsByKey.putIfAbsent(
        resolved.key,
        () => _MutableGradeGroup(
          key: resolved.key,
          title: resolved.title,
          sortOrder: resolved.sortOrder,
          insertionIndex: insertionCounter++,
        ),
      );
      group.classrooms.add(classroom);
    }

    final sortedGroups = groupsByKey.values.toList()
      ..sort((a, b) {
        final orderCmp = a.sortOrder.compareTo(b.sortOrder);
        if (orderCmp != 0) return orderCmp;
        return a.insertionIndex.compareTo(b.insertionIndex);
      });

    return sortedGroups
        .map(
          (g) => ClassroomGradeGroup(
            key: g.key,
            title: g.title,
            sortOrder: g.sortOrder,
            classrooms: List<Classroom>.unmodifiable(
              g.classrooms..sort(_compareClassroomsWithinGrade),
            ),
          ),
        )
        .toList(growable: false);
  }

  /// يرتب جميع الفصول الدراسية حسب ترتيب صفوفها ثم ترتيب الشعب داخل كل صف.
  static List<Classroom> sortClassrooms(List<Classroom> classrooms) {
    final groups = groupClassroomsByGrade(classrooms);
    return <Classroom>[
      for (final group in groups) ...group.classrooms,
    ];
  }

  static _ResolvedGradeIdentity _resolveGradeIdentity(Classroom classroom) {
    final rawGrade = ((classroom.grade as String?) ?? '').trim();
    final rawName = ((classroom.name as String?) ?? '').trim();

    final academicGrade =
        _parseAcademicGrade(rawGrade) ?? _parseAcademicGrade(rawName);
    final branch = _extractBranchLabel('$rawGrade $rawName');

    if (academicGrade != null) {
      final branchSuffix = branch != null ? ':$branch' : '';
      final branchTitle = branch != null ? ' $branch' : '';
      final branchOrderOffset = branch == 'علمي'
          ? 1
          : branch == 'أدبي'
              ? 2
              : 0;
      return _ResolvedGradeIdentity(
        key: 'grade:${academicGrade.order}$branchSuffix',
        title: 'الصف ${academicGrade.label}$branchTitle',
        sortOrder: academicGrade.order * 10 + branchOrderOffset,
      );
    }

    final normalizedGrade = _normalizeArabicText(rawGrade);
    if (normalizedGrade.isNotEmpty) {
      return _ResolvedGradeIdentity(
        key: 'custom:$normalizedGrade',
        title: rawGrade,
        sortOrder: 1000,
      );
    }

    return const _ResolvedGradeIdentity(
      key: 'custom:unassigned',
      title: 'بدون صف',
      sortOrder: 9999,
    );
  }

  /// يستخرج الصف الدراسي (الأول..السادس) مع إعطاء الأولوية للكلمات العربية
  /// قبل الأرقام لتفادي الخلط بين رقم الشعبة (مثل «الأول 2») ورقم الصف.
  static AcademicGrade? _parseAcademicGrade(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final normalized = _normalizeArabicText(raw);

    if (normalized.contains('سادس')) return AcademicGrade.sixth;
    if (normalized.contains('خامس')) return AcademicGrade.fifth;
    if (normalized.contains('رابع')) return AcademicGrade.fourth;
    if (normalized.contains('ثالث')) return AcademicGrade.third;
    if (normalized.contains('ثاني') ||
        RegExp(r'(^|[\s/\-_])ثان($|[\s/\-_])').hasMatch(normalized)) {
      return AcademicGrade.second;
    }
    if (normalized.contains('اول')) return AcademicGrade.first;

    final digitMatch = RegExp(
      r'(?:^|[\s/\-_\(\)])([1-6١-٦])(?=$|[\s/\-_\(\)])',
    ).firstMatch(normalized);
    if (digitMatch != null) {
      final digit = _arabicIndicToWestern(digitMatch.group(1)!);
      switch (digit) {
        case '1':
          return AcademicGrade.first;
        case '2':
          return AcademicGrade.second;
        case '3':
          return AcademicGrade.third;
        case '4':
          return AcademicGrade.fourth;
        case '5':
          return AcademicGrade.fifth;
        case '6':
          return AcademicGrade.sixth;
      }
    }

    return AcademicGrade.tryParse(raw);
  }

  static String? _extractBranchLabel(String raw) {
    final normalized = _normalizeArabicText(raw);
    if (normalized.contains('علمي')) return 'علمي';
    if (normalized.contains('ادبي')) return 'أدبي';
    return null;
  }

  static int _compareClassroomsWithinGrade(Classroom a, Classroom b) {
    final secA = _extractSectionOrder(a.name);
    final secB = _extractSectionOrder(b.name);
    if (secA != null && secB != null && secA != secB) {
      return secA.compareTo(secB);
    }
    final idCmp = a.id.compareTo(b.id);
    if (idCmp != 0) return idCmp;
    final nameA = ((a.name as String?) ?? '').trim();
    final nameB = ((b.name as String?) ?? '').trim();
    return nameA.compareTo(nameB);
  }

  /// يستخرج ترتيب الشعبة (أ، ب، ج، د، هـ، و... أو 1، 2، 3...) لترتيب الشعب داخل الصف الواحد.
  static int? _extractSectionOrder(String? rawName) {
    if (rawName == null || rawName.trim().isEmpty) {
      return null;
    }

    final cleaned = _normalizeArabicText(rawName)
        .replaceAll(RegExp(r'[/\-_\(\)\[\]\.:،,]+'), ' ')
        .trim();
    if (cleaned.isEmpty) {
      return null;
    }

    // إزالة الكلمات الدالة على الصف والمرحلة للإبقاء على رمز الشعبة فقط
    const wordsToStrip = <String>{
      'الصف',
      'صف',
      'شعبه',
      'الشعبه',
      'فصل',
      'الفصل',
      'الاول',
      'اول',
      'الثاني',
      'ثاني',
      'ثان',
      'الثالث',
      'ثالث',
      'الرابع',
      'رابع',
      'الخامس',
      'خامس',
      'السادس',
      'سادس',
      'الابتدايي',
      'ابتدايي',
      'الابتداييه',
      'ابتداييه',
      'المتوسط',
      'المتوسطه',
      'متوسط',
      'متوسطه',
      'الاعدادي',
      'الاعداديه',
      'اعدادي',
      'اعداديه',
      'الثانوي',
      'الثانويه',
      'ثانوي',
      'ثانويه',
      'العلمي',
      'علمي',
      'الادبي',
      'ادبي',
    };

    final tokens = cleaned
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && !wordsToStrip.contains(t))
        .toList();
    if (tokens.isEmpty) {
      return null;
    }

    final lastToken = tokens.last;

    // يدعم كلاً من الترتيب الأبجدي المدرسي (أ، ب، ج، د، هـ، و، ز، ح، ط، ي)
    // والترتيب الهجائي (أ، ب، ت، ث، ج، ح، خ، د، ذ، ر...) والحروف اللاتينية.
    const sectionLetterOrder = <String, int>{
      'ا': 10,
      'ب': 20,
      'ت': 25,
      'ث': 26,
      'ج': 30,
      'ح': 35,
      'خ': 36,
      'د': 40,
      'ذ': 45,
      'ر': 46,
      'ه': 50,
      'هـ': 50,
      'و': 60,
      'ز': 70,
      'س': 75,
      'ش': 76,
      'ص': 77,
      'ض': 78,
      'ط': 80,
      'ظ': 85,
      'ع': 86,
      'غ': 87,
      'ف': 88,
      'ق': 89,
      'ي': 90,
      'ك': 100,
      'ل': 110,
      'م': 120,
      'ن': 130,
      'A': 10,
      'a': 10,
      'B': 20,
      'b': 20,
      'C': 30,
      'c': 30,
      'D': 40,
      'd': 40,
      'E': 50,
      'e': 50,
      'F': 60,
      'f': 60,
    };

    final letterOrder = sectionLetterOrder[lastToken];
    if (letterOrder != null) {
      return letterOrder;
    }

    final westernDigits = _arabicIndicToWestern(lastToken);
    final numberOrder = int.tryParse(westernDigits);
    if (numberOrder != null && numberOrder > 0) {
      return 1000 + numberOrder;
    }

    return null;
  }

  static String _normalizeArabicText(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ٱ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
  }

  static String _arabicIndicToWestern(String input) {
    const eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var result = input;
    for (var i = 0; i < eastern.length; i++) {
      result = result.replaceAll(eastern[i], i.toString());
    }
    return result;
  }

  Future<pw.Font> _loadArabicFont() async {
    try {
      final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
      return pw.Font.ttf(fontData);
    } catch (_) {
      final file = File('assets/fonts/Amiri-Regular.ttf');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        return pw.Font.ttf(ByteData.sublistView(bytes));
      }
      return pw.Font.helvetica();
    }
  }

  Future<Uint8List> generateTeacherTimetablePdf(List<Lesson> lessons,
      List<Teacher> teachers, AppSettings settings) async {
    final doc = pw.Document();

    final font = await _loadArabicFont();

    PdfPageFormat format = PdfPageFormat.a4.landscape;

    final PdfPageFormat highResFormat = PdfPageFormat(
      format.width * _highResFactor,
      format.height * _highResFactor,
      marginTop: 20 * _highResFactor,
      marginBottom: 20 * _highResFactor,
      marginLeft: 20 * _highResFactor,
      marginRight: 20 * _highResFactor,
    );

    for (var teacher in teachers) {
      final teacherLessons = lessons
          .where((l) => !l.isUnassigned && l.teacher.value?.id == teacher.id)
          .toList();

      final Map<String, Lesson> lessonMap = {};
      for (final l in teacherLessons) {
        lessonMap['${teacher.id}_${l.dayIndex}_${l.periodIndex}'] = l;
      }

      doc.addPage(
        pw.Page(
          pageFormat: highResFormat,
          textDirection: pw.TextDirection.rtl,
          margin: pw.EdgeInsets.all(20 * _highResFactor),
          theme: pw.ThemeData.withFont(
            base: font,
            bold: font,
          ),
          build: (pw.Context context) {
            String teacherName = (teacher.name as String?) ?? 'بدون اسم';
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                children: [
                  _buildHeader(settings, font,
                      subtitle: 'جدول المدرس: $teacherName'),
                  pw.SizedBox(height: 15 * _highResFactor),
                  pw.Expanded(
                    child: _buildTeacherTable(
                        teacher,
                        lessonMap,
                        settings,
                        font,
                        highResFormat.availableHeight - (120 * _highResFactor)),
                  ),
                  _buildFooter(settings, font, context),
                ],
              ),
            );
          },
        ),
      );
    }

    return doc.save();
  }

  pw.Widget _buildTeacherTable(Teacher teacher, Map<String, Lesson> lessonMap,
      AppSettings settings, pw.Font font, double availableHeight) {
    final displayDays = timetableDayLabels(settings.daysPerWeek);
    var periodsPerDay = settings.periodsPerDay;
    for (final lesson in lessonMap.values) {
      final p = lesson.periodIndex;
      if (p != null && p + 1 > periodsPerDay) {
        periodsPerDay = p + 1;
      }
    }

    final int totalCols = 1 + periodsPerDay;

    final Map<int, pw.TableColumnWidth> columnWidths = {
      totalCols - 1: const pw.FlexColumnWidth(0.5),
      for (int i = 0; i < periodsPerDay; i++)
        totalCols - 2 - i: const pw.FlexColumnWidth(1.0),
    };

    final double rowHeight = math.min(
      availableHeight / (1 + displayDays.length),
      34 * _highResFactor,
    );

    final List<pw.TableRow> rows = [];

    // Header Row
    final headerCells = <pw.Widget>[
      _buildCell('اليوم / الحصة', font, isHeader: true, height: rowHeight),
      for (int p = 0; p < periodsPerDay; p++)
        _buildCell((p + 1).toString(), font, isHeader: true, height: rowHeight),
    ];
    rows.add(
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: PdfColors.teal100),
        children: headerCells.reversed.toList(),
      ),
    );

    for (int d = 0; d < displayDays.length; d++) {
      final cells = <pw.Widget>[];
      cells.add(
          _buildCell(displayDays[d], font, isBold: true, height: rowHeight));

      for (int p = 0; p < periodsPerDay; p++) {
        final lesson = lessonMap['${teacher.id}_${d}_${p}'];
        if (lesson != null) {
          final cellLabel = formatTimetableCellLabel(
            subjectName: lesson.subject.value?.name,
            companionName: lesson.classroom.value?.name,
          );
          cells.add(
            pw.Container(
              height: rowHeight,
              alignment: pw.Alignment.center,
              padding: pw.EdgeInsets.symmetric(
                horizontal: 2 * _highResFactor,
                vertical: 1 * _highResFactor,
              ),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                      color: PdfColors.grey400, width: 0.5 * _highResFactor),
                  left: pw.BorderSide(
                      color: PdfColors.grey400, width: 0.5 * _highResFactor),
                  right: pw.BorderSide(
                      color: PdfColors.grey400, width: 0.5 * _highResFactor),
                  top: pw.BorderSide(
                      color: PdfColors.grey400, width: 0.5 * _highResFactor),
                ),
              ),
              child: pw.FittedBox(
                fit: pw.BoxFit.scaleDown,
                child: pw.Text(
                  cellLabel,
                  maxLines: 1,
                  textAlign: pw.TextAlign.center,
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(
                    font: font,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10 * _highResFactor,
                  ),
                ),
              ),
            ),
          );
        } else {
          cells.add(pw.Container(
            height: rowHeight,
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                    color: PdfColors.grey400, width: 0.5 * _highResFactor),
                left: pw.BorderSide(
                    color: PdfColors.grey400, width: 0.5 * _highResFactor),
                right: pw.BorderSide(
                    color: PdfColors.grey400, width: 0.5 * _highResFactor),
                top: pw.BorderSide(
                    color: PdfColors.grey400, width: 0.5 * _highResFactor),
              ),
            ),
          ));
        }
      }

      final bgColor = d % 2 == 0 ? PdfColors.grey50 : PdfColors.white;
      rows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: bgColor),
        children: cells.reversed.toList(),
      ));
    }

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Table(
        border: pw.TableBorder.all(
            color: PdfColors.grey400, width: 0.5 * _highResFactor),
        columnWidths: columnWidths,
        children: rows,
      ),
    );
  }

  Future<Uint8List> generateTimetablePdf(
    List<Lesson> lessons,
    List<Classroom> classrooms,
    AppSettings settings, {
    TimetablePdfExportMode mode = TimetablePdfExportMode.full,
  }) async {
    final doc = pw.Document();

    final font = await _loadArabicFont();

    final PdfPageFormat baseFormat;
    if (mode == TimetablePdfExportMode.splitByGrade) {
      // في التصدير المقسم: كل صف مع شعبه في ورقة A4 خاصة به
      baseFormat = PdfPageFormat.a4;
    } else {
      switch (settings.exportPageSize) {
        case 'A3':
          baseFormat = PdfPageFormat.a3;
          break;
        case 'A5':
          baseFormat = PdfPageFormat.a5;
          break;
        case 'Custom':
          final customW = settings.customPageWidth;
          final customH = settings.customPageHeight;
          if (customW != null &&
              customW > 0 &&
              customH != null &&
              customH > 0) {
            baseFormat = PdfPageFormat(
              customW * PdfPageFormat.cm,
              customH * PdfPageFormat.cm,
            );
          } else {
            baseFormat = PdfPageFormat.a4;
          }
          break;
        case 'A4':
        default:
          baseFormat = PdfPageFormat.a4;
          break;
      }
    }

    final PdfPageFormat format = settings.exportOrientation == 'Portrait'
        ? baseFormat.portrait
        : baseFormat.landscape;

    final PdfPageFormat highResFormat = PdfPageFormat(
      format.width * _highResFactor,
      format.height * _highResFactor,
      marginTop: 20 * _highResFactor,
      marginBottom: 20 * _highResFactor,
      marginLeft: 20 * _highResFactor,
      marginRight: 20 * _highResFactor,
    );

    final List<_PdfPageChunk> pageChunks = [];
    if (mode == TimetablePdfExportMode.splitByGrade) {
      final groups = groupClassroomsByGrade(classrooms);
      for (final group in groups) {
        if (group.classrooms.isNotEmpty) {
          pageChunks.add(
            _PdfPageChunk(
              classrooms: group.classrooms,
              subtitle: group.title,
            ),
          );
        }
      }
    } else {
      final sortedAll = sortClassrooms(classrooms);
      if (sortedAll.isNotEmpty) {
        pageChunks.add(
          _PdfPageChunk(
            classrooms: sortedAll,
            subtitle: null,
          ),
        );
      }
    }

    final Map<String, Lesson> lessonMap = {};
    for (final l in lessons) {
      if (!l.isUnassigned) {
        if (l.teacher.value == null) l.teacher.loadSync();
        if (l.subject.value == null) l.subject.loadSync();
        if (l.classroom.value == null) l.classroom.loadSync();
        final cId = l.classroom.value?.id;
        if (cId != null) {
          lessonMap['${cId}_${l.dayIndex}_${l.periodIndex}'] = l;
        }
      }
    }

    for (final pageChunk in pageChunks) {
      doc.addPage(
        pw.Page(
          pageFormat: highResFormat,
          textDirection: pw.TextDirection.rtl,
          margin: pw.EdgeInsets.all(20 * _highResFactor),
          theme: pw.ThemeData.withFont(
            base: font,
            bold: font,
          ),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                children: [
                  _buildHeader(settings, font, subtitle: pageChunk.subtitle),
                  pw.SizedBox(height: 15 * _highResFactor),
                  pw.Expanded(
                    child: _buildMasterTable(
                      pageChunk.classrooms,
                      lessonMap,
                      settings,
                      font,
                      highResFormat.availableHeight - (120 * _highResFactor),
                    ),
                  ),
                  _buildFooter(settings, font, context),
                ],
              ),
            );
          },
        ),
      );
    }

    return doc.save();
  }

  pw.Widget _buildHeader(AppSettings settings, pw.Font font,
      {String? subtitle}) {
    String schoolName = (settings.schoolName as String?) ?? '';
    String principalName = (settings.principalName as String?) ?? '';
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            flex: 1,
            child: pw.Text(
              schoolName,
              style: pw.TextStyle(
                  fontSize: 14 * _highResFactor,
                  font: font,
                  fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.right,
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Column(children: [
              pw.Text(
                'جدول الدروس الأسبوعي',
                style: pw.TextStyle(
                    fontSize: 18 * _highResFactor,
                    font: font,
                    fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              if (subtitle != null) ...[
                pw.SizedBox(height: 4 * _highResFactor),
                pw.Text(
                  subtitle,
                  style: pw.TextStyle(
                      fontSize: 16 * _highResFactor,
                      font: font,
                      fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
              ],
              pw.SizedBox(height: 4 * _highResFactor),
              pw.Text(
                'العام الدراسي: ${getAcademicYear()}',
                style: pw.TextStyle(fontSize: 12 * _highResFactor, font: font),
                textAlign: pw.TextAlign.center,
              ),
            ]),
          ),
          pw.Expanded(
            flex: 1,
            child: pw.Text(
              'المدير : $principalName',
              style: pw.TextStyle(
                  fontSize: 12 * _highResFactor,
                  font: font,
                  fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(
      AppSettings settings, pw.Font font, pw.Context context) {
    return pw.Container(
        alignment: pw.Alignment.center,
        padding: pw.EdgeInsets.only(top: 10 * _highResFactor),
        child: pw.Text(
          'صفحة ${context.pageNumber} من ${context.pagesCount}',
          style: pw.TextStyle(
              fontSize: 12 * _highResFactor,
              font: font,
              fontWeight: pw.FontWeight.normal),
          textDirection: pw.TextDirection.rtl,
        ));
  }

  pw.Widget _buildMasterTable(
      List<Classroom> chunk,
      Map<String, Lesson> lessonMap,
      AppSettings settings,
      pw.Font font,
      double availableHeight) {
    final displayDays = timetableDayLabels(settings.daysPerWeek);
    var periodsPerDay = settings.periodsPerDay;
    for (final lesson in lessonMap.values) {
      final p = lesson.periodIndex;
      if (p != null && p + 1 > periodsPerDay) {
        periodsPerDay = p + 1;
      }
    }

    bool isA3Layout = chunk.length > 4;

    final int totalCols = 2 + chunk.length;

    final Map<int, pw.TableColumnWidth> columnWidths = {
      totalCols - 1: isA3Layout
          ? const pw.FlexColumnWidth(1.0)
          : const pw.FlexColumnWidth(0.5),
      totalCols - 2: isA3Layout
          ? const pw.FlexColumnWidth(1.0)
          : const pw.FlexColumnWidth(0.3),
      for (int i = 0; i < chunk.length; i++)
        totalCols - 3 - i: isA3Layout
            ? const pw.FlexColumnWidth(1.0)
            : const pw.FlexColumnWidth(2.0),
    };

    final double rowHeight = math.min(
      availableHeight / (1 + displayDays.length * periodsPerDay),
      34 * _highResFactor,
    );

    final List<pw.TableRow> rows = [];

    // Header Row
    final headerCells = <pw.Widget>[
      _buildCell('اليوم', font, isHeader: true, height: rowHeight),
      _buildCell('الدرس', font, isHeader: true, height: rowHeight),
      for (int c = 0; c < chunk.length; c++)
        _buildCell(
          (chunk[c].name as String?) ?? '',
          font,
          isHeader: true,
          height: rowHeight,
        ),
    ];
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.teal100),
        children: headerCells.reversed.toList(),
      ),
    );

    for (int d = 0; d < displayDays.length; d++) {
      for (int p = 0; p < periodsPerDay; p++) {
        final cells = <pw.Widget>[];

        bool isLastPeriodOfDay = p == periodsPerDay - 1;

        // Day Cell Logic
        if (p == 0) {
          cells.add(
            _buildCell(displayDays[d], font,
                isBold: true,
                hideBottomBorder: !isLastPeriodOfDay,
                height: rowHeight),
          );
        } else {
          cells.add(
            pw.Container(
              height: rowHeight,
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: isLastPeriodOfDay
                      ? pw.BorderSide(
                          color: PdfColors.grey400, width: 0.5 * _highResFactor)
                      : pw.BorderSide.none,
                  left: pw.BorderSide(
                      color: PdfColors.grey400, width: 0.5 * _highResFactor),
                  right: pw.BorderSide(
                      color: PdfColors.grey400, width: 0.5 * _highResFactor),
                ),
              ),
              child: pw.SizedBox(),
            ),
          );
        }

        // Period Cell Logic
        cells.add(
          _buildCell((p + 1).toString(), font, isBold: true, height: rowHeight),
        );

        // Classrooms Cells Logic
        for (int c = 0; c < chunk.length; c++) {
          final classroom = chunk[c];

          final lesson = lessonMap['${classroom.id}_${d}_${p}'];

          pw.Widget cellContent = pw.SizedBox();
          if (lesson != null) {
            final cellLabel = formatTimetableCellLabel(
              subjectName: lesson.subject.value?.name,
              companionName: firstTimetableName(lesson.teacher.value?.name),
            );

            cellContent = pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              child: pw.Text(
                cellLabel,
                maxLines: 1,
                textAlign: pw.TextAlign.center,
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(
                  font: font,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
          }

          cells.add(
            pw.Container(
              height: rowHeight,
              alignment: pw.Alignment.center,
              padding: pw.EdgeInsets.all(1 * _highResFactor),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                      color: PdfColors.grey400, width: 0.5 * _highResFactor),
                  left: pw.BorderSide(
                      color: PdfColors.grey400, width: 0.5 * _highResFactor),
                  right: pw.BorderSide(
                      color: PdfColors.grey400, width: 0.5 * _highResFactor),
                ),
              ),
              child: cellContent,
            ),
          );
        }

        final bgColor = p % 2 == 0 ? PdfColors.grey50 : PdfColors.white;
        rows.add(pw.TableRow(
          decoration: pw.BoxDecoration(color: bgColor),
          children: cells.reversed.toList(),
        ));
      }
    }

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Table(
        border: pw.TableBorder.all(
            color: PdfColors.grey400, width: 0.5 * _highResFactor),
        columnWidths: columnWidths,
        children: rows,
      ),
    );
  }

  pw.Widget _buildCell(String text, pw.Font font,
      {bool isHeader = false,
      bool isBold = false,
      bool hideBottomBorder = false,
      double? height}) {
    return pw.Container(
      height: height,
      alignment: pw.Alignment.center,
      padding: pw.EdgeInsets.symmetric(
        horizontal: 2 * _highResFactor,
        vertical: 1 * _highResFactor,
      ),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: hideBottomBorder
              ? pw.BorderSide.none
              : pw.BorderSide(
                  color: PdfColors.grey400, width: 0.5 * _highResFactor),
          left: pw.BorderSide(
              color: PdfColors.grey400, width: 0.5 * _highResFactor),
          right: pw.BorderSide(
              color: PdfColors.grey400, width: 0.5 * _highResFactor),
        ),
      ),
      child: pw.FittedBox(
        fit: pw.BoxFit.scaleDown,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            font: font,
            fontWeight: (isHeader || isBold)
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }
}

class _ResolvedGradeIdentity {
  const _ResolvedGradeIdentity({
    required this.key,
    required this.title,
    required this.sortOrder,
  });

  final String key;
  final String title;
  final int sortOrder;
}

class _MutableGradeGroup {
  _MutableGradeGroup({
    required this.key,
    required this.title,
    required this.sortOrder,
    required this.insertionIndex,
  });

  final String key;
  final String title;
  final int sortOrder;
  final int insertionIndex;
  final List<Classroom> classrooms = <Classroom>[];
}

class _PdfPageChunk {
  const _PdfPageChunk({
    required this.classrooms,
    required this.subtitle,
  });

  final List<Classroom> classrooms;
  final String? subtitle;
}
