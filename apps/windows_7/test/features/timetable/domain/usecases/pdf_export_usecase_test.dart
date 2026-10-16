import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/models/classroom.dart';
import 'package:jadwal_v2/core/models/lesson.dart';
import 'package:jadwal_v2/core/models/settings.dart';
import 'package:jadwal_v2/core/models/subject.dart';
import 'package:jadwal_v2/core/models/teacher.dart';
import 'package:jadwal_v2/core/services/file_save_service.dart';
import 'package:jadwal_v2/features/timetable/domain/usecases/pdf_export_usecase.dart';
import 'package:jadwal_v2/features/timetable/presentation/pages/timetable_page.dart';
import 'package:jadwal_v2/features/timetable/presentation/providers/timetable_provider.dart';

Classroom _makeClassroom(int id, {required String name, required String grade}) {
  return Classroom()
    ..id = id
    ..name = name
    ..grade = grade;
}

List<Classroom> _buildStandardGradeClassrooms(int gradeCount) {
  const gradeNames = <int, (String, String)>{
    1: ('الأول', 'الصف الأول'),
    2: ('الثاني', 'الصف الثاني'),
    3: ('الثالث', 'الصف الثالث'),
    4: ('الرابع', 'الصف الرابع'),
    5: ('الخامس', 'الصف الخامس'),
    6: ('السادس', 'الصف السادس'),
    7: ('السابع', 'الصف السابع'),
    8: ('الثامن', 'الصف الثامن'),
  };
  const sections = <String>['أ', 'ب', 'ج'];
  final result = <Classroom>[];
  var id = 1;
  for (var g = 1; g <= gradeCount; g++) {
    final (shortGrade, fullGrade) = gradeNames[g]!;
    for (final sec in sections) {
      result.add(
        _makeClassroom(
          id++,
          name: '$shortGrade $sec',
          grade: fullGrade,
        ),
      );
    }
  }
  return result;
}

int _countPdfPages(List<int> pdfBytes) {
  final raw = latin1.decode(pdfBytes, allowInvalid: true);
  return RegExp(r'/Type\s*/Page\b').allMatches(raw).length;
}

List<List<double>> _extractPageMediaBoxes(List<int> pdfBytes) {
  final raw = latin1.decode(pdfBytes, allowInvalid: true);
  final matches = RegExp(
    r'/MediaBox\s*\[\s*([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s*\]',
  ).allMatches(raw);
  return matches
      .map(
        (m) => <double>[
          double.parse(m.group(1)!),
          double.parse(m.group(2)!),
          double.parse(m.group(3)!),
          double.parse(m.group(4)!),
        ],
      )
      .toList();
}

/// يفك ضغط جميع تدفقات محتوى الصفحات (Content Streams) داخل ملف PDF للتحقق من وجود عناصر الرسم والنصوص.
List<String> _extractDecompressedPdfStreams(Uint8List pdfBytes) {
  final raw = latin1.decode(pdfBytes, allowInvalid: true);
  final streamPattern = RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream');
  final decodedStreams = <String>[];

  for (final match in streamPattern.allMatches(raw)) {
    final compressedLatin1 = match.group(1)!;
    final compressedBytes = latin1.encode(compressedLatin1);
    try {
      final decompressed = zlib.decode(compressedBytes);
      decodedStreams.add(latin1.decode(decompressed, allowInvalid: true));
    } catch (_) {
      decodedStreams.add(compressedLatin1);
    }
  }
  return decodedStreams;
}

class _FakeTimetableNotifier extends TimetableNotifier {
  @override
  Future<List<Lesson>> build() async => const <Lesson>[];
}

class _RecordingFileSaveService extends FileSaveService {
  _RecordingFileSaveService({
    this.simulatedOutcome,
  }) : super(
          isDesktop: () => true,
        );

  final FileSaveOutcome? simulatedOutcome;
  int saveCallCount = 0;
  String? lastFileName;
  Uint8List? lastBytes;

