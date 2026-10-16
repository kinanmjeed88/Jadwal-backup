import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/models/classroom.dart';
import 'package:jadwal_v2/core/models/lesson.dart';
import 'package:jadwal_v2/core/models/settings.dart';
import 'package:jadwal_v2/core/models/subject.dart';
import 'package:jadwal_v2/core/models/teacher.dart';
import 'package:jadwal_v2/features/timetable/domain/usecases/pdf_export_usecase.dart';
import 'package:pdf/pdf.dart';

Classroom _makeClassroom(int id, {required String name, required String grade}) {
  return Classroom()
    ..id = id
    ..name = name
    ..grade = grade;
}

int _countPdfPages(List<int> pdfBytes) {
  final raw = String.fromCharCodes(pdfBytes);
  return RegExp(r'/Type\s*/Page\b').allMatches(raw).length;
}

List<List<double>> _extractPageMediaBoxes(List<int> pdfBytes) {
  final raw = String.fromCharCodes(pdfBytes);
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

      // الورقة الأولى: الصف الأول (الأول أ - الأول ب - الأول ج)
      expect(groups[0].title, 'الصف الأول');
      expect(
        groups[0].classrooms.map((c) => c.name).toList(),
        ['الأول أ', 'الأول ب', 'الأول ج'],
      );

      // الورقة الثانية: الصف الثاني (الثاني أ - الثاني ب - الثاني ج)
      expect(groups[1].title, 'الصف الثاني');
      expect(
        groups[1].classrooms.map((c) => c.name).toList(),
        ['الثاني أ', 'الثاني ب', 'الثاني ج'],
      );

      // الورقة الثالثة: الصف الثالث (الثالث أ - الثالث ب - الثالث ج)
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

    test('يرتب الصفوف الستة بالترتيب الأكاديمي (الأول..السادس) وليس الأبجدي', () {
      final classrooms = <Classroom>[
        _makeClassroom(1, name: 'السادس أ', grade: 'الصف السادس'),
        _makeClassroom(2, name: 'الخامس أ', grade: 'الصف الخامس'),
        _makeClassroom(3, name: 'الرابع أ', grade: 'الصف الرابع'),
        _makeClassroom(4, name: 'الثالث أ', grade: 'الصف الثالث'),
        _makeClassroom(5, name: 'الثاني أ', grade: 'الصف الثاني'),
        _makeClassroom(6, name: 'الأول أ', grade: 'الصف الأول'),
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
        ],
      );
    });

    test(
        'يرتب الشعب بالحروف العربية (أبجد وهجاء) والحروف الإنجليزية والأرقام العربية والهندية',
        () {
      // 1) الشعب الأبجدية: أ، ب، ج، د، هـ، و، ز
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

      // 2) الشعب الهجائية: أ، ب، ت، ث، ج
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

      // 3) الحروف اللاتينية والأرقام الهندية/العربية
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
      // 1) الصفوف الأكاديمية المعروفة أولاً
      expect(groups[0].title, 'الصف الأول');
      expect(groups[0].classrooms.map((c) => c.name).toList(), ['الأول أ']);

      // 2) المرحلة المخصصة المعرّفة نصياً
      expect(groups[1].title, 'المرحلة التمهيدية');
      expect(
        groups[1].classrooms.map((c) => c.name).toList(),
        ['تمهيدي أ', 'تمهيدي ب'],
      );

      // 3) الفصول غير المحددة المرحلة أو الصف في النهاية تحت «بدون صف»
      expect(groups[2].title, 'بدون صف');
      expect(
        groups[2].classrooms.map((c) => c.name).toList(),
        ['قاعة النشاط', 'المختبر'],
      );
    });
  });

  group('PdfExportUseCase - PDF Document Generation', () {
    test(
        'يولد صفحة واحدة للجدول الكامل و 3 صفحات A4 مستقلة للجدول المقسم لثلاثة صفوف حتى لو كان الإعداد A3',
        () async {
      final classrooms = <Classroom>[
        _makeClassroom(1, name: 'الأول أ', grade: 'الصف الأول'),
        _makeClassroom(2, name: 'الأول ب', grade: 'الصف الأول'),
        _makeClassroom(3, name: 'الأول ج', grade: 'الصف الأول'),
        _makeClassroom(4, name: 'الثاني أ', grade: 'الصف الثاني'),
        _makeClassroom(5, name: 'الثاني ب', grade: 'الصف الثاني'),
        _makeClassroom(6, name: 'الثاني ج', grade: 'الصف الثاني'),
        _makeClassroom(7, name: 'الثالث أ', grade: 'الصف الثالث'),
        _makeClassroom(8, name: 'الثالث ب', grade: 'الصف الثالث'),
        _makeClassroom(9, name: 'الثالث ج', grade: 'الصف الثالث'),
      ];

      final teacher = Teacher()
        ..id = 1
        ..name = 'أحمد علي';
      final subject = Subject()
        ..id = 1
        ..name = 'الرياضيات';

      final lessons = <Lesson>[
        for (final c in classrooms)
          Lesson()
            ..id = c.id
            ..dayIndex = 0
            ..periodIndex = 0
            ..classroom.value = c
            ..teacher.value = teacher
            ..subject.value = subject,
      ];

      final settings = AppSettings()
        ..schoolName = 'مدرسة الاختبار'
        ..principalName = 'مدير المدرسة'
        ..daysPerWeek = 5
        ..periodsPerDay = 6
        ..exportPageSize = 'A3'
        ..exportOrientation = 'Landscape';

      final useCase = PdfExportUseCase();

      // 1) تصدير جدول كامل -> ورقة واحدة شاملة لكل الصفوف والشعب بالحجم المحدد (A3)
      final fullPdfBytes = await useCase.generateTimetablePdf(
        lessons,
        List<Classroom>.from(classrooms),
        settings,
        mode: TimetablePdfExportMode.full,
      );
      expect(fullPdfBytes, isNotEmpty);
      expect(_countPdfPages(fullPdfBytes), 1);
      final fullBoxes = _extractPageMediaBoxes(fullPdfBytes);
      expect(fullBoxes.length, 1);
      expect(
        fullBoxes.single[2],
        closeTo(PdfPageFormat.a3.landscape.width * 3.0, 1.0),
      );
      expect(
        fullBoxes.single[3],
        closeTo(PdfPageFormat.a3.landscape.height * 3.0, 1.0),
      );

      // 2) تصدير جدول مقسم -> 3 ورقات A4 (ورقة لكل صف مع شعبه: الأول، الثاني، الثالث)
      final splitPdfBytes = await useCase.generateTimetablePdf(
        lessons,
        List<Classroom>.from(classrooms),
        settings,
        mode: TimetablePdfExportMode.splitByGrade,
      );
      expect(splitPdfBytes, isNotEmpty);
      expect(_countPdfPages(splitPdfBytes), 3);
      final splitBoxes = _extractPageMediaBoxes(splitPdfBytes);
      expect(splitBoxes.length, 3);
      for (final box in splitBoxes) {
        expect(box[2], closeTo(PdfPageFormat.a4.landscape.width * 3.0, 1.0));
        expect(box[3], closeTo(PdfPageFormat.a4.landscape.height * 3.0, 1.0));
      }
    });
  });
}
