<div dir="rtl">

# المراجعة المستقلة لدمج Windows 10/11 وخطة عزل Windows 7

**المستودع:** `kinanmjeed88/Jadwal-backup`  
**الفرع:** `arena/e18c18da-jadwal-backup`  
**الرأس الذي روجع:** `aef6f20034a24e342fc780760a07f258b4ada934`  
**القاعدة الفعلية:** `searchidf` عند `34b6b04e463693b1d4e09d7834f1a11e2591fcf8`  
**PR:** [#1](https://github.com/kinanmjeed88/Jadwal-backup/pull/1)  
**نوع العمل الحالي:** مراجعة وخطة فقط؛ لم يُدخل أي كود Windows 7.

---

## الخلاصة التنفيذية

المراجعة المستقلة **تقبل دمج Windows 10/11 وظيفيًا مع تحفظات موثقة**:

- PR #1 مفتوح، قابل للدمج تقنيًا، قاعدته الفعلية `searchidf`، ولم يُدمج.
- تشغيل Android وتشغيل Windows المذكوران في التسليم النهائي نجحا، وكلاهما على SHA النهائي نفسه `aef6f20`.
- لم تتغير شجرة Android ولا `pubspec.yaml`/`pubspec.lock` ولا `lib/main.dart` مقارنة بلقطة Android المستوردة `dd951397`.
- اختبارات CI لا تُستبعد: Android يشغّل `flutter test` مباشرة، وWindows يشغّل `flutter test --machine` على المجموعة كلها، ومنها benchmark.
- Debug Android موسوم صراحة بأنه تحقق غير موقع، ولا يُرفع باسم Release. مسار Release الموقع ما زال موجودًا ومشروطًا بتوفر الأسرار، لكنه **لم يُختبر على SHA النهائي**؛ لذلك لا يمكن الجزم بأنه يعمل عمليًا بعد.
- توجد ملاحظات لا تمنع قبول دمج Windows 10/11، لكنها يجب أن تُعالج أو تُتخذ بشأنها قرارات قبل الإصدار: عدم تثبيت نسخة Flutter الحديثة، عدم اتساق SDK في lockfile مع manifest، وتحوير ملفات Android داخل CI بعد analyze/test.

التوصية لـWindows 7: إجراء **إثبات قابلية بناء مؤقت** لبنية `apps/windows_7/` أولًا، ثم اعتمادها فقط إذا اجتازت `pub get/analyze/test/build` بـFlutter 3.16.9 واختبار تشغيل على Windows 7 حقيقي. لا يُستخرج `jadwal_core` في خطوة العزل الأولى.

---

# الجزء الأول: المراجعة المستقلة لمرحلة Windows 10/11

## 1. حالة PR والقاعدة

| البند | النتيجة المثبتة |
|---|---|
| حالة PR #1 | `OPEN` |
| Draft | لا |
| القاعدة | `searchidf` |
| رأس القاعدة | `34b6b04` |
| فرع الرأس | `arena/e18c18da-jadwal-backup` |
| رأس PR | `aef6f20` |
| قابلية الدمج حسب GitHub | `MERGEABLE` |
| مراجعات بشرية مسجلة | صفر |
| هل دُمج؟ | لا |

المستودع الأساسي ليس فرع كود Flutter؛ `searchidf` يحتوي الأرشيفات الثلاثة فقط. لذلك يظهر فرق PR الكامل كالتالي:

- **301 ملفًا مضافًا**.
- **44,911 سطرًا مضافًا**.
- لا تظهر تعديلات/حذوفات نسبةً إلى `searchidf` لأن ملفات المشروع لم تكن مفكوكة على القاعدة.

هذه نتيجة صحيحة لبنية المستودع، لكنها تجعل مراجعة GitHub المعتادة صعبة؛ لذلك راجعت أيضًا الفرق المنطقي من لقطة Android المستوردة `dd951397` إلى الرأس النهائي.

## 2. سجل الالتزامات

التسلسل الفعلي بعد `searchidf`:

1. `6dea340`: إضافة تقريري المرحلة الأولى.
2. `6f578b3`: إعادة بناء نقطة الأصل المشتركة الموثقة `9d3a215` داخل تاريخ Jadwal-backup.
3. `dd951397`: استيراد لقطة Android من `Jadwal-main.zip`.
4. `f1d6d5e`: استيراد لقطة Windows 10/11 من أرشيفها، متفرعة من نقطة الأصل نفسها.
5. `2cdb650`: merge commit بوالدين (`dd951397` و`f1d6d5e`).
6. `c03704c`: بوابات CI للقاعدة الفعلية.
7. `3292b92`: فصل تحقق Debug غير الموقع عن Release الموقع.
8. `aef6f20`: تقرير مرحلة Windows 10/11 فقط؛ لا يغير الكود.

التزام `aef6f20` نفسه يضيف ملف التقرير المكون من 127 سطرًا ولا يغير التطبيق.

## 3. الفرق المنطقي من Android إلى الرأس النهائي

من `dd951397` إلى `aef6f20`:

- **23 ملفًا**؛ 1,331 إضافة و146 حذفًا.
- الـ23 تشمل تقرير التسليم نفسه. قبل التقرير كان العدد 22 ملفًا كما ذكر التقرير السابق.
- بقيت العناصر التالية مطابقة بايتًا للّقطة الأساسية: `android/`، `docs/`، `lib/main.dart`، `pubspec.yaml`، `pubspec.lock`، `README.md`.
- بقيت الأرشيفات الثلاثة مطابقة لكائناتها في `34b6b04`.

تغييرات التطبيق محصورة في نقطة دخول/غلاف Windows، خدمة حفظ الملفات، صفحتي الإعدادات والجدول، ملفات Windows الأصلية، أدوات التدقيق، اختبار خدمة الحفظ، وCI/التوثيق.

## 4. مطابقة تقرير المرحلة السابقة

### نتائج صحيحة

- المستودع المستهدف هو Jadwal-backup.
- التعارضان كانا في workflow Windows و`settings_page.dart`، وحُلّا يدويًا.
- لم يبدأ Windows 7 أو `jadwal_core`.
- اختلاف 22 ملفًا صحيح عند القياس قبل إضافة التقرير، وأصبح 23 بعده.
- Android ومداخل التطبيق والـmanifest/lock والـREADME لم تتغير من لقطة Android.
- بقيت ثلاثة استدعاءات فعلية لـ`SharePlus.instance.share`.
- `_exportData` و`_importData` و`FilePicker.platform.pickFiles` وتصدير PDF/Excel/الصورة موجودة.
- لم يُدعَ نجاح Android Release موقع.

### تصحيحات/توضيحات لازمة

1. التقرير يسجل «آخر التزام تم اختباره» = `3292b92` ويربط تشغيلَي ذلك الرأس. هذا كان صحيحًا وقت كتابة الملف، ثم شُغلت بوابات جديدة على `aef6f20`. التسليم النهائي اللاحق ذكر التشغيلين الصحيحين للرأس النهائي.
2. عبارة نجاح `git diff --check` صحيحة لفرق الدمج المرحلي الذي فُحص آنذاك، لكنها ليست صحيحة إذا طُبقت على **كل** فرق PR من `searchidf`: توجد مسافات نهائية موروثة، كما تحتوي تقارير Markdown على علامات تعارض مقتبسة بوصفها أدلة نصية، لا تعارضات source فعلية.
3. `pubspec.yaml` والـlock لم يتغيرا بالدمج، لكنهما غير متسقين SDK-wise أصلًا: manifest يسمح Dart `>=3.3.0`، بينما lock الحالي يسجل Dart `>=3.11.0-0` وFlutter `>=3.38.4`.

## 5. تحقق CI على SHA النهائي

كلا التشغيلين التاليين حدث `pull_request`، فرعهما فرع العمل، و`headSha` فيهما:

`aef6f20034a24e342fc780760a07f258b4ada934`

### Android

- التشغيل: [38244066122](https://github.com/kinanmjeed88/Jadwal-backup/actions/runs/38244066122)
- النتيجة: نجاح.
- `pub get`: نجاح.
- `flutter analyze --no-fatal-infos`: نجاح.
- `flutter test`: نجاح؛ لا قائمة استثناءات.
- كشف التوقيع: نجاح، وقرر أن الأسرار غير متاحة.
- Release الموقع: skipped عمدًا.
- Debug غير الموقع: نجاح.
- artifact: `debug-verification-apk`، وليس `release-apk`.

### Windows 10/11

- التشغيل: [38244066082](https://github.com/kinanmjeed88/Jadwal-backup/actions/runs/38244066082)
- النتيجة: نجاح.
- `pub get` وanalyze وجميع الاختبارات: نجاح.
- Windows Release: نجاح.
- فحص executable وdata: نجاح.
- smoke test: نجاح.
- ZIP وInno Setup installer: نجاح ورفعا كـartifacts.
- التوقيع الاختياري: skipped لغياب الشهادة.

توجد أيضًا نسختان مكررتان ناجحتان للتشغيلين على SHA نفسه بسبب تفعيل `push` و`pull_request` معًا.

## 6. مراجعة Workflows وعدم إخفاء الفشل

### ما هو سليم

- لا يوجد `continue-on-error`.
- Android `flutter test` يفشل المهمة عند exit code غير صفري.
- Windows يحفظ `$LASTEXITCODE` لـanalyze/test ويعيده صراحة، ويشترط وجود اختبار مكتمل واحد على الأقل.
- لا يستبعد benchmark أو أي ملف اختبار في النسخة المدمجة.
- فشل Inno Setup يوقف المهمة.
- غياب artifact في upload يسبب فشلًا في Windows، ومسار ملخص Android يتحقق من وجود APK.
- خطوات التوقيع skipped فقط إذا كانت بيانات التوقيع غير متاحة؛ ليست أخطاء مخفية.

### ملاحظات الجودة

1. `--no-fatal-infos` يسمح برسائل info ولا يسمح بإخفاء warnings/errors؛ هذا قرار لينت، لا تجاوز للفشل.
2. أسطر `sed ... || true` في Android قد تخفي عدم وجود ملف/نمط في خطوة التحوير. لا تخفي فشل analyze/test/build، لكن ينبغي في تحسين لاحق استبدالها بتحقق صريح مما عُدّل.
3. analyze/test يعملان **قبل** تحوير Android SDK وIsar وتوليد الأيقونات. البناء يختبر الشجرة المحوّرة، بينما الاختبارات تختبر المصدر قبل التحوير. الأفضل مستقبلًا إزالة التحوير من CI ووضع الإعداد الصحيح في المصدر، أو تنفيذ تحقق بعده.
4. Workflows الحديثة تستخدم `channel: stable` دون تثبيت رقم؛ النتيجة قابلة للتغير بمرور الوقت.

## 7. Android والتبعيات وGradle والتوقيع

- لا يوجد فرق في `android/` أو manifest/lock من لقطة Android الأساسية إلى الرأس النهائي.
- Gradle يتطلب Java 17، ويستخدم `flutter.compileSdkVersion/minSdkVersion/targetSdkVersion`، ثم تجبر CI بعض القيم مؤقتًا.
- Release config لا يتراجع إلى debug signing: إن طلب Release دون `key.properties` صالح أو متغيرات البيئة الأربعة، يرمي `GradleException`.
- عند توفر الأسرار الأربعة، CI يفك keystore في `$RUNNER_TEMP` ويمرر المسار وكلمات المرور إلى Gradle، ثم يبني `--release` ويرفع `app-release.apk` باسم `release-apk`.
- عند غيابها، يبني `--debug` ويرفع `app-debug.apk` باسم `debug-verification-apk`، ويكتب في الملخص أنه غير موقع وليس إنتاجيًا.
- إذًا Debug **لا يُسوّق كبديل Release**. لكن صلاحية مسار Release الموقع مثبتة بنيويًا فقط ولم تُختبر على الرأس النهائي؛ يجب تشغيله في سياق أسرار موثوق قبل أي إصدار.
- dependency manifest لم يتغير بالدمج. بقاء `share_plus ^12.0.2` يحافظ على Android.

## 8. حكم المراجعة

**PASS مع تحفظات قبل الإصدار**. لا توجد علة مثبتة تستلزم إعادة فتح دمج Windows 10/11 قبل التخطيط لـWindows 7. لا يُنصح بدمج PR #1 الآن قبل قرار المالك، واختبار Android Release الموقع والاختبارات التفاعلية يبقيان بوابتي إصدار، لا بوابتي قبول خطة Windows 7.

---

# الجزء الثاني: خطة Windows 7

## 9. مصفوفة أدوات SDK

| المنصة | Flutter | Dart | السبب |
|---|---|---|---|
| Android | Stable الحديثة، لكن يجب تثبيت النسخة التي أعادت lock الحالي | lock يطلب `>=3.11.0-0` | عدم إجبار المنصة الحديثة على SDK قديم؛ يلزم تثبيت رقم الإصدار في CI بدل `stable` قبل الاعتماد النهائي. lock يسجل Flutter `>=3.38.4`. |
| Windows 10/11 | النسخة الحديثة نفسها المستخدمة للجذر | `>=3.11.0-0` وفق lock | البناء الحالي ناجح على stable، ويجب تثبيت النسخة الفعلية القابلة لإعادة الإنتاج. |
| Windows 7 | **Flutter 3.16.9** | **Dart 3.2.6** (المرفق معه) | آخر خط أساس مستهدف ومستخدم في فرع W7؛ لا يجوز حل تبعياته بأداة Flutter الحديثة. |

`pubspec.yaml` للجذر يقول Dart `>=3.3.0`، وهو أوسع من lock الفعلي. يجب عدم نسخ lock الجذر إلى W7، وعدم تشغيل `pub get` الخاص بـW7 بFlutter الحديثة.

## 10. اختلافات manifest والـlock

manifest W7 المقترح/الموروث يستخدم Dart `>=3.2.0 <4.0.0` ويخفض أو يثبت الحزم التالية قياسًا بالجذر:

| الحزمة | الجذر الحديث | W7 manifest |
|---|---:|---:|
| `path_provider` | `^2.1.6` | `^2.1.1` |
| `file_picker` | `^10.3.10` | `^8.0.0+1` |
| `url_launcher` | `^6.3.2` | `^6.2.6` |
| `font_awesome_flutter` | `^11.0.0` | `10.7.0` |
| `firebase_core` | `^4.11.0` | `^2.25.0` |
| `firebase_analytics` | `^12.4.3` | `^10.4.5` |
| `window_manager` | `^0.5.2` | `0.3.9` |
| `screen_retriever` | `^0.2.2` | `0.1.9` |
| `path` | `^1.9.1` | `^1.8.3` |
| `meta` | `^1.17.0` | `^1.10.0` |
| `share_plus` | `^12.0.2` | غير موجود |
| `gal` | `^2.3.2` | غير موجود (وهو غير مستخدم حاليًا) |

الـlock الموجود داخل أرشيف W7 **غير صالح كدليل توافق**: ما زال يحتوي الإصدارات الحديثة، ومنها `file_picker 10.3.10` وFirebase 4/12 و`window_manager 0.5.2`، ويسجل Dart `>=3.11.0-0` وFlutter `>=3.38.4`. يجب حذف lock المنسوخ داخل تجربة مؤقتة فقط ثم إعادة توليده بFlutter 3.16.9، وفحص كل نسخة محلولة. لا يُقبل lock قبل نجاح analyze/test/build.

## 11. `DropdownButtonFormField.initialValue`

Flutter 3.16.9 لا يوفر `initialValue` في منشئ `DropdownButtonFormField`؛ يستخدم `value`. في كود W7 الفعلي، Dropdowns التسعة تستخدم `value`، بينما النسخة الحديثة تستخدم `initialValue` في خمسة مواضع و`value` في أربعة. يجب:

- إبقاء ملفات W7 المتوافقة (`settings_page.dart` و`subject_constraints_page.dart`) داخل تطبيق W7.
- عدم مشاركة widgets التي تحتوي constructor API المختلف في الحزمة المشتركة الأولى.
- عدم إجراء استبدال شامل؛ `TextFormField.initialValue` صالح ومختلف ولا يجوز تغييره.
- إضافة فحص CI يمنع `DropdownButtonFormField` مع `initialValue` داخل `apps/windows_7/lib/`.

## 12. التبعيات التي يجب عزلها

الفواصل الرئيسية هي:

- `share_plus`: مطلوب لـAndroid، غير موجود في W7. لا يُحذف من الجذر.
- `file_picker`: API/نسخة مختلفة، ويبقى داخل طبقة التطبيق/خدمة الملفات لكل منصة.
- Firebase وanalytics: major versions مختلفة؛ تبقى في bootstrap والخدمات الخاصة بكل تطبيق.
- `window_manager` و`screen_retriever`: نسخ W7 مثبتة وقديمة؛ تبقى في تطبيق W7.
- `path_provider` و`path` و`url_launcher`: يجب إثبات النسخ المحلولة تحت Dart 3.2.
- مولدات Isar/Riverpod والملفات `.g.dart`: يجب التحقق من أن generator versions المحلولة لا تعيد توليد schema/API مختلف. لا تُجدّد الملفات المولدة عشوائيًا.
- `printing` و`google_fonts` و`uuid` وغيرها ذات قيود caret واسعة قد تحل إلى نسخ حديثة غير متوافقة؛ ينبغي تثبيت النسخ التي يثبتها `pub get` المتوافق ثم مراجعتها.

## 13. تقييم `apps/windows_7/`

### لماذا هو مرشح جيد

Flutter يتعامل مع أي مجلد يحوي `pubspec.yaml` و`lib/` و`windows/` كمشروع مستقل. تشغيل الأوامر مع:

`working-directory: apps/windows_7`

يعزل manifest والـlock و`.dart_tool` والبناء عن الجذر. إبقاء اسم package الداخلي `jadwal_v2` في المرحلة الأولى يحافظ على 29 ملفًا تستخدم `package:jadwal_v2/...` دون إعادة كتابة imports.

### ما لم يُثبت بعد

لا نعتمد التصميم حتى تنجح تجربة مؤقتة في worktree/فرع مرحلة منفصل تثبت:

1. `flutter pub get` بFlutter 3.16.9 داخل المسار المتداخل.
2. حل الأصول `assets/` والخطوط من جذر تطبيق W7 نفسه.
3. imports الذاتية وgenerated files.
4. اكتشاف `windows/` المتداخل وبناء `lib/main_windows.dart`.
5. مسارات scripts وInno Setup من working directory الجديد.
6. عدم كتابة ملفات generated أو build في جذر التطبيق الحديث.
7. تشغيل artifact على Windows 7 حقيقي، لأن `windows-2022` يثبت قابلية البناء لا توافق runtime.

### قرار الخطة

**اعتماد مشروط** لـ`apps/windows_7/`: هو التصميم الموصى به لإثبات المرحلة التالية، وليس تصميمًا نهائيًا معتمدًا قبل اجتياز البوابات أعلاه.

## 14. آلية الحفاظ على الميزات ومشاركة الكود

### المرحلة 4A — العزل الآمن أولًا

يُدخل W7 كتطبيق مستقل مكتمل وظيفيًا تحت `apps/windows_7/`. هذا يكرر بعض الكود مؤقتًا، لكنه يمنع كسر منصة مستقرة. ميزات W7 للحفظ المحلي تبقى، وميزات Android للمشاركة لا تُمس.

يضاف drift guard يقارن الملفات المتطابقة حاليًا ويمنع اختلاف business logic خارج قائمة واضحة للملفات الخاصة بالمنصة. القائمة الأولية المرشحة للاختلاف:

- `lib/app/jadwal_windows_app.dart`
- `lib/main_windows.dart`
- `lib/features/management/presentation/pages/settings_page.dart`
- `lib/features/management/presentation/pages/subject_constraints_page.dart`
- `lib/features/timetable/presentation/pages/timetable_page.dart`
- ملفات `windows/` وmanifest/lock وCI والتوثيق.

ولا يُسمح باختلاف خوارزميات الجدولة والكيانات والمستودعات دون مراجعة صريحة.

### المرحلة 4B — مشاركة الكود بعد الإثبات فقط

بعد نجاح التطبيق المعزول، يُقترح PR منفصل لاستخراج كود pure Dart/common Flutter إلى `packages/jadwal_core/` مع حد SDK مشترك (`>=3.2.0`) وتبعيات متوافقة مع كلا البيئتين. لا تُنقل إليه plugins الخاصة بالمنصة.

الواجهات المقترحة تكون adapters/gateways مع المحافظة على signatures الحالية عبر أغلفة:

- `ShareGateway`: Android ينفذ بالمشاركة، وW7 ينفذ الحفظ المحلي أو يعلن أن المشاركة غير متاحة دون حذف زر/ميزة موجودة.
- `FileSaveGateway` و`FilePickGateway`.
- `AnalyticsGateway` وbootstrap خاص بكل تطبيق.
- `WindowStateGateway` يبقى في تطبيقات Windows.

تُنقل أولًا الخوارزميات والكيانات ذات hashes المتطابقة والاختبارات التابعة لها؛ تبقى UI المختلف وgenerated Isar schema خارج الحزمة حتى إثبات توافق generator/runtime. كل نقل يكون على دفعات صغيرة مع اختبار parity، وليس نقلًا شاملًا لنحو 110 ملفات.

## 15. الملفات المتوقعة في مرحلة التنفيذ التالية

### تُنشأ/تضاف مشروطًا

- `apps/windows_7/pubspec.yaml`
- `apps/windows_7/pubspec.lock` مولد حصريًا بFlutter 3.16.9
- `apps/windows_7/.metadata`
- `apps/windows_7/lib/**`
- `apps/windows_7/test/**`
- `apps/windows_7/windows/**`
- `apps/windows_7/assets/**`
- `apps/windows_7/analysis_options.yaml`
- `.github/workflows/build_windows_7.yml`
- أداة/اختبار drift guard تحت `tools/` أو workflow.
- توثيق Windows 7 الخاص به.

### لا تتغير في خطوة العزل الأولى

- `lib/**` في الجذر، عدا عدم وجود حاجة متوقعة لأي تعديل.
- `android/**` و`ios/**` وmanifest/lock للجذر.
- workflow Android وWindows 10/11، إلا إذا احتاجا path filters لمنع تشغيل غير لازم؛ أي تعديل يُراجع مستقلًا.
- APIs الحالية والخوارزميات والـgenerated files في الجذر.

### لا تُضاف داخل تطبيق W7

لا حاجة إلى `android/ios/macos/linux/web/` داخل التطبيق الخاص بـW7، بشرط أن يثبت `pub get/build` عدم اعتماد tooling عليها. لا تُحذف هذه المجلدات من الجذر.

## 16. CI واختبارات كل منصة

### Android

- Flutter حديث مثبت برقم.
- `pub get`, format check, analyze, جميع tests.
- Debug verification لكل PR.
- Release موقع في سياق الأسرار قبل الإصدار.
- اختبار يدوي/آلي للمشاركة والتصدير والنسخ الاحتياطي والاستعادة.

### Windows 10/11

- Flutter حديث مثبت بالرقم نفسه للجذر.
- analyze/test/Release build/smoke/PE audit/installer.
- عدم تشغيل workflow عند تغييرات W7-only باستخدام path filters بعد اختبارها.

### Windows 7

- `windows-2022` للبناء، Flutter `3.16.9` مثبت، و`working-directory: apps/windows_7` لكل أمر.
- فحص `flutter --version` و`dart --version` وإيقاف المهمة إذا اختلفا.
- حذف `.dart_tool` وlock التجريبي قبل أول حل، ثم تثبيت lock الناتج ومقارنته في التشغيلات اللاحقة (`git diff --exit-code pubspec.lock`).
- format/analyze/all tests. لا يُستبعد benchmark بصمت؛ إن تعذر زمنيًا، يوضع في job مسمى مستقل وتبقى حالته ظاهرة.
- `flutter build windows --release --target=lib/main_windows.dart`.
- فحص executable/data وPE imports وinstaller.
- اختبار فعلي على Windows 7 SP1 x64 نظيف أو VM موثقة. لا يُستبدل ذلك بنجاح Windows 2022.

## 17. ترتيب التنفيذ المقترح ونقاط التراجع

1. **Proof branch/worktree فقط:** إنشاء البنية في فرع مرحلة منفصل وتجربة المسارات والـSDK؛ نقطة التراجع حذف الفرع/الـworktree، بلا أثر على PR #1.
2. **استيراد W7 المعزول:** commit مستقل للملفات فقط؛ التراجع `git revert` لذلك الالتزام.
3. **إصلاح lock المتوافق:** commit مستقل بعد `pub get` 3.16.9 ومراجعة dependency graph؛ التراجع يعيد lock/manifest فقط.
4. **CI W7:** commit مستقل؛ لا تعديل لأسرار المستودع.
5. **اختبار Windows 7 الحقيقي:** توثيق artifact SHA ونتيجة التشغيل.
6. **مشاركة core لاحقًا:** PR منفصل تمامًا بعد قبول العزل، مع rollback لكل دفعة.

لا يُدمج أي PR في أي خطوة دون موافقة صريحة.

## 18. المخاطر

| الخطر | التخفيف/البوابة |
|---|---|
| lock W7 مولد بأداة حديثة | إعادة توليد حصرية ب3.16.9 وفشل CI عند drift. |
| caret constraints تحل نسخًا غير متوافقة | تثبيت النسخ المثبت توافقها ومراجعة graph. |
| بناء Windows 2022 يعمل لكن binary يفشل على Win7 | اختبار VM/جهاز Win7 إلزامي. |
| تباعد business logic بسبب النسخ | hash/drift guard ثم استخراج core تدريجي. |
| كسر Android بإزالة `share_plus` | لا تغيير manifest الجذر؛ gateway في PR لاحق فقط. |
| Flutter API حديث يدخل W7 | lint/grep مخصص لـ`DropdownButtonFormField.initialValue` + analyze 3.16.9. |
| generated code يتغير | مقارنة schema/API وعدم regeneration إلا بالأداة المثبتة. |
| تضاعف CI | path filters بعد التحقق من أنها لا تمنع بوابات مطلوبة. |
| تضخم المستودع بالأصول المكررة | قبول مؤقت صغير؛ تقييم package assets لاحقًا، دون symlinks غير موثوقة على Windows. |

## 19. شروط السماح بالانتقال للتنفيذ

لا تبدأ مرحلة التنفيذ إلا بعد موافقة المالك على:

1. اعتماد `apps/windows_7/` **كتجربة إثبات أولًا** لا كقرار نهائي مسبق.
2. Flutter 3.16.9/Dart 3.2.6 كأداة W7.
3. إعادة توليد lock W7 وعدم الوثوق بالlock الموجود في الأرشيف.
4. تأجيل `jadwal_core` إلى PR لاحق بعد نجاح العزل.
5. إلزام اختبار Windows 7 حقيقي قبل إعلان دعم المنصة.

**توقفت الخطة هنا. لم يُعدل أو يُنقل أي ملف من نسخة Windows 7.**

</div>
