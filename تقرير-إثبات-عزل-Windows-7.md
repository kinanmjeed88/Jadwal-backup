<div dir="rtl">

# التقرير النهائي لتجربة إثبات عزل Windows 7

**المستودع:** `kinanmjeed88/Jadwal-backup`  
**الفرع:** `arena/e18c18da-jadwal-backup`  
**SHA البداية المعتمد:** `e17b680bce35922d97ba00125b66a6bb13e96c06`  
**نقطة الرجوع المحلية:** `poc-windows7-approved-base-e17b680`  
**SHA الكود المختبر قبل إضافة هذا التقرير:** `fc16905099d5cc6b3ba1fedf7a60c326b7f89303`  
**PR:** [#1](https://github.com/kinanmjeed88/Jadwal-backup/pull/1) — مفتوح ولم يُدمج.

> ملاحظة: يُذكر SHA النهائي للتقرير ونتائج بواباته في تسليم المحادثة بعد دفع هذا الملف، لأن إضافة التقرير نفسها تنشئ SHA جديدًا. Workflow W7 مضبوط ليعمل على كل مراجعة PR كي لا يعتمد التسليم على SHA سابق.

## 1. النتيجة

نجحت تجربة الإثبات ضمن حدود البيئة المتاحة:

1. توجد نسخة Windows 7 مستقلة تحت `apps/windows_7/` وبـmanifest وlock مستقلين.
2. ثبت CI استخدام Flutter 3.16.9 وDart 3.2.6.
3. نجح `pub get` وثبتت قابلية إعادة إنتاج lock.
4. نجح analyze وجميع الاختبارات وبناء Windows Release وفحص الحزمة وsmoke test على Windows Server 2022.
5. نجح حارس التطابق واختباره الإيجابي والسلبي.
6. نجحت بوابات Android وWindows 10/11 على SHA الكود نفسه.
7. **لم يُختبر التشغيل على Windows 7 حقيقي**؛ لذلك لا تدعي التجربة إثبات التوافق التشغيلي النهائي مع Windows 7.

## 2. حماية البداية والتراجع

قبل التنفيذ كان المحلي والبعيد عند `e17b680` وحالة Git نظيفة. في الجولة السابقة، عندما ظهر المحلي قديمًا و301 ملفًا غير متتبع، قورنت الملفات بايتًا بالبعيد ووجدت كلها متطابقة قبل المزامنة. لم توجد ملفات غير متتبعة عند بدء التنفيذ الحالي.

نقطة التراجع الكاملة هي `e17b680`. التزامات PoC صغيرة منطقيًا:

- `99647f6`: استيراد التطبيق دون lock غير صالح.
- `5e176e6`: حارس التطابق.
- `ce073cc`: Workflow W7.
- `5aa5dee`: تصحيح تحقق SDK.
- `ee179f7`: تشخيص الحارس.
- `06ca14f`: قبول header مولد دقيق وتمكين توليد lock المستهدف.
- `55ce211`: lock مولد فعلًا في CI Flutter 3.16.9.
- `fc16905`: إزالة صلاحية الكتابة والتحقق من ثبات lock.

يمكن التراجع عن كامل التجربة بإرجاع هذه السلسلة أو إعادة إنشاء فرع من العلامة. لم يُعدل `searchidf`.

## 3. البنية والملفات

أضيف `apps/windows_7/` وفيه **148 ملفًا متتبعًا**:

- `lib/`: 86 ملفًا.
- `test/`: 30 ملفًا (29 ملف `_test.dart` إضافة إلى fixture).
- `assets/`: 5 ملفات.
- `windows/`: 23 ملفًا.
- `.metadata` و`analysis_options.yaml` و`pubspec.yaml` و`pubspec.lock`: أربعة ملفات.

كما أضيف:

- `.github/workflows/build_windows_7.yml`
- `tools/check_windows7_drift.py`
- هذا التقرير.

لم يُستخرج `jadwal_core`، ولم يتغير `lib/main.dart` في الجذر أو Android أو manifest/lock الجذر.

## 4. Flutter وDart والتبعيات

| التطبيق | Flutter/Dart | manifest/lock |
|---|---|---|
| Android + Windows 10/11 | stable الحديثة؛ lock الجذر يتطلب Flutter ≥3.38.4 وDart ≥3.11 | لم يتغيرا بالتجربة |
| Windows 7 | Flutter **3.16.9** + Dart **3.2.6** | مستقلان تحت `apps/windows_7/` |

manifest W7 يطلب Dart `>=3.2.0 <4.0.0`. lock المولد بواسطة 3.16.9 يسجل:

- Dart `>=3.2.3 <4.0.0`
- Flutter `>=3.16.6`
- 133 حزمة محلولة، منها 29 مباشرة.

أمثلة الإصدارات المثبتة فعليًا:

| الحزمة | إصدار W7 المحلول |
|---|---:|
| `file_picker` | 8.0.0+1 |
| `font_awesome_flutter` | 10.7.0 |
| `firebase_core` | 2.27.0 |
| `firebase_analytics` | 10.8.9 |
| `window_manager` | 0.3.9 |
| `screen_retriever` | 0.1.9 |
| `path_provider` | 2.1.4 |
| `url_launcher` | 6.3.0 |
| `path` | 1.8.3 |
| `meta` | 1.10.0 |
| `pdf` | 3.11.3 |
| `printing` | 5.12.0 |

لا يوجد `dependency_overrides`. يتحقق CI من ذلك، ويشغّل `pub get` ثم `git diff --exit-code -- pubspec.lock` لإثبات أن الحل قابل لإعادة الإنتاج تحت SDK المستهدف.

## 5. Dropdown والتوافق

نسخة W7 تستخدم `value` في منشئات `DropdownButtonFormField` التسعة، ولا تستخدم `DropdownButtonFormField.initialValue`. بقي `TextFormField.initialValue` دون تغيير لأنه API مختلف وصالح. CI يحتوي فحصًا يرفض إدخال API الحديث غير المتوافق إلى W7.

لم يتغير السلوك المقصود؛ الملفات الخمسة الخاصة بالمنصة مأخوذة من أرشيف W7 المرجعي.

## 6. مراجعة ملفات Windows المختلفة

الاختلافات السبعة الأصلية من الأرشيف قبل تشغيل tooling:

1. `windows/CMakeLists.txt`: اسم executable هو `JadwalV2_Windows7`.
2. `windows/flutter/generated_plugin_registrant.cc`: مجموعة plugins الخاصة بتبعيات W7.
3. `windows/flutter/generated_plugins.cmake`: مجموعة plugins وروابطها.
4. `windows/packaging/README.md`: أسماء حزم W7.
5. `windows/packaging/jadwal_v2.iss`: executable والمثبت وهوية W7.
6. `windows/runner/Runner.rc`: metadata والاسم/الأيقونة.
7. `windows/runner/runner.exe.manifest`: تعريفات أنظمة Windows المدعومة الخاصة بالفرع.

عند `pub get` بFlutter 3.16.9 يتغير أيضًا header المولد الدقيق `generated_plugin_registrant.h`; أضيف إلى allowlist باسمه الكامل وسببه، لا باستثناء مجلد واسع.

## 7. Drift/Hash Guard

يقارن الحارس **كل ملف** تحت `lib/` و`test/` و`assets/` و`windows/` بين الجذر وW7. يفشل عند:

- ملف مفقود في W7.
- ملف زائد في W7.
- اختلاف محتوى غير موجود في allowlist.
- allowlist قديمة لم تعد تختلف، باستثناء header المولد الذي قد يطابق قبل تشغيل Flutter القديم.

قائمة السماح الدقيقة تضم خمسة ملفات Dart خاصة بالمنصة وثمانية ملفات Windows محددة بالاسم، ويطبع الحارس مسار كل اختلاف وسبب السماح به.

الاختبارات:

- إيجابي: النسختان الفعليتان تمران.
- سلبي: ينسخ W7 إلى مساحة مؤقتة ويغيّر `lib/core/constants/app_constants.dart` عمدًا؛ يجب أن يكتشف `UNALLOWED_CONTENT_DIFF`. نجح الاختبار.

## 8. نتائج CI على SHA الكود `fc16905`

### Windows 7

[تشغيل 38749880027](https://github.com/kinanmjeed88/Jadwal-backup/actions/runs/38749880027) — نجاح:

- تثبيت Flutter 3.16.9: نجاح.
- إثبات Dart 3.2.6: نجاح.
- manifest policy: نجاح.
- `flutter pub get`: نجاح.
- dependency graph وlock SDK validation: نجاح.
- ثبات lock: نجاح.
- الحارس والاختبار الإيجابي/السلبي: نجاح.
- فحص Dropdown: نجاح.
- `flutter analyze --no-fatal-infos`: نجاح.
- `flutter test` لجميع الاختبارات، بما فيها benchmark: نجاح.
- `flutter build windows --release --target=lib/main_windows.dart`: نجاح.
- وجود `JadwalV2_Windows7.exe` و`data/`: مثبت.
- smoke test على المضيف الحديث: نجاح.
- رفع `windows-7-poc-release`: نجاح.

### Android

[تشغيل 38749879654](https://github.com/kinanmjeed88/Jadwal-backup/actions/runs/38749879654) — نجاح:

- pub get/analyze/جميع tests: نجاح.
- Debug verification APK: نجاح.
- Release الموقع: لم ينفذ لغياب الأسرار، ولم يُدع نجاحه.

### Windows 10/11

[تشغيل 38749879152](https://github.com/kinanmjeed88/Jadwal-backup/actions/runs/38749879152) — نجاح:

- pub get/analyze/جميع tests: نجاح.
- Release build + bundle verification + smoke test + ZIP/installer: نجاح.
- التوقيع الاختياري: لم ينفذ لغياب الشهادة.

## 9. حماية المنصات الأخرى

من `e17b680` إلى كود PoC:

- `android/`: بلا تغيير.
- `lib/main.dart`: بلا تغيير.
- `pubspec.yaml` و`pubspec.lock` للجذر: بلا تغيير.
- workflows الحالية لـAndroid وWindows 10/11: بلا تغيير.
- بقيت استدعاءات `SharePlus.instance.share` الثلاثة في الجذر.
- لم تحذف ميزة أو اختبار أو إعداد توقيع.
- نجاح CI للجذر يثبت عدم حدوث تراجع آلي ظاهر؛ الاختبارات اليدوية لأندرويد لم تُكرر على جهاز حقيقي.

## 10. ما أثبت وما لم يثبت

### مثبت

- استقلال dependency resolution ومسار البناء.
- توافق source والتحليل والاختبارات مع Flutter 3.16.9/Dart 3.2.6.
- إنتاج Windows Release يحمل اسم W7 الصحيح.
- تشغيل smoke test على Windows Server 2022.
- عدم كسر بوابات Android وWindows 10/11.

### غير مثبت

- التشغيل على Windows 7 SP1 حقيقي/VM؛ لا تتوفر بيئة كهذه في GitHub-hosted runners أو الحاوية.
- توقيع حزمة W7.
- اختبار واجهة كامل يدويًا على Windows 7 (حفظ PDF/Excel/صورة، backup/restore، النافذة).

لذلك النتيجة هي **PoC ناجح للبناء والعزل، وليس شهادة دعم تشغيل نهائية لـWindows 7**.

## 11. مخاطر الصيانة

1. تكرار 111 ملفًا من source/tests؛ الحارس يمنع drift الصامت لكنه لا يلغي كلفة المزامنة.
2. generated files يجب ألا تُجدد إلا بالأداة المناسبة لكل تطبيق.
3. Flutter 3.16.9 قديم؛ security/plugin fixes الحديثة لا تصل إلى W7 تلقائيًا.
4. Windows 2022 smoke لا يعادل Windows 7 runtime.
5. Root Flutter ما زال غير مثبت برقم في workflows القديمة؛ خارج نطاق هذا PoC.

## 12. التوقف

لم يُدمج PR #1، ولم يُعدل `searchidf`، ولم يبدأ استخراج core أو إعادة هيكلة إضافية. يلزم قرار مستقل قبل اعتماد البنية نهائيًا أو بدء اختبار Windows 7 حقيقي/دمج أي PR.

</div>