  @override
  Future<FileSaveOutcome> saveBytes({
    required String dialogTitle,
    required String fileName,
    required List<String> allowedExtensions,
    required Uint8List bytes,
  }) async {
    saveCallCount++;
    lastFileName = fileName;
    lastBytes = bytes;
    return simulatedOutcome ?? FileSaved('/tmp/$fileName');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfExportUseCase - Grade Grouping & Section Ordering', () {
    test(
        'يقسم الصفوف (الأول أ-ب-ج، الثاني أ-ب-ج، الثالث أ-ب-ج) إلى مجموعة لكل صف مرتبة ترتيباً صحيحاً',
        () {
      final classrooms = <Classroom>[
        _makeClassroom(1, name: 'الثالث ج', grade: 'الصف الثالث'),
        _makeClassroom(2, name: 'الأول ب', grade: 'الصف الأول'),
        _makeClassroom(3, name: 'الثاني أ', grade: 'الصف الثاني'),
        _makeClassroom(4, name: 'الأول أ', grade: 'الصف الأول'),
        _makeClassroom(5, name: 'الثالث أ', grade: 'الصف الثالث'),
        _makeClassroom(6, name: 'الثاني ج', grade: 'الصف الثاني'),
        _makeClassroom(7, name: 'الأول ج', grade: 'الصف الأول'),
        _makeClassroom(8, name: 'الثاني ب', grade: 'الصف الثاني'),
        _makeClassroom(9, name: 'الثالث ب', grade: 'الصف الثالث'),
      ];

      final groups = PdfExportUseCase.groupClassroomsByGrade(classrooms);

      expect(groups.length, 3);

      expect(groups[0].title, 'الصف الأول');
      expect(
        groups[0].classrooms.map((c) => c.name).toList(),
        ['الأول أ', 'الأول ب', 'الأول ج'],
      );

      expect(groups[1].title, 'الصف الثاني');
      expect(
        groups[1].classrooms.map((c) => c.name).toList(),
        ['الثاني أ', 'الثاني ب', 'الثاني ج'],
      );

      expect(groups[2].title, 'الصف الثالث');
      expect(
        groups[2].classrooms.map((c) => c.name).toList(),
        ['الثالث أ', 'الثالث ب', 'الثالث ج'],
      );
    });

    test(
        'يتعرف على الصف من اسم الشعبة حتى لو كتب المستخدم المرحلة العامة (مثل «المتوسطة») في حقل المرحلة',
        () {
      final classrooms = <Classroom>[
        _makeClassroom(1, name: 'الأول أ', grade: 'المتوسطة'),
        _makeClassroom(2, name: 'الأول ب', grade: 'المتوسطة'),
        _makeClassroom(3, name: 'الأول ج', grade: 'المتوسطة'),
        _makeClassroom(4, name: 'الثاني أ', grade: 'المتوسطة'),
        _makeClassroom(5, name: 'الثاني ب', grade: 'المتوسطة'),
        _makeClassroom(6, name: 'الثاني ج', grade: 'المتوسطة'),
        _makeClassroom(7, name: 'الثالث أ', grade: 'المتوسطة'),
        _makeClassroom(8, name: 'الثالث ب', grade: 'المتوسطة'),
        _makeClassroom(9, name: 'الثالث ج', grade: 'المتوسطة'),
      ];

      final groups = PdfExportUseCase.groupClassroomsByGrade(classrooms);

      expect(groups.length, 3);
      expect(groups[0].title, 'الصف الأول');
      expect(
        groups[0].classrooms.map((c) => c.name).toList(),
        ['الأول أ', 'الأول ب', 'الأول ج'],
      );
      expect(groups[1].title, 'الصف الثاني');
      expect(
        groups[1].classrooms.map((c) => c.name).toList(),
        ['الثاني أ', 'الثاني ب', 'الثاني ج'],
      );
      expect(groups[2].title, 'الصف الثالث');
      expect(
        groups[2].classrooms.map((c) => c.name).toList(),
        ['الثالث أ', 'الثالث ب', 'الثالث ج'],
      );
    });

    test('يرتب الصفوف بالترتيب الأكاديمي (الأول..السابع) وليس الأبجدي', () {
      final classrooms = <Classroom>[
        _makeClassroom(1, name: 'السابع أ', grade: 'الصف السابع'),
        _makeClassroom(2, name: 'السادس أ', grade: 'الصف السادس'),
        _makeClassroom(3, name: 'الخامس أ', grade: 'الصف الخامس'),
        _makeClassroom(4, name: 'الرابع أ', grade: 'الصف الرابع'),
        _makeClassroom(5, name: 'الثالث أ', grade: 'الصف الثالث'),
        _makeClassroom(6, name: 'الثاني أ', grade: 'الصف الثاني'),
        _makeClassroom(7, name: 'الأول أ', grade: 'الصف الأول'),
      ];

      final groups = PdfExportUseCase.groupClassroomsByGrade(classrooms);

      expect(
        groups.map((g) => g.title).toList(),
        [
          'الصف الأول',
          'الصف الثاني',
          'الصف الثالث',
          'الصف الرابع',
          'الصف الخامس',
          'الصف السادس',
          'الصف السابع',
        ],
      );
    });

    test(
        'يرتب الشعب بالحروف العربية (أبجد وهجاء) والحروف الإنجليزية والأرقام العربية والهندية',
        () {
      final abjadClassrooms = <Classroom>[
        _makeClassroom(1, name: 'الأول ز', grade: 'الصف الأول'),
        _makeClassroom(2, name: 'الأول هـ', grade: 'الصف الأول'),
        _makeClassroom(3, name: 'الأول ب', grade: 'الصف الأول'),
        _makeClassroom(4, name: 'الأول و', grade: 'الصف الأول'),
        _makeClassroom(5, name: 'الأول أ', grade: 'الصف الأول'),
        _makeClassroom(6, name: 'الأول د', grade: 'الصف الأول'),
        _makeClassroom(7, name: 'الأول ج', grade: 'الصف الأول'),
      ];
      final abjadGroups =
          PdfExportUseCase.groupClassroomsByGrade(abjadClassrooms);
      expect(
        abjadGroups.single.classrooms.map((c) => c.name).toList(),
        [
          'الأول أ',
          'الأول ب',
          'الأول ج',
          'الأول د',
          'الأول هـ',
          'الأول و',
          'الأول ز',
        ],
      );

      final hijaiClassrooms = <Classroom>[
        _makeClassroom(1, name: 'الثاني ج', grade: 'الصف الثاني'),
        _makeClassroom(2, name: 'الثاني ث', grade: 'الصف الثاني'),
        _makeClassroom(3, name: 'الثاني أ', grade: 'الصف الثاني'),
        _makeClassroom(4, name: 'الثاني ت', grade: 'الصف الثاني'),
        _makeClassroom(5, name: 'الثاني ب', grade: 'الصف الثاني'),
      ];
      final hijaiGroups =
          PdfExportUseCase.groupClassroomsByGrade(hijaiClassrooms);
      expect(
        hijaiGroups.single.classrooms.map((c) => c.name).toList(),
        ['الثاني أ', 'الثاني ب', 'الثاني ت', 'الثاني ث', 'الثاني ج'],
      );

      final latinAndIndic = <Classroom>[
        _makeClassroom(1, name: 'الثالث C', grade: 'الصف الثالث'),
        _makeClassroom(2, name: 'الثالث A', grade: 'الصف الثالث'),
        _makeClassroom(3, name: 'الثالث B', grade: 'الصف الثالث'),
        _makeClassroom(4, name: 'الرابع ٣', grade: 'الصف الرابع'),
        _makeClassroom(5, name: 'الرابع ١', grade: 'الصف الرابع'),
        _makeClassroom(6, name: 'الرابع ٢', grade: 'الصف الرابع'),
      ];
      final mixedGroups = PdfExportUseCase.groupClassroomsByGrade(latinAndIndic);
      expect(mixedGroups.length, 2);
      expect(
        mixedGroups[0].classrooms.map((c) => c.name).toList(),
        ['الثالث A', 'الثالث B', 'الثالث C'],
      );
      expect(
        mixedGroups[1].classrooms.map((c) => c.name).toList(),
        ['الرابع ١', 'الرابع ٢', 'الرابع ٣'],
      );
    });

    test('لا يخلط بين رقم الشعبة (الأول 1، الأول 2، الأول 3) ورقم الصف', () {
      final classrooms = <Classroom>[
        _makeClassroom(1, name: 'الأول 3', grade: 'الصف الأول'),
        _makeClassroom(2, name: 'الأول 1', grade: 'الصف الأول'),
        _makeClassroom(3, name: 'الأول 2', grade: 'الصف الأول'),
        _makeClassroom(4, name: 'الثاني 2', grade: 'الصف الثاني'),
        _makeClassroom(5, name: 'الثاني 1', grade: 'الصف الثاني'),
      ];

      final groups = PdfExportUseCase.groupClassroomsByGrade(classrooms);

      expect(groups.length, 2);
      expect(groups[0].title, 'الصف الأول');
      expect(
        groups[0].classrooms.map((c) => c.name).toList(),
        ['الأول 1', 'الأول 2', 'الأول 3'],
      );
      expect(groups[1].title, 'الصف الثاني');
      expect(
        groups[1].classrooms.map((c) => c.name).toList(),
        ['الثاني 1', 'الثاني 2'],
      );
    });

    test('يفصل بين الفروع الدراسية (علمي / أدبي) لنفس الصف الإعدادي', () {
      final classrooms = <Classroom>[
        _makeClassroom(1, name: 'السادس الأدبي أ', grade: 'السادس الأدبي'),
        _makeClassroom(2, name: 'السادس العلمي ب', grade: 'السادس العلمي'),
        _makeClassroom(3, name: 'السادس العلمي أ', grade: 'السادس العلمي'),
        _makeClassroom(4, name: 'السادس الأدبي ب', grade: 'السادس الأدبي'),
      ];

      final groups = PdfExportUseCase.groupClassroomsByGrade(classrooms);

      expect(groups.length, 2);
      expect(groups[0].title, 'الصف السادس علمي');
      expect(
        groups[0].classrooms.map((c) => c.name).toList(),
        ['السادس العلمي أ', 'السادس العلمي ب'],
      );
      expect(groups[1].title, 'الصف السادس أدبي');
      expect(
        groups[1].classrooms.map((c) => c.name).toList(),
        ['السادس الأدبي أ', 'السادس الأدبي ب'],
      );
    });

    test(
        'يتعامل بأمان مع الصفوف المخصصة أو التي لا يمكن تحديد مرحلتها أو صفها بوضوح',
        () {
      final classrooms = <Classroom>[
        _makeClassroom(1, name: 'قاعة النشاط', grade: ''),
        _makeClassroom(2, name: 'تمهيدي ب', grade: 'المرحلة التمهيدية'),
        _makeClassroom(3, name: 'الأول أ', grade: 'الصف الأول'),
        _makeClassroom(4, name: 'تمهيدي أ', grade: 'المرحلة التمهيدية'),
        _makeClassroom(5, name: 'المختبر', grade: '   '),
      ];

      final groups = PdfExportUseCase.groupClassroomsByGrade(classrooms);

      expect(groups.length, 3);
      expect(groups[0].title, 'الصف الأول');
      expect(groups[0].classrooms.map((c) => c.name).toList(), ['الأول أ']);

      expect(groups[1].title, 'المرحلة التمهيدية');
      expect(
        groups[1].classrooms.map((c) => c.name).toList(),
        ['تمهيدي أ', 'تمهيدي ب'],
      );

      expect(groups[2].title, 'بدون صف');
      expect(
        groups[2].classrooms.map((c) => c.name).toList(),
        ['قاعة النشاط', 'المختبر'],
      );
    });
  });

  group('PdfExportUseCase - Grades Per Page Distribution (ceil(N / K))', () {
    test('1. ستة صفوف مع اختيار صف واحد لكل ورقة (K=1) ينتج 6 أوراق', () {
      final classrooms = _buildStandardGradeClassrooms(6).reversed.toList();
      final chunks = PdfExportUseCase.distributeClassroomsByGradesPerPage(
        classrooms,
        gradesPerPage: 1,
      );

      expect(chunks.length, 6);
      expect(
        chunks.map((c) => c.subtitle).toList(),
        [
          'الصف الأول',
          'الصف الثاني',
          'الصف الثالث',
          'الصف الرابع',
          'الصف الخامس',
          'الصف السادس',
        ],
      );
      expect(
        chunks[0].classrooms.map((c) => c.name).toList(),
        ['الأول أ', 'الأول ب', 'الأول ج'],
      );
      expect(
        chunks[5].classrooms.map((c) => c.name).toList(),
        ['السادس أ', 'السادس ب', 'السادس ج'],
      );
    });

    test('2. ستة صفوف مع اختيار صفّين لكل ورقة (K=2) ينتج 3 أوراق مرتبة', () {
      final classrooms = _buildStandardGradeClassrooms(6).reversed.toList();
      final chunks = PdfExportUseCase.distributeClassroomsByGradesPerPage(
        classrooms,
        gradesPerPage: 2,
      );

      expect(chunks.length, 3);

      // الورقة الأولى: الصف الأول بشعبه أ، ب، ج ثم الصف الثاني بشعبه أ، ب، ج
      expect(chunks[0].subtitle, 'الصف الأول - الصف الثاني');
      expect(
        chunks[0].classrooms.map((c) => c.name).toList(),
        ['الأول أ', 'الأول ب', 'الأول ج', 'الثاني أ', 'الثاني ب', 'الثاني ج'],
      );

      // الورقة الثانية: الصف الثالث بشعبه أ، ب، ج ثم الصف الرابع بشعبه أ، ب، ج
      expect(chunks[1].subtitle, 'الصف الثالث - الصف الرابع');
      expect(
        chunks[1].classrooms.map((c) => c.name).toList(),
        [
          'الثالث أ',
          'الثالث ب',
          'الثالث ج',
          'الرابع أ',
          'الرابع ب',
          'الرابع ج',
        ],
      );

      // الورقة الثالثة: الصف الخامس بشعبه أ، ب، ج ثم الصف السادس بشعبه أ، ب، ج
      expect(chunks[2].subtitle, 'الصف الخامس - الصف السادس');
      expect(
        chunks[2].classrooms.map((c) => c.name).toList(),
        [
          'الخامس أ',
          'الخامس ب',
          'الخامس ج',
          'السادس أ',
          'السادس ب',
          'السادس ج',
        ],
      );
    });

    test('3. ستة صفوف مع اختيار 3 صفوف لكل ورقة (K=3) ينتج ورقتين', () {
      final classrooms = _buildStandardGradeClassrooms(6);
      final chunks = PdfExportUseCase.distributeClassroomsByGradesPerPage(
        classrooms,
        gradesPerPage: 3,
      );

      expect(chunks.length, 2);
      expect(chunks[0].subtitle, 'الصف الأول - الصف الثاني - الصف الثالث');
      expect(
        chunks[0].classrooms.map((c) => c.name).toList(),
        [
          'الأول أ',
          'الأول ب',
          'الأول ج',
          'الثاني أ',
          'الثاني ب',
          'الثاني ج',
          'الثالث أ',
          'الثالث ب',
          'الثالث ج',
        ],
      );

      expect(chunks[1].subtitle, 'الصف الرابع - الصف الخامس - الصف السادس');
      expect(
        chunks[1].classrooms.map((c) => c.name).toList(),
        [
          'الرابع أ',
          'الرابع ب',
          'الرابع ج',
          'الخامس أ',
          'الخامس ب',
          'الخامس ج',
          'السادس أ',
          'السادس ب',
          'السادس ج',
        ],
      );
    });

    test('4. ستة صفوف مع اختيار 4 صفوف لكل ورقة (K=4) ينتج ورقتين (4 + 2)', () {
      final classrooms = _buildStandardGradeClassrooms(6);
      final chunks = PdfExportUseCase.distributeClassroomsByGradesPerPage(
        classrooms,
        gradesPerPage: 4,
      );

      expect(chunks.length, 2);
      expect(
        chunks[0].subtitle,
        'الصف الأول - الصف الثاني - الصف الثالث - الصف الرابع',
      );
      expect(chunks[0].gradeGroups.length, 4);
      expect(chunks[0].classrooms.length, 12);

      expect(chunks[1].subtitle, 'الصف الخامس - الصف السادس');
      expect(chunks[1].gradeGroups.length, 2);
      expect(
        chunks[1].classrooms.map((c) => c.name).toList(),
        [
          'الخامس أ',
          'الخامس ب',
          'الخامس ج',
          'السادس أ',
          'السادس ب',
          'السادس ج',
        ],
      );
    });

    test(
        '5. سبعة صفوف مع اختيار 3 صفوف لكل ورقة (K=3) ينتج 3 أوراق وتحتوي الأخيرة الصف السابع وحده',
        () {
      final classrooms = _buildStandardGradeClassrooms(7).reversed.toList();
      final chunks = PdfExportUseCase.distributeClassroomsByGradesPerPage(
        classrooms,
        gradesPerPage: 3,
      );

      expect(chunks.length, 3);
      expect(chunks[0].subtitle, 'الصف الأول - الصف الثاني - الصف الثالث');
      expect(chunks[0].gradeGroups.length, 3);

      expect(chunks[1].subtitle, 'الصف الرابع - الصف الخامس - الصف السادس');
      expect(chunks[1].gradeGroups.length, 3);

      expect(chunks[2].subtitle, 'الصف السابع');
      expect(chunks[2].gradeGroups.length, 1);
      expect(
        chunks[2].classrooms.map((c) => c.name).toList(),
        ['السابع أ', 'السابع ب', 'السابع ج'],
      );
    });

    test('6 & 7. يتعامل مع صف واحد فقط ومع قائمة الفصول الفارغة بأمان', () {
      final singleGrade = _buildStandardGradeClassrooms(1);
      for (final k in [1, 2, 3, 5]) {
        final chunks = PdfExportUseCase.distributeClassroomsByGradesPerPage(
          singleGrade,
          gradesPerPage: k,
        );
        expect(chunks.length, 1);
        expect(chunks.single.subtitle, 'الصف الأول');
        expect(
          chunks.single.classrooms.map((c) => c.name).toList(),
          ['الأول أ', 'الأول ب', 'الأول ج'],
        );
      }

      final emptyChunks = PdfExportUseCase.distributeClassroomsByGradesPerPage(
        const <Classroom>[],
        gradesPerPage: 2,
      );
      expect(emptyChunks, isEmpty);
    });

    test(
        '8 & 9. لا يفصل شعب الصف الواحد بين ورقتين ولا يسقط أو يكرر أي فصل مهما اختلفت أعداد الشعب',
        () {
      final classrooms = <Classroom>[
        // الصف الأول: شعبة واحدة
        _makeClassroom(1, name: 'الأول أ', grade: 'الصف الأول'),
        // الصف الثاني: 5 شعب
        _makeClassroom(2, name: 'الثاني هـ', grade: 'الصف الثاني'),
        _makeClassroom(3, name: 'الثاني أ', grade: 'الصف الثاني'),
        _makeClassroom(4, name: 'الثاني ج', grade: 'الصف الثاني'),
        _makeClassroom(5, name: 'الثاني ب', grade: 'الصف الثاني'),
        _makeClassroom(6, name: 'الثاني د', grade: 'الصف الثاني'),
        // الصف الثالث: شعبتان
        _makeClassroom(7, name: 'الثالث ب', grade: 'الصف الثالث'),
        _makeClassroom(8, name: 'الثالث أ', grade: 'الصف الثالث'),
        // الصف الرابع: 4 شعب
        _makeClassroom(9, name: 'الرابع د', grade: 'الصف الرابع'),
        _makeClassroom(10, name: 'الرابع أ', grade: 'الصف الرابع'),
        _makeClassroom(11, name: 'الرابع ج', grade: 'الصف الرابع'),
        _makeClassroom(12, name: 'الرابع ب', grade: 'الصف الرابع'),
      ];

      final chunks = PdfExportUseCase.distributeClassroomsByGradesPerPage(
        classrooms,
        gradesPerPage: 2,
      );

      expect(chunks.length, 2);
      // الورقة 1: الأول (1 شعبة) + الثاني (5 شعب) = 6 شعب مجتمعة
      expect(
        chunks[0].classrooms.map((c) => c.name).toList(),
        [
          'الأول أ',
          'الثاني أ',
          'الثاني ب',
          'الثاني ج',
          'الثاني د',
          'الثاني هـ',
        ],
      );
      // الورقة 2: الثالث (2 شعبة) + الرابع (4 شعب) = 6 شعب مجتمعة
      expect(
        chunks[1].classrooms.map((c) => c.name).toList(),
        [
          'الثالث أ',
          'الثالث ب',
          'الرابع أ',
          'الرابع ب',
          'الرابع ج',
          'الرابع د',
        ],
      );

      // التحقق من عدم إسقاط أو تكرار أي فصل عند أي قيمة لـ K
      for (final k in [1, 2, 3, 4, 6]) {
        final kChunks = PdfExportUseCase.distributeClassroomsByGradesPerPage(
          classrooms,
          gradesPerPage: k,
        );
        final allDistributedIds = <int>[
          for (final chunk in kChunks)
            for (final c in chunk.classrooms) c.id,
        ];
        expect(allDistributedIds.length, classrooms.length);
        expect(allDistributedIds.toSet().length, classrooms.length);
      }
    });

    test('يصوغ التسميات العربية لعدد الصفوف في كل ورقة بشكل سليم', () {
      expect(PdfExportUseCase.formatGradesPerPageLabel(1), 'صف واحد في كل ورقة');
      expect(PdfExportUseCase.formatGradesPerPageLabel(2), 'صفّان في كل ورقة');
      expect(PdfExportUseCase.formatGradesPerPageLabel(3), '3 صفوف في كل ورقة');
      expect(PdfExportUseCase.formatGradesPerPageLabel(4), '4 صفوف في كل ورقة');
      expect(PdfExportUseCase.formatGradesPerPageLabel(5), '5 صفوف في كل ورقة');
      expect(PdfExportUseCase.formatGradesPerPageLabel(6), '6 صفوف في كل ورقة');
    });
  });

  group('PdfExportUseCase - Physical PDF Generation & MediaBox Verification',
      () {
    test(
        'يتحقق من أبعاد A4 الفيزيائية القياسية (841.89 × 595.28 نقطة) وعدد الصفحات الفعلي عند K=1,2,3,4 على 6 و7 صفوف',
        () async {
      final sixGradesClassrooms = _buildStandardGradeClassrooms(6);
      final sevenGradesClassrooms = _buildStandardGradeClassrooms(7);

      final teacher = Teacher()
        ..id = 1
        ..name = 'أحمد علي';
      final subject = Subject()
        ..id = 1
        ..name = 'الرياضيات';

      final lessons = <Lesson>[
        for (final c in sevenGradesClassrooms)
          Lesson()
            ..id = c.id
            ..dayIndex = 0
            ..periodIndex = 0
            ..classroom.value = c
            ..teacher.value = teacher
            ..subject.value = subject,
      ];

      final settings = AppSettings()
        ..schoolName = 'ثانوية الاختبار'
        ..principalName = 'مدير المدرسة'
        ..daysPerWeek = 5
        ..periodsPerDay = 6
        ..exportPageSize = 'A3'
        ..exportOrientation = 'Landscape';

      final useCase = PdfExportUseCase();

      // 1) التصدير الكامل -> صفحة A3 أفقية واحدة (1190.55 × 841.89 pt)
      final fullPdfBytes = await useCase.generateTimetablePdf(
        lessons,
        sixGradesClassrooms,
        settings,
        mode: TimetablePdfExportMode.full,
      );
      expect(_countPdfPages(fullPdfBytes), 1);
      final fullBoxes = _extractPageMediaBoxes(fullPdfBytes);
      expect(fullBoxes.length, 1);
      expect(fullBoxes.single[2], closeTo(1190.55, 0.5));
      expect(fullBoxes.single[3], closeTo(841.89, 0.5));

      // 2) التصدير المقسم لـ 6 صفوف مع K = 1, 2, 3, 4
      final expectedPagesForSixGrades = <int, int>{
        1: 6,
        2: 3,
        3: 2,
        4: 2,
      };

      for (final entry in expectedPagesForSixGrades.entries) {
        final k = entry.key;
        final expectedPages = entry.value;

        final splitBytes = await useCase.generateTimetablePdf(
          lessons,
          sixGradesClassrooms,
          settings,
          mode: TimetablePdfExportMode.splitByGrade,
          gradesPerPage: k,
        );

        expect(
          _countPdfPages(splitBytes),
          expectedPages,
          reason: '6 grades with gradesPerPage=$k should produce $expectedPages pages',
        );

        final boxes = _extractPageMediaBoxes(splitBytes);
        expect(boxes.length, expectedPages);
        for (final box in boxes) {
          // أبعاد A4 الأفقية القياسية الفعلية: 841.89 × 595.28 نقطة (وليس مضروبة في 3)
          expect(box[0], closeTo(0.0, 0.01));
          expect(box[1], closeTo(0.0, 0.01));
          expect(box[2], closeTo(841.89, 0.5));
          expect(box[3], closeTo(595.28, 0.5));
        }

        // التحقق من أن كل صفحة تحتوي على تدفق رسم فعلي غير فارغ (جدول + نصوص الترويسة والترقيم)
        final streams = _extractDecompressedPdfStreams(splitBytes);
        final pageContentStreams =
            streams.where((s) => s.contains('BT') && s.contains('ET')).toList();
        expect(pageContentStreams.length, expectedPages);
        for (final content in pageContentStreams) {
          // حجم خط الترويسة (18pt)، العنوان الفرعي للصفوف (16pt)، الترقيم (12pt)، وخلايا الجدول (10pt)
          expect(content, contains('18 Tf'));
          expect(content, contains('16 Tf'));
          expect(content, contains('12 Tf'));
          expect(content, contains('10 Tf'));
        }
      }

      // 3) التصدير المقسم لـ 7 صفوف مع K = 3 -> 3 صفحات A4
      final sevenGradesSplitBytes = await useCase.generateTimetablePdf(
        lessons,
        sevenGradesClassrooms,
        settings,
        mode: TimetablePdfExportMode.splitByGrade,
        gradesPerPage: 3,
      );
      expect(_countPdfPages(sevenGradesSplitBytes), 3);
      final sevenBoxes = _extractPageMediaBoxes(sevenGradesSplitBytes);
      expect(sevenBoxes.length, 3);
      for (final box in sevenBoxes) {
        expect(box[2], closeTo(841.89, 0.5));
        expect(box[3], closeTo(595.28, 0.5));
      }

      // 4) التحقق من أبعاد A4 العمودية (Portrait: 595.28 × 841.89 pt)
      final portraitSettings = AppSettings()
        ..schoolName = 'ثانوية الاختبار'
        ..principalName = 'مدير المدرسة'
        ..daysPerWeek = 5
        ..periodsPerDay = 6
        ..exportPageSize = 'A4'
        ..exportOrientation = 'Portrait';

      final portraitBytes = await useCase.generateTimetablePdf(
        lessons,
        sixGradesClassrooms,
        portraitSettings,
        mode: TimetablePdfExportMode.splitByGrade,
        gradesPerPage: 3,
      );
      expect(_countPdfPages(portraitBytes), 2);
      final portraitBoxes = _extractPageMediaBoxes(portraitBytes);
      for (final box in portraitBoxes) {
        expect(box[2], closeTo(595.28, 0.5));
        expect(box[3], closeTo(841.89, 0.5));
      }
    });
  });

  group('TimetablePage - PDF Export UI & Dialog Flow', () {
    Future<void> pumpTimetablePageForExportTest(
      WidgetTester tester, {
      required _RecordingFileSaveService saveService,
      required TimetablePdfExportData exportData,
    }) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fileSaveServiceProvider.overrideWithValue(saveService),
            timetableNotifierProvider.overrideWith(_FakeTimetableNotifier.new),
          ],
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.windows),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: TimetablePage(
                pdfExportDataLoader: () async => exportData,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
        'الوضع الكامل لا يطلب عدد الصفوف ويحفظ timetable.pdf مباشرة من زر الواجهة',
        (tester) async {
      final saveService = _RecordingFileSaveService();
      final classrooms = _buildStandardGradeClassrooms(6);
      final settings = AppSettings()
        ..schoolName = 'مدرسة الاختبار'
        ..daysPerWeek = 5
        ..periodsPerDay = 6;
      final exportData = TimetablePdfExportData(
        lessons: const <Lesson>[],
        classrooms: classrooms,
        settings: settings,
      );

      await pumpTimetablePageForExportTest(
        tester,
        saveService: saveService,
        exportData: exportData,
      );

      await tester.tap(find.byIcon(Icons.picture_as_pdf));
      await tester.pumpAndSettle();

      expect(find.text('تصدير جدول الفصول (PDF)'), findsOneWidget);
      expect(find.text('تصدير جدول كامل'), findsOneWidget);
      expect(find.text('تصدير جدول مقسم'), findsOneWidget);

      await tester.tap(find.text('تصدير جدول كامل'));
      await tester.pumpAndSettle();

      // لا تظهر نافذة عدد الصفوف في الوضع الكامل
      expect(find.text('عدد الصفوف في كل ورقة A4'), findsNothing);
      expect(saveService.saveCallCount, 1);
      expect(saveService.lastFileName, 'timetable.pdf');
      expect(_countPdfPages(saveService.lastBytes!), 1);
      expect(find.textContaining('تم حفظ ملف PDF بنجاح'), findsOneWidget);
    });

    testWidgets(
        'الوضع المقسم يعرض خيارات عدد الصفوف ويصدر العدد المختار (مثلاً صفّان في كل ورقة -> 3 صفحات لـ 6 صفوف)',
        (tester) async {
      final saveService = _RecordingFileSaveService();
      final classrooms = _buildStandardGradeClassrooms(6);
      final settings = AppSettings()
        ..schoolName = 'مدرسة الاختبار'
        ..daysPerWeek = 5
        ..periodsPerDay = 6;
      final exportData = TimetablePdfExportData(
        lessons: const <Lesson>[],
        classrooms: classrooms,
        settings: settings,
      );

      await pumpTimetablePageForExportTest(
        tester,
        saveService: saveService,
        exportData: exportData,
      );

      await tester.tap(find.byIcon(Icons.picture_as_pdf));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تصدير جدول مقسم'));
      await tester.pumpAndSettle();

      expect(find.text('عدد الصفوف في كل ورقة A4'), findsOneWidget);
      expect(find.text('صف واحد في كل ورقة'), findsOneWidget);
      expect(find.text('صفّان في كل ورقة'), findsOneWidget);
      expect(find.text('3 صفوف في كل ورقة'), findsOneWidget);
      expect(find.text('4 صفوف في كل ورقة'), findsOneWidget);
      expect(find.text('5 صفوف في كل ورقة'), findsOneWidget);
      expect(find.text('6 صفوف في كل ورقة'), findsOneWidget);

      await tester.tap(find.text('صفّان في كل ورقة'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تصدير PDF'));
      await tester.pumpAndSettle();

      expect(saveService.saveCallCount, 1);
      expect(saveService.lastFileName, 'timetable_split.pdf');
      expect(_countPdfPages(saveService.lastBytes!), 3);
    });

    testWidgets(
        'إلغاء نافذة نوع التصدير أو نافذة عدد الصفوف يلغي العملية دون حفظ أو إظهار خطأ',
        (tester) async {
      final saveService = _RecordingFileSaveService();
      final exportData = TimetablePdfExportData(
        lessons: const <Lesson>[],
        classrooms: _buildStandardGradeClassrooms(6),
        settings: AppSettings()..periodsPerDay = 6,
      );

      await pumpTimetablePageForExportTest(
        tester,
        saveService: saveService,
        exportData: exportData,
      );

      // 1) إلغاء النافذة الأولى
      await tester.tap(find.byIcon(Icons.picture_as_pdf));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      expect(saveService.saveCallCount, 0);
      expect(find.byType(SnackBar), findsNothing);

      // 2) فتح التصدير المقسم ثم إلغاء نافذة عدد الصفوف
      await tester.tap(find.byIcon(Icons.picture_as_pdf));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تصدير جدول مقسم'));
      await tester.pumpAndSettle();
      expect(find.text('عدد الصفوف في كل ورقة A4'), findsOneWidget);

      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      expect(saveService.saveCallCount, 0);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
        'يعالج فشل الحفظ بالطريقة المعتادة ويمنع تكرار التصدير عند استخدام Ctrl+P',
        (tester) async {
      final saveService = _RecordingFileSaveService(
        simulatedOutcome: const FileSaveFailed('قرص ممتلئ'),
      );
      final exportData = TimetablePdfExportData(
        lessons: const <Lesson>[],
        classrooms: _buildStandardGradeClassrooms(6),
        settings: AppSettings()..periodsPerDay = 6,
      );

      await pumpTimetablePageForExportTest(
        tester,
        saveService: saveService,
        exportData: exportData,
      );

      // إطلاق التصدير عبر اختصار Ctrl+P
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.text('تصدير جدول الفصول (PDF)'), findsOneWidget);

      // محاولة إرسال Ctrl+P مرة أخرى أثناء فتح النافذة لا تفتح نافذة مكررة
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('تصدير جدول الفصول (PDF)'), findsOneWidget);

      await tester.tap(find.text('تصدير جدول مقسم'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 صفوف في كل ورقة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تصدير PDF'));
      await tester.pumpAndSettle();

      expect(saveService.saveCallCount, 1);
      expect(_countPdfPages(saveService.lastBytes!), 2);
      expect(
        find.textContaining('فشل في حفظ الملف: قرص ممتلئ'),
        findsOneWidget,
      );
    });
  });
}
