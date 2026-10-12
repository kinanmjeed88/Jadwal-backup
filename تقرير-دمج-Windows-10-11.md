<div dir="rtl">

# تقرير دمج Windows 10/11 والتحقق — Jadwal-backup

**التاريخ:** 12 تشرين الأول 2026  
**فرع العمل:** `arena/e18c18da-jadwal-backup`  
**التزام الدمج:** `2cdb65090b70c2890352879e42797d37be26b4d2`  
**آخر التزام تم اختباره:** `3292b92dea29259e493a2cda198367c49bfdf13e`  
**طلب السحب:** [PR #1](https://github.com/kinanmjeed88/Jadwal-backup/pull/1) — مفتوح ولم يُدمج.

## 1. النطاق المنفذ

1. اعتُمد `Jadwal-backup` وحده مستودعًا مستهدفًا.
2. أُبقيت الأرشيفات الثلاثة وتقريرا التحليل والتحقق دون حذف أو تغيير.
3. استُوردت شجرة Android الأساسية من `Jadwal-main.zip`، وشجرة Windows 10/11 من أرشيفها، مع نقطة أصل موثقة من `9d3a215` حتى يكون الدمج ثلاثي الأطراف حقيقيًا وقابلًا للتراجع.
4. دُمج Windows 10/11 يدويًا. ظهر تعارضان فقط:
   - `.github/workflows/build_windows.yml`
   - `lib/features/management/presentation/pages/settings_page.dart`
5. لم يُستخدم `git merge -X theirs` ولا `git merge -X ours`.
6. لم يبدأ عزل Windows 7، ولم يبدأ استخراج `jadwal_core`.

## 2. نتيجة مراجعة الفرق سطرًا بسطر

الفرق من شجرة Android الأساسية إلى الرأس المختبَر: **22 ملفًا**، **1204 إضافات**، **146 حذفًا**. لم يتغير `pubspec.yaml` أو `pubspec.lock`، ولم تُضف تبعية جديدة.

### ملفات التطبيق

| الملف | السبب والمراجعة |
|---|---|
| `lib/app/app_bootstrap.dart` | تمهيد مشترك مع تهيئة Firebase وقاعدة البيانات وسجل أخطاء سطح المكتب. |
| `lib/app/jadwal_app.dart` | غلاف تطبيق Android المعتاد؛ يحافظ على `HomeShell` وتدفق الإعداد الأول. |
| `lib/app/jadwal_windows_app.dart` | غلاف Windows مستقل مع استعادة حالة النافذة. |
| `lib/main_windows.dart` | نقطة دخول Windows 10/11 المستقلة. |
| `lib/core/services/file_save_service.dart` | حفظ موثوق للملفات، مع حالات نجاح/إلغاء/فشل بدل افتراض نجاح الكتابة. |
| `settings_page.dart` | أبقي مسار Android للمشاركة بواسطة `SharePlus` ومسار الاستيراد بواسطة `FilePicker`، وأضيف الحفظ المحلي على Windows. |
| `timetable_page.dart` | أبقيت مشاركة Excel والصورة على Android، وأضيف حفظ Windows؛ وأضيفت معالجة خطأ Excel. تغيّرت رسالة نجاح PDF فقط إلى الصياغة الأدق «تم حفظ ملف PDF بنجاح». |
| `test/core/services/file_save_service_test.dart` | اختبارات خدمة الحفظ الجديدة. |

### ملفات Windows والبناء

- `windows/CMakeLists.txt`: اسم الملف التنفيذي `JadwalV2_Windows10_11`.
- `windows/runner/Runner.rc` والأيقونة: هوية Windows 10/11.
- `windows/packaging/jadwal_v2.iss` و`README.md`: أسماء المثبت والحزمة متوافقة مع الملف التنفيذي.
- `tools/analyze_pe_imports.py` و`tools/audit_windows_bundle.py`: تدقيق PE وحزمة Windows.
- ملفات `WINDOWS*.md`: توثيق التشغيل والتدقيق.
- `.github/workflows/build_windows.yml`: analyze + test + Release build + smoke test + ZIP + installer، وتشغيل جميع الاختبارات بما فيها benchmark؛ لم يُستبعد أي اختبار بصمت.
- `.github/workflows/build.yml`: أضيف `flutter analyze` و`flutter test`. عند غياب أسرار التوقيع في PR يُبنى Debug غير موقع ويُسمّى بوضوح؛ وعند توفرها يبقى مسار Release الموقّع كما هو.

## 3. إثبات الحفاظ على Android

بعد الدمج:

- مجلد `android/`: مطابق بايتًا لشجرة Android الأساسية.
- `docs/`: مطابق.
- `lib/main.dart`: مطابق.
- `pubspec.yaml` و`pubspec.lock`: مطابقان.
- `README.md`: النسخة الكاملة محفوظة ومطابقة.
- المشاركة: بقيت **3** استدعاءات `SharePlus.instance.share`.
- تصدير النسخة الاحتياطية: `_exportData()` موجود.
- الاستعادة: `_importData()` و`FilePicker.platform.pickFiles` موجودان.
- تصدير PDF وExcel والصورة موجود، ومسار المشاركة المحمول بقي فعالًا في Excel والصورة والنسخة الاحتياطية.
- فحص الواردات النسبية: صفر مسار مفقود.
- فحص علامات التعارض و`git diff --check`: ناجح.

## 4. نتائج الاختبارات والبناء المنفذة فعليًا

### Android — نجاح

تشغيل GitHub Actions: [38243264838](https://github.com/kinanmjeed88/Jadwal-backup/actions/runs/38243264838)

| البوابة | النتيجة |
|---|---|
| `flutter pub get` | نجاح |
| `flutter analyze --no-fatal-infos` | نجاح |
| `flutter test` (جميع الاختبارات) | نجاح |
| توليد الأيقونات | نجاح |
| بناء APK | نجاح — **Debug غير موقع للتحقق** لأن أسرار التوقيع لم تكن متاحة للتشغيل |
| رفع `debug-verification-apk` | نجاح |
| Release موقع | **لم يُنفذ**؛ لم يُدعَ نجاحه |

حدث قبل ذلك تشغيل فشل في Release عند غياب إعداد التوقيع، مع نجاح analyze والاختبارات. عولجت بوابة CI دون لمس الأسرار أو تخفيف شرط توقيع Release: البناء غير الموقع مخصص للتحقق فقط ولا يُقدّم كإصدار إنتاجي.

### Windows 10/11 — نجاح

تشغيل GitHub Actions: [38243264848](https://github.com/kinanmjeed88/Jadwal-backup/actions/runs/38243264848)

| البوابة | النتيجة |
|---|---|
| `flutter pub get` | نجاح |
| `flutter analyze --no-fatal-infos` | نجاح |
| `flutter test` (جميع الاختبارات) | نجاح |
| `flutter build windows --release --target=lib/main_windows.dart` | نجاح |
| التحقق من executable ومجلد data | نجاح |
| Windows smoke test | نجاح |
| إنشاء ZIP وInno Setup installer | نجاح |
| رفع الحزم | نجاح |
| توقيع executable والمثبت | لم يُنفذ (اختياري؛ بيانات التوقيع غير متاحة) |

## 5. ما تعذر تنفيذه وحدود الإثبات

- لا توجد بيئة Flutter محلية في الحاوية، وتنزيل SDK محجوب؛ لذلك نُفذت بوابات Flutter الفعلية في GitHub Actions على Linux وWindows، ولم يُدعَ أي تشغيل محلي.
- لم يُنفذ اختبار يدوي على جهاز Android حقيقي لفتح واجهة المشاركة واختيار ملف والاستعادة التفاعلية. الاختبارات الآلية والتحليل والبناء نجحت، وبقاء المسارات تحقق سكونيًا، لكن الاختبار التفاعلي ما زال مطلوبًا قبل إصدار إنتاجي.
- لم يُبنَ Android Release موقع لغياب الأسرار عن تشغيل PR. لم تُقرأ الأسرار أو تُغيّر.
- توقيع Windows اختياري ولم يُنفذ للسبب نفسه.

## 6. المخاطر المتبقية

1. يلزم smoke test يدوي على Android للمشاركة وتصدير PDF/Excel/صورة والنسخ الاحتياطي والاستعادة.
2. يلزم بناء Android Release موقع في بيئة تتوفر فيها أسرار المستودع قبل النشر.
3. الاعتماد على `channel: stable` غير مثبت برقم إصدار؛ نجح الآن، لكن تثبيت الإصدار قرار لاحق لتحسين قابلية إعادة الإنتاج.
4. رسالة نجاح PDF تغيّرت صياغتها فقط؛ لا تغيير في API أو البيانات.
5. Windows 7 لم يُمس بعد، وفق الترتيب المطلوب.

## 7. التراجع والمراجعة

- التراجع عن دمج Windows 10/11: `git revert -m 1 2cdb650`، ثم مراجعة التزامات CI اللاحقة بصورة منفصلة.
- PR #1 مفتوح وقابل للمراجعة؛ **لم يُدمج**.
- لم يُعدل `main` أو `searchidf` مباشرة.

## 8. القرار المطلوب

توقفت العملية هنا قبل Windows 7. المطلوب مراجعة PR #1 وهذا التقرير، ثم قرار صريح بأحد الخيارين:

1. قبول نتيجة مرحلة Windows 10/11 والسماح ببدء مرحلة عزل Windows 7، مع بقاء PR دون دمج حتى موافقة منفصلة؛ أو
2. طلب تعديلات إضافية على مرحلة Windows 10/11 أولًا.

</div>
