// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get coachNameLeon => 'ليون';

  @override
  String get coachNameLeona => 'ليونا';

  @override
  String get coachAnimalLion => 'أسد';

  @override
  String get coachAnimalLioness => 'لبؤة';

  @override
  String get coachAskTitle => 'اسأل GoHard';

  @override
  String get coachAskAiAssistant => 'مساعد تدريب بالذكاء الاصطناعي';

  @override
  String coachAskAbout(String label) {
    return 'الموضوع: $label';
  }

  @override
  String get coachAskIntro =>
      'اطرح سؤالًا عن خطتك. تكتب الإجابات بواسطة الذكاء الاصطناعي اعتمادًا على مسودتك ودليل GoHard المُراجَع، لذا تحقّق من كل ما هو مهم. لا يُرسل أي شيء قبل الضغط على إرسال.';

  @override
  String get coachAskSuggestWhyIncluded => 'لماذا أُدرج هذا التمرين؟';

  @override
  String get coachAskSuggestDumbbell => 'هل يمكن استبداله بتمرين بالدمبل؟';

  @override
  String get coachAskSuggestAlternatives =>
      'ما فوائد هذه البدائل وما سلبياتها؟';

  @override
  String get coachAskSuggestSetsReps => 'ماذا يعني 3 × 8–12؟';

  @override
  String get coachAskSuggestShorten => 'كيف يمكن تقصير هذه الحصة التدريبية؟';

  @override
  String get coachAskSuggestWhySplit => 'لماذا هذا التقسيم لجدولي؟';

  @override
  String get coachAskSuggestCompareSplits =>
      'ما الفرق بين تقسيم علوي/سفلي وتقسيم دفع/سحب/أرجل؟';

  @override
  String get coachAskClearTitle => 'مسح هذه المحادثة؟';

  @override
  String get coachAskClearBody =>
      'تُحذف أسئلتها وإجاباتها من هذا الهاتف. لا تتغيّر مسودتك.';

  @override
  String get coachAskClearAction => 'مسح';

  @override
  String get coachAskClearTooltip => 'مسح المحادثة';

  @override
  String get coachAskInputHint => 'اطرح سؤالًا';

  @override
  String get coachAskSend => 'إرسال';

  @override
  String coachAskYouAsked(String text) {
    return 'سؤالك: $text';
  }

  @override
  String get coachAskWaiting => 'بانتظار الإجابة';

  @override
  String get coachAskRetry => 'إعادة المحاولة';

  @override
  String get coachAskEditQuestion => 'تعديل السؤال';

  @override
  String get coachAskProblemLimit =>
      'طرحت أسئلة كثيرة اليوم. سيجيب «اسأل GoHard» مجددًا لاحقًا، ولا يزال الدليل السريع المدمج يعمل.';

  @override
  String get coachAskProblemBusy =>
      '«اسأل GoHard» مشغول حاليًا. أعد المحاولة بعد قليل.';

  @override
  String get coachAskProblemUnreached =>
      'تعذّر الوصول إلى «اسأل GoHard». قد يكون السبب اتصال هذا الهاتف أو الخادم. لا يزال الدليل السريع المدمج يعمل.';

  @override
  String get coachAskProblemInvalid =>
      'تعذّر إرسال هذا السؤال. عدّله وأرسله مجددًا (حتى 600 حرف).';

  @override
  String get coachAskProblemInterrupted =>
      'لم يتلقَّ هذا السؤال إجابة قبل إغلاق «اسأل GoHard». أعد المحاولة لطرحه مجددًا.';

  @override
  String get coachAskProblemUnavailable =>
      '«اسأل GoHard» غير متاح حاليًا. سؤالك محفوظ، ولا يزال الدليل السريع المدمج يعمل.';

  @override
  String get coachAskAiGenerated => 'مُنشأ بالذكاء الاصطناعي';

  @override
  String get coachAskStale => 'مبني على نسخة سابقة من مسودتك';

  @override
  String get coachAskLess => 'أقل';

  @override
  String get coachAskMore => 'المزيد';

  @override
  String get coachAskSourcesHeading => 'مصادر من دليل GoHard المُراجَع';

  @override
  String get coachAskSuggestedChange => 'تغيير مقترح';

  @override
  String get coachAskChangeFallback => 'تغيير على مسودتك';

  @override
  String get coachAskApplied =>
      'طُبّق على مسودتك. يُحفظ مثل أي تعديل آخر، ولا يُفعَّل أي شيء.';

  @override
  String get coachAskUndo => 'تراجع';

  @override
  String get coachAskUndone => 'تم التراجع: مسودتك كما كانت قبل هذا الاقتراح.';

  @override
  String get coachAskTextOnly =>
      'افتح أداة إنشاء الخطة لمعاينة الاقتراحات وتطبيقها.';

  @override
  String get coachAskPreview => 'معاينة التغيير';

  @override
  String get coachAskCantApply => 'لا يمكن تطبيق هذا الاقتراح على مسودتك.';

  @override
  String get coachAskDraftOnly => 'المسودة فقط';

  @override
  String get coachAskDraftOnlyBody =>
      'يغيّر المسودة في أداة الإنشاء، ويُحفظ مثل أي تعديل. لا يُفعَّل أي شيء.';

  @override
  String get coachAskDraftChanged => 'تغيّرت مسودتك منذ هذا الاقتراح';

  @override
  String get coachAskRecheck => 'التحقق مقابل مسودتي الحالية';

  @override
  String get coachAskNotApplicableHeading => 'لا ينطبق على مسودتك الحالية';

  @override
  String get coachAskNothingApplies =>
      'لم يعد أي جزء من هذا الاقتراح ينطبق على مسودتك.';

  @override
  String get coachAskApply => 'تطبيق على المسودة';

  @override
  String get coachAskKeep => 'الإبقاء على الحالي';

  @override
  String coachAskChangeAdded(String name, String rx) {
    return 'أُضيف: $name · $rx';
  }

  @override
  String coachAskChangeRemoved(String name, String rx) {
    return 'أُزيل: $name · $rx';
  }

  @override
  String coachAskChangeArrow(String before, String after) {
    return '$before ← $after';
  }

  @override
  String coachAskWeightCleared(String load, String name) {
    return 'يُلغى الوزن المستهدف $load: يبدأ البديل من دونه ولا يأخذ سجل $name.';
  }

  @override
  String coachAskWeightKept(String load) {
    return 'يُحتفظ بالوزن المستهدف $load.';
  }

  @override
  String coachSkipWorkoutGone(String op) {
    String _temp0 = intl.Intl.selectLogic(op, {
      'removeExercise': 'إزالة تمرين',
      'replaceExercise': 'استبدال تمرين',
      'setPrescription': 'تغيير المجموعات والتكرارات',
      'other': 'إضافة تمرين',
    });
    return '$_temp0: الحصة التدريبية المذكورة لم تعد في مسودتك.';
  }

  @override
  String coachSkipExerciseGone(String op, String workout) {
    String _temp0 = intl.Intl.selectLogic(op, {
      'removeExercise': 'إزالة تمرين',
      'replaceExercise': 'استبدال تمرين',
      'setPrescription': 'تغيير المجموعات والتكرارات',
      'other': 'إضافة تمرين',
    });
    return '$_temp0: هذا التمرين لم يعد في $workout.';
  }

  @override
  String coachSkipReplaceUnavailable(String exercise) {
    return 'استبدال $exercise: التمرين المقترح غير متاح لحسابك.';
  }

  @override
  String coachSkipReplaceSame(String exercise) {
    return 'استبدال $exercise: إنه هذا التمرين بالفعل.';
  }

  @override
  String coachSkipValuesOutside(String exercise) {
    return 'تغيير $exercise: القيم المقترحة خارج ما تسمح به الخطة.';
  }

  @override
  String coachSkipAddUnavailable(String workout) {
    return 'إضافة تمرين إلى $workout: غير متاح لحسابك.';
  }

  @override
  String coachSkipAddOutside(String exercise, String workout) {
    return 'إضافة $exercise إلى $workout: القيم المقترحة خارج ما تسمح به الخطة.';
  }

  @override
  String coachSkipAddFull(String exercise, String workout) {
    return 'إضافة $exercise إلى $workout: تضم الحصة التدريبية 30 تمرينًا بالفعل.';
  }

  @override
  String coachUndoRefused(String exercise) {
    return 'لم يعد التراجع آمنًا: تغيّر $exercise بعد تطبيق الاقتراح. عدّله في أداة الإنشاء بدلًا من ذلك.';
  }

  @override
  String get coachQuickGuide => 'الدليل السريع';

  @override
  String get coachQuickGuideBuiltIn => 'الدليل السريع · مدمج';

  @override
  String get coachQuickGuideReviewed => 'الدليل السريع · محتوى مدمج مُراجَع';

  @override
  String get coachAskOpenQuickGuide => 'فتح الدليل السريع';

  @override
  String get coachGuideSources => 'المصادر';

  @override
  String get coachGuideThisSplit => 'هذا التقسيم';

  @override
  String get coachGuideBenefits => 'الفوائد';

  @override
  String get coachGuideLimitations => 'القيود';

  @override
  String get coachGuideTechniqueCues => 'إرشادات الأداء';

  @override
  String get coachGuideAlternatives => 'البدائل';

  @override
  String get coachGuideCustomNoInfo =>
      'أضفته بنفسك. لا تتوفر لدى GoHard معلومات أداء مُراجَعة للتمارين التي تضيفها.';

  @override
  String coachGuideMusclesLine(String list) {
    return 'العضلات: $list';
  }

  @override
  String coachGuideEquipmentLine(String equipment) {
    return 'المعدات: $equipment';
  }

  @override
  String get coachGuideRoleMain => 'الدور: تمرين رئيسي';

  @override
  String get coachGuideRoleAccessory => 'الدور: تمرين مساعد';

  @override
  String get coachListSeparator => '، ';

  @override
  String get coachCycleArrow => ' ← ';

  @override
  String coachWhyTitle(String name) {
    return 'لماذا $name؟';
  }

  @override
  String get coachSheetHowItWorks => 'كيف يعمل';

  @override
  String get coachSheetGoodToKnow => 'معلومات مفيدة';

  @override
  String get coachSheetTradeOffs => 'السلبيات';

  @override
  String get coachSheetChoosingSplit => 'اختيار التقسيم';

  @override
  String get coachSplitEvidenceNote =>
      'وجدت الدراسات التي قارنت بين تقسيمات بالحجم الأسبوعي نفسه مكاسب متقاربة في القوة والعضلات، لذا اختر البنية التي يمكنك الاستمرار عليها.';

  @override
  String get coachCompareTitle => 'مقارنة التقسيمات';

  @override
  String coachCompareSuggested(String name) {
    return '$name · مقترح';
  }

  @override
  String get coachSheetYourWeek => 'أسبوعك';

  @override
  String get coachSheetOrganisation => 'التنظيم';

  @override
  String get coachSheetDays => 'الأيام';

  @override
  String get coachInfoCustom =>
      'أضفته بنفسك. لا تتوفر لدى GoHard ملاحظات أداء مُراجَعة للتمارين التي تضيفها.';

  @override
  String get coachInfoCategoryEquipment => 'الفئة والمعدات';

  @override
  String get coachInfoNoNotes => 'لا توجد ملاحظات مدمجة لهذا التمرين بعد.';

  @override
  String get coachInfoMuscles => 'العضلات';

  @override
  String get coachInfoEquipment => 'المعدات';

  @override
  String get coachInfoInRoutine => 'في هذا البرنامج';

  @override
  String get coachInfoRoleMain =>
      'تمرين رئيسي: تمرين مركّب يعمل على عدة عضلات كبيرة، ويُؤدّى عادةً في البداية مع راحة أطول.';

  @override
  String coachInfoRoleMainIn(String workout) {
    return 'تمرين رئيسي في $workout: تمرين مركّب يعمل على عدة عضلات كبيرة، ويُؤدّى عادةً في البداية مع راحة أطول.';
  }

  @override
  String get coachInfoRoleAccessory =>
      'تمرين مساعد: عمل إضافي لعضلات محددة، ويُؤدّى عادةً بعد التمارين الرئيسية.';

  @override
  String coachInfoRoleAccessoryIn(String workout) {
    return 'تمرين مساعد في $workout: عمل إضافي لعضلات محددة، ويُؤدّى عادةً بعد التمارين الرئيسية.';
  }

  @override
  String get coachInfoTechnique => 'الأداء';

  @override
  String get coachInfoPrescription => 'الوصفة التدريبية';

  @override
  String get coachInfoAsk => 'اسأل عن هذا التمرين';

  @override
  String get coachInfoReplace => 'استبدال…';

  @override
  String get coachRxNone => 'لم يُحدَّد هدف بعد.';

  @override
  String coachRxSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مجموعة',
      many: '$count مجموعة',
      few: '$count مجموعات',
      two: 'مجموعتان',
      one: 'مجموعة واحدة',
      zero: '0 مجموعات',
    );
    return '$_temp0';
  }

  @override
  String coachRxSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ثانية',
      many: '$count ثانية',
      few: '$count ثوانٍ',
      two: 'ثانيتان',
      one: 'ثانية واحدة',
      zero: '0 ثانية',
    );
    return '$_temp0';
  }

  @override
  String coachRxReps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تكرار',
      many: '$count تكرارًا',
      few: '$count تكرارات',
      two: 'تكراران',
      one: 'تكرار واحد',
      zero: '0 تكرار',
    );
    return '$_temp0';
  }

  @override
  String coachRxRepRange(int lo, int hi) {
    return 'من $lo إلى $hi تكرارًا';
  }

  @override
  String coachRxSetsOf(String sets, String amount) {
    return '$sets من $amount';
  }

  @override
  String coachRxSentence(String what) {
    return '$what.';
  }

  @override
  String coachRxSentenceRest(String what, int rest) {
    String _temp0 = intl.Intl.pluralLogic(
      rest,
      locale: localeName,
      other: '$what، مع راحة $rest ثانية بين المجموعات.',
      many: '$what، مع راحة $rest ثانية بين المجموعات.',
      few: '$what، مع راحة $rest ثوانٍ بين المجموعات.',
      two: '$what، مع راحة ثانيتين بين المجموعات.',
      one: '$what، مع راحة ثانية واحدة بين المجموعات.',
      zero: '$what، دون راحة بين المجموعات.',
    );
    return '$_temp0';
  }

  @override
  String coachGuideDays(String count) {
    String _temp0 = intl.Intl.selectLogic(count, {
      'd0': 'دون أيام تدريب',
      'd1': 'يوم تدريب واحد',
      'd2': 'يومَي تدريب',
      'd3': 'ثلاثة أيام تدريب',
      'd4': 'أربعة أيام تدريب',
      'd5': 'خمسة أيام تدريب',
      'd6': 'ستة أيام تدريب',
      'd7': 'سبعة أيام تدريب',
      'other': '$count يوم تدريب',
    });
    return '$_temp0';
  }

  @override
  String coachGuideEquipment(String equipment) {
    String _temp0 = intl.Intl.selectLogic(equipment, {
      'full_gym': 'معدات صالة رياضية',
      'dumbbells': 'الدمبل فقط',
      'bodyweight': 'وزن الجسم فقط',
      'other': 'معدات صالة رياضية',
    });
    return '$_temp0';
  }

  @override
  String coachGuideSuggestedBecause(String days, String equipment) {
    return 'مقترح لأنك اخترت $days و$equipment.';
  }

  @override
  String get coachGuideSwapDumbbell => 'تستخدم التمارين نسخ الدمبل.';

  @override
  String get coachGuideSwapBodyweight => 'تستخدم التمارين نسخ وزن الجسم.';

  @override
  String coachGuideFitWeekly(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'حصة تدريبية واحدة في كل يوم من أيامك الـ$days.',
      many: 'حصة تدريبية واحدة في كل يوم من أيامك الـ$days.',
      few: 'حصة تدريبية واحدة في كل يوم من أيامك الـ$days.',
      two: 'حصة تدريبية واحدة في كل من يوميك.',
      one: 'حصة تدريبية واحدة في يومك.',
      zero: 'حصة تدريبية واحدة في كل يوم.',
    );
    return '$_temp0';
  }

  @override
  String coachGuideFitRotate(int days, int workouts) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'تتناوب حصصه التدريبية الـ$workouts على أيامك الـ$days.',
      many: 'تتناوب حصصه التدريبية الـ$workouts على أيامك الـ$days.',
      few: 'تتناوب حصصه التدريبية الـ$workouts على أيامك الـ$days.',
      two: 'تتناوب حصصه التدريبية الـ$workouts على يوميك.',
      one: 'تتناوب حصصه التدريبية الـ$workouts على يومك.',
      zero: 'تتناوب حصصه التدريبية الـ$workouts على أيامك.',
    );
    return '$_temp0';
  }

  @override
  String get coachGuideAnyDay => 'أي يوم';

  @override
  String coachGuideRotation(String cycle, String days) {
    return '$cycle، في $days. يستمر الترتيب من أسبوع إلى آخر.';
  }

  @override
  String get coachAskMeInline => 'اسألني ›';

  @override
  String get coachAskMe => 'اسألني';

  @override
  String coachAskOpenWith(String name) {
    return 'اسأل GoHard: افتح المحادثة مع $name';
  }

  @override
  String get languageSystem => 'النظام';

  @override
  String languageSystemResolved(String language) {
    return 'لغة الهاتف: $language';
  }

  @override
  String get languageTitle => 'اللغة';

  @override
  String get languageFootnote =>
      'تُحفظ على هذا الهاتف فقط. يتغيّر نص GoHard، أما ملاحظاتك وأسماء الأطعمة والتمارين التي كتبتها فتبقى كما هي.';

  @override
  String get navToday => 'اليوم';

  @override
  String get navTrain => 'التدريب';

  @override
  String get navEat => 'التغذية';

  @override
  String get navMe => 'حسابي';

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get busyWorking => 'جارٍ التنفيذ';

  @override
  String percentValue(int percent) {
    return '$percent بالمئة';
  }

  @override
  String get motionDevice => 'الجهاز';

  @override
  String get motionReduced => 'مُخفَّضة';

  @override
  String get hapticsDevice => 'الجهاز';

  @override
  String get hapticsOff => 'إيقاف';

  @override
  String durationSeconds(int seconds) {
    return '$seconds ث';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes د';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours س $minutes د';
  }

  @override
  String get valueUnknown => '—';

  @override
  String get unitKg => 'كغ';

  @override
  String get unitLb => 'رطل';

  @override
  String get unitKm => 'كم';

  @override
  String get unitMi => 'ميل';

  @override
  String get unitKmPerHour => 'كم/س';

  @override
  String get unitMph => 'ميل/س';

  @override
  String get unitMetre => 'م';

  @override
  String get unitFoot => 'قدم';

  @override
  String paceValue(String pace, String unit) {
    return '$pace لكل $unit';
  }

  @override
  String get actionSave => 'حفظ';

  @override
  String get actionDone => 'تم';

  @override
  String get actionDelete => 'حذف';

  @override
  String get actionClose => 'إغلاق';

  @override
  String get actionEdit => 'تعديل';

  @override
  String get actionTryAgain => 'حاول مرة أخرى';

  @override
  String get actionContinue => 'متابعة';

  @override
  String get actionRemove => 'إزالة';

  @override
  String get actionOk => 'حسنًا';

  @override
  String get errorGeneric => 'حدث خطأ ما. لم يُفقد شيء؛ حاول مرة أخرى.';

  @override
  String get brandName => 'GoHard';

  @override
  String get foodCategoryProteins => 'البروتينات';

  @override
  String get foodCategoryCarbohydrates => 'الكربوهيدرات';

  @override
  String get foodCategoryCarbsShort => 'النشويات';

  @override
  String get foodCategoryVegetables => 'الخضروات';

  @override
  String get foodCategoryFruits => 'الفواكه';

  @override
  String get foodCategoryDairy => 'منتجات الألبان';

  @override
  String get foodCategoryFatsOils => 'الدهون والزيوت';

  @override
  String get foodCategorySnacks => 'الوجبات الخفيفة';

  @override
  String get foodCategoryBeverages => 'المشروبات';

  @override
  String get foodCategoryAll => 'الكل';

  @override
  String get foodTagFavourite => 'مفضّل';

  @override
  String get foodTagMine => 'طعامي';

  @override
  String get foodTagRecent => 'حديث';

  @override
  String get foodAsYouLoggedIt => 'كما سجّلته';

  @override
  String foodBasisPer(String basis) {
    return 'لكل $basis';
  }

  @override
  String get foodServingFallback => 'حصة';

  @override
  String get mealBreakfast => 'الفطور';

  @override
  String get mealLunch => 'الغداء';

  @override
  String get mealDinner => 'العشاء';

  @override
  String get mealSnack => 'وجبات خفيفة';

  @override
  String get eatUnitKcal => 'سعرة';

  @override
  String get eatUnitGram => 'غ';

  @override
  String eatKcalValue(String value) {
    return '$value سعرة';
  }

  @override
  String eatGramsValue(String value) {
    return '$value غ';
  }

  @override
  String eatProteinGramsValue(String value) {
    return '$value غ بروتين';
  }

  @override
  String eatWaterValue(String amount) {
    return '$amount ماء';
  }

  @override
  String get eatTodayCaption => 'اليوم';

  @override
  String get eatCarbs => 'الكربوهيدرات';

  @override
  String get eatFat => 'الدهون';

  @override
  String get eatCalories => 'السعرات';

  @override
  String get eatProtein => 'البروتين';

  @override
  String get eatGoalCaloriesWhole =>
      'هدف السعرات رقم صحيح، أو اتركه فارغًا لعدم تحديد هدف.';

  @override
  String get eatGoalProteinWhole =>
      'هدف البروتين رقم صحيح، أو اتركه فارغًا لعدم تحديد هدف.';

  @override
  String get eatGoalWaterInvalid =>
      'هدف الماء كمية أكبر من صفر، أو اتركه فارغًا لعدم تحديد هدف.';

  @override
  String get eatGoalsSaveFailed =>
      'تعذّر حفظ أهدافك على هذا الهاتف. ما كتبته لا يزال هنا.';

  @override
  String get eatGoalCaloriesLabel => 'السعرات اليومية';

  @override
  String get eatGoalProteinLabel => 'البروتين اليومي';

  @override
  String get eatGoalWaterLabel => 'الماء اليومي';

  @override
  String get eatGoalNone => 'بلا هدف';

  @override
  String get eatGoalCaloriesHelper =>
      'من 500 إلى 10,000. اتركه فارغًا لعدم تحديد هدف للسعرات.';

  @override
  String get eatGoalProteinHelper =>
      'من 10 إلى 500. اتركه فارغًا لعدم تحديد هدف للبروتين.';

  @override
  String get eatGoalWaterHelperMl =>
      'من 100 إلى 10,000. اتركه فارغًا لعدم تحديد هدف للماء.';

  @override
  String get eatGoalWaterHelperFlOz =>
      'من 3.4 إلى 338 (أونصة سائلة أمريكية). اتركه فارغًا لعدم تحديد هدف للماء.';

  @override
  String get eatGoalsSave => 'حفظ الأهداف';

  @override
  String get eatGoalsNoSuggestion =>
      'لا يقترح GoHard هدفًا للسعرات أو البروتين. إن لم تكن متأكدًا مما يناسبك، يمكن لأخصائي تغذية أو طبيب المساعدة.';

  @override
  String get eatGoalsSheetTitle => 'الأهداف اليومية';

  @override
  String get eatGoalsSheetIntro =>
      'تتكرر هذه الأهداف كل يوم حتى تغيّرها. اترك أيًّا منها فارغًا لعدم تحديد هدف.';

  @override
  String get eatEditGoals => 'تعديل الأهداف';

  @override
  String get eatEditGoalsSaid => 'تعديل الأهداف اليومية';

  @override
  String get eatSetGoals => 'تحديد الأهداف اليومية';

  @override
  String get eatCustomizeTracking => 'تخصيص التتبّع';

  @override
  String get eatTrackingIntro =>
      'تُعرض السعرات والبروتين دائمًا. الإخفاء يغيّر ما تراه فقط: لا يُحذف شيء مما سجّلته أو حدّدته.';

  @override
  String get eatTrackWaterSubtitle =>
      'سطر للماء في «اليوم» و«التغذية»، مع هدف اختياري';

  @override
  String get eatTrackWaterUnsupported =>
      'يتطلب تتبّع الماء إصدارًا أحدث من خادم حسابك. لا يتغيّر شيء آخر.';

  @override
  String get eatTrackCarbsSubtitle => 'إجمالي الكربوهيدرات في «التغذية»';

  @override
  String get eatTrackFatSubtitle => 'إجمالي الدهون في «التغذية»';

  @override
  String get eatTrackSynced =>
      'تنتقل هذه الاختيارات مع حسابك إلى هواتفك الأخرى.';

  @override
  String get waterUnitMl => 'مل';

  @override
  String get waterUnitFlOz => 'أونصة سائلة';

  @override
  String get waterUnitMlName => 'المليلترات';

  @override
  String get waterUnitFlOzName => 'الأونصات السائلة الأمريكية';

  @override
  String get waterTitle => 'الماء';

  @override
  String get waterNoneLogged => 'لم يُسجَّل ماء';

  @override
  String get waterSaidLoading => 'الماء، جارٍ التحميل';

  @override
  String get waterSaidNone => 'الماء، لم يُسجَّل ماء';

  @override
  String waterSaid(String amount) {
    return 'الماء $amount';
  }

  @override
  String waterSaidWithGoal(String amount, String goal, int percent) {
    return 'الماء $amount من $goal، $percent بالمئة';
  }

  @override
  String waterAddSaidMl(String amount) {
    return 'إضافة $amount مل من الماء';
  }

  @override
  String waterAddSaidFlOz(String amount) {
    return 'إضافة $amount أونصة سائلة من الماء';
  }

  @override
  String waterUndo(String amount) {
    return 'تراجع عن $amount';
  }

  @override
  String waterUndoSaid(String amount) {
    return 'تراجع عن إضافة $amount من الماء';
  }

  @override
  String get waterOtherAmount => 'كمية أخرى';

  @override
  String get waterRowHint => 'يفتح تفاصيل الماء لهذا اليوم';

  @override
  String get waterSaveFailed => 'تعذّر الحفظ على هذا الهاتف. لم تُضَف أي كمية.';

  @override
  String waterAddedAnnounce(String amount) {
    return 'أُضيف $amount من الماء. يمكن التراجع.';
  }

  @override
  String waterAddedOnDayAnnounce(String amount, String date) {
    return 'أُضيف $amount من الماء في $date. يمكن التراجع.';
  }

  @override
  String get waterAddTitle => 'إضافة ماء';

  @override
  String waterForDay(String date) {
    return 'ليوم $date';
  }

  @override
  String get waterAmountLabel => 'الكمية';

  @override
  String get waterProblemNotAboveZero => 'أدخل كمية أكبر من صفر.';

  @override
  String get waterProblemOverMax =>
      'لا يتجاوز الإدخال الواحد 5 لترات. سجّل الكمية الأكبر على دفعات.';

  @override
  String get waterGoalLabel => 'هدف الماء';

  @override
  String get waterAdd => 'إضافة';

  @override
  String get waterAnotherAmount => 'كمية أخرى';

  @override
  String get waterNothingThisDay => 'لم يُسجَّل شيء في هذا اليوم';

  @override
  String get waterLoggedThisDay => 'المسجَّل في هذا اليوم';

  @override
  String get waterEntryPending => 'محفوظ على هذا الهاتف · انقر للتصحيح';

  @override
  String get waterEntryTap => 'انقر للتصحيح';

  @override
  String waterRemoveTooltip(String amount) {
    return 'إزالة $amount';
  }

  @override
  String get waterOnlyLoggedNote =>
      'يُحتسب الماء الذي تسجّله هنا فقط، لا المشروبات ولا الطعام.';

  @override
  String get waterCorrectTitle => 'تصحيح هذه الكمية';

  @override
  String get waterSuggestionAboutTitle => 'حول هدف الماء المقترح';

  @override
  String waterSuggestionAboutBody(String amount) {
    return '$amount يوميًا نقطة بداية عامة، وليست توصية محسوبة لك. تختلف الحاجة باختلاف حجم الجسم والنشاط والحرارة والصحة؛ وإن كانت حالة صحية أو دواء يؤثر في الكمية التي ينبغي شربها، فاتّبع نصيحة طبيبك.\n\nتسهم المشروبات الأخرى والطعام أيضًا في الترطيب. لا يحتسب GoHard إلا الماء الذي تسجّله بنفسك، لذا فإجماليك هنا ليس كل ما شربته.';
  }

  @override
  String waterSuggestedGoal(String amount) {
    return 'هدف بداية مقترح: $amount يوميًا.';
  }

  @override
  String get waterSuggestedGoalNote =>
      'نقطة بداية عامة؛ قد تختلف احتياجاتك. يُحتسب الماء الذي تسجّله فقط.';

  @override
  String waterSuggestionUse(String amount) {
    return 'استخدام $amount';
  }

  @override
  String get eatUnitGramProtein => 'غ بروتين';

  @override
  String eatGoalProgressCalories(String eaten, String goal) {
    return '$eaten من $goal سعرة';
  }

  @override
  String eatGoalProgressProtein(String eaten, String goal) {
    return 'البروتين $eaten من $goal غ';
  }

  @override
  String eatGoalNoCalorieValue(String goal) {
    return 'لم تُدخَل قيمة للسعرات بعد · الهدف $goal سعرة';
  }

  @override
  String eatGoalNoProteinValue(String goal) {
    return 'لم تُدخَل قيمة للبروتين بعد · الهدف $goal غ';
  }

  @override
  String eatGoalKnownSoFar(String progress) {
    return '$progress · المعروف حتى الآن';
  }

  @override
  String eatGoalOverKcal(String progress, String diff) {
    return '$progress · $diff سعرة فوق الهدف';
  }

  @override
  String eatGoalLeftKcal(String progress, String diff) {
    return '$progress · يتبقى $diff سعرة';
  }

  @override
  String eatGoalOverGrams(String progress, String diff) {
    return '$progress · $diff غ فوق الهدف';
  }

  @override
  String eatGoalLeftGrams(String progress, String diff) {
    return '$progress · يتبقى $diff غ';
  }

  @override
  String get eatNoFoodLoggedYet => 'لم يُسجَّل أي طعام بعد';

  @override
  String get eatTotals => 'الإجماليات';

  @override
  String get eatKnownTotals => 'الإجماليات المعروفة';

  @override
  String get eatNoNutritionForFood => 'لم تُدخَل قيم غذائية لهذا الطعام بعد';

  @override
  String get eatNutritionOverline => 'التغذية';

  @override
  String get eatNothingRecorded =>
      'لم يُسجَّل شيء لهذا اليوم. وهذا لا يعني أنه لم يُؤكل شيء.';

  @override
  String eatYourDailyGoal(String goals) {
    return 'هدفك اليومي: $goals';
  }

  @override
  String eatNutrientSaid(String nutrient, String value) {
    return '$nutrient $value';
  }

  @override
  String eatNutrientUnknownSaid(String nutrient) {
    return '$nutrient غير معروف';
  }

  @override
  String get eatPartialNote =>
      'بعض الأطعمة بلا قيمة لأحد العناصر الغذائية، لذا هذه مجاميع ما أدخلته، وليست إجماليات كاملة.';

  @override
  String get eatSyncPending => 'محفوظ على هذا الهاتف · المزامنة معلّقة';

  @override
  String get eatKnown => 'معروف';

  @override
  String get eatKnownSoFar => 'المعروف حتى الآن';

  @override
  String eatSaidKcal(String nutrient, String value) {
    return '$nutrient $value سعرة حرارية';
  }

  @override
  String eatSaidGrams(String nutrient, String value) {
    return '$nutrient $value غرام';
  }

  @override
  String eatSaidKnownFrom(int known, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'معروف من $known من $total طعام',
      many: 'معروف من $known من $total طعامًا',
      few: 'معروف من $known من $total أطعمة',
      two: 'معروف من $known من طعامين',
      one: 'معروف من $known من طعام واحد',
      zero: 'معروف من $known من 0 أطعمة',
    );
    return '$_temp0';
  }

  @override
  String eatSaidGoalKcal(String goal) {
    return 'الهدف $goal سعرة حرارية';
  }

  @override
  String eatSaidGoalGrams(String goal) {
    return 'الهدف $goal غرام';
  }

  @override
  String get eatListSeparator => '، ';

  @override
  String get eatCaloriesGoalBar => 'هدف السعرات';

  @override
  String get eatProteinGoalBar => 'هدف البروتين';

  @override
  String get eatOpensJournalHint => 'يفتح سجل الطعام';

  @override
  String get eatSomeValuesMissing => 'بعض القيم الغذائية ناقصة';

  @override
  String get eatNoValuesYet => 'لم تُدخَل قيم غذائية بعد';

  @override
  String get foodProblemNoName => 'أدخل ما تناولته.';

  @override
  String get foodProblemNoAmount => 'أدخل الكمية بكلماتك.';

  @override
  String get foodProblemTooLong => 'هذا النص طويل جدًا.';

  @override
  String get foodProblemNoMeal => 'اختر وجبة.';

  @override
  String get foodProblemNoQuantity =>
      'أدخل الكمية التي تناولتها، رقمًا أكبر من صفر.';

  @override
  String get foodProblemBadValues =>
      'يجب أن تكون القيم الغذائية صفرًا أو أكثر.';

  @override
  String foodProblemBadValue(String nutrient) {
    return '$nutrient: يجب أن يكون رقمًا يساوي صفرًا أو أكثر، أو يُترك فارغًا.';
  }

  @override
  String get foodProblemBadSavedName =>
      'أعطِ الطعام اسمًا لا يتجاوز 120 حرفًا.';

  @override
  String get foodSaveFailedLocal =>
      'تعذّر الحفظ على هاتفك. إدخالك لا يزال هنا. حاول مرة أخرى.';

  @override
  String get foodSavedToMine => 'حُفظ في «أطعمتي». لم يُسجَّل شيء.';

  @override
  String foodRemoveTitle(String name) {
    return 'إزالة $name؟';
  }

  @override
  String foodRemoveBody(String name, String amount, String meal, String date) {
    return 'سيُزال «$name» ($amount) فقط من $meal في $date. يبقى طعامك الآخر.';
  }

  @override
  String get foodRemoveAction => 'إزالة هذا الطعام';

  @override
  String get foodDetailsTitle => 'تفاصيل الطعام';

  @override
  String get foodEditTitle => 'تعديل الطعام';

  @override
  String get foodNewTitle => 'طعام جديد';

  @override
  String get foodYourValue => 'قيمتك';

  @override
  String get foodWhatDidYouEat => 'ماذا تناولت؟';

  @override
  String get foodNameInJournal => 'الاسم في سجلّك';

  @override
  String get foodMealLabel => 'الوجبة';

  @override
  String foodForDateTapToChange(String date) {
    return 'ليوم $date. انقر لتغيير التاريخ.';
  }

  @override
  String get foodHelpPortions => 'مساعدة في الكميات والحصص';

  @override
  String get foodFavouriteRemove => 'إزالة من المفضلة';

  @override
  String get foodFavouriteAdd => 'إضافة إلى المفضلة';

  @override
  String get foodSaveChanges => 'حفظ التغييرات';

  @override
  String get foodLogButton => 'سجّل الطعام';

  @override
  String get foodCancelKeep => 'إلغاء والإبقاء على النسخة المسجّلة';

  @override
  String get foodAmountLabel => 'الكمية';

  @override
  String get foodPortionLabel => 'الحصة';

  @override
  String get foodAddPortion => 'إضافة حصة خاصة بك';

  @override
  String get foodPortionCoach =>
      'يمكنك عدّ الحصص هنا. يظهر الوزن عندما يتوفر تحويل موثوق.';

  @override
  String get foodHowMuch => 'كم الكمية؟';

  @override
  String get foodHowMuchHelper => 'بكلماتك، مثل «200 غ» أو «شريحتان»';

  @override
  String get foodNutritionHeading => 'القيم الغذائية';

  @override
  String foodNutritionFor(String amount) {
    return 'القيم الغذائية لـ $amount';
  }

  @override
  String get foodNutritionOptional =>
      'اختياري. انقر على قيمة لإدخالها؛ الحقل الفارغ يبقى غير معروف ولا يُحتسب صفرًا أبدًا.';

  @override
  String get foodNutritionFromSource =>
      'من المصدر، لهذه الكمية. انقر على قيمة لتصحيحها؛ الحقل الفارغ يبقى غير معروف ولا يُحتسب صفرًا أبدًا.';

  @override
  String foodSourceMissing(int count, String nutrients) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'لا يقدّم هذا المصدر قيمة لـ $nutrients. تبقى غير معروفة ما لم تُدخلها.',
      many:
          'لا يقدّم هذا المصدر قيمة لـ $nutrients. تبقى غير معروفة ما لم تُدخلها.',
      few:
          'لا يقدّم هذا المصدر قيمة لـ $nutrients. تبقى غير معروفة ما لم تُدخلها.',
      two:
          'لا يقدّم هذا المصدر قيمة لـ $nutrients. تبقيان غير معروفتين ما لم تُدخلهما.',
      one:
          'لا يقدّم هذا المصدر قيمة لـ $nutrients. تبقى غير معروفة ما لم تُدخلها.',
      zero: 'لا يقدّم هذا المصدر قيمة لـ $nutrients.',
    );
    return '$_temp0';
  }

  @override
  String get foodUseSourceValues => 'استخدام قيم المصدر مجددًا';

  @override
  String get foodSaveToMine => 'الحفظ في «أطعمتي» دون تسجيل';

  @override
  String get foodShowsDetailsHint => 'يعرض تفاصيل الطعام';

  @override
  String foodSource(String credit) {
    return 'المصدر: $credit';
  }

  @override
  String get foodYourOwn => 'طعامك الخاص';

  @override
  String foodBarcode(String code) {
    return 'الرمز الشريطي $code';
  }

  @override
  String get foodYoureLogging => 'ستسجّل';

  @override
  String get foodEnergy => 'الطاقة';

  @override
  String get foodUnknownSaid => 'غير معروف';

  @override
  String foodKcalSaid(String value) {
    return '$value سعرة حرارية';
  }

  @override
  String foodGramsSaid(String value) {
    return '$value غرام';
  }

  @override
  String get foodPortionNameInvalid =>
      'سمِّ الحصة بكلمة أو كلمتين، مثل «شريحة» أو «وعاء صغير».';

  @override
  String foodPortionExists(String name) {
    return 'لهذا الطعام حصة باسم «$name» بالفعل.';
  }

  @override
  String foodPortionAmountInvalid(String name) {
    return 'أدخل مقدار حصة «$name» الواحدة، رقمًا أكبر من صفر.';
  }

  @override
  String foodPortionFor(String food) {
    return 'لـ $food فقط. لا تتغيّر قيمه الغذائية، ولا يُسجَّل شيء.';
  }

  @override
  String get foodPortionCalled => 'اسم الحصة الواحدة';

  @override
  String get foodPortionHint => 'شريحة';

  @override
  String get foodPortionHowMuch => 'كم مقدار الواحدة؟';

  @override
  String get foodAddPortionButton => 'إضافة الحصة';

  @override
  String foodNutritionBasis(String basis) {
    return 'القيم الغذائية $basis';
  }

  @override
  String foodBarcodeNotFound(String code) {
    return 'لم يُعثر على منتج للرمز الشريطي $code. يمكنك البحث عنه بالاسم أو إنشاء طعامك الخاص.';
  }

  @override
  String foodBarcodeOffline(String code) {
    return 'تعذّر البحث عن الرمز الشريطي $code الآن، ولم يُبحث عنه على هذا الهاتف من قبل. قد يكون السبب اتصال الهاتف أو الخادم. يمكنك إنشاء طعامك الخاص.';
  }

  @override
  String foodBarcodeTimeout(String code) {
    return 'استغرقت قاعدة بيانات المنتجات وقتًا طويلًا للرد على الرمز الشريطي $code. حاول مجددًا أو أنشئ طعامك الخاص.';
  }

  @override
  String get foodBarcodeRateLimited =>
      'تلقّت قاعدة بيانات المنتجات طلبات كثيرة حاليًا. حاول بعد بضع دقائق أو أنشئ طعامك الخاص.';

  @override
  String get foodBarcodeInvalid => 'هذا ليس رمزًا شريطيًا لمنتج.';

  @override
  String get foodBarcodeUnavailable =>
      'لا تستجيب قاعدة بيانات المنتجات الآن. حاول مجددًا أو أنشئ طعامك الخاص.';

  @override
  String foodBarcodeLookingUp(String code) {
    return 'جارٍ البحث عن الرمز الشريطي $code…';
  }

  @override
  String get foodSearchStillLocal =>
      'الأطعمة أعلاه من هذا الهاتف ولا تزال متاحة.';

  @override
  String get foodSearchStillScan =>
      'لا يزال بإمكانك مسح رمز شريطي أو إنشاء طعامك الخاص.';

  @override
  String get foodSearchOffline =>
      'تعذّر الوصول إلى قاعدة بيانات الأطعمة الموسّعة الآن. قد يكون السبب اتصال الهاتف أو الخادم.';

  @override
  String get foodSearchTimeout =>
      'استغرقت قاعدة بيانات الأطعمة الموسّعة وقتًا طويلًا للرد.';

  @override
  String get foodSearchRateLimited =>
      'تلقّت قاعدة بيانات الأطعمة الموسّعة طلبات كثيرة حاليًا. حاول بعد بضع دقائق.';

  @override
  String get foodSearchNotConfigured =>
      'البحث الموسّع عن الأطعمة غير مُعدّ على هذا الخادم. لا تزال الأطعمة الشائعة وأطعمتك والرموز الشريطية متاحة.';

  @override
  String get foodSearchInvalid => 'تعذّر استخدام هذا البحث. جرّب كلمات أخرى.';

  @override
  String get foodSearchUnavailable =>
      'لا تستجيب قاعدة بيانات الأطعمة الموسّعة الآن. حاول بعد قليل.';

  @override
  String get foodSearchGuide =>
      'اكتب اسم طعام، مثل «بيض» أو «أرز»، أو اختر فئة. يُعثر على الأطعمة اليومية وأطعمتك دون اتصال.';

  @override
  String get foodGroupYours => 'أطعمتك';

  @override
  String get foodGroupCommon => 'الأطعمة الشائعة';

  @override
  String get foodGroupMore => 'أطعمة أخرى';

  @override
  String foodCategoryEmpty(String category) {
    return 'لا توجد أطعمة شائعة ضمن $category.';
  }

  @override
  String foodCategoryNoMatch(String category, String query) {
    return 'لا يوجد طعام شائع في $category يطابق «$query».';
  }

  @override
  String get foodCategoryNote =>
      'الفئات للأطعمة الشائعة فقط. اختر «الكل» لتضمين أطعمتك وقاعدة البيانات الموسّعة.';

  @override
  String get foodSearchBusy => 'جارٍ البحث عن أطعمة أخرى…';

  @override
  String foodSearchLocalEmpty(String query) {
    return 'لا شيء على هذا الهاتف يطابق «$query».';
  }

  @override
  String get foodSearchMore => 'البحث عن مزيد من الأطعمة';

  @override
  String foodSearchMoreSubtitle(String query) {
    return 'البحث عن «$query» في USDA FoodData Central';
  }

  @override
  String foodSearchNoOthers(String query) {
    return 'لا تحتوي قاعدة البيانات الموسّعة على أطعمة أخرى لـ «$query».';
  }

  @override
  String foodSearchNoneFound(String query) {
    return 'لم يُعثر على أطعمة لـ «$query». جرّب كلمات أخرى أو امسح الرمز الشريطي أو أنشئ طعامك الخاص.';
  }

  @override
  String foodSearchNoneNonEnglish(String query) {
    return 'تبحث قاعدة البيانات الموسّعة بالإنجليزية ولم تجد شيئًا لـ «$query». جرّب الاسم الإنجليزي أو امسح الرمز الشريطي أو أدخله بنفسك.';
  }

  @override
  String get foodSearchCredit =>
      'من USDA FoodData Central، بالإنجليزية، ومعظمها أطعمة تُباع أو تُؤكل في الولايات المتحدة. القيم كما نُشرت وقد تختلف عن عبوتك.';

  @override
  String get foodRecentEmptyTitle => 'لم يُسجَّل شيء بعد';

  @override
  String get foodRecentEmptyBody =>
      'تظهر هنا الأطعمة التي تسجّلها، جاهزة لتسجيلها مجددًا.';

  @override
  String get foodFavouritesEmptyTitle => 'لا مفضلات بعد';

  @override
  String get foodFavouritesEmptyBody =>
      'ضع نجمة على الطعام في صفحة الكمية للاحتفاظ به هنا.';

  @override
  String get foodMineEmptyTitle => 'لا أطعمة خاصة بك بعد';

  @override
  String get foodMineEmptyBody =>
      'أنشئ طعامك الخاص أدناه، أو استخدم «الحفظ في أطعمتي» في صفحة كمية أي طعام.';

  @override
  String foodListNoMatch(String query) {
    return 'لا شيء في هذه القائمة يطابق «$query».';
  }

  @override
  String get foodAddTitle => 'إضافة طعام';

  @override
  String get foodHelpSearch => 'مساعدة في العثور على طعام';

  @override
  String get foodSearchHint => 'ابحث عن الأطعمة';

  @override
  String get foodSearchClear => 'مسح البحث';

  @override
  String get foodScanBarcode => 'مسح الرمز الشريطي';

  @override
  String get foodScopeSearch => 'بحث';

  @override
  String get foodScopeRecent => 'الأخيرة';

  @override
  String get foodScopeFavourites => 'المفضلة';

  @override
  String get foodScopeMine => 'أطعمتي';

  @override
  String get foodSearchCoach =>
      'ابحث عن طعام أو امسح رمزًا شريطيًا أو أدخل طعامك. «الأخيرة» و«المفضلة» و«أطعمتي» على بُعد نقرة.';

  @override
  String get foodManualTitle => 'أدخله بنفسك';

  @override
  String get foodManualSubtitle => 'لم تجده؟ أنشئ طعامك الخاص';

  @override
  String get foodFooter => 'اختر طعامًا لمراجعة الكمية قبل التسجيل.';

  @override
  String get foodCredits =>
      'الأطعمة الشائعة والبحث الموسّع: USDA FoodData Central. الرموز الشريطية: Open Food Facts (Open Database License).';

  @override
  String get foodChangeMeal => 'تغيير الوجبة';

  @override
  String get foodRowProteinUnknown => '— بروتين';

  @override
  String get foodChooseHint => 'اختيار هذا الطعام';

  @override
  String get barcodeTypedInvalid =>
      'يتكوّن الرمز الشريطي من 6 إلى 14 رقمًا، كما هي مطبوعة تحت الخطوط.';

  @override
  String get barcodeTitle => 'مسح رمز شريطي';

  @override
  String get barcodeHold => 'ضع الرمز الشريطي الموجود على العبوة داخل الإطار.';

  @override
  String get barcodeLookUp => 'البحث عن هذا الرمز الشريطي';

  @override
  String get barcodeCameraRefused =>
      'لا يُسمح لـ GoHard باستخدام الكاميرا، لذا لا يمكنه المسح. يمكنك السماح بذلك من إعدادات الهاتف، أو كتابة الرمز الشريطي أدناه.';

  @override
  String get barcodeCameraUnavailable =>
      'لا يمكن استخدام الكاميرا على هذا الهاتف الآن. يمكنك كتابة الرمز الشريطي أدناه.';

  @override
  String get barcodeOrType => 'أو اكتب الرمز الشريطي';

  @override
  String get barcodeDigitsLabel => 'أرقام الرمز الشريطي';

  @override
  String get barcodeCameraStarting => 'جارٍ تشغيل الكاميرا';

  @override
  String get barcodeTorchOff => 'إطفاء الضوء';

  @override
  String get barcodeTorchOn => 'تشغيل الضوء';

  @override
  String get eatHelpTitle => 'سجل طعامك';

  @override
  String get eatHelpBody =>
      'أضف الطعام تحت وجبة: ابحث أو امسح رمزًا شريطيًا أو أدخل طعامك. تجمع الإجماليات ما سجّلته فقط. تُحدَّد أهدافك اليومية من الملخص هنا أو في «اليوم» أو في «حسابي». تُحفظ الأطعمة التي تتناولها مرارًا في «إضافة طعام»: «المفضلة» هي الأطعمة التي وضعت عليها نجمة في صفحة الكمية؛ و«أطعمتي» هي الأطعمة التي كتبتها أو صحّحتها بنفسك. اختيار أحدها يفتح كميته فقط: لا يُسجَّل شيء حتى تؤكده.';

  @override
  String get eatOpenFavourites => 'فتح المفضلة';

  @override
  String get eatOpenMine => 'فتح أطعمتي';

  @override
  String get eatHintHistory =>
      'وجباتك ومياهك السابقة، حسب اليوم والأسبوع والشهر، موجودة في «السجل والاتجاهات».';

  @override
  String get eatHintSavedNew =>
      'تتناول الأطعمة نفسها كثيرًا؟ انقر على النجمة في صفحة كمية الطعام وسيبقى في «المفضلة» ضمن «إضافة طعام».';

  @override
  String get eatHintFavourites =>
      'أطعمتك المفضلة على بُعد نقرة. اختر واحدًا وراجع الكمية ثم سجّله.';

  @override
  String get eatHintMine =>
      'الأطعمة التي حفظتها في «أطعمتي». اختر واحدًا وراجع الكمية ثم سجّله.';

  @override
  String get eatSayGoalWater =>
      'سجّل وجبة أو بعض الماء وشاهد حصيلة يومك مقارنةً بأهدافك.';

  @override
  String get eatSayGoal => 'سجّل وجبة وشاهد حصيلة يومك مقارنةً بأهدافك.';

  @override
  String get eatSayNoGoalWater =>
      'سجّل وجبة أو بعض الماء، أو حدّد أهدافك اليومية.';

  @override
  String get eatSayNoGoal => 'سجّل وجبة، أو حدّد أهدافك اليومية.';

  @override
  String eatMacroProtein(String value) {
    return 'بروتين $value غ';
  }

  @override
  String eatMacroCarbs(String value) {
    return 'كربوهيدرات $value غ';
  }

  @override
  String eatMacroFat(String value) {
    return 'دهون $value غ';
  }

  @override
  String get eatNoNutritionEntered => 'لم تُدخَل قيم غذائية';

  @override
  String get eatNeedsReview => 'بحاجة إلى مراجعة';

  @override
  String get eatSyncPendingShort => 'المزامنة معلّقة';

  @override
  String get eatCaloriesUnknown => 'السعرات غير معروفة';

  @override
  String eatKcalKnown(String value) {
    return '$value سعرة معروفة';
  }

  @override
  String get eatHelpLabel => 'مساعدة في سجل طعامك';

  @override
  String eatHelpFrom(String coach) {
    return 'مساعدة في سجل طعامك، من $coach';
  }

  @override
  String get eatPreviousDay => 'اليوم السابق';

  @override
  String get eatNextDay => 'اليوم التالي';

  @override
  String get eatHistoryTrends => 'السجل والاتجاهات';

  @override
  String get eatBackToToday => 'العودة إلى اليوم';

  @override
  String get eatJournalReadError =>
      'تعذّرت قراءة سجل طعامك من هذا الهاتف. اسحب للأسفل للمحاولة مجددًا.';

  @override
  String get eatJournalLoading => 'جارٍ تحميل سجلّك…';

  @override
  String get eatTodaysMeals => 'وجبات اليوم';

  @override
  String get eatMeals => 'الوجبات';

  @override
  String eatAddFoodToMeal(String meal) {
    String _temp0 = intl.Intl.selectLogic(meal, {
      'Breakfast': 'إضافة طعام إلى الفطور',
      'Lunch': 'إضافة طعام إلى الغداء',
      'Dinner': 'إضافة طعام إلى العشاء',
      'Snack': 'إضافة طعام إلى الوجبات الخفيفة',
      'other': 'إضافة طعام',
    });
    return '$_temp0';
  }

  @override
  String get eatAddFood => 'إضافة طعام';

  @override
  String get eatOnlyLoggedNote =>
      'يظهر هنا فقط الطعام الذي سجّلته على أنه أُكل.';

  @override
  String trendsFoodCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count طعام',
      many: '$count طعامًا',
      few: '$count أطعمة',
      two: 'طعامان',
      one: 'طعام واحد',
      zero: '0 طعام',
    );
    return '$_temp0';
  }

  @override
  String get trendsFuture => 'قادم';

  @override
  String get trendsNoFoodLogged => 'لم يُسجَّل طعام';

  @override
  String trendsDayUnknown(String metric, String foods) {
    return '$metric غير مُدخلة · سُجِّل $foods';
  }

  @override
  String trendsDayPartial(
    String amount,
    int unknown,
    String foods,
    String noun,
  ) {
    return '$amount معروفة · $unknown من $foods بلا قيم $noun';
  }

  @override
  String trendsDayZero(String amount) {
    return '$amount مسجّلة';
  }

  @override
  String get trendsNounCalorie => 'السعرات';

  @override
  String get trendsNounProtein => 'البروتين';

  @override
  String get trendsNounCarb => 'الكربوهيدرات';

  @override
  String get trendsNounFat => 'الدهون';

  @override
  String get trendsNounWater => 'الماء';

  @override
  String get trendsHelpBody =>
      'كل عمود هو إجمالي ما سُجِّل في يوم واحد. انقر أو اسحب على الرسم لاختيار يوم، ثم يفتح «عرض اليوم» وجباته ومياهه. الشرطة تعني أنه لم يُسجَّل شيء ذلك اليوم؛ وعلامة الاستفهام تعني أن أطعمة سُجِّلت بلا هذه القيمة؛ والنجمة تعني أن بعض الأطعمة بلا قيمة، فالمجموع هو المعروف. تستخدم المتوسطات الأيام ذات القيمة المعروفة فقط.';

  @override
  String get trendsHelpLabel => 'مساعدة في «السجل والاتجاهات»';

  @override
  String get trendsCoachSay => 'انقر على يوم لترى ما سجّلته.';

  @override
  String get trendsWeek => 'أسبوع';

  @override
  String get trendsMonth => 'شهر';

  @override
  String get trendsChooseDay => 'اختر يومًا';

  @override
  String get trendsWaterReadError => 'تعذّرت قراءة بيانات الماء من هذا الهاتف.';

  @override
  String get trendsFoodReadError => 'تعذّرت قراءة سجل طعامك من هذا الهاتف.';

  @override
  String get trendsReading => 'جارٍ قراءة سجلّك على هذا الهاتف…';

  @override
  String trendsByDay(String metric) {
    return '$metric حسب اليوم';
  }

  @override
  String get trendsLegendNotLogged => 'غير مسجّل';

  @override
  String get trendsLegendNotEntered => 'غير مُدخل';

  @override
  String get trendsLegendPartial => 'بعض القيم ناقصة';

  @override
  String get trendsLegendZero => 'صفر مسجّل';

  @override
  String get trendsDaysInPeriod => 'أيام هذه الفترة';

  @override
  String get trendsCalendar => 'التقويم';

  @override
  String get trendsCalendarSaid => 'التقويم وكل الأيام التي فيها إدخالات';

  @override
  String get trendsFoodErrorWaterShown =>
      'تعذّرت قراءة الطعام من هذا الهاتف؛ يُعرض الماء.';

  @override
  String get trendsWaterErrorFoodShown =>
      'تعذّرت قراءة الماء من هذا الهاتف؛ يُعرض الطعام.';

  @override
  String trendsFoodsLogged(String foods) {
    return 'سُجِّل $foods';
  }

  @override
  String get trendsFootnote =>
      'تجمع الإجماليات ما سُجِّل فقط. اليوم الذي لم يُسجَّل فيه شيء، أو الطعام بلا قيمة، لا يُحتسب صفرًا أبدًا. لا تظهر الأهداف هنا: لم تُحفظ أهداف الأيام السابقة.';

  @override
  String trendsWeekSoFar(String range) {
    return 'هذا الأسبوع حتى الآن · $range';
  }

  @override
  String trendsMonthToDate(String range) {
    return 'الشهر حتى اليوم · $range';
  }

  @override
  String get trendsPreviousWeek => 'الأسبوع السابق';

  @override
  String get trendsPreviousMonth => 'الشهر السابق';

  @override
  String get trendsNextWeek => 'الأسبوع التالي';

  @override
  String get trendsNextMonth => 'الشهر التالي';

  @override
  String trendsPeriodSaid(String period) {
    return 'اختر يومًا. المعروض: $period';
  }

  @override
  String trendsPeriodSaidSub(String period, String sub) {
    return 'اختر يومًا. المعروض: $period، $sub';
  }

  @override
  String get trendsThisWeek => 'هذا الأسبوع';

  @override
  String get trendsThisMonth => 'هذا الشهر';

  @override
  String trendsKnownLogged(String metric) {
    return '$metric المعروفة المسجّلة';
  }

  @override
  String trendsLogged(String metric) {
    return '$metric المسجّلة';
  }

  @override
  String trendsNoValues(String noun) {
    return 'لا قيم $noun';
  }

  @override
  String trendsCoverage(int known, int elapsed, String noun) {
    String _temp0 = intl.Intl.pluralLogic(
      elapsed,
      locale: localeName,
      other: '$known من $elapsed يوم بقيم $noun',
      many: '$known من $elapsed يومًا بقيم $noun',
      few: '$known من $elapsed أيام بقيم $noun',
      two: '$known من يومين بقيم $noun',
      one: '$known من يوم واحد بقيم $noun',
      zero: '$known من 0 يوم بقيم $noun',
    );
    return '$_temp0';
  }

  @override
  String trendsCoverageSoFar(int known, int elapsed, String noun) {
    String _temp0 = intl.Intl.pluralLogic(
      elapsed,
      locale: localeName,
      other: '$known من $elapsed يوم بقيم $noun حتى الآن',
      many: '$known من $elapsed يومًا بقيم $noun حتى الآن',
      few: '$known من $elapsed أيام بقيم $noun حتى الآن',
      two: '$known من يومين بقيم $noun حتى الآن',
      one: '$known من يوم واحد بقيم $noun حتى الآن',
      zero: '$known من 0 يوم بقيم $noun حتى الآن',
    );
    return '$_temp0';
  }

  @override
  String trendsCoverageWater(int known, int elapsed) {
    String _temp0 = intl.Intl.pluralLogic(
      elapsed,
      locale: localeName,
      other: '$known من $elapsed يوم سُجِّل فيها ماء',
      many: '$known من $elapsed يومًا سُجِّل فيها ماء',
      few: '$known من $elapsed أيام سُجِّل فيها ماء',
      two: '$known من يومين سُجِّل فيهما ماء',
      one: '$known من يوم واحد سُجِّل فيه ماء',
      zero: '$known من 0 يوم سُجِّل فيها ماء',
    );
    return '$_temp0';
  }

  @override
  String trendsCoverageWaterSoFar(int known, int elapsed) {
    String _temp0 = intl.Intl.pluralLogic(
      elapsed,
      locale: localeName,
      other: '$known من $elapsed يوم سُجِّل فيها ماء حتى الآن',
      many: '$known من $elapsed يومًا سُجِّل فيها ماء حتى الآن',
      few: '$known من $elapsed أيام سُجِّل فيها ماء حتى الآن',
      two: '$known من يومين سُجِّل فيهما ماء حتى الآن',
      one: '$known من يوم واحد سُجِّل فيه ماء حتى الآن',
      zero: '$known من 0 يوم سُجِّل فيها ماء حتى الآن',
    );
    return '$_temp0';
  }

  @override
  String trendsDaysWithFood(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم سُجِّل فيها طعام',
      many: '$count يومًا سُجِّل فيها طعام',
      few: '$count أيام سُجِّل فيها طعام',
      two: 'يومان سُجِّل فيهما طعام',
      one: 'يوم واحد سُجِّل فيه طعام',
      zero: '0 يوم سُجِّل فيه طعام',
    );
    return '$_temp0';
  }

  @override
  String trendsDaysWithoutValue(int count, String noun) {
    return '$count بلا أي قيمة $noun';
  }

  @override
  String get trendsAverageKnown => 'المتوسط اليومي، القيم المعروفة';

  @override
  String get trendsAverage => 'المتوسط اليومي';

  @override
  String trendsAcross(int count, String noun) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'على $count يوم بقيم $noun',
      many: 'على $count يومًا بقيم $noun',
      few: 'على $count أيام بقيم $noun',
      two: 'على اليومين بقيم $noun',
      one: 'على اليوم الوحيد بقيم $noun',
      zero: 'على 0 يوم بقيم $noun',
    );
    return '$_temp0';
  }

  @override
  String trendsAcrossWater(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'على $count يوم سُجِّل فيها ماء',
      many: 'على $count يومًا سُجِّل فيها ماء',
      few: 'على $count أيام سُجِّل فيها ماء',
      two: 'على اليومين اللذين سُجِّل فيهما ماء',
      one: 'على اليوم الوحيد الذي سُجِّل فيه ماء',
      zero: 'على 0 يوم سُجِّل فيه ماء',
    );
    return '$_temp0';
  }

  @override
  String trendsPartialNote(int count, String noun) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'يشمل $count يوم فيها أطعمة بلا قيمة $noun: يُضاف الجزء المعروف فقط.',
      many:
          'يشمل $count يومًا فيها أطعمة بلا قيمة $noun: يُضاف الجزء المعروف فقط.',
      few:
          'يشمل $count أيام فيها أطعمة بلا قيمة $noun: يُضاف الجزء المعروف فقط.',
      two: 'يشمل يومين فيهما أطعمة بلا قيمة $noun: يُضاف الجزء المعروف فقط.',
      one:
          'يشمل يومًا واحدًا فيه أطعمة بلا قيمة $noun: يُضاف الجزء المعروف فقط.',
      zero: 'يشمل 0 يوم فيه أطعمة بلا قيمة $noun: يُضاف الجزء المعروف فقط.',
    );
    return '$_temp0';
  }

  @override
  String get trendsViewDay => 'عرض اليوم';

  @override
  String trendsViewDaySaid(String date) {
    return 'عرض $date';
  }

  @override
  String trendsChartSaid(String metric, String period, int known, int elapsed) {
    return '$metric حسب اليوم، $period: $known من $elapsed بقيمة. كل يوم موجود في قائمة الأيام أدناه.';
  }

  @override
  String get trendsCaloriesUnknownLower => 'السعرات غير معروفة';

  @override
  String get trendsCalendarSubtitle => 'وجباتك ومياهك، حسب اليوم';

  @override
  String get trendsCalendarCaption => 'اختر يومًا لترى ما سُجِّل فيه.';

  @override
  String get trendsDaysWithEntries => 'أيام فيها إدخالات';

  @override
  String get trendsNothingYetBody =>
      'تظهر هنا الأيام التي تسجّل فيها طعامًا أو ماءً.';

  @override
  String get accountErrorInvalidCredentials =>
      'لا يطابق هذا البريد الإلكتروني وكلمة المرور أي حساب.';

  @override
  String get accountErrorEmailInUse =>
      'يوجد حساب بهذا البريد الإلكتروني بالفعل. سجّل الدخول بدلًا من ذلك.';

  @override
  String get accountErrorWeakPassword =>
      'استخدم كلمة مرور من 15 حرفًا على الأقل.';

  @override
  String get accountErrorInvalidEmail => 'أدخل عنوان بريد إلكتروني صالحًا.';

  @override
  String get accountErrorInvalidDisplayName =>
      'أدخل الاسم الذي تريد رؤيته في التطبيق.';

  @override
  String get accountErrorWrongPassword =>
      'كلمة المرور هذه غير صحيحة. لم يُحذف حسابك.';

  @override
  String get accountErrorTooManyAttempts =>
      'محاولات كثيرة جدًا. انتظر دقيقة ثم حاول مرة أخرى.';

  @override
  String get accountErrorUnreachable =>
      'تعذّر الوصول إلى الخادم. تحقّق من اتصالك وحاول مرة أخرى؛ لم يُفقد شيء مما كتبته.';

  @override
  String get accountErrorUnreachableDelete =>
      'تعذّر الوصول إلى الخادم، لذا لم يُحذف شيء. يتطلّب حذف الحساب اتصالًا.';

  @override
  String get accountErrorNameLength => 'أدخل اسمًا من 1 إلى 80 حرفًا.';

  @override
  String get accountErrorCalorieGoal =>
      'هدف السعرات عدد صحيح من 500 إلى 10,000، أو يُترك فارغًا.';

  @override
  String get accountErrorProteinGoal =>
      'هدف البروتين عدد صحيح من 10 إلى 500 غرام، أو يُترك فارغًا.';

  @override
  String get accountErrorWaterGoal =>
      'هدف الماء من 100 مل إلى 10 ل (نحو 3.4 إلى 338 أونصة سائلة)، أو يُترك فارغًا.';

  @override
  String get reminderNotificationTitle => 'حصة تدريبية اليوم';

  @override
  String get reminderChannelName => 'تذكيرات الحصص التدريبية';

  @override
  String get reminderChannelDescription =>
      'تذكير في الأيام التي فيها حصة تدريبية مخطط لها';

  @override
  String get permissionAllowed => 'مسموح';

  @override
  String get permissionNotAllowed => 'غير مسموح';

  @override
  String get permissionNotAskedOrNotAllowed => 'لم يُطلب بعد، أو غير مسموح';

  @override
  String get permissionUnknown => 'غير معروف';

  @override
  String get permissionsSubtitle => 'يتحكّم فيها الهاتف، لا إعدادات GoHard.';

  @override
  String get permissionLocation => 'الموقع';

  @override
  String get permissionLocationExplanation =>
      'تقريبي، أثناء فتح التطبيق: الطقس التلقائي في «اليوم» والجري بنظام GPS. يُطلب عند استخدام أحدهما.';

  @override
  String get permissionCamera => 'الكاميرا';

  @override
  String get permissionCameraExplanation =>
      'لمسح الرموز الشريطية فقط. يُطلب عند أول مسح؛ ويوضّح الماسح ذلك إن لم يكن مسموحًا.';

  @override
  String get permissionNotifications => 'الإشعارات';

  @override
  String get permissionNotificationsExplanation =>
      'لتذكيرات الحصص التدريبية فقط. تُطلب عند تفعيلها في «حسابي».';

  @override
  String get permissionsFootnote =>
      'يطلب GoHard كل إذن فقط عند استخدام الميزة التي تحتاجه. للسماح بشيء رفضته أو أوقفه بعد السماح به، استخدم إعدادات الهاتف. تفضيلات التطبيق مثل الوحدات والمظهر وخلفية «اليوم» موجودة في «حسابي».';

  @override
  String get permissionsOpenSettings => 'فتح إعدادات الهاتف';

  @override
  String get syncRemoved => 'محذوف';

  @override
  String syncFoodLine(String name, String amount, String meal, String date) {
    String _temp0 = intl.Intl.selectLogic(meal, {
      'breakfast': 'الفطور',
      'lunch': 'الغداء',
      'dinner': 'العشاء',
      'snack': 'وجبة خفيفة',
      'other': '$meal',
    });
    return '$name · $amount · $_temp0 · $date';
  }

  @override
  String syncFoodLineCalories(
    String name,
    String amount,
    String meal,
    String date,
    String calories,
  ) {
    String _temp0 = intl.Intl.selectLogic(meal, {
      'breakfast': 'الفطور',
      'lunch': 'الغداء',
      'dinner': 'العشاء',
      'snack': 'وجبة خفيفة',
      'other': '$meal',
    });
    return '$name · $amount · $_temp0 · $date · $calories سعرة';
  }

  @override
  String syncWorkoutInProgress(String title, String date) {
    return '$title · $date · قيد التنفيذ';
  }

  @override
  String syncWorkoutFinished(String title, String date, String outcome) {
    String _temp0 = intl.Intl.selectLogic(outcome, {
      'full': 'كاملة',
      'partial': 'جزئية',
      'other': '$outcome',
    });
    return '$title · $date · منتهية ($_temp0)';
  }

  @override
  String get syncNoPrimaryPlan => 'لا توجد خطة رئيسية';

  @override
  String get syncPrimaryPlanSet => 'تم تعيين خطة رئيسية';

  @override
  String syncPlanLine(String title, String lifecycle) {
    String _temp0 = intl.Intl.selectLogic(lifecycle, {
      'draft': 'مسودة',
      'active': 'نشطة',
      'paused': 'متوقفة مؤقتًا',
      'closed': 'مغلقة',
      'other': '$lifecycle',
    });
    return '$title · $_temp0';
  }

  @override
  String syncProfileLine(String name, String appearance, String unit) {
    String _temp0 = intl.Intl.selectLogic(appearance, {
      'light': 'فاتح',
      'dark': 'داكن',
      'system': 'النظام',
      'other': '$appearance',
    });
    return '$name · $_temp0 · $unit';
  }

  @override
  String syncGoalCalories(String value) {
    return 'الهدف $value سعرة';
  }

  @override
  String syncGoalProtein(String value) {
    return 'الهدف $value غ بروتين';
  }

  @override
  String syncGoalWater(String value) {
    return 'الهدف $value مل ماء';
  }

  @override
  String get syncFoodFallback => 'طعام';

  @override
  String get syncFavourite => 'مفضّل';

  @override
  String syncRunLine(String date) {
    return 'جري · $date';
  }

  @override
  String syncWaterLine(String amount, String date) {
    return 'ماء · $amount · $date';
  }

  @override
  String syncWeeklyGoalsLine(String date, String workouts, String runs) {
    return 'الأهداف الأسبوعية من $date: $workouts · $runs';
  }

  @override
  String get syncNoWorkoutTarget => 'لا هدف للحصص';

  @override
  String syncWorkoutsTarget(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حصة',
      many: '$count حصة',
      few: '$count حصص',
      two: 'حصتان',
      one: 'حصة واحدة',
      zero: '0 حصص',
    );
    return '$_temp0';
  }

  @override
  String get syncNoRunWalkTarget => 'لا هدف للجري / المشي';

  @override
  String syncRunWalkTarget(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مرة جري أو مشي',
      many: '$count مرة جري أو مشي',
      few: '$count مرات جري أو مشي',
      two: 'مرتا جري أو مشي',
      one: 'مرة جري أو مشي واحدة',
      zero: '0 مرات جري أو مشي',
    );
    return '$_temp0';
  }

  @override
  String get syncNoIncrement => 'لا زيادة في الوزن';

  @override
  String syncIncrement(String load) {
    return 'زيادة الوزن $load';
  }

  @override
  String get syncKindSet => 'مجموعة مسجّلة';

  @override
  String get syncKindFood => 'إدخال طعام';

  @override
  String get syncKindWorkout => 'حصة تدريبية';

  @override
  String get syncKindContext => 'تغيير الخطة الرئيسية';

  @override
  String get syncKindPlan => 'تغيير الخطة';

  @override
  String get syncKindProfile => 'الملف الشخصي';

  @override
  String get syncKindRun => 'جري';

  @override
  String get syncKindMetric => 'قياس الجسم';

  @override
  String get syncKindProposal => 'تغيير مقترح';

  @override
  String get syncKindSavedFood => 'طعام محفوظ';

  @override
  String get syncKindWater => 'إدخال ماء';

  @override
  String get syncKindWeeklyGoal => 'الأهداف الأسبوعية';

  @override
  String get syncKindIncrement => 'زيادة الوزن';

  @override
  String get syncReasonRevisionConflict =>
      'تم تغييره في مكان آخر أيضًا، لذا تختلف النسختان.';

  @override
  String get syncReasonDeleted => 'حُذف في مكان آخر بعد أن غيّرته هنا.';

  @override
  String get syncReasonOccasionNotEligible =>
      'تم بدء هذه الحصة المخطط لها أو تسجيلها أو تخطيها في مكان آخر.';

  @override
  String get syncReasonAlreadyFinished =>
      'انتهت هذه الحصة التدريبية بالفعل في مكان آخر.';

  @override
  String get syncReasonSetMismatch =>
      'تختلف المجموعات في حسابك عن المجموعات على هذا الهاتف.';

  @override
  String get syncReasonPlansChanged =>
      'تغيّرت خططك في مكان آخر قبل أن يصل هذا إلى حسابك.';

  @override
  String get syncReasonNotFound => 'لم يعد موجودًا في حسابك.';

  @override
  String syncReasonOther(String code) {
    return 'لم يقبله حسابك ($code).';
  }

  @override
  String get syncReasonUnknownCode => 'سبب غير معروف';

  @override
  String get syncReviewTitle => 'مراجعة التغييرات المحفوظة';

  @override
  String get syncReviewIntro =>
      'كل ما يلي محفوظ على هذا الهاتف. كل عنصر يختلف عن حسابك أو لم يُقبل، لذا يحتاج إلى قرارك.';

  @override
  String get syncReviewEmptyTitle => 'لا شيء للمراجعة';

  @override
  String get syncReviewEmptyBody =>
      'كل تغييراتك إما متزامنة أو تنتظر المزامنة بشكل طبيعي.';

  @override
  String get syncOnThisPhone => 'على هذا الهاتف';

  @override
  String get syncInYourAccount => 'في حسابك';

  @override
  String get syncKeepLocal => 'الإبقاء على النسخة الموجودة على هذا الهاتف';

  @override
  String get syncKeptLocal => 'تم الإبقاء على نسختك. نسخة الحساب محفوظة كبديل.';

  @override
  String get syncKeepManual => 'الإبقاء عليها كحصة تدريبية يدوية';

  @override
  String get syncKeptManual =>
      'تم الإبقاء عليها كتدريب يدوي. كل مجموعة مسجّلة محفوظة.';

  @override
  String get syncUseServer => 'استخدام نسخة الحساب';

  @override
  String get syncUsingServer => 'يتم استخدام نسخة الحساب. نسختك محفوظة كبديل.';

  @override
  String get syncRemoveFromPhone => 'إزالته من هذا الهاتف';

  @override
  String get syncDropChange => 'تجاهل تغييري';

  @override
  String get syncRemoveConfirmTitle => 'إزالته من هذا الهاتف؟';

  @override
  String get syncRemoveConfirmBody =>
      'لم يقبل حسابك هذا مطلقًا، لذا فإن إزالته هنا تزيله تمامًا.';

  @override
  String get syncRemoveConfirmBodyWorkout =>
      'لم يقبل حسابك هذا مطلقًا، لذا فإن إزالته هنا تزيله تمامًا، بما في ذلك مجموعاته المسجّلة.';

  @override
  String get syncDropConfirmTitle => 'تجاهل هذا التغيير؟';

  @override
  String get syncDropConfirmBody => 'ستظهر نسخة حسابك مرة أخرى.';

  @override
  String get syncDiscardDone => 'تم.';

  @override
  String get meRemindersNotAllowed =>
      'الإشعارات غير مسموح بها لـ GoHard، لذا تبقى التذكيرات متوقفة. يمكنك السماح بها في إعدادات الهاتف.';

  @override
  String get mePrefNotSaved => 'تعذّر حفظ هذا التفضيل على هذا الهاتف.';

  @override
  String get meUnits => 'الوحدات';

  @override
  String get meUnitKilograms => 'كيلوغرامات';

  @override
  String get meUnitPounds => 'أرطال';

  @override
  String get meUnitsLoadNote =>
      'يغيّر طريقة إدخال الأوزان وعرضها. يُخزَّن تدريبك المسجّل بالكيلوغرام ولا يُعاد كتابته أبدًا. يُعرض الوقت بالدقائق والثواني.';

  @override
  String get meUnitBodyKg => 'وزن الجسم بالكيلوغرام';

  @override
  String get meUnitBodyLb => 'وزن الجسم بالرطل';

  @override
  String get meUnitBodyCm => 'القياسات بالسنتيمتر (سم)';

  @override
  String get meUnitBodyIn => 'القياسات بالبوصة (بوصة)';

  @override
  String get meUnitsBodyNote =>
      'لتقدّم الجسم فقط: تبقى وحدة الأوزان كما هي. يُخزَّن بالكيلوغرام والسنتيمتر، لذا لا يغيّر هذا أي قياس. يُضبط على هذا الهاتف لهذا الحساب.';

  @override
  String get meUnitsTemperature => 'درجة الحرارة';

  @override
  String get meUnitFahrenheit => 'فهرنهايت (°F)';

  @override
  String get meUnitCelsius => 'مئوية (°C)';

  @override
  String get meUnitsTemperatureNote =>
      'للطقس في «اليوم». يُضبط على هذا الهاتف.';

  @override
  String get meUnitsWater => 'الماء';

  @override
  String get meUnitMillilitres => 'مليلتر (مل، ل)';

  @override
  String get meUnitFluidOunces => 'أونصات سائلة أمريكية (fl oz)';

  @override
  String get meUnitsWaterNote =>
      'للماء الذي تسجّله. يُخزَّن بالمليلتر، لذا لا يغيّر هذا أي كمية. الأونصة السائلة حجم وليست وزنًا. يُضبط على هذا الهاتف.';

  @override
  String get meUnitsRunWalk => 'الجري / المشي';

  @override
  String get meUnitKilometres => 'كيلومترات (د/كم، كم/س، م)';

  @override
  String get meUnitMiles => 'أميال (د/ميل، ميل/س، قدم)';

  @override
  String get meUnitsRunWalkNote =>
      'المسافة والوتيرة والسرعة والارتفاع. تُخزَّن المسارات بالمتر، لذا لا يغيّر هذا أي تسجيل. يُضبط على هذا الهاتف.';

  @override
  String get meSyncNeedsReview => 'يحتاج إلى مراجعة';

  @override
  String meSyncNeedsReviewDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count تغيير محفوظ يحتاج إلى مراجعة. لم يُفقد شيء. انقر للمراجعة.',
      many:
          '$count تغييرًا محفوظًا يحتاج إلى مراجعة. لم يُفقد شيء. انقر للمراجعة.',
      few:
          '$count تغييرات محفوظة تحتاج إلى مراجعة. لم يُفقد شيء. انقر للمراجعة.',
      two: 'تغييران محفوظان يحتاجان إلى مراجعة. لم يُفقد شيء. انقر للمراجعة.',
      one: 'تغيير محفوظ واحد يحتاج إلى مراجعة. لم يُفقد شيء. انقر للمراجعة.',
      zero: 'لا تغييرات تحتاج إلى مراجعة.',
    );
    return '$_temp0';
  }

  @override
  String get meSyncNotSynced => 'غير متزامن';

  @override
  String get meSyncUnreachableDetail =>
      'تتعذّر المزامنة الآن · انقر للمحاولة مرة أخرى';

  @override
  String meSyncUnreachableWaitingDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count تغيير بانتظار المزامنة، محفوظة على هذا الهاتف.\nتتعذّر المزامنة الآن · انقر للمحاولة مرة أخرى',
      many:
          '$count تغييرًا بانتظار المزامنة، محفوظة على هذا الهاتف.\nتتعذّر المزامنة الآن · انقر للمحاولة مرة أخرى',
      few:
          '$count تغييرات بانتظار المزامنة، محفوظة على هذا الهاتف.\nتتعذّر المزامنة الآن · انقر للمحاولة مرة أخرى',
      two: 'تغييران بانتظار المزامنة، محفوظان على هذا الهاتف.\nتتعذّر المزامنة الآن · انقر للمحاولة مرة أخرى',
      one: 'تغيير واحد بانتظار المزامنة، محفوظ على هذا الهاتف.\nتتعذّر المزامنة الآن · انقر للمحاولة مرة أخرى',
      zero: 'لا تغييرات بانتظار المزامنة.\nتتعذّر المزامنة الآن · انقر للمحاولة مرة أخرى',
    );
    return '$_temp0';
  }

  @override
  String get meSyncWaiting => 'قيد الانتظار';

  @override
  String meSyncWaitingDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تغيير محفوظ على هذا الهاتف، بانتظار المزامنة',
      many: '$count تغييرًا محفوظًا على هذا الهاتف، بانتظار المزامنة',
      few: '$count تغييرات محفوظة على هذا الهاتف، بانتظار المزامنة',
      two: 'تغييران محفوظان على هذا الهاتف، بانتظار المزامنة',
      one: 'تغيير واحد محفوظ على هذا الهاتف، بانتظار المزامنة',
      zero: 'لا تغييرات بانتظار المزامنة',
    );
    return '$_temp0';
  }

  @override
  String get meSyncSaved => 'محفوظ';

  @override
  String get meSyncSavedDetail => 'كل شيء محفوظ في حسابك';

  @override
  String meBuildNumber(String version, String build) {
    return '$version (إصدار $build)';
  }

  @override
  String meBuildLine(
    String version,
    String commit,
    String contract,
    String server,
  ) {
    return '$version · الإيداع $commit · العقد $contract\nالخادم: $server';
  }

  @override
  String get meEditProfile => 'تعديل الملف الشخصي';

  @override
  String get meProfileNotLoaded => 'لم يُحمَّل ملفك الشخصي على هذا الهاتف بعد.';

  @override
  String get meGroupPersonal => 'شخصي';

  @override
  String get meGroupActivity => 'النشاط والتتبّع';

  @override
  String get meGroupPreferences => 'التفضيلات';

  @override
  String get meGroupAccount => 'الحساب';

  @override
  String get meBodySubtitle => 'الوزن والقياسات والمقارنات';

  @override
  String get meGoals => 'أهداف التغذية';

  @override
  String get meGoalsNoneSet => 'لم يُحدَّد أي هدف';

  @override
  String get meGoalsSet => 'الأهداف اليومية التي حدّدتها';

  @override
  String get meGoalsHelp => 'مساعدة في أهداف التغذية';

  @override
  String get meGoalsCoachSay =>
      'هذه أهداف التتبّع اليومية. يمكنك ترك أيٍّ منها فارغًا.';

  @override
  String get meGoalsPanelTitle =>
      'حدّد أهدافك اليومية بنفسك. يمكن ترك أي منها فارغًا.';

  @override
  String get meGoalsPanelBody =>
      'تتكرّر كل يوم إلى أن تغيّرها. يعرض «اليوم» و«التغذية» تقدّمك بمجرد تحديد أحدها.';

  @override
  String get meSteps => 'الخطوات';

  @override
  String get meStepsOnSubtitle => 'تُحسب بهذا الهاتف';

  @override
  String get meStepsOffSubtitle => 'متوقفة · تُحسب بهاتفك عند تفعيلها';

  @override
  String get meOn => 'تشغيل';

  @override
  String get meOff => 'إيقاف';

  @override
  String get meAppearance => 'المظهر';

  @override
  String get meAppearanceSubtitle => 'اجعل GoHard يشبهك.';

  @override
  String get meAppearanceHelp => 'مساعدة في هذه الإعدادات';

  @override
  String get meAppearanceCoachSay =>
      'اختر مرشدك ومتى أظهر. يحدّد «الحركة والاهتزاز» مقدار حركتي.';

  @override
  String get meAccentTitle => 'لون التمييز';

  @override
  String get meAccentBody => 'يُستخدم للأزرار والإبرازات واللوحات.';

  @override
  String get meAccentBlue => 'أزرق';

  @override
  String get meAccentGreen => 'أخضر';

  @override
  String get meAccentPink => 'وردي';

  @override
  String meAccentSemantics(String accent) {
    return 'لون التمييز $accent';
  }

  @override
  String get meModeTitle => 'الوضع';

  @override
  String get meModeBody => 'يتبع «النظام» مظهر هاتفك.';

  @override
  String get meModeLight => 'فاتح';

  @override
  String get meModeDark => 'داكن';

  @override
  String get meModeSystem => 'النظام';

  @override
  String get meAppearancePreviewSemantics => 'معاينة «اليوم» بهذا المظهر';

  @override
  String get meAppearancePreview => 'معاينة';

  @override
  String get meAppearancePreviewLine => 'لونك، ووضعك.';

  @override
  String get meAppearancePreviewButton => 'استئناف الحصة التدريبية';

  @override
  String get meCoachTitle => 'المدرّب';

  @override
  String get meCoachBody =>
      'ليون، أسد، أو ليونا، لبؤة. المدرّب نفسه في الحالتين: يتغيّر الشكل فقط.';

  @override
  String meCoachChoiceSemantics(String name, String animal) {
    return '$name، $animal';
  }

  @override
  String get meCoachOnToday => 'إظهار المدرّب في «اليوم»';

  @override
  String meCoachOnTodayOn(String guide) {
    return '$guide بجانب تحيتك.';
  }

  @override
  String meCoachOnTodayOff(String guide) {
    return 'متوقف. ما زال «اسأل GoHard» هو $guide، في «التدريب».';
  }

  @override
  String get meCoachOnTabs => 'إظهار المدرّب في «التدريب» و«التغذية»';

  @override
  String meCoachOnTabsOn(String guide) {
    return '$guide مع نصيحة قصيرة تحت العنوان.';
  }

  @override
  String meCoachOnTabsOff(String guide) {
    return 'متوقف. ما زالت المساعدة بنقرة على صورة $guide.';
  }

  @override
  String get meCoachHints => 'نصائح المدرّب';

  @override
  String meCoachHintsOn(String guide) {
    return 'نصيحة قصيرة من $guide بجانب مساعدة GoHard، مرة واحدة لكل منها.';
  }

  @override
  String get meCoachHintsOff => 'متوقف. ما زالت المساعدة متاحة عندما تطلبها.';

  @override
  String get meCoachHintsReset => 'إظهار نصائح المدرّب مجددًا';

  @override
  String get meCoachHintsResetDone =>
      'يمكن أن تظهر النصائح التي رأيتها مجددًا.';

  @override
  String get meTodayBackground => 'خلفية «اليوم»';

  @override
  String get meMotionHaptics => 'الحركة والاهتزاز';

  @override
  String get meMotionSubtitle => 'كيف يتحرّك GoHard ويهتز على هذا الهاتف.';

  @override
  String get meMotionSection => 'الحركة';

  @override
  String get meHapticsSection => 'الاهتزاز';

  @override
  String get meMotionReducedSummary => 'حركة مُخفَّضة';

  @override
  String get meHapticsOffSummary => 'الاهتزاز متوقف';

  @override
  String get meMotionReducedHapticsOffSummary => 'مُخفَّضة · الاهتزاز متوقف';

  @override
  String get meMotionDevicePhoneReduces =>
      'يتبع هاتفك. خيار تقليل الحركة مفعّل فيه، لذا تتغيّر الشاشات والتقدّم دون حركة.';

  @override
  String get meMotionDevicePhoneMoves =>
      'يتبع إعداد تقليل الحركة في هاتفك. وهو متوقف فيه، لذا تظهر انتقالات قصيرة.';

  @override
  String get meMotionReducedExplanation =>
      'تتغيّر الشاشات واللوحات والتقدّم دون حركة، مهما كان إعداد هاتفك.';

  @override
  String get meHapticsDeviceExplanation =>
      'نقرة خفيفة عند الاختيار أو تأكيد إجراء، إن سمح هاتفك بالاهتزاز. ليس أبدًا للمزامنة أو الكتابة.';

  @override
  String get meHapticsOffExplanation => 'لا يهزّ GoHard هذا الهاتف.';

  @override
  String get mePrefsApplyNow =>
      'تُطبَّق التغييرات فورًا وتُحفظ على هذا الهاتف.';

  @override
  String get mePermissions => 'أذونات الهاتف';

  @override
  String get mePermissionsSubtitle => 'الموقع والكاميرا والإشعارات';

  @override
  String get meReminders => 'تذكيرات الحصص التدريبية';

  @override
  String get meRemindersOnSubtitle =>
      'في الأيام التي فيها حصة مخطط لها. لا شيء أثناء إيقاف خطتك مؤقتًا.';

  @override
  String get meReminderTime => 'وقت التذكير';

  @override
  String get meReminderTimeSubtitle => 'التوقيت المحلي لهذا الهاتف';

  @override
  String get meSyncStatus => 'حالة المزامنة';

  @override
  String get meDeleteAccount => 'حذف الحساب';

  @override
  String get meDeleteAccountSubtitle => 'يمحو حسابك وبياناتك نهائيًا';

  @override
  String get meSignOut => 'تسجيل الخروج';

  @override
  String get meSignOutConfirmTitle => 'تسجيل الخروج؟';

  @override
  String meSignOutConfirmBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'تبقى حصصك التدريبية وطعامك وخططك محفوظة، بما في ذلك $count تغيير لم تتم مزامنته بعد. تبقى خاصة بحسابك على هذا الهاتف وتواصل المزامنة عند تسجيل الدخول مجددًا.',
      many:
          'تبقى حصصك التدريبية وطعامك وخططك محفوظة، بما في ذلك $count تغييرًا لم تتم مزامنته بعد. تبقى خاصة بحسابك على هذا الهاتف وتواصل المزامنة عند تسجيل الدخول مجددًا.',
      few:
          'تبقى حصصك التدريبية وطعامك وخططك محفوظة، بما في ذلك $count تغييرات لم تتم مزامنتها بعد. تبقى خاصة بحسابك على هذا الهاتف وتواصل المزامنة عند تسجيل الدخول مجددًا.',
      two: 'تبقى حصصك التدريبية وطعامك وخططك محفوظة، بما في ذلك تغييران لم تتم مزامنتهما بعد. تبقى خاصة بحسابك على هذا الهاتف وتواصل المزامنة عند تسجيل الدخول مجددًا.',
      one: 'تبقى حصصك التدريبية وطعامك وخططك محفوظة، بما في ذلك تغيير واحد لم تتم مزامنته بعد. تبقى خاصة بحسابك على هذا الهاتف وتواصل المزامنة عند تسجيل الدخول مجددًا.',
      zero: 'تبقى حصصك التدريبية وطعامك وخططك محفوظة. تبقى خاصة بحسابك على هذا الهاتف وتواصل المزامنة عند تسجيل الدخول مجددًا.',
    );
    return '$_temp0';
  }

  @override
  String get meSaveName => 'حفظ الاسم';

  @override
  String get meNameNotSaved =>
      'تعذّر حفظ اسمك على هذا الهاتف. ما كتبته ما زال هنا.';

  @override
  String get meNameField => 'الاسم الظاهر في التطبيق';

  @override
  String meSignedInAs(String email) {
    return 'تم تسجيل الدخول باسم $email';
  }

  @override
  String get meDeletePasswordMissing => 'أدخل كلمة المرور للتأكيد.';

  @override
  String get meDeleteConfirmTitle => 'حذف حسابك؟';

  @override
  String get meDeleteConfirmBody =>
      'سيُمحى حسابك وكل حصصه التدريبية وطعامه وخططه وقياساته نهائيًا. لا يمكن التراجع عن ذلك.';

  @override
  String get meDeleteConfirmAction => 'حذف كل شيء';

  @override
  String get meDeleteButton => 'حذف حسابي';

  @override
  String get meDeleteKeep => 'الإبقاء على حسابي';

  @override
  String get meDeleteExplanation =>
      'يمحو هذا حسابك وكل ما فيه نهائيًا، على الخادم وعلى هذا الهاتف. تسجيل الخروج مختلف: يحتفظ بكل شيء.';

  @override
  String meDeletePendingWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تغيير على هذا الهاتف لم تتم مزامنته بعد وسيُمحى أيضًا.',
      many: '$count تغييرًا على هذا الهاتف لم تتم مزامنته بعد وسيُمحى أيضًا.',
      few: '$count تغييرات على هذا الهاتف لم تتم مزامنتها بعد وستُمحى أيضًا.',
      two: 'تغييران على هذا الهاتف لم تتم مزامنتهما بعد وسيُمحيان أيضًا.',
      one: 'تغيير واحد على هذا الهاتف لم تتم مزامنته بعد وسيُمحى أيضًا.',
      zero: 'لا تغييرات غير متزامنة.',
    );
    return '$_temp0';
  }

  @override
  String get meDeletePasswordField => 'كلمة المرور';

  @override
  String get bodyTitle => 'تقدّم الجسم';

  @override
  String get bodyFieldWeight => 'الوزن';

  @override
  String get bodyFieldWaist => 'محيط الخصر';

  @override
  String get bodyFieldChest => 'محيط الصدر';

  @override
  String get bodyFieldLeftUpperArm => 'أعلى الذراع اليسرى';

  @override
  String get bodyFieldRightUpperArm => 'أعلى الذراع اليمنى';

  @override
  String get bodyFieldLeftThigh => 'الفخذ الأيسر';

  @override
  String get bodyFieldRightThigh => 'الفخذ الأيمن';

  @override
  String get bodyFieldBodyFat => 'نسبة الدهون';

  @override
  String bodyFieldValue(String field, String value) {
    return '$field $value';
  }

  @override
  String get bodyUnitCm => 'سم';

  @override
  String get bodyUnitIn => 'بوصة';

  @override
  String get bodyUnitPoints => 'نقطة';

  @override
  String get bodyUnitWeight => 'الوزن';

  @override
  String get bodyUnitLength => 'الطول';

  @override
  String get bodyErrorNotANumber => 'أدخل رقمًا، أو اتركه فارغًا.';

  @override
  String get bodyErrorWeightRange =>
      'الوزن أكبر من 0 وبحد أقصى 700 كغ (1543 رطل).';

  @override
  String get bodyErrorLengthRange =>
      'استخدم قيمة أكبر من 0 وبحد أقصى 500 سم (196.85 بوصة).';

  @override
  String get bodyErrorFatRange => 'نسبة الدهون من 0 إلى 100%.';

  @override
  String get bodyErrorNothingEntered => 'أدخل قياسًا واحدًا على الأقل للحفظ.';

  @override
  String bodyErrorFieldOutOfRange(String field) {
    return '$field خارج النطاق.';
  }

  @override
  String get bodyErrorNoteTooLong => 'الملاحظة 200 حرف على الأكثر.';

  @override
  String get bodyErrorMeasurementsNeedServer =>
      'لا يستطيع خادم حسابك تخزين هذه القياسات بعد. يمكن حفظ الوزن ونسبة الدهون الآن.';

  @override
  String get bodyErrorNeedsOneMeasurement =>
      'يحتاج الإدخال إلى قياس واحد على الأقل. لإزالته، استخدم «حذف الإدخال».';

  @override
  String get bodyErrorCorrectionNeedsServer =>
      'يتطلّب تصحيح إدخال تحديثًا لخادم حسابك. تغييراتك ما زالت هنا.';

  @override
  String bodyRangeLabel(String range) {
    String _temp0 = intl.Intl.selectLogic(range, {
      'weeks4': '4 أسابيع',
      'weeks12': '12 أسبوعًا',
      'other': 'الكل',
    });
    return '$_temp0';
  }

  @override
  String bodyRangeWords(String range) {
    String _temp0 = intl.Intl.selectLogic(range, {
      'weeks4': 'خلال آخر 4 أسابيع',
      'weeks12': 'خلال آخر 12 أسبوعًا',
      'other': 'في كامل سجلك',
    });
    return '$_temp0';
  }

  @override
  String get bodyReadErrorTitle => 'تعذّرت القراءة';

  @override
  String get bodyReadErrorBody =>
      'تعذّرت قراءة قياساتك على هذا الهاتف الآن. لم يتغيّر شيء؛ حاول مرة أخرى.';

  @override
  String get bodySyncNeedsReview =>
      'يحتاج إلى مراجعة في «حسابي» › حالة المزامنة';

  @override
  String get bodySyncWaiting => 'محفوظ على هذا الهاتف · بانتظار المزامنة';

  @override
  String bodyDayEntriesKnown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إدخال في هذا اليوم، بترتيب حفظها.',
      many: '$count إدخالًا في هذا اليوم، بترتيب حفظها.',
      few: '$count إدخالات في هذا اليوم، بترتيب حفظها.',
      two: 'إدخالان في هذا اليوم، بترتيب حفظهما.',
      one: 'إدخال واحد في هذا اليوم، بترتيب حفظه.',
      zero: 'لا إدخالات في هذا اليوم.',
    );
    return '$_temp0';
  }

  @override
  String bodyDayEntriesUnknown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إدخال في هذا اليوم. ترتيب أخذها غير معروف.',
      many: '$count إدخالًا في هذا اليوم. ترتيب أخذها غير معروف.',
      few: '$count إدخالات في هذا اليوم. ترتيب أخذها غير معروف.',
      two: 'إدخالان في هذا اليوم. ترتيب أخذهما غير معروف.',
      one: 'إدخال واحد في هذا اليوم. ترتيب أخذه غير معروف.',
      zero: 'لا إدخالات في هذا اليوم.',
    );
    return '$_temp0';
  }

  @override
  String bodySavedAt(String time) {
    return 'حُفظ في $time';
  }

  @override
  String bodySavedAtLower(String time) {
    return 'حُفظ في $time';
  }

  @override
  String bodyEntryNumber(int number) {
    return 'الإدخال $number';
  }

  @override
  String get bodyHelp => 'مساعدة في تقدّم الجسم';

  @override
  String get bodyCoachSay => 'تتبّع ما يهمّك. كل قياس اختياري.';

  @override
  String get bodyHowToMeasure => 'كيفية القياس';

  @override
  String get bodyEmptyTitle => 'لم يُسجَّل شيء بعد';

  @override
  String get bodyEmptyBody =>
      'سجّل وزنًا أو أي قياس واحد عندما يفيدك. لا شيء هنا إلزامي.';

  @override
  String get bodyLogMeasurements => 'تسجيل القياسات';

  @override
  String bodyPendingOldServer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count تغيير محفوظ على هذا الهاتف. بعضها ينتظر دعم خادم حسابك لقياسات الجسم.',
      many:
          '$count تغييرًا محفوظًا على هذا الهاتف. بعضها ينتظر دعم خادم حسابك لقياسات الجسم.',
      few:
          '$count تغييرات محفوظة على هذا الهاتف. بعضها ينتظر دعم خادم حسابك لقياسات الجسم.',
      two: 'تغييران محفوظان على هذا الهاتف. بعضها ينتظر دعم خادم حسابك لقياسات الجسم.',
      one: 'تغيير واحد محفوظ على هذا الهاتف. بعضها ينتظر دعم خادم حسابك لقياسات الجسم.',
      zero: 'لا تغييرات محفوظة.',
    );
    return '$_temp0';
  }

  @override
  String bodyPendingWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تغيير محفوظ على هذا الهاتف · بانتظار المزامنة',
      many: '$count تغييرًا محفوظًا على هذا الهاتف · بانتظار المزامنة',
      few: '$count تغييرات محفوظة على هذا الهاتف · بانتظار المزامنة',
      two: 'تغييران محفوظان على هذا الهاتف · بانتظار المزامنة',
      one: 'تغيير واحد محفوظ على هذا الهاتف · بانتظار المزامنة',
      zero: 'لا تغييرات بانتظار المزامنة',
    );
    return '$_temp0';
  }

  @override
  String get bodyAllMeasurements => 'كل القياسات';

  @override
  String get bodyLatestWeight => 'آخر وزن';

  @override
  String get bodyNotRecorded => 'غير مسجّل';

  @override
  String get bodyNotRecordedLower => 'غير مسجّل';

  @override
  String get bodyDashNotRecorded => '— غير مسجّل';

  @override
  String get bodyOtherBelow => 'قياساتك الأخرى أدناه.';

  @override
  String bodyAverageOfEntries(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'متوسط $count إدخال في $date',
      many: 'متوسط $count إدخالًا في $date',
      few: 'متوسط $count إدخالات في $date',
      two: 'متوسط إدخالين في $date',
      one: 'متوسط إدخال واحد في $date',
      zero: 'لا إدخالات في $date',
    );
    return '$_temp0';
  }

  @override
  String bodyRecordedOn(String date) {
    return 'سُجّل في $date';
  }

  @override
  String get bodySevenDayAverage => 'متوسط 7 أيام';

  @override
  String get bodyNotAvailable => 'غير متاح';

  @override
  String get bodyNotAvailableLower => 'غير متاح';

  @override
  String get bodyNoWeightSevenDays => 'لا وزن خلال آخر 7 أيام';

  @override
  String bodyRecordedDaysOfSeven(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم مسجّل من 7',
      many: '$count يومًا مسجّلًا من 7',
      few: '$count أيام مسجّلة من 7',
      two: 'يومان مسجّلان من 7',
      one: 'يوم مسجّل واحد من 7',
      zero: '0 أيام مسجّلة من 7',
    );
    return '$_temp0';
  }

  @override
  String bodyDateRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get bodyLog => 'تسجيل';

  @override
  String get bodyCompareDates => 'مقارنة التواريخ';

  @override
  String bodyOverTime(String field) {
    return '$field بمرور الوقت';
  }

  @override
  String get bodySeeAll => 'عرض الكل';

  @override
  String get bodyChartNoWeight =>
      'لم يُسجَّل وزن بعد. سجّل واحدًا لرؤيته بمرور الوقت.';

  @override
  String bodyChartNone(String field) {
    return 'لم يُسجَّل $field بعد.';
  }

  @override
  String bodyChartEmptyInRange(String field, String range) {
    return 'لا يوجد $field مسجّل $range. اختر مدة أطول.';
  }

  @override
  String get bodyChartLegendDaily => 'النقاط: كل إدخال · الخط: المتوسط اليومي';

  @override
  String get bodyChartLegendPoints => 'كل نقطة إدخال سجّلته';

  @override
  String bodyChartSemantics(
    String field,
    String range,
    int count,
    String readings,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إدخال',
      many: '$count إدخالًا',
      few: '$count إدخالات',
      two: 'إدخالان',
      one: 'إدخال واحد',
      zero: 'لا إدخالات',
    );
    return '$field $range: $_temp0. $readings.';
  }

  @override
  String bodyReading(String date, String value) {
    return '$date، $value';
  }

  @override
  String bodyOneDayInRange(String range) {
    return 'يوم واحد مسجّل $range. يحتاج التغيير إلى يومين على الأقل.';
  }

  @override
  String bodyRangeChange(String change) {
    return 'من أول يوم إلى آخر يوم في هذه المدة: $change';
  }

  @override
  String get bodyLatestMeasurements => 'أحدث القياسات';

  @override
  String get bodyLatestNone =>
      'لا قياسات غير الوزن بعد. سجّل القياسات لإضافة الخصر أو الصدر أو الذراعين أو الفخذين.';

  @override
  String get bodyMetricFatSubtitle =>
      'نسبة الدهون التي أدخلتها، بالنسبة المئوية';

  @override
  String bodyMetricUnitSubtitle(String unit) {
    return 'بوحدة $unit';
  }

  @override
  String get bodyEntriesInRange => 'الإدخالات في هذه المدة';

  @override
  String get bodyHistorySubtitle => 'كل الإدخالات، الأحدث أولًا';

  @override
  String get bodyHistoryEmptyBody => 'تظهر إدخالاتك هنا بمجرد تسجيل أحدها.';

  @override
  String get bodyNoMeasurement => 'لا قياس';

  @override
  String bodyOneOfEntriesLower(int count) {
    return 'واحد من $count إدخالات، الترتيب غير معروف';
  }

  @override
  String bodyOneOfEntriesDay(int count) {
    return 'واحد من $count إدخالات في هذا اليوم، الترتيب غير معروف';
  }

  @override
  String bodyQuotedNote(String note) {
    return '«$note»';
  }

  @override
  String get bodyConvertBlocked =>
      'يحتوي حقل على نص ليس رقمًا. صحّحه أو امسحه، ثم غيّر الوحدة.';

  @override
  String get bodyDateMeasured => 'تاريخ القياس';

  @override
  String get bodyFutureDate => 'اختر اليوم أو تاريخًا سابقًا.';

  @override
  String get bodyCheckFields => 'تحقّق من الحقول المميّزة. لم يُحفظ شيء.';

  @override
  String get bodySavedToast =>
      'حُفظ على هذا الهاتف · تتم مزامنته مع حسابك عندما يكون ذلك ممكنًا';

  @override
  String get bodySaveFailed =>
      'تعذّر الحفظ على هذا الهاتف. كل ما كتبته ما زال هنا.';

  @override
  String get bodyDeleteConfirmTitle => 'حذف هذا الإدخال؟';

  @override
  String bodyDeleteConfirmBody(String date) {
    return 'سيُزال إدخال $date من قياساتك.';
  }

  @override
  String get bodyDeleteFailed =>
      'تعذّرت الإزالة على هذا الهاتف. حاول مرة أخرى.';

  @override
  String get bodyChooseMeasurements => 'اختيار القياسات';

  @override
  String get bodyChooseSubtitle => 'نسبة الدهون أو ملاحظة أو حقول أقل';

  @override
  String get bodyChooseExplanation =>
      'اختر ما يعرضه هذا النموذج. إخفاء حقل لا يزيل أبدًا أي شيء سجّلته.';

  @override
  String get bodyNote => 'ملاحظة';

  @override
  String get bodyNoteOptional => 'ملاحظة (اختيارية)';

  @override
  String get bodyDiscardTitle => 'تجاهل تغييراتك؟';

  @override
  String get bodyDiscardBody => 'لم يُحفظ ما كتبته.';

  @override
  String get bodyDiscard => 'تجاهل';

  @override
  String get bodyKeepEditing => 'متابعة التعديل';

  @override
  String get bodyEditEntry => 'تعديل الإدخال';

  @override
  String get bodyEveryOptional => 'كل قياس اختياري.';

  @override
  String get bodyDoneTyping => 'انتهيت من الكتابة';

  @override
  String get bodySaveMeasurements => 'حفظ القياسات';

  @override
  String get bodySaveChanges => 'حفظ التغييرات';

  @override
  String get bodyAtLeastOne =>
      'أدخل قياسًا واحدًا على الأقل للحفظ. الحقل الفارغ يعني أنه لم يُقَس.';

  @override
  String get bodyDeleteEntry => 'حذف الإدخال';

  @override
  String get bodyCompareFrom => 'المقارنة من';

  @override
  String get bodyCompareTo => 'المقارنة مع';

  @override
  String get bodyCompareOnlySaved =>
      'يمكن اختيار الأيام التي فيها إدخال محفوظ فقط.';

  @override
  String get bodyCompareSubtitle => 'التغييرات بين إدخالاتك المسجّلة.';

  @override
  String get bodyCompareHelp => 'مساعدة في المقارنة';

  @override
  String get bodyCompareCoachSay =>
      'قارن القياس نفسه في تاريخين. تعني الشَّرطة أنه لم يُسجَّل في ذلك اليوم.';

  @override
  String get bodyTwoDatesTitle => 'يلزم تاريخان';

  @override
  String get bodyTwoDatesNone =>
      'تتطلّب المقارنة إدخالات في يومين مختلفين. ليس لديك أي إدخال بعد.';

  @override
  String bodyTwoDatesOne(String date) {
    return 'تتطلّب المقارنة إدخالات في يومين مختلفين. لديك إدخالات في $date فقط.';
  }

  @override
  String get bodyCompareLost =>
      'لم يعد إدخال اخترته متاحًا، لذا يُعرض الافتراضي.';

  @override
  String get bodyCompareChoose =>
      'في هذين اليومين أكثر من إدخال وترتيبها غير معروف. اختر الإدخالات للمقارنة.';

  @override
  String get bodyCompareSame => '«من» و«إلى» الإدخال نفسه. اختر إدخالًا آخر.';

  @override
  String get bodyChoose => 'اختيار';

  @override
  String get bodyFrom => 'من';

  @override
  String get bodyTo => 'إلى';

  @override
  String bodyCompareWeightChange(String change) {
    return 'التغيير  $change';
  }

  @override
  String get bodyCompareWeightNoChange => 'التغيير  —  يلزم وزن في اليومين';

  @override
  String get bodyMeasurements => 'القياسات';

  @override
  String get bodyChange => 'التغيير';

  @override
  String bodyChangeValue(String change) {
    return 'التغيير: $change';
  }

  @override
  String bodyDatedValue(String date, String value) {
    return '$date: $value';
  }

  @override
  String bodyCompareRowSemantics(
    String field,
    String fromDate,
    String fromValue,
    String toDate,
    String toValue,
    String change,
  ) {
    return '$field: $fromDate $fromValue، $toDate $toValue، التغيير $change';
  }

  @override
  String get bodyFatPointsNote => 'تغيير نسبة الدهون بالنقاط المئوية.';

  @override
  String get bodyRecordedOnly =>
      'القيم المسجّلة فقط. لا يُعرض التغيير إلا حين يحتوي الإدخالان على ذلك القياس.';

  @override
  String get bodyHowSubtitle =>
      'قِس بالطريقة نفسها في كل مرة، لتكون الإدخالات قابلة للمقارنة.';

  @override
  String get bodyHowTapeTitle => 'أي قياس بالشريط';

  @override
  String get bodyHowTapeBody =>
      'استخدم شريطًا مرنًا. أبقِه مستويًا ومحكمًا دون الضغط على الجلد، واقرأه في المكان نفسه كل مرة.';

  @override
  String get bodyHowWaistBody =>
      'حدّد أعلى عظم الورك من الجانب. لفّ الشريط حول خصرك عند هذا المستوى، موازيًا للأرض، واقرأه في نهاية زفير عادي.';

  @override
  String get bodyHowArmTitle => 'أعلى الذراع';

  @override
  String get bodyHowArmBody =>
      'حدّد منتصف المسافة بين طرف الكتف العظمي ورأس المرفق، في الجزء الخلفي من الذراع. والذراع مسترخية ومتدلية بحرية، لفّ الشريط حول الذراع عند تلك النقطة. شدّ العضلة يغيّر القراءة. قِس الذراع اليسرى واليمنى كلًّا على حدة.';

  @override
  String get bodyHowChestThighsTitle => 'الصدر والفخذان';

  @override
  String get bodyHowChestThighsBody =>
      'لا يملك GoHard معلمًا قياسيًا موثّقًا لهذه القياسات. اختر موضعًا واحدًا، ودوّنه إن كان ذلك مفيدًا، وقِس عنده في كل مرة بإحكام الشريط نفسه. قِس الفخذ الأيسر والأيمن كلًّا على حدة.';

  @override
  String get bodyHowWeightFatTitle => 'الوزن ونسبة الدهون';

  @override
  String get bodyHowWeightFatBody =>
      'اختياري. أدخل نسبة الدهون فقط إن كانت لديك قيمة من طريقة تثق بها؛ لا يقدّرها GoHard.';

  @override
  String get bodyHowSource =>
      'المصدر: Centers for Disease Control and Prevention، National Center for Health Statistics. NHANES Anthropometry Procedures Manual، يناير 2017: 3.4.6 Upper Arm Length، 3.4.7 Arm Circumference، 3.4.8 Abdominal (Waist) Circumference.';

  @override
  String get bodyHowNotAdvice =>
      'هذه تقنية قياس، وليست نصيحة صحية. لا يحكم GoHard على القياسات.';

  @override
  String get planListComma => '، ';

  @override
  String get planSequenceArrow => ' ← ';

  @override
  String planDateMove(String from, String to) {
    return '$from  ←  $to';
  }

  @override
  String planDateSpan(String start, String end) {
    return 'من $start إلى $end';
  }

  @override
  String planDateRangeSameMonth(String month, String startDay, String endDay) {
    return '$startDay–$endDay $month';
  }

  @override
  String planDateRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String planTitleDate(String title, String date) {
    return '$title، $date';
  }

  @override
  String get planWorkoutFallback => 'حصة';

  @override
  String get planDefaultTitle => 'خطتي';

  @override
  String planCopyName(String name) {
    return '$name (نسخة)';
  }

  @override
  String get planModeFixed => 'أيام ثابتة';

  @override
  String get planModeRotating => 'تسلسل متناوب';

  @override
  String planWeekN(int week) {
    return 'الأسبوع $week';
  }

  @override
  String planWeekNOfM(int week, int total) {
    return 'الأسبوع $week من $total';
  }

  @override
  String planWeekLower(int week) {
    return 'الأسبوع $week';
  }

  @override
  String planSessionN(int n) {
    return 'الحصة $n';
  }

  @override
  String planSessionLower(int n) {
    return 'الحصة $n';
  }

  @override
  String planSessionStep(int n, int step, int total, int cycle) {
    return 'الحصة $n · الخطوة $step من $total، الدورة $cycle';
  }

  @override
  String planWeeksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أسبوع',
      many: '$count أسبوعًا',
      few: '$count أسابيع',
      two: 'أسبوعان',
      one: 'أسبوع واحد',
      zero: '0 أسبوع',
    );
    return '$_temp0';
  }

  @override
  String planWeeksPlain(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أسبوع',
      many: '$count أسبوعًا',
      few: '$count أسابيع',
      two: 'أسبوعان',
      one: 'أسبوع واحد',
      zero: '0 أسبوع',
    );
    return '$_temp0';
  }

  @override
  String planWorkoutsPlain(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حصة',
      many: '$count حصة',
      few: '$count حصص',
      two: 'حصتان',
      one: 'حصة واحدة',
      zero: 'لا حصص',
    );
    return '$_temp0';
  }

  @override
  String planExerciseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تمرين',
      many: '$count تمرينًا',
      few: '$count تمارين',
      two: 'تمرينان',
      one: 'تمرين واحد',
      zero: 'لا تمارين',
    );
    return '$_temp0';
  }

  @override
  String planExercisesPlain(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تمرين',
      many: '$count تمرينًا',
      few: '$count تمارين',
      two: 'تمرينان',
      one: 'تمرين واحد',
      zero: 'لا تمارين',
    );
    return '$_temp0';
  }

  @override
  String planPlannedSetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مجموعة مخططة',
      many: '$count مجموعة مخططة',
      few: '$count مجموعات مخططة',
      two: 'مجموعتان مخططتان',
      one: 'مجموعة مخططة واحدة',
      zero: 'لا مجموعات مخططة',
    );
    return '$_temp0';
  }

  @override
  String planSetsPlain(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مجموعة',
      many: '$count مجموعة',
      few: '$count مجموعات',
      two: 'مجموعتان',
      one: 'مجموعة واحدة',
      zero: '0 مجموعة',
    );
    return '$_temp0';
  }

  @override
  String planSetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مجموعة',
      many: '$count مجموعة',
      few: '$count مجموعات',
      two: 'مجموعتان',
      one: 'مجموعة واحدة',
      zero: '0 مجموعة',
    );
    return '$_temp0';
  }

  @override
  String planRepCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تكرار',
      many: '$count تكرارًا',
      few: '$count تكرارات',
      two: 'تكراران',
      one: 'تكرار واحد',
      zero: '0 تكرار',
    );
    return '$_temp0';
  }

  @override
  String planRxSetsTimes(int sets, String amount) {
    return '$sets × $amount';
  }

  @override
  String planRestMinutes(int minutes) {
    return 'راحة $minutes د';
  }

  @override
  String planRestSeconds(int seconds) {
    return 'راحة $seconds ث';
  }

  @override
  String get planNoTarget => 'بلا هدف';

  @override
  String planTargetLoad(String load) {
    return 'الوزن المستهدف $load';
  }

  @override
  String planPlannedTime(int minutes) {
    return 'الوقت المخطط $minutes د';
  }

  @override
  String get planOngoing => 'مستمرة';

  @override
  String get planOngoingLower => 'مستمرة';

  @override
  String planStartsOn(String date) {
    return 'تبدأ في $date';
  }

  @override
  String planEndsOn(String date) {
    return 'تنتهي في $date';
  }

  @override
  String get planTodayLower => 'اليوم';

  @override
  String get planTodayLabel => 'اليوم';

  @override
  String get planRestDayLower => 'يوم راحة';

  @override
  String get planNext => 'التالية';

  @override
  String get planSplitEvidenceNote =>
      'وجدت الدراسات التي قارنت تقسيمات بنفس الحجم الأسبوعي مكاسب متقاربة في القوة والعضلات، لذا اختر البنية التي تستطيع الاستمرار عليها.';

  @override
  String planSuggestReasonFew(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'مع $days يوم في الأسبوع، تُمرّن حصص الجسم الكامل كل مجموعة عضلية في كل مرة تتدرب فيها.',
      many:
          'مع $days يومًا في الأسبوع، تُمرّن حصص الجسم الكامل كل مجموعة عضلية في كل مرة تتدرب فيها.',
      few:
          'مع $days أيام في الأسبوع، تُمرّن حصص الجسم الكامل كل مجموعة عضلية في كل مرة تتدرب فيها.',
      two: 'مع يومين في الأسبوع، تُمرّن حصص الجسم الكامل كل مجموعة عضلية في كل مرة تتدرب فيها.',
      one: 'مع يوم واحد في الأسبوع، تُمرّن حصص الجسم الكامل كل مجموعة عضلية في كل مرة تتدرب فيها.',
      zero: 'بلا أيام في الأسبوع، تُمرّن حصص الجسم الكامل كل مجموعة عضلية في كل مرة تتدرب فيها.',
    );
    return '$_temp0';
  }

  @override
  String get planSuggestReasonFour =>
      'مع 4 أيام، يؤدي التناوب بين الجزء العلوي والسفلي من الجسم إلى تمرين كل نصف مرتين في الأسبوع.';

  @override
  String get planSuggestReasonFive =>
      'مع 5 أيام، يؤدي يوم للجزء العلوي ويوم للجزء السفلي ثم الدفع والسحب والأرجل إلى تمرين كل منطقة نحو مرتين في الأسبوع.';

  @override
  String planSuggestReasonMany(int days) {
    return 'مع $days أيام، يؤدي تكرار الدفع والسحب والأرجل إلى تمرين كل منطقة مرتين في الأسبوع.';
  }

  @override
  String planSuggestReasonSeven(int days) {
    return 'مع $days أيام، يؤدي تكرار الدفع والسحب والأرجل إلى تمرين كل منطقة مرتين في الأسبوع ويترك يومًا للراحة.';
  }

  @override
  String get planDirectionStrength => 'زيادة القوة';

  @override
  String get planDirectionMuscle => 'بناء العضلات';

  @override
  String get planDirectionFatLoss => 'خسارة الدهون';

  @override
  String get planDirectionGeneral => 'لياقة عامة';

  @override
  String planSetupPerWeek(String count) {
    return '$count في الأسبوع';
  }

  @override
  String planSetupAbout(String minutes) {
    return 'نحو $minutes د';
  }

  @override
  String get planReviewedPlan => 'خطة تمت مراجعتها';

  @override
  String get planOwnSplit => 'تقسيمك الخاص';

  @override
  String get planStarterSplit => 'تقسيم مبدئي';

  @override
  String get builderEquipmentFullGym => 'صالة كاملة';

  @override
  String get builderEquipmentDumbbells => 'دمبلز فقط';

  @override
  String get builderEquipmentBodyweight => 'وزن الجسم فقط';

  @override
  String get builderExperienceNew => 'جديد على التدريب';

  @override
  String get builderExperienceComfortable => 'متمكن من الأساسيات';

  @override
  String get builderExperienceExperienced => 'ذو خبرة';

  @override
  String planLifecycle(String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'draft': 'مسودة',
      'active': 'نشطة',
      'paused': 'متوقفة مؤقتًا',
      'closed': 'مغلقة',
      'other': '$state',
    });
    return '$_temp0';
  }

  @override
  String get planProvenanceManual => 'حصة يدوية · ليست ضمن خطة';

  @override
  String planProvenanceGone(String title) {
    return 'من خطة لم تعد على هذا الهاتف · $title';
  }

  @override
  String planProvenanceFrom(String plan, String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'archived': 'من $plan (مؤرشفة)',
      'closed': 'من $plan (مغلقة)',
      'paused': 'من $plan (متوقفة مؤقتًا)',
      'other': 'من $plan',
    });
    return '$_temp0';
  }

  @override
  String planSessionOfRotation(int n) {
    return 'الحصة $n من التناوب';
  }

  @override
  String get planErrTitle => 'أعطِ الخطة اسمًا لا يتجاوز 60 حرفًا.';

  @override
  String get planErrDuration =>
      'اختر مدة بين 1 و52 أسبوعًا. وحده التسلسل المتناوب يمكن أن يستمر بلا نهاية.';

  @override
  String get planErrTimeBudget =>
      'اختر وقتًا مخططًا بين 10 و240 دقيقة، أو بلا وقت.';

  @override
  String get planErrWorkouts =>
      'راجع الحصص: تحتاج كل حصة إلى اسم، ويجب أن تكون المجموعات والتكرارات والراحة والأوزان ضمن النطاق.';

  @override
  String get planErrSchedule =>
      'راجع الجدول: يحتاج كل يوم أو خطوة إلى حصة، بحصة واحدة لكل يوم من أيام الأسبوع.';

  @override
  String get planErrNotUsable =>
      'أضف تمرينًا واحدًا على الأقل إلى كل حصة مجدولة قبل تفعيل الخطة.';

  @override
  String get planErrNewerApp =>
      'أُنشئت هذه الخطة بإصدار أحدث من التطبيق. حدّث التطبيق لتعديلها.';

  @override
  String get planErrUnknownExercise => 'أحد تمارين هذه الخطة غير متاح لحسابك.';

  @override
  String get planErrStartLocked =>
      'تحتفظ الخطة النشطة بتاريخ بدايتها. انسخها لتبدأ من جديد في يوم آخر.';

  @override
  String get planErrModeLocked =>
      'تحتفظ الخطة النشطة بنوع جدولها. انسخها للتبديل بين أيام الأسبوع والتناوب.';

  @override
  String get planErrNotMovable =>
      'لا توجد تواريخ ثابتة في الخطة المتناوبة. تخطَّ الحصة، أو أدّها في المرة القادمة التي تتدرب فيها.';

  @override
  String get planErrExerciseName => 'أعطِ التمرين اسمًا لا يتجاوز 80 حرفًا.';

  @override
  String get planErrChangedSinceEdit =>
      'تغيّرت هذه الخطة بعد أن بدأت تعديلها. ابدأ من جديد من الخطة كما هي الآن.';

  @override
  String get planErrNotActive => 'هذه الخطة مغلقة. انسخها لتتدرب بها من جديد.';

  @override
  String get planErrTargetContext =>
      'لم يعد هذا التمرين ضمن حصة الخطة تلك، لذا لم يتغيّر هدفه. راجع الخطة بدلًا من ذلك.';

  @override
  String get planErrTargetChanged =>
      'تغيّر هذا الهدف مرة أخرى منذ ذلك الحين، لذا لم يُستعد الهدف السابق. عدّله بدلًا من ذلك.';

  @override
  String planErrUnknown(String code) {
    return 'تعذّر تطبيق هذا التغيير ($code).';
  }

  @override
  String get planErrRecovery => 'لا يترك ذلك يوم تعافٍ بين حصتين.';

  @override
  String get planErrNotEligible =>
      'هذه الحصة مسجّلة أو تم تخطيها أو جارية بالفعل، لذا لا يمكن نقلها.';

  @override
  String get planErrStaleReview =>
      'تغيّر الجدول منذ أن راجعته. راجعه مرة أخرى.';

  @override
  String get planErrWeekdayCount =>
      'اختر عدد أيام مساويًا تمامًا لعدد الحصص في الأسبوع.';

  @override
  String get planErrInvalidDate => 'أدخل تاريخًا صحيحًا من التقويم.';

  @override
  String get planErrNoLongerInPlan => 'لم تعد هذه الحصة جزءًا من هذه الخطة.';

  @override
  String get planPrimaryExists =>
      'هناك خطة أخرى هي خطتك الأساسية بالفعل. راجع الاستبدال أولًا.';

  @override
  String get planLocalSaveFailed =>
      'تعذّر الحفظ على هذا الهاتف. لم يتغيّر شيء.';

  @override
  String get trainSectionWorkouts => 'الحصص';

  @override
  String get trainSectionPlan => 'الخطة';

  @override
  String get trainSectionProgress => 'التقدّم';

  @override
  String get trainAskStartingPlan => 'بدء خطة';

  @override
  String get trainAskYourPlan => 'خطتك';

  @override
  String get trainAskYourProgress => 'تقدّمك';

  @override
  String get trainAskYourTraining => 'تدريبك';

  @override
  String get planStartInProgressCoach =>
      'خطتك قيد الإعداد محفوظة على هذا الهاتف. تابع من حيث توقفت.';

  @override
  String get planStartInProgressTitle => 'خطة قيد الإعداد';

  @override
  String get planStartInProgressBody =>
      'محفوظة على هذا الهاتف. لا يُجدول شيء حتى تبدأها.';

  @override
  String get planStartContinue => 'متابعة خطتي';

  @override
  String get planStartDraftCoach =>
      'خطتك محفوظة كمسودة. راجعها، ثم ابدأها عندما تكون مستعدًا.';

  @override
  String get planStartDraftTitle => 'خطتك جاهزة للمراجعة';

  @override
  String get planStartDraftBody =>
      'لا تُجدول المسودة المحفوظة أي شيء حتى تبدأها.';

  @override
  String get planStartReview => 'مراجعة خطتي';

  @override
  String get planStartNewCoach =>
      'لنُعِدّ خطتك التدريبية. اختر تقسيمًا مألوفًا أو أنشئ تقسيمك الخاص.';

  @override
  String get planStartNewTitle => 'لا توجد خطة بعد';

  @override
  String get planStartNewBody =>
      'اختر تقسيمًا مألوفًا أو أنشئ تقسيمك الخاص. لا يُجدول شيء حتى تراجعه.';

  @override
  String get planStartCreate => 'إنشاء خطتي';

  @override
  String get trainCoachPlanPaused =>
      'خطتك متوقفة مؤقتًا، لذا لا يُحتسب شيء فائتًا. استأنفها أدناه عندما تكون مستعدًا.';

  @override
  String get trainCoachPlanWeek =>
      'هذه خطتك أسبوعًا بأسبوع. اضغط على حصة لعرض تفاصيلها، أو اسألني عن الجدول.';

  @override
  String get trainCoachWorkoutOpen =>
      'لا تزال هناك حصة مفتوحة. استأنفها أدناه عندما تكون مستعدًا.';

  @override
  String get trainCoachWorkoutsPlan =>
      'ابدأ حصتك المخططة من «اليوم»، أو سجّل حصة خاصة بك هنا.';

  @override
  String get trainCoachWorkoutsNoPlan =>
      'سجّل حصة خاصة بك هنا. يمكن للخطة أن تجدولها لك.';

  @override
  String get trainScheduledToday => 'مجدولة اليوم';

  @override
  String trainDueToday(String summary) {
    return 'مستحقة اليوم · $summary';
  }

  @override
  String get trainOpenWorkouts => 'الحصص المفتوحة';

  @override
  String get trainStartManual => 'بدء حصة يدوية';

  @override
  String get trainStartManualSubtitle =>
      'تدرّب بلا خطة. لا تُحتسب أبدًا بدلًا من حصة مخططة.';

  @override
  String get trainRunWalk => 'جري / مشي';

  @override
  String get trainRunWalkSubtitle => 'سجّل جريًا أو مشيًا في الخارج مع مساره';

  @override
  String get trainRunWalkHistory => 'سجل الجري / المشي';

  @override
  String get trainRunWalkHistorySubtitle =>
      'كل جري ومشي، المسارات وأفضل الأرقام الشخصية';

  @override
  String get trainRecentEmptyTitle => 'لم تُسجَّل أي حصة بعد';

  @override
  String get trainRecentEmptyBody =>
      'عندما تُنهي حصة، يظهر هنا ما أدّيته فعلًا.';

  @override
  String get trainSavedForLater => 'محفوظة لوقت لاحق';

  @override
  String get trainInProgress => 'جارية';

  @override
  String trainOpenStatusLine(String status, String date) {
    return '$status · بدأت في $date';
  }

  @override
  String trainSetsRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'سُجِّلت $count مجموعة',
      many: 'سُجِّلت $count مجموعة',
      few: 'سُجِّلت $count مجموعات',
      two: 'سُجِّلت مجموعتان',
      one: 'سُجِّلت مجموعة واحدة',
      zero: 'لم تُسجَّل أي مجموعة',
    );
    return '$_temp0';
  }

  @override
  String get trainResume => 'استئناف';

  @override
  String get trainDetails => 'التفاصيل';

  @override
  String trainDetailsOf(String title) {
    return 'تفاصيل $title';
  }

  @override
  String get planNeedsReview =>
      'يختلف تغيير في الخطة محفوظ على هذا الهاتف عن حسابك. راجعه من الإشعار أسفل الشاشة.';

  @override
  String get planTrainWithoutPlan => 'التدرّب بلا خطة';

  @override
  String get planTrainWithoutPlanSaid => 'بدء حصة يدوية بلا خطة';

  @override
  String get planSavedAndPast => 'الخطط المحفوظة والسابقة';

  @override
  String planSavedDraftReady(String mode, String date) {
    return 'مسودة · $mode · لم تبدأ · ستبدأ في $date';
  }

  @override
  String planSavedDraftEmpty(String mode) {
    return 'مسودة · $mode · أضف تمارين لاستخدامها';
  }

  @override
  String planSavedDraftOld(String date) {
    return 'مسودة · لم تبدأ · ستبدأ في $date';
  }

  @override
  String get planSavedPaused => 'متوقفة مؤقتًا · ليست خطتك الأساسية';

  @override
  String get planSavedActive => 'نشطة · ليست خطتك الأساسية';

  @override
  String get planStoppedEarly => 'أوقفت مبكرًا';

  @override
  String get planFinishedForNow => 'منتهية حاليًا';

  @override
  String planArchivedCount(int count) {
    return 'الخطط المؤرشفة ($count)';
  }

  @override
  String get planNotStarted => 'لم تبدأ';

  @override
  String get planPaused => 'متوقفة مؤقتًا';

  @override
  String planEnds(String date) {
    return 'تنتهي في $date';
  }

  @override
  String get planOngoingNoEnd => 'مستمرة، بلا تاريخ انتهاء';

  @override
  String planStarts(String date) {
    return 'تبدأ في $date';
  }

  @override
  String get planPausedLine =>
      'الخطة متوقفة مؤقتًا. لا يُنتظر أي حصص جديدة، ولا يُحتسب شيء فائتًا أثناء التوقف.';

  @override
  String get planResume => 'استئناف الخطة';

  @override
  String get planSuggestedChange => 'تغيير مقترح للمراجعة';

  @override
  String get planManage => 'إدارة هذه الخطة';

  @override
  String get planEdit => 'تعديل الخطة';

  @override
  String get planEditSubtitle =>
      'الحصص والتمارين والجدول بدءًا من تاريخ تختاره. لا تتغيّر الحصص المسجّلة أبدًا.';

  @override
  String get planPause => 'إيقاف الخطة مؤقتًا';

  @override
  String get planDuplicate => 'نسخ الخطة';

  @override
  String get planDuplicateSubtitle =>
      'مسودة جديدة بنفس الحصص والجدول. تبقى هذه الخطة كما هي.';

  @override
  String get planReplaceMovement => 'استبدال حركة في الحصص المتبقية';

  @override
  String get planReviewBlockRow => 'مراجعة هذه الكتلة أو إنهاؤها';

  @override
  String get planCreateDifferent => 'إنشاء خطة مختلفة';

  @override
  String get planCreateDifferentSubtitle =>
      'سيُطلب تأكيدك قبل أن تحل محل هذه الخطة عند بدئها.';

  @override
  String get planArchiveNote =>
      'يجب إيقاف خطتك الأساسية مؤقتًا أو إنهاؤها أو استبدالها قبل أرشفتها. يمكن أرشفة الخطط المحفوظة والسابقة من صفحتها.';

  @override
  String get planChooseWeek => 'اختر أسبوعًا';

  @override
  String get planThisWeek => 'هذا الأسبوع';

  @override
  String planCompletedOf(int done, int total) {
    return '$done من $total مكتملة';
  }

  @override
  String get planWeekRailLabel => 'الحصص المكتملة في هذا الأسبوع';

  @override
  String get planNoWorkoutsThisWeek => 'لا توجد حصص مخططة في هذا الأسبوع.';

  @override
  String get planNextInCycle => 'التالية في الدورة';

  @override
  String get planProjected => 'متوقعة';

  @override
  String get planProjectedLower => 'متوقعة';

  @override
  String get planYourCycle => 'دورتك';

  @override
  String planCycleN(int n) {
    return 'الدورة $n';
  }

  @override
  String get planRotationNoteEveryDay =>
      'لا توجد تواريخ ثابتة في التناوب. تنتظرك الحصة التالية حتى تُنهيها أو تتخطاها، وتستمر الدورة عبر الأسابيع. تفترض الأيام القادمة أنك تتدرب كل يوم.';

  @override
  String planRotationNoteDays(String days) {
    return 'لا توجد تواريخ ثابتة في التناوب. تنتظرك الحصة التالية حتى تُنهيها أو تتخطاها، وتستمر الدورة عبر الأسابيع. تتبع الأيام القادمة أيام تدريبك ($days)؛ والبقية أيام راحة.';
  }

  @override
  String get planComingUp => 'القادم';

  @override
  String get planNothingLeft => 'لم يتبقَّ شيء في هذه الخطة.';

  @override
  String get planRecentSessions => 'الحصص الأخيرة';

  @override
  String planCycleStepSemantics(int step, int total, String name) {
    return 'الخطوة $step من $total، $name';
  }

  @override
  String planCycleStepNextSemantics(int step, int total, String name) {
    return 'الخطوة $step من $total، $name، التالية';
  }

  @override
  String planCycleNothingLeft(int cycle) {
    return 'الدورة $cycle · لم يتبقَّ شيء';
  }

  @override
  String planCycleLine(int cycle, int step, int total, String name) {
    return 'الدورة $cycle · الخطوة $step من $total · التالية $name';
  }

  @override
  String planPassSemantics(String title, String week, int done, int total) {
    return '$title. $week. $done / $total حصص مكتملة.';
  }

  @override
  String planPassSemanticsPercent(
    String title,
    String week,
    int done,
    int total,
    String percent,
  ) {
    return '$title. $week. $done / $total حصص مكتملة، $percent.';
  }

  @override
  String planPassRotationSemantics(
    String title,
    String week,
    int count,
    String cycleLine,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$title. $week. $count حصة مكتملة هذا الأسبوع. $cycleLine.',
      many: '$title. $week. $count حصة مكتملة هذا الأسبوع. $cycleLine.',
      few: '$title. $week. $count حصص مكتملة هذا الأسبوع. $cycleLine.',
      two: '$title. $week. حصتان مكتملتان هذا الأسبوع. $cycleLine.',
      one: '$title. $week. حصة واحدة مكتملة هذا الأسبوع. $cycleLine.',
      zero: '$title. $week. لا حصص مكتملة هذا الأسبوع. $cycleLine.',
    );
    return '$_temp0';
  }

  @override
  String get planTrainingPlanOverline => 'خطة التدريب';

  @override
  String get planWorkoutsCompleted => 'الحصص المكتملة';

  @override
  String planSessionsThisWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حصة مكتملة هذا الأسبوع',
      many: 'حصة مكتملة هذا الأسبوع',
      few: 'حصص مكتملة هذا الأسبوع',
      two: 'حصتان مكتملتان هذا الأسبوع',
      one: 'حصة مكتملة هذا الأسبوع',
      zero: 'حصص مكتملة هذا الأسبوع',
    );
    return '$_temp0';
  }

  @override
  String planMovedOriginally(String date) {
    return 'نُقلت · كانت في $date';
  }

  @override
  String get planWeekDone => 'مكتمل';

  @override
  String get planWeekCurrent => 'الحالي';

  @override
  String planWeekPartial(int done, int total) {
    return '$done من $total';
  }

  @override
  String get planWeekMissed => 'فائتة';

  @override
  String get planWeekSkipped => 'تم تخطيها';

  @override
  String get planWeekUpcoming => 'قادم';

  @override
  String get planWeekEmpty => 'لا حصص';

  @override
  String get planThisWeekLower => 'هذا الأسبوع';

  @override
  String get planNoWorkoutsLower => 'لا حصص';

  @override
  String planWorkoutsCompletedOf(int done, int total) {
    return '$done من $total حصص مكتملة';
  }

  @override
  String planPauseTitle(String title) {
    return 'إيقاف $title مؤقتًا؟';
  }

  @override
  String get planPauseBody =>
      'تتوقف الحصص المستقبلية عن كونها متوقعة بدءًا من اليوم، ولن يُحتسب شيء فائتًا أثناء التوقف. يُحتفظ بسجلك وحصصك المتبقية.';

  @override
  String planPauseOpenWorkout(String workout) {
    return 'لا تتأثر حصتك المفتوحة \"$workout\": يستمر توقيتها ويمكنك إنهاؤها.';
  }

  @override
  String get planPauseAction => 'إيقاف هذه الخطة مؤقتًا';

  @override
  String get planPausedToast => 'تم إيقاف الخطة مؤقتًا.';

  @override
  String planMoveHelp(String title) {
    return 'نقل $title إلى';
  }

  @override
  String get planMoveTitle => 'نقل هذه الحصة؟';

  @override
  String planMoveBody(
    String title,
    int week,
    String current,
    String proposed,
    String original,
    String end,
  ) {
    return 'الحصة: $title (الأسبوع $week)\nالتاريخ الحالي: $current\nالتاريخ المقترح: $proposed\nالتاريخ الأصلي: $original\nنهاية الكتلة: $end\n\nتبقى الحصة نفسها في أسبوع التدريب نفسه. لا تتغيّر أي حصة أخرى، ويبقى الجدول المتكرر كما هو.';
  }

  @override
  String get planMoveAction => 'نقل الحصة';

  @override
  String get planMoveCancel => 'الإبقاء على التواريخ الحالية';

  @override
  String planMovedToast(String date) {
    return 'نُقلت إلى $date.';
  }

  @override
  String planSkipTitle(String title) {
    return 'تخطي $title؟';
  }

  @override
  String planSkipBodyRotation(String title) {
    return 'ستُعلَّم $title كمتخطاة اليوم وينتقل التناوب إلى الحصة التي تليها. لا تُوضع تلك الحصة التالية اليوم: تأتي في يوم تدريبك القادم، أو يمكنك بدؤها الآن. لا تُنشأ أي حصة أو مجموعات أو احتساب للإكمال.';
  }

  @override
  String planSkipBodyFixed(String date) {
    return 'ستُعلَّم الحصة المخططة في $date كمتخطاة. لا تُنشأ أي حصة أو مجموعات أو احتساب للإكمال، ولن تُحتسب تدريبًا.';
  }

  @override
  String get planSkipAction => 'تخطي هذه الحصة';

  @override
  String get planSkipCancel => 'الإبقاء عليها';

  @override
  String get planSkippedToast => 'عُلِّمت كمتخطاة.';

  @override
  String planVirtualWhen(String date) {
    return 'مخططة في $date. لا توجد تواريخ ثابتة في التناوب: هذا موعدها إن التزمت بأيام تدريبك.';
  }

  @override
  String planDateOriginally(String date, String original) {
    return '$date · كانت في $original';
  }

  @override
  String get planResumeWorkout => 'استئناف الحصة';

  @override
  String get planViewRecorded => 'عرض ما سُجِّل';

  @override
  String get planUndoSkip => 'التراجع عن التخطي';

  @override
  String get planUnskippedToast => 'لم تعد متخطاة.';

  @override
  String get planSkippedStays => 'متخطاة. تجاوزها التناوب، لذا تبقى متخطاة.';

  @override
  String get planPausedNoStart =>
      'الخطة متوقفة مؤقتًا. استأنفها لبدء حصصها أو إعادة جدولتها.';

  @override
  String get planStartNowRotation => 'بدء هذه الحصة الآن';

  @override
  String get planStartWorkout => 'بدء الحصة';

  @override
  String get planRestInstead => 'الراحة اليوم بدلًا من ذلك';

  @override
  String planRestToast(String title) {
    return 'يوم راحة. لم يُتخطَّ شيء: تنتظر $title يوم تدريبك القادم.';
  }

  @override
  String get planRotationNoMove =>
      'لا توجد تواريخ لنقلها في التناوب: تنتظرك هذه الحصة حتى تؤديها أو تتخطاها.';

  @override
  String planComesAfter(String title) {
    return 'تأتي بعد $title. يسير التناوب بالترتيب: أدِّ التالية أو تخطَّها أولًا.';
  }

  @override
  String get planComesAfterEarlier =>
      'تأتي بعد الحصص التي تسبقها. يسير التناوب بالترتيب: أدِّ التالية أو تخطَّها أولًا.';

  @override
  String planMissedOn(String date) {
    return 'فاتت في $date. انقلها أو تخطَّها أو أدّها الآن. لا تُعلَّم مكتملة من تلقاء نفسها أبدًا.';
  }

  @override
  String get planStartNowMissed => 'البدء الآن';

  @override
  String get planStartEarly => 'بدء هذه الحصة مبكرًا';

  @override
  String get planMoveDate => 'النقل إلى تاريخ آخر';

  @override
  String get planEditOnlyThis => 'تعديل هذه الحصة فقط';

  @override
  String get planChangeSchedule => 'تغيير الجدول';

  @override
  String get planStartDate => 'تاريخ البدء';

  @override
  String get planBlockLength => 'مدة الكتلة';

  @override
  String planTrainingDaysChoose(int count) {
    return 'أيام التدريب (اختر $count)';
  }

  @override
  String get planUpdateDraft => 'تحديث المسودة';

  @override
  String get planCancelKeepSchedule =>
      'الإلغاء والإبقاء على الجدول الذي راجعته';

  @override
  String get planUnreachableDraft =>
      'تعذّر الوصول إلى حسابك. لم تتغيّر المسودة.';

  @override
  String planFinishAndStartTitle(String title) {
    return 'إنهاء $title وبدء هذه الخطة؟';
  }

  @override
  String planPauseAndStartTitle(String title) {
    return 'إيقاف $title مؤقتًا وبدء هذه الخطة؟';
  }

  @override
  String planStartFinishBody(String current, String plan, String date) {
    return 'ستُغلق \"$current\" كمنتهية حاليًا. تصبح \"$plan\" خطتك الأساسية بدءًا من $date. يُحتفظ بكل الحصص المسجّلة.';
  }

  @override
  String planStartPauseBody(String current, String plan, String date) {
    return 'ستُوقف \"$current\" مؤقتًا ولن تُحذف. يمكنك استئنافها لاحقًا. تصبح \"$plan\" خطتك الأساسية بدءًا من $date. يُحتفظ بكل الحصص المسجّلة.';
  }

  @override
  String planOpenWorkoutStaysOpen(String workout) {
    return 'تبقى حصتك المفتوحة \"$workout\" مفتوحة بمجموعاتها المسجّلة؛ ويمكنك إنهاؤها.';
  }

  @override
  String get planFinishAndStart => 'إنهاء وبدء';

  @override
  String get planPauseAndStart => 'إيقاف مؤقت وبدء';

  @override
  String planSavedStarts(String date) {
    return 'حُفظت الخطة. تبدأ في $date.';
  }

  @override
  String get planStarted => 'بدأت خطتك.';

  @override
  String get planDraftNeedsExercises =>
      'مسودة — أضف تمارين لاستخدامها. تحتاج كل حصة مجدولة إلى تمرين واحد على الأقل قبل أن تبدأ الخطة.';

  @override
  String get planStartThis => 'بدء هذه الخطة';

  @override
  String get planFinishBlockStart => 'إنهاء الكتلة الحالية والبدء';

  @override
  String get planReplaceCurrent => 'استبدال خطتي الحالية';

  @override
  String get planSaveForLater => 'حفظ لوقت لاحق';

  @override
  String get planDraftNothingScheduled => 'مسودة · لم يُجدول شيء بعد';

  @override
  String planCycleList(String names) {
    return 'الدورة: $names';
  }

  @override
  String get planAnyDayNext => 'أي يوم: الحصة التالية متاحة متى تدربت.';

  @override
  String planTrainingDaysList(String days) {
    return 'أيام التدريب: $days';
  }

  @override
  String planFirstWorkout(String value) {
    return 'الحصة الأولى: $value';
  }

  @override
  String get planChangeDates => 'تغيير التواريخ أو الأيام أو المدة';

  @override
  String planFollowingFinish(String title) {
    return 'أنت تتبع \"$title\". سيؤدي بدء هذه الخطة إلى إنهائها. يحتاج ذلك إلى تأكيدك الصريح؛ لا يُحذف شيء.';
  }

  @override
  String planFollowingPause(String title) {
    return 'أنت تتبع \"$title\". سيؤدي بدء هذه الخطة إلى إيقافها مؤقتًا. يحتاج ذلك إلى تأكيدك الصريح؛ لا يُحذف شيء.';
  }

  @override
  String get planNextSessions => 'الحصص التالية';

  @override
  String get planFirstWeek => 'الأسبوع الأول';

  @override
  String get planRotationReviewNote =>
      'لا توجد تواريخ ثابتة في التناوب. هذه هي الأيام التي سيقع عليها التسلسل بدءًا من اليوم؛ وينتظرك إن فاتك أحدها.';

  @override
  String get planNoExercisesYetDot => 'لا تمارين بعد.';

  @override
  String get planRepeatOld =>
      'تتكرر الحصص نفسها كل أسبوع بيوم تعافٍ بينها. الأهداف إرشادية؛ ما تسجّله هو ما يُحتسب.';

  @override
  String get planRepeatRotation =>
      'يستمر التسلسل بالترتيب عبر الأسابيع؛ ولا يبدأ من جديد يوم الاثنين أبدًا. لا يتقدم إلا عندما تُنهي حصة أو تتخطاها. الأهداف إرشادية؛ ما تسجّله هو ما يُحتسب.';

  @override
  String get planRepeatFixed =>
      'تتكرر هذه الحصص في أيام الأسبوع نفسها كل أسبوع. الأهداف إرشادية؛ ما تسجّله هو ما يُحتسب.';

  @override
  String planResumeTitle(String title) {
    return 'استئناف $title';
  }

  @override
  String get planResumeAccept => 'الاستئناف بهذه التواريخ';

  @override
  String get planResumedToast => 'استُؤنفت الخطة.';

  @override
  String get planKeepPaused => 'الإبقاء على التوقف المؤقت';

  @override
  String get planNextWorkoutOn => 'الحصة التالية في';

  @override
  String get planResumeDateHelp => 'تاريخ الاستئناف';

  @override
  String planResumeDisplaces(String title) {
    return 'يجعلها هذا خطتك الأساسية ويوقف \"$title\" مؤقتًا.';
  }

  @override
  String get planResumeNoChanges =>
      'لا حاجة لتغيير أي تاريخ. تحتفظ الحصص المتبقية بتواريخها الحالية.';

  @override
  String get planResumeShifts =>
      'تنتقل كل حصة متبقية بعدد الأيام نفسه مع الحفاظ على تباعدها. تحتفظ الحصص المسجّلة والمتخطاة والجارية بتواريخها.';

  @override
  String planBlockWouldEnd(String date) {
    return 'ستنتهي الكتلة في $date.';
  }

  @override
  String planCloseOpenWorkout(String workout) {
    return 'يمكن إنهاء حصتك المفتوحة \"$workout\" لاحقًا؛ وتبقى نتيجتها مع هذه الكتلة.';
  }

  @override
  String get planBlockClosedToast => 'أُغلقت الكتلة. يُحتفظ بسجلك.';

  @override
  String get planReviewBlock => 'مراجعة هذه الكتلة';

  @override
  String get planCountFinished => 'مكتملة';

  @override
  String get planCountPartial => 'جزئية';

  @override
  String get planCountRemaining => 'قادمة أو جارية';

  @override
  String get planCountsNote =>
      'تأتي الأعداد مما سُجِّل فعلًا لكل حصة مخططة. بلوغ تاريخ النهاية لا يعني بحد ذاته أن التدريب حدث.';

  @override
  String get planBlockStoppedEarly => 'أوقفت هذه الكتلة مبكرًا.';

  @override
  String get planBlockFinished => 'انتهت هذه الكتلة حاليًا.';

  @override
  String get planContinueGoal => 'مواصلة هذا الهدف';

  @override
  String get planNextBlockStarts => 'تبدأ الكتلة التالية';

  @override
  String get planUnreachableNothingCreated =>
      'تعذّر الوصول إلى حسابك. لم يُنشأ شيء.';

  @override
  String get planContinueNote =>
      'يُنشئ مسودة جديدة بالإعداد نفسه. لا تبدأ حتى تراجعها وتبدأها.';

  @override
  String get planFinishForNow => 'الإنهاء حاليًا';

  @override
  String get planCloseBlockTitle => 'إغلاق هذه الكتلة؟';

  @override
  String get planCloseBlockBody =>
      'تُغلق الكتلة كمنتهية حاليًا ويُحرَّر مكان خطتك الأساسية. لا يعني هذا أن الهدف قد تحقق.';

  @override
  String get planCloseBlockAction => 'إغلاق هذه الكتلة';

  @override
  String get planStopEarly => 'الإيقاف مبكرًا';

  @override
  String get planStopTitle => 'إيقاف هذه الكتلة مبكرًا؟';

  @override
  String planStopBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'لن تُنتظر $count حصة مخططة بعد الآن. تُسجَّل الكتلة كموقوفة مبكرًا، لا كمنتهية.',
      many:
          'لن تُنتظر $count حصة مخططة بعد الآن. تُسجَّل الكتلة كموقوفة مبكرًا، لا كمنتهية.',
      few:
          'لن تُنتظر $count حصص مخططة بعد الآن. تُسجَّل الكتلة كموقوفة مبكرًا، لا كمنتهية.',
      two: 'لن تُنتظر حصتان مخططتان بعد الآن. تُسجَّل الكتلة كموقوفة مبكرًا، لا كمنتهية.',
      one: 'لن تُنتظر حصة مخططة واحدة بعد الآن. تُسجَّل الكتلة كموقوفة مبكرًا، لا كمنتهية.',
      zero: 'لن تُنتظر أي حصة مخططة بعد الآن. تُسجَّل الكتلة كموقوفة مبكرًا، لا كمنتهية.',
    );
    return '$_temp0';
  }

  @override
  String get planStopAction => 'إيقاف هذه الكتلة';

  @override
  String get planResumeAsPrimary => 'الاستئناف كخطتي الأساسية';

  @override
  String get planDuplicateAsNew => 'النسخ كخطة جديدة';

  @override
  String get planUnarchive => 'إخراج من الأرشيف';

  @override
  String get planArchiveHide => 'أرشفة (إخفاء من هذه القائمة)';

  @override
  String get planRestoredToast => 'أُعيدت إلى خططك.';

  @override
  String get planArchivedToast => 'أُرشفت. لم تتغيّر نتيجتها ولا سجلها.';

  @override
  String get planNotDone => 'لم تُؤدَّ';

  @override
  String get planArchivedTitle => 'الخطط المؤرشفة';

  @override
  String get planArchivedNote =>
      'الأرشفة تُخفي الخطة فقط. لا تتغيّر نتيجتها ولا حصصها المسجّلة.';

  @override
  String get planReplaceMovementTitle => 'استبدال حركة';

  @override
  String get planShowChange => 'اعرض لي التغيير';

  @override
  String get planUnreachableNothingChanged =>
      'تعذّر الوصول إلى حسابك. لم يتغيّر شيء.';

  @override
  String get planProposalDeclinedUnchanged =>
      'اخترت بالفعل الإبقاء على الخطة الحالية لهذا التغيير تحديدًا.';

  @override
  String get planNothingToChange => 'لا يوجد ما يتغيّر لهذا الاختيار.';

  @override
  String get planSubstitutionNote =>
      'لا تتأثر إلا الحصص المتبقية التي لم تبدأ. ستراجع التغيير بدقة قبل تطبيقه.';

  @override
  String get planReplaceLabel => 'استبدال';

  @override
  String get planNoMovement => 'لا توجد حصة متبقية فيها حركة لاستبدالها.';

  @override
  String get planWith => 'بـ';

  @override
  String get planChooseMovement => 'اختر حركة';

  @override
  String get planReplaceWith => 'الاستبدال بـ';

  @override
  String get planCustomNotInPlanChange =>
      'اختر حركة من القائمة. يمكن استخدام الحركات المخصصة داخل حصة، لا في تغيير الخطة.';

  @override
  String get planChangeApplied => 'طُبِّق التغيير على الحصص التي راجعتها.';

  @override
  String get planKeptCurrent => 'أُبقي على خطتك الحالية.';

  @override
  String get planSuggestionStale =>
      'لم يعد هذا الاقتراح متوافقًا مع خطتك أو سجلاتك، لذا لم يُطبَّق. لم يتغيّر شيء.';

  @override
  String get planSuggestedChangeTitle => 'تغيير مقترح';

  @override
  String get planAcceptChange => 'قبول هذا التغيير';

  @override
  String get planKeepCurrent => 'الإبقاء على الخطة الحالية';

  @override
  String get planDismissSuggestion => 'تجاهل هذا الاقتراح';

  @override
  String get planProposalStaleLine =>
      'تغيّرت خطتك أو حصصك المسجّلة بعد هذا الاقتراح، لذا لم يعد بالإمكان تطبيقه كما رُوجع. اطلبه مجددًا إن كنت لا تزال تريده.';

  @override
  String get planAcceptedLine => 'قبلت هذا التغيير.';

  @override
  String get planDeclinedLine => 'أبقيت على خطتك الحالية.';

  @override
  String planAffects(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يؤثر في $count حصة لم تبدأ',
      many: 'يؤثر في $count حصة لم تبدأ',
      few: 'يؤثر في $count حصص لم تبدأ',
      two: 'يؤثر في حصتين لم تبدآ',
      one: 'يؤثر في حصة واحدة لم تبدأ',
      zero: 'لا يؤثر في أي حصة لم تبدأ',
    );
    return '$_temp0';
  }

  @override
  String planProposalMove(String from, String to) {
    return 'الآن $from  ←  المقترح $to';
  }

  @override
  String planProposalNow(String from, String to) {
    return 'الآن: $from\nالمقترح: $to';
  }

  @override
  String get planProposalNote =>
      'لا يغيّر الاقتراح أبدًا الحصص المسجّلة أو الجارية.';

  @override
  String get builderStepAvailability => 'التوفّر';

  @override
  String get builderStepStructure => 'البنية';

  @override
  String get builderStepWorkouts => 'الحصص';

  @override
  String get builderStepReview => 'المراجعة';

  @override
  String get builderStartOverTitle => 'البدء من جديد؟';

  @override
  String get builderDiscardAction => 'تجاهلها';

  @override
  String get builderDiscardBody =>
      'تُحذف الخطة قيد الإعداد من هذا الهاتف. لا يتغيّر شيء آخر: لم تُنشأ أي خطة منها.';

  @override
  String get builderCreatePlan => 'إنشاء خطة';

  @override
  String get builderUntitled => 'خطة بلا اسم';

  @override
  String builderStepSaved(int step, String name) {
    return 'الخطوة $step من 4 · $name. محفوظة على هذا الهاتف؛ لا شيء نشط بعد.';
  }

  @override
  String get builderContinuePlan => 'متابعة هذه الخطة';

  @override
  String get builderStartOver => 'البدء من جديد';

  @override
  String get builderStartOverSaid =>
      'البدء من جديد وتجاهل هذه الخطة قيد الإعداد';

  @override
  String get builderBothWays =>
      'كلتا الطريقتين تُنشئ خطة خاصة بك يمكنك تغييرها في أي وقت.';

  @override
  String get builderGuideMe => 'أرشدني';

  @override
  String get builderGuideMeAbout => 'ساعدني في اختيار خطة بداية.';

  @override
  String get builderKnowWhat => 'أعرف ما أريد';

  @override
  String get builderKnowWhatAbout => 'اختيار قالب أو إنشاء خطتي الخاصة.';

  @override
  String builderChoiceSemantics(String label, String about) {
    return '$label. $about';
  }

  @override
  String get builderFromTemplate => 'البدء من قالب';

  @override
  String get builderFromTemplateSubtitle =>
      'استعرض تقسيمًا مألوفًا مثل علوي / سفلي أو دفع / سحب / أرجل، ثم اجعله خاصًا بك.';

  @override
  String get builderBuildOwn => 'إنشاء خطتي الخاصة';

  @override
  String get builderBuildOwnSubtitle => 'سمِّ حصصك وأضف التمارين ونظّم أسبوعك.';

  @override
  String get builderPlanChanged =>
      'تغيّرت هذه الخطة منذ آخر تعديل لك، لذا تبدأ من الخطة كما هي الآن.';

  @override
  String get builderContinueChangesTitle => 'متابعة تغييراتك؟';

  @override
  String get builderContinueChanges => 'متابعة التغييرات';

  @override
  String get builderStartFromSaved => 'البدء من الخطة المحفوظة';

  @override
  String builderContinueChangesBody(String title) {
    return 'كنت تعدّل \"$title\" ولم تحفظ. تابع من حيث توقفت، أو ابدأ من جديد من الخطة كما هي الآن.';
  }

  @override
  String get builderReplaceInProgressTitle => 'استبدال خطتك قيد الإعداد؟';

  @override
  String get builderReplaceIt => 'استبدالها';

  @override
  String builderReplaceInProgressBody(String existing, String plan) {
    return '\"$existing\" لم تكتمل. يؤدي نسخ \"$plan\" إلى استبدالها على هذا الهاتف.';
  }

  @override
  String get builderSaveFailed =>
      'تعذّر حفظ آخر تغيير على هذا الهاتف. أبقِ هذه الشاشة مفتوحة وحاول مجددًا.';

  @override
  String get builderHelpWeek => 'مساعدة في أسبوعك التدريبي';

  @override
  String get builderCoachWeek =>
      'اختر الأيام التي يمكنك التدرب فيها ومعداتك. تقترح الخطوة التالية نقطة بداية بناءً على هذه الإجابات.';

  @override
  String get builderAskWeek => 'أسبوعك التدريبي';

  @override
  String get builderHelpSplit => 'مساعدة في اختيار التقسيم';

  @override
  String get builderCoachSplit =>
      'لست متأكدًا من التقسيم المناسب لأسبوعك؟ لنقارن خياراتك.';

  @override
  String get builderAskSplit => 'اختيار تقسيم';

  @override
  String get builderCompareSplits => 'مقارنة التقسيمات';

  @override
  String get builderHelpWorkouts => 'مساعدة في هذه الحصص';

  @override
  String get builderCoachWorkouts =>
      'أسئلة عن المجموعات أو التكرارات أو حركة ما؟ زر المعلومات بجانب كل تمرين يفتح الدليل المدمج.';

  @override
  String get builderChooseDay => 'اختر يومًا واحدًا على الأقل.';

  @override
  String get builderChooseStarting => 'اختر خطة بداية للمتابعة.';

  @override
  String builderPauseActivateTitle(String title) {
    return 'إيقاف $title مؤقتًا وتفعيل هذه الخطة؟';
  }

  @override
  String get builderPauseActivate => 'إيقاف مؤقت وتفعيل';

  @override
  String builderPauseActivateBody(String current, String plan, String date) {
    return 'ستُوقف \"$current\" مؤقتًا ولن تُحذف. يُحتفظ بسجلها وحصصها المسجّلة، ويمكنك استئنافها لاحقًا. تصبح \"$plan\" خطتك بدءًا من $date.';
  }

  @override
  String builderOpenWorkoutStays(String workout) {
    return 'تبقى حصتك المفتوحة \"$workout\" مفتوحة بمجموعاتها المسجّلة.';
  }

  @override
  String builderActiveStarts(String title, String date) {
    return '\"$title\" نشطة. تبدأ في $date.';
  }

  @override
  String builderActive(String title) {
    return '\"$title\" نشطة.';
  }

  @override
  String get builderDraftSaved =>
      'حُفظت المسودة على هذا الهاتف. لا شيء نشط بعد.';

  @override
  String get builderChangesSaved => 'حُفظت التغييرات.';

  @override
  String builderChangesSavedFrom(String date) {
    return 'حُفظت التغييرات بدءًا من $date.';
  }

  @override
  String get builderBack => 'رجوع';

  @override
  String get builderNext => 'التالي';

  @override
  String get builderSaveChanges => 'حفظ التغييرات';

  @override
  String get builderActivate => 'تفعيل الخطة';

  @override
  String get builderSaveDraft => 'حفظ المسودة';

  @override
  String builderProgressSemantics(int step, String name) {
    return 'الخطوة $step من 4: $name';
  }

  @override
  String builderProgressOverline(int step, String name) {
    return 'الخطوة $step من 4 · $name';
  }

  @override
  String builderDefaultWorkoutName(String letter) {
    return 'الحصة $letter';
  }

  @override
  String get builderPrefsGuided =>
      'أجب عن هذه الأسئلة وستقترح الخطوة التالية خطة بداية بناءً عليها، مع ما يصل إلى بديلين. لا يُنشأ شيء حتى تختار، ويمكنك تغيير كل شيء لاحقًا.';

  @override
  String get builderPrefsIntro =>
      'بضع إجابات لاقتراح نقطة بداية. يمكنك تغيير كل شيء لاحقًا.';

  @override
  String get builderDaysAWeek => 'أيام في الأسبوع';

  @override
  String builderDaysAWeekCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم في الأسبوع',
      many: '$count يومًا في الأسبوع',
      few: '$count أيام في الأسبوع',
      two: 'يومان في الأسبوع',
      one: 'يوم واحد في الأسبوع',
      zero: 'لا أيام في الأسبوع',
    );
    return '$_temp0';
  }

  @override
  String get builderWhichDays => 'أي الأيام';

  @override
  String get builderEquipment => 'المعدات';

  @override
  String get builderPlannedTime => 'الوقت المخطط لكل حصة (اختياري)';

  @override
  String get builderNoLimit => 'بلا حد';

  @override
  String get builderPlannedTimeNote =>
      'الوقت الذي تخطط لقضائه. إنه اختيارك، وليس مدة محسوبة للحصة.';

  @override
  String get builderAddExperience => 'إضافة خبرتك التدريبية (اختياري)';

  @override
  String get builderExperience => 'الخبرة التدريبية (اختياري)';

  @override
  String get builderReplaceWorkoutsTitle => 'استبدال حصصك؟';

  @override
  String get builderReplaceThem => 'استبدالها';

  @override
  String builderReplaceWorkoutsBody(String source, String now, String next) {
    return 'يبدأ هذا الحصص من جديد من $source.\n\nالآن: $now\nبعد ذلك: $next\n\nلا يُحتفظ بالتغييرات التي أجريتها على التمارين.';
  }

  @override
  String get builderYourOwnNames => 'أسمائك الخاصة';

  @override
  String get builderUsingStarting =>
      'تُستخدم خطة البداية هذه. إنها مسودة: غيّر أي شيء في الخطوات التالية.';

  @override
  String get builderUseStarting => 'استخدام خطة البداية هذه';

  @override
  String builderAnswersChanged(String name) {
    return 'تقترح إجاباتك الآن $name. تبقى حصصك المعدّلة كما هي ما لم تختر «استخدام خطة البداية هذه» أدناه.';
  }

  @override
  String get builderSuggestedStarting => 'خطة البداية المقترحة';

  @override
  String get builderYourWeek => 'أسبوعك';

  @override
  String get builderWhySuggestion => 'لماذا هذا الاقتراح؟';

  @override
  String get builderOtherStartingPoints => 'نقاط بداية أخرى';

  @override
  String get builderAlsoFits => 'يناسب أيامك أيضًا';

  @override
  String get builderRest => 'راحة';

  @override
  String get builderRestSubtitle => 'لا حصة في هذا اليوم';

  @override
  String get builderAddStep => 'إضافة خطوة';

  @override
  String get builderPlanLength => 'مدة الخطة';

  @override
  String get builderWeeks => 'الأسابيع';

  @override
  String get builderWeeksHelper => 'من 1 إلى 52 أسبوعًا';

  @override
  String get builderWeeksError => 'اختر من 1 إلى 52 أسبوعًا.';

  @override
  String get builderUseLength => 'استخدام هذه المدة';

  @override
  String get builderTemplateCustomPreview => 'سمِّ حصصك الخاصة واختر أيامها.';

  @override
  String builderTemplateWeekly(int count, String names) {
    return 'أيامك الـ$count: $names';
  }

  @override
  String builderTemplateRotates(String names, int count) {
    return 'تتناوب $names على أيامك الـ$count';
  }

  @override
  String builderSuggestedLine(String name, String reason) {
    return 'المقترح: $name. $reason';
  }

  @override
  String builderTemplateSuggested(String name) {
    return '$name · مقترح';
  }

  @override
  String get builderIncludeExercises => 'تضمين تمارين البداية';

  @override
  String get builderWithExercisesOn =>
      'روتين بداية بمجموعات وتكرارات وراحة دون أوزان. غيّر أي شيء في الخطوة التالية.';

  @override
  String get builderWithExercisesOff =>
      'تبدأ الحصص فارغة. تبقى الخطة مسودة حتى يكون لكل حصة مجدولة تمرين.';

  @override
  String get builderYourWorkouts => 'حصصك';

  @override
  String get builderNameOnce =>
      'سمِّ كل حصة مختلفة مرة واحدة. يمكن أن تتكرر الحصة في عدة أيام.';

  @override
  String builderWorkoutN(int n) {
    return 'الحصة $n';
  }

  @override
  String builderWorkoutNLower(int n) {
    return 'الحصة $n';
  }

  @override
  String get builderGiveName => 'أعطها اسمًا.';

  @override
  String builderRemoveNamed(String name) {
    return 'إزالة $name';
  }

  @override
  String builderRemoveTitle(String name) {
    return 'إزالة $name؟';
  }

  @override
  String get builderRemoveBody =>
      'تُزال تمارينها معها، وكل يوم أو خطوة استخدمتها.';

  @override
  String get builderAddAWorkout => 'إضافة حصة';

  @override
  String get builderFixedNote =>
      'حصة واحدة لكل يوم من أيام الأسبوع. يمكن استخدام الحصة في عدة أيام. تبقى الحصة الفائتة في يومها حتى تنقلها أو تتخطاها.';

  @override
  String get builderTheCycle => 'الدورة';

  @override
  String get builderCycleNote =>
      'تتبع الحصص هذا الترتيب وتبدأ من الأول عند انتهائه. يستمر الترتيب عبر الأسابيع؛ ولا يبدأ من جديد يوم الاثنين.';

  @override
  String builderMoveStepUp(int n) {
    return 'نقل الخطوة $n لأعلى';
  }

  @override
  String builderMoveStepDown(int n) {
    return 'نقل الخطوة $n لأسفل';
  }

  @override
  String builderRemoveStep(int n) {
    return 'إزالة الخطوة $n';
  }

  @override
  String get builderTrainingDays => 'أيام التدريب';

  @override
  String get builderTrainingDaysNote =>
      'تُوضع الحصة التالية في أقرب هذه الأيام. إن لم تختر أيًا منها، يمكن أن يكون أي يوم يوم تدريب.';

  @override
  String get builderPlanName => 'اسم الخطة';

  @override
  String get builderName => 'الاسم';

  @override
  String get builderSchedule => 'الجدول';

  @override
  String get builderModeLocked =>
      'تحتفظ الخطة النشطة بنوع جدولها. انسخها للتبديل.';

  @override
  String get builderFixedExplain =>
      'أيام ثابتة: لكل حصة يومها الخاص، وتبقى الفائتة في يومها.';

  @override
  String get builderRotatingExplain =>
      'تسلسل متناوب: دورة مرتبة تستمر عبر الأسابيع ولا تتقدم إلا عندما تُنهي حصة أو تتخطاها.';

  @override
  String get builderStartAndLength => 'البداية والمدة';

  @override
  String get builderStarts => 'تبدأ';

  @override
  String get builderStartLocked => 'تحتفظ الخطة النشطة بتاريخ بدايتها.';

  @override
  String get builderPlanStartsHelp => 'بداية الخطة';

  @override
  String get builderOtherLength => 'مدة أخرى';

  @override
  String get builderRotationLength =>
      'يمكن أن يستمر التناوب من 1 إلى 52 أسبوعًا، أو بلا نهاية.';

  @override
  String get builderFixedLength =>
      'للخطة ذات الأيام الثابتة نهاية: من 1 إلى 52 أسبوعًا.';

  @override
  String builderFromDate(String date) {
    return 'بدءًا من $date';
  }

  @override
  String get builderSecondWeek => 'الأسبوع الثاني';

  @override
  String builderReviewSummary(int count, String weeks, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count حصة خلال $weeks، آخرها في $date. يتكرر الأسبوع نفسه حتى ذلك الحين.',
      many:
          '$count حصة خلال $weeks، آخرها في $date. يتكرر الأسبوع نفسه حتى ذلك الحين.',
      few:
          '$count حصص خلال $weeks، آخرها في $date. يتكرر الأسبوع نفسه حتى ذلك الحين.',
      two:
          'حصتان خلال $weeks، آخرهما في $date. يتكرر الأسبوع نفسه حتى ذلك الحين.',
      one:
          'حصة واحدة خلال $weeks، آخرها في $date. يتكرر الأسبوع نفسه حتى ذلك الحين.',
      zero: 'لا حصص خلال $weeks. يتكرر الأسبوع نفسه حتى ذلك الحين.',
    );
    return '$_temp0';
  }

  @override
  String builderCycleThenAgain(String names) {
    return 'الدورة: $names، ثم تبدأ من جديد.';
  }

  @override
  String get builderAnyDayTraining => 'يمكن أن يكون أي يوم يوم تدريب.';

  @override
  String builderTrainingDaysDot(String days) {
    return 'أيام التدريب: $days.';
  }

  @override
  String get builderNextIfTrain => 'الحصص التالية إن تدربت في كل يوم تدريب';

  @override
  String get builderProjectionNote =>
      'هذه التواريخ توقّع. لا يؤدي اليوم الفائت إلى تخطي حصة: تنتظرك الحصة نفسها في يوم تدريبك القادم.';

  @override
  String builderPlannedTimeLower(int minutes) {
    return 'الوقت المخطط $minutes د';
  }

  @override
  String builderDraftMissing(String names) {
    return 'مسودة — أضف تمارين إلى $names قبل أن يمكن تفعيل هذه الخطة.';
  }

  @override
  String builderFollowingActivate(String title) {
    return 'أنت تتبع \"$title\". يؤدي تفعيل هذه الخطة إلى إيقافها مؤقتًا. يُحتفظ بسجلها وحصصها المسجّلة، ويمكنك استئنافها لاحقًا.';
  }

  @override
  String get builderChangesApplyFrom => 'تُطبَّق التغييرات بدءًا من';

  @override
  String get builderEditKeeps =>
      'تبقى الحصص التي سجّلتها أو تخطيتها، والحصة الجارية، كما هي تمامًا. لا تتغيّر الحصص السابقة ولا أي حصة عدّلتها وحدها.';

  @override
  String get builderRebuilt =>
      'لم تبدأ هذه الخطة، لذا يُعاد بناؤها بهذه التغييرات.';

  @override
  String get builderNoExercises => 'لا تمارين بعد';

  @override
  String get builderTargetsNote =>
      'الأهداف نقطة بداية، لا وصفة. ما تسجّله هو ما يُحتسب.';

  @override
  String builderUsageSteps(int count, String steps) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'الخطوات $steps',
      many: 'الخطوات $steps',
      few: 'الخطوات $steps',
      two: 'الخطوتان $steps',
      one: 'الخطوة $steps',
      zero: 'الخطوات $steps',
    );
    return '$_temp0';
  }

  @override
  String get builderRxSetsError => 'المجموعات: عدد صحيح من 1 إلى 20.';

  @override
  String get builderRxRepsError => 'التكرارات: من 1 إلى 100.';

  @override
  String get builderRxRepsOrder =>
      'لا يمكن أن يكون أعلى عدد تكرارات أقل من أدناه.';

  @override
  String get builderRxTimeError => 'الوقت: من 1 إلى 3600 ثانية.';

  @override
  String get builderRxRestError => 'الراحة: من 0 إلى 900 ثانية (15 دقيقة).';

  @override
  String builderRxLoadError(String max) {
    return 'وزن من 0 إلى $max، أو اتركه فارغًا.';
  }

  @override
  String get builderRxNotesError => 'الملاحظات: حتى 500 حرف.';

  @override
  String get builderRxHelp => 'مساعدة في المجموعات والتكرارات وهذا التمرين';

  @override
  String get builderRxSets => 'المجموعات';

  @override
  String get builderRxSeconds => 'الوقت لكل مجموعة (ثوانٍ)';

  @override
  String get builderRxRepsMin => 'التكرارات، الأدنى';

  @override
  String get builderRxRepsMax => 'التكرارات، الأعلى';

  @override
  String get builderRxRepsHelper => 'العدد نفسه مرتين هدف محدد.';

  @override
  String get builderRxRest => 'الراحة بين المجموعات (ثوانٍ)';

  @override
  String builderRxLoad(String unit) {
    return 'الوزن المستهدف ($unit)، اختياري';
  }

  @override
  String get builderRxLoadHelper =>
      'هدف تضعه لنفسك. ليس آخر وزن سجّلته، ولا يملؤه التطبيق أبدًا.';

  @override
  String get builderRxNotes => 'ملاحظات، اختياري';

  @override
  String get builderCoachExercise =>
      'أسئلة عن المجموعات أو التكرارات أو هذه الحركة؟';

  @override
  String get builderAboutExercise => 'عن هذا التمرين';

  @override
  String builderReplaceExercise(String name) {
    return 'استبدال $name';
  }

  @override
  String get builderNoExercisesWarn =>
      'لا تمارين بعد. أضف تمرينًا واحدًا على الأقل لتتمكن من جدولة هذه الحصة.';

  @override
  String get builderEditRx => 'تعديل المجموعات والتكرارات والراحة';

  @override
  String builderAbout(String name) {
    return 'عن $name';
  }

  @override
  String builderMoveUp(String name) {
    return 'نقل $name لأعلى';
  }

  @override
  String builderMoveDown(String name) {
    return 'نقل $name لأسفل';
  }

  @override
  String builderMoreFor(String name) {
    return 'المزيد لـ$name';
  }

  @override
  String get builderReplaceWithAnother => 'الاستبدال بتمرين آخر';

  @override
  String get builderAddExercise => 'إضافة تمرين';

  @override
  String builderAddTo(String name) {
    return 'إضافة إلى $name';
  }

  @override
  String get builderCopyWorkout => 'نسخ حصة';

  @override
  String get builderCopyNote =>
      'تصبح النسخة حصة جديدة في هذه الخطة بنفس التمارين. لا شيء يربطها بمصدرها.';

  @override
  String get builderThisPlan => 'هذه الخطة';

  @override
  String get builderRecordedSection => 'الحصص التي سجّلتها (تمارينها المخططة)';

  @override
  String get builderCopied => 'نُسخت. اختر أيامها في «البنية» لجدولتها.';

  @override
  String get builderWorkoutsIntro =>
      'اضغط على تمرين لتغيير مجموعاته وتكراراته وراحته. الأهداف نقطة بداية؛ ما تسجّله هو ما يُحتسب.';

  @override
  String get builderNotScheduled => 'لم تُجدول بعد. اختر أيامها في «البنية».';

  @override
  String get builderRename => 'إعادة تسمية';

  @override
  String get builderDuplicate => 'نسخ';

  @override
  String get builderRenameWorkout => 'إعادة تسمية الحصة';

  @override
  String builderDeleteTitle(String name) {
    return 'حذف $name؟';
  }

  @override
  String get builderDeleteWorkout => 'حذف الحصة';

  @override
  String get builderDeleteBody =>
      'تُزال من هذه الخطة ومن كل يوم أو خطوة تستخدمها. تحتفظ الحصص التي سجّلتها بنسختها الخاصة.';

  @override
  String get builderAddWorkout => 'إضافة الحصة';

  @override
  String get builderNewWorkout => 'حصة جديدة';

  @override
  String get builderCopyFrom => 'النسخ من…';

  @override
  String get builderGiveWorkoutName => 'أعطِ الحصة اسمًا.';

  @override
  String builderSavedOnly(String date) {
    return 'حُفظت ليوم $date فقط.';
  }

  @override
  String get builderThisWorkoutOnly => 'هذه الحصة فقط';

  @override
  String get builderSaveThisWorkout => 'حفظ هذه الحصة';

  @override
  String builderOnlyThisChanges(String date, String plan) {
    return 'تتغيّر الحصة في $date فقط. يبقى باقي \"$plan\" كما هو، ولا تمس التغييرات اللاحقة على الخطة هذه الحصة.';
  }

  @override
  String get builderWorkoutName => 'اسم الحصة';

  @override
  String runActivityTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'مشي',
      'other': 'جري',
    });
    return '$_temp0';
  }

  @override
  String get runTitle => 'الجري / المشي';

  @override
  String get runHistory => 'السجل';

  @override
  String get runHelpAvatar => 'مساعدة في الجري / المشي';

  @override
  String get runCoachReadyIntervals =>
      'الفترات جاهزة. ابدأ عندما تكون مستعدًا.';

  @override
  String get runCoachReady => 'اختر إعداداتك. ابدأ عندما تكون مستعدًا.';

  @override
  String get runHelpBody =>
      'اختر الجري أو المشي، ثم ابدأ. يسجّل GoHard مسارك والشاشة مقفلة أو أثناء فتح تطبيق آخر، ويحفظه على هذا الهاتف أولًا. أوقف مؤقتًا متى شئت؛ ويتيح لك «إنهاء» المراجعة قبل الحفظ. تتناوب الفترات بين الجري والمشي في نشاط واحد؛ ومع تشغيل الصوت والتنبيهات أعلن كل تغيير بصوت مسموع.';

  @override
  String runStartButton(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'ابدأ المشي',
      'other': 'ابدأ الجري',
    });
    return '$_temp0';
  }

  @override
  String runStartIntervalsButton(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'ابدأ فترات المشي',
      'other': 'ابدأ فترات الجري',
    });
    return '$_temp0';
  }

  @override
  String get runStartNoGpsTitle => 'البدء بدون GPS؟';

  @override
  String get runStartNoGpsBody =>
      'يُسجَّل الوقت، ويمكنك كتابة المسافة عند الانتهاء. لا يُسجَّل أي مسار أو مسافة GPS.';

  @override
  String get runStartNoGpsAction => 'ابدأ المؤقّت فقط';

  @override
  String runStartFailed(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'تعذّر بدء المشي على هذا الهاتف. لم يُسجَّل شيء.',
      'other': 'تعذّر بدء الجري على هذا الهاتف. لم يُسجَّل شيء.',
    });
    return '$_temp0';
  }

  @override
  String get runStateOn => 'مُفعّل';

  @override
  String get runStateOff => 'متوقف';

  @override
  String runVoiceValueEvery(String interval) {
    return 'مُفعّل · كل $interval';
  }

  @override
  String get runMapNoPosition => 'الخريطة، لا يوجد موقع بعد';

  @override
  String get runMapHere => 'خريطة تُظهر موقعك الحالي';

  @override
  String get runMapTitle => 'الخريطة';

  @override
  String get runSimulatedGps => 'GPS محاكى (نسخة اختبار)';

  @override
  String get runSetupTitle => 'إعداداتك';

  @override
  String get runSetupIntervals => 'الفترات';

  @override
  String get runSetupVoice => 'الصوت والتنبيهات';

  @override
  String get runSetupAutoPause => 'الإيقاف التلقائي';

  @override
  String get runAutoPauseNotWithIntervals => 'غير مستخدم مع الفترات';

  @override
  String get runAutoPauseSubtitle =>
      'يتوقف مؤقتًا عندما تتوقف لفترة ويستأنف عندما تتحرك مجددًا.';

  @override
  String get runAutoPauseIntervalsNote =>
      'غير مستخدم مع الفترات: المشي للتعافي ليس إيقافًا مؤقتًا. ينطبق هذا الاختيار على جريك ومشيك الحر.';

  @override
  String runPlanShort(String run, String walk, int reps) {
    return 'جري $run · مشي $walk · × $reps';
  }

  @override
  String get runGpsChecking => 'جارٍ التحقق من GPS…';

  @override
  String get runGpsCheckingDetail =>
      'جارٍ قراءة إعدادات الموقع على هذا الهاتف.';

  @override
  String get runGpsOff => 'الموقع متوقف';

  @override
  String get runGpsOffDetail => 'شغّل الموقع لتسجيل مسار.';

  @override
  String get runGpsOpenSettings => 'افتح الإعدادات';

  @override
  String get runGpsNotAllowed => 'الموقع غير مسموح به بعد';

  @override
  String get runGpsNotAllowedDetail =>
      'اسمح بالوصول إلى الموقع أثناء استخدام GoHard لتسجيل مسارك.';

  @override
  String get runGpsAllow => 'السماح';

  @override
  String get runGpsBlocked => 'الموقع محظور على GoHard';

  @override
  String get runGpsBlockedDetail =>
      'اسمح به من الإعدادات، أو ابدأ بالمؤقّت فقط.';

  @override
  String get runGpsOpenAppSettings => 'افتح إعدادات التطبيق';

  @override
  String get runGpsApproximate => 'الموقع الدقيق متوقف';

  @override
  String get runGpsApproximateDetail => 'لا يمكن للموقع التقريبي قياس مسار.';

  @override
  String get runGpsAllowPrecise => 'السماح بالموقع الدقيق';

  @override
  String get runGpsUnavailable => 'الموقع غير متاح';

  @override
  String get runGpsUnavailableDetail => 'لا يزال بإمكانك البدء بالمؤقّت فقط.';

  @override
  String get runGpsWaiting => 'في انتظار GPS…';

  @override
  String get runGpsWaitingDetail =>
      'في الخارج، مع رؤية واضحة للسماء، يستغرق ذلك بضع ثوانٍ.';

  @override
  String get runGpsReady => 'GPS جاهز';

  @override
  String get runGpsWeak => 'إشارة GPS ضعيفة';

  @override
  String get runGpsSignalGood => 'إشارة جيدة';

  @override
  String get runGpsSignalFair => 'إشارة متوسطة';

  @override
  String get runGpsSignalWeak => 'إشارة ضعيفة';

  @override
  String runGpsAccuracyDetail(String quality, String accuracy) {
    return '$quality · الدقة $accuracy';
  }

  @override
  String get runStatusPaused => 'متوقف مؤقتًا';

  @override
  String get runStatusAutoPaused => 'إيقاف تلقائي';

  @override
  String get runStatusInterrupted => 'متقطّع';

  @override
  String get runMapRouteSoFar => 'المسار حتى الآن';

  @override
  String runMapRouteSoFarDistance(String distance) {
    return 'المسار حتى الآن، $distance';
  }

  @override
  String get runFinish => 'إنهاء';

  @override
  String get runResume => 'استئناف';

  @override
  String get runPause => 'إيقاف مؤقت';

  @override
  String runInterruptedLegacy(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'بدأ هذا المشي قبل حفظ المسارات. يُحتفظ بوقته ومسافته حتى الآن؛ استأنف لتسجيل الباقي مع مسار.',
      'other': 'بدأ هذا الجري قبل حفظ المسارات. يُحتفظ بوقته ومسافته حتى الآن؛ استأنف لتسجيل الباقي مع مسار.',
    });
    return '$_temp0';
  }

  @override
  String get runInterrupted =>
      'توقف التسجيل عند إغلاق GoHard. لا يُحتسب الوقت منذ ذلك الحين. استأنف للمتابعة، أو أنهِ لحفظه.';

  @override
  String get runTimerOnlyNote =>
      'المؤقّت فقط: لا يُسجَّل مسار أو مسافة GPS. يمكنك كتابة المسافة عند الانتهاء.';

  @override
  String get runNotSaving =>
      'لا يحفظ هذا الهاتف التسجيل الآن. أبقِ GoHard مفتوحًا؛ فهو يواصل المحاولة.';

  @override
  String get runGpsStopped =>
      'توقف GPS عن إعطاء المواقع. يستمر المؤقّت؛ وتُستأنف المسافة عند عودة GPS.';

  @override
  String get runVoiceToggleOn => 'التحديثات الصوتية مُفعّلة. إيقاف';

  @override
  String get runVoiceToggleOff => 'التحديثات الصوتية متوقفة. تشغيل';

  @override
  String runHelpRecording(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'مساعدة في تسجيل المشي',
      'other': 'مساعدة في تسجيل الجري',
    });
    return '$_temp0';
  }

  @override
  String get runViewStats => 'الإحصاءات';

  @override
  String get runSteps => 'الخطوات';

  @override
  String get runStepsPartly => 'الخطوات (جزئيًا)';

  @override
  String get runStepsNotCounted => 'الخطوات غير محسوبة';

  @override
  String get runStepsPartOfTime => 'الخطوات (جزء من الوقت)';

  @override
  String get runActiveTime => 'الوقت النشط';

  @override
  String runActiveTimeSaid(String duration) {
    return 'الوقت النشط $duration';
  }

  @override
  String runActiveTimePausedSaid(String duration) {
    return 'الوقت النشط $duration، متوقف مؤقتًا';
  }

  @override
  String runFigureSaid(String label, String value) {
    return '$label $value';
  }

  @override
  String runFigureSaidUnknown(String label) {
    return '$label غير معروفة';
  }

  @override
  String get runDistance => 'المسافة';

  @override
  String get runAvgMovingPace => 'متوسط الوتيرة أثناء الحركة';

  @override
  String get runChipTimerOnly => 'المؤقّت فقط';

  @override
  String get runChipGpsOff => 'GPS متوقف';

  @override
  String get runChipGpsLost => 'فُقد GPS';

  @override
  String get runChipWaiting => 'في انتظار GPS';

  @override
  String runChipGps(String accuracy) {
    return 'GPS · $accuracy';
  }

  @override
  String runTitleMorning(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'مشي الصباح',
      'other': 'جري الصباح',
    });
    return '$_temp0';
  }

  @override
  String runTitleAfternoon(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'مشي بعد الظهر',
      'other': 'جري بعد الظهر',
    });
    return '$_temp0';
  }

  @override
  String runTitleEvening(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'مشي المساء',
      'other': 'جري المساء',
    });
    return '$_temp0';
  }

  @override
  String runTitleNight(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'مشي الليل',
      'other': 'جري الليل',
    });
    return '$_temp0';
  }

  @override
  String runSaveTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'احفظ نشاط المشي',
      'other': 'احفظ نشاط الجري',
    });
    return '$_temp0';
  }

  @override
  String runSaveButton(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'احفظ المشي',
      'other': 'احفظ الجري',
    });
    return '$_temp0';
  }

  @override
  String get runRecordedRoute => 'المسار المسجَّل';

  @override
  String runNoRouteFor(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'لم يُسجَّل أي مسار GPS لهذا المشي.',
      'other': 'لم يُسجَّل أي مسار GPS لهذا الجري.',
    });
    return '$_temp0';
  }

  @override
  String get runRouteNotRecordedLine => 'لم يُسجَّل المسار.';

  @override
  String get runRouteNotRecorded => 'لم يُسجَّل المسار';

  @override
  String get runDistanceNotMeasured => 'المسافة غير مقيسة';

  @override
  String get runMovingTime => 'وقت الحركة';

  @override
  String runMovingTimeSaid(String duration) {
    return 'وقت الحركة $duration';
  }

  @override
  String get runTitleField => 'العنوان';

  @override
  String get runNotesOptional => 'ملاحظات (اختياري)';

  @override
  String get runNotesField => 'ملاحظات';

  @override
  String get runDistanceOptional => 'المسافة (اختياري)';

  @override
  String get runCorrectDistance => 'تصحيح المسافة (اختياري)';

  @override
  String get runDistanceTypedHelper => 'مكتوبة، وليست مقيسة بـ GPS.';

  @override
  String get runDistanceGpsKeptHelper =>
      'يُحتفظ بقياس GPS بجانبها؛ ولا يتغيّر المسار.';

  @override
  String runBlankKeepsGps(String distance) {
    return 'اتركه فارغًا للإبقاء على قياس GPS ($distance).';
  }

  @override
  String get runResumeRecording => 'استئناف التسجيل';

  @override
  String runDiscardButton(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'تجاهل المشي',
      'other': 'تجاهل الجري',
    });
    return '$_temp0';
  }

  @override
  String runDiscardTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'تجاهل هذا المشي؟',
      'other': 'تجاهل هذا الجري؟',
    });
    return '$_temp0';
  }

  @override
  String runDiscardBody(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk':
          'يُحذف المشي ومساره من هذا الهاتف ومن حسابك. لا يمكن التراجع عن ذلك.',
      'other':
          'يُحذف الجري ومساره من هذا الهاتف ومن حسابك. لا يمكن التراجع عن ذلك.',
    });
    return '$_temp0';
  }

  @override
  String get runDistanceInvalid => 'أدخل المسافة رقمًا، أو اتركها فارغة.';

  @override
  String get runTitleInvalid => 'أعطه عنوانًا من 1 إلى 80 حرفًا.';

  @override
  String get runTitleRequired => 'أعطه عنوانًا.';

  @override
  String get runSaveFailed =>
      'تعذّر الحفظ على هذا الهاتف. لم يُفقد شيء؛ جرّب الحفظ مرة أخرى.';

  @override
  String get runIntervalsIntro =>
      'تناوب بين الجري والمشي. المشي للتعافي جزء من الحصة وليس إيقافًا مؤقتًا: إنه نشاط واحد.';

  @override
  String get runIntervalsPresetNote =>
      'نقطة البداية: جري دقيقة ومشي دقيقة ونصف، 8 مرات، كما في الأسبوع الأول من خطة Couch to 5K من NHS. غيّر ما تشاء.';

  @override
  String get runIntervalsUsePreset => 'استخدمها';

  @override
  String get runIntervalWarmup => 'مشي الإحماء';

  @override
  String get runIntervalRun => 'الجري';

  @override
  String get runIntervalWalk => 'المشي / التعافي';

  @override
  String get runIntervalRepeats => 'التكرارات';

  @override
  String get runIntervalCooldown => 'مشي التهدئة';

  @override
  String get runIntervalNone => 'لا شيء';

  @override
  String get runIntervalNoneSaid => 'لا شيء';

  @override
  String runIntervalRepsValue(int count) {
    return '$count ×';
  }

  @override
  String runIntervalRepsSaid(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مرة',
      many: '$count مرة',
      few: '$count مرات',
      two: 'مرتان',
      one: 'مرة واحدة',
      zero: '0 مرة',
    );
    return '$_temp0';
  }

  @override
  String runIntervalLess(String label) {
    return 'تقليل $label';
  }

  @override
  String runIntervalMore(String label) {
    return 'زيادة $label';
  }

  @override
  String runIntervalTotal(String time) {
    return 'الوقت النشط المبرمج $time';
  }

  @override
  String get runIntervalsUse => 'استخدم هذه الفترات';

  @override
  String get runIntervalsOff => 'إيقاف الفترات';

  @override
  String runPlanWarmup(String time) {
    return '$time إحماء';
  }

  @override
  String runPlanRepeats(int reps, String run, String walk) {
    return '$reps × جري $run، مشي $walk';
  }

  @override
  String runPlanCooldown(String time) {
    return '$time تهدئة';
  }

  @override
  String get runPhaseWarmup => 'إحماء';

  @override
  String get runPhaseRun => 'جري';

  @override
  String get runPhaseWalk => 'مشي';

  @override
  String get runPhaseCooldown => 'تهدئة';

  @override
  String runSpokenSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ثانية',
      many: '$count ثانية',
      few: '$count ثوانٍ',
      two: 'ثانيتين',
      one: 'ثانية واحدة',
      zero: '0 ثانية',
    );
    return '$_temp0';
  }

  @override
  String runSpokenMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دقيقة',
      many: '$count دقيقة',
      few: '$count دقائق',
      two: 'دقيقتين',
      one: 'دقيقة واحدة',
      zero: '0 دقيقة',
    );
    return '$_temp0';
  }

  @override
  String runSpokenMinutesSeconds(String minutes, String seconds) {
    return '$minutes و$seconds';
  }

  @override
  String runRoundOf(int round, int total) {
    return 'الجولة $round من $total';
  }

  @override
  String get runSkipPhase => 'تخطّي المرحلة';

  @override
  String runTimeLeft(String time) {
    return 'متبقٍ $time';
  }

  @override
  String runNextPhase(String phase, String time) {
    return 'التالي: $phase $time';
  }

  @override
  String runNextPhaseSaid(String phase) {
    return 'التالي: $phase';
  }

  @override
  String get runIntervalsFinished => 'انتهت الفترات';

  @override
  String get runIntervalsStillRecording =>
      'لا يزال التسجيل مستمرًا. تابع بحرية، أو أنهِ وراجع.';

  @override
  String get runContinueFreely => 'المتابعة بحرية';

  @override
  String get runFinishAndReview => 'إنهاء ومراجعة';

  @override
  String get runCueIntervalsDone => 'انتهت الفترات. تابع بحرية، أو أنهِ وراجع.';

  @override
  String get runCueIntervalsFinished => 'انتهت الفترات.';

  @override
  String runCueWarmup(String duration) {
    return 'إحماء: امشِ لمدة $duration.';
  }

  @override
  String runCueRun(String duration) {
    return 'اجرِ لمدة $duration.';
  }

  @override
  String runCueFinalRun(String duration) {
    return 'الجولة الأخيرة. اجرِ لمدة $duration.';
  }

  @override
  String runCueWalk(String duration) {
    return 'امشِ وتعافَ لمدة $duration.';
  }

  @override
  String runCueCooldown(String duration) {
    return 'تهدئة: امشِ لمدة $duration.';
  }

  @override
  String runCueDistanceDone(String distance) {
    return 'اكتملت $distance.';
  }

  @override
  String runCueActiveTime(String time) {
    return 'الوقت النشط $time.';
  }

  @override
  String runCuePace(String pace) {
    return 'متوسط الوتيرة أثناء الحركة $pace.';
  }

  @override
  String runCueMinutesActive(int minutes) {
    return '$minutes د من النشاط.';
  }

  @override
  String runSaidKilometres(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count كيلومتر',
      many: '$count كيلومترًا',
      few: '$count كيلومترات',
      two: 'كيلومتران',
      one: 'كيلومتر واحد',
      zero: '0 كيلومتر',
    );
    return '$_temp0';
  }

  @override
  String runSaidMiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ميل',
      many: '$count ميلًا',
      few: '$count أميال',
      two: 'ميلان',
      one: 'ميل واحد',
      zero: '0 ميل',
    );
    return '$_temp0';
  }

  @override
  String runSaidKilometresDecimal(String value) {
    return '$value كيلومتر';
  }

  @override
  String runSaidMilesDecimal(String value) {
    return '$value ميل';
  }

  @override
  String runSaidActiveTime(String duration) {
    return 'الوقت النشط $duration.';
  }

  @override
  String runSaidPace(String unit, String duration) {
    String _temp0 = intl.Intl.selectLogic(unit, {
      'mi': 'متوسط الوتيرة أثناء الحركة $duration لكل ميل.',
      'other': 'متوسط الوتيرة أثناء الحركة $duration لكل كيلومتر.',
    });
    return '$_temp0';
  }

  @override
  String runSaidMinutesActive(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes دقيقة من النشاط.',
      many: '$minutes دقيقة من النشاط.',
      few: '$minutes دقائق من النشاط.',
      two: 'دقيقتان من النشاط.',
      one: 'دقيقة واحدة من النشاط.',
      zero: '0 دقيقة من النشاط.',
    );
    return '$_temp0';
  }

  @override
  String runVoicePreviewLine(String name) {
    return 'مرحبًا، أنا $name. سأخبرك متى تجري ومتى تمشي وكم قطعت من مسافة.';
  }

  @override
  String get runVoiceUpdates => 'التحديثات الصوتية';

  @override
  String runVoiceUpdatesSubtitle(String guide, String name) {
    String _temp0 = intl.Intl.selectLogic(guide, {
      'leona':
          'تعلن $name تغييرات الفترات والتحديثات وأفضل الأرقام الشخصية بصوت مسموع، بصوت مثبّت على هذا الهاتف. لا يُرسل أي شيء.',
      'other':
          'يعلن $name تغييرات الفترات والتحديثات وأفضل الأرقام الشخصية بصوت مسموع، بصوت مثبّت على هذا الهاتف. لا يُرسل أي شيء.',
    });
    return '$_temp0';
  }

  @override
  String get runVoiceUpdatesLabel => 'التحديثات';

  @override
  String get runVoiceUpdatesNone => 'بلا';

  @override
  String get runVoiceUpdatesDistance => 'المسافة';

  @override
  String get runVoiceUpdatesTime => 'الوقت';

  @override
  String get runVoiceUpdatesExplain =>
      'يذكر كل تحديث المسافة والوقت النشط ومتوسط الوتيرة أثناء الحركة (وقت الحركة ÷ المسافة)، فقط بعد أن يقيس GPS ما يكفي.';

  @override
  String get runVoiceField => 'الصوت';

  @override
  String get runVoiceMissing =>
      'الصوت المختار سابقًا غير مثبّت أو يحتاج إلى اتصال: يُستخدم صوت الهاتف.';

  @override
  String get runVoiceNoneForLanguage =>
      'لا يوجد صوت باللغة العربية يعمل دون اتصال مثبّت على هذا الهاتف، لذا لا يُقال شيء بصوت مسموع. تظل التنبيهات ظاهرة على الشاشة ويستمر الاهتزاز.';

  @override
  String get runVoiceOfflineOnly => 'تُعرض فقط الأصوات التي تعمل دون اتصال.';

  @override
  String get runVoicePhoneDefault => 'صوت الهاتف';

  @override
  String get runVoicePreview => 'معاينة الصوت';

  @override
  String get runVoiceVibrate => 'الاهتزاز عند تغيّر الفترات';

  @override
  String get runVoiceVibrateSubtitle =>
      'حتى مع قفل الشاشة على Android. وعلى iPhone أثناء فتح GoHard.';

  @override
  String get runVoiceCountdown => 'العد التنازلي';

  @override
  String get runVoiceCountdownSubtitle =>
      'نقرة كل ثانية في آخر ثلاث ثوانٍ من المرحلة.';

  @override
  String get runVoiceFooter =>
      'تظهر تغييرات الفترات دائمًا على الشاشة. تُحفظ هذه الاختيارات على هذا الهاتف.';

  @override
  String get runPersonalBests => 'أفضل الأرقام الشخصية';

  @override
  String get runBestNotSet => 'لم يُسجَّل بعد';

  @override
  String get runBestLongestRun => 'أطول جري';

  @override
  String get runBestLongestWalk => 'أطول مشي';

  @override
  String get runBestFastest1kRun => 'أسرع جري لمسافة 1 كم';

  @override
  String get runBestFastest5kRun => 'أسرع جري لمسافة 5 كم';

  @override
  String get runBestFastest1kWalk => 'أسرع مشي لمسافة 1 كم';

  @override
  String get runBestsFootnote =>
      'من الأنشطة المحفوظة التي قاس GPS مسافتها. أسرع وقت هو أسرع مقطع متواصل لتلك المسافة، يُحتسب من بدايته إلى نهايته؛ ويقطع الإيقاف المؤقت أو انقطاع GPS المقطع. لا تُحتسب المسافات المكتوبة أو المصحّحة.';

  @override
  String runBestsUnchecked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'حُفظ $count نشاط سابق قبل حفظ أسرع الأوقات، ولا تُحتسب إلا للمسافة إن قيست.',
      many:
          'حُفظ $count نشاطًا سابقًا قبل حفظ أسرع الأوقات، ولا تُحتسب إلا للمسافة إن قيست.',
      few:
          'حُفظت $count أنشطة سابقة قبل حفظ أسرع الأوقات، ولا تُحتسب إلا للمسافة إن قيست.',
      two: 'حُفظ نشاطان سابقان قبل حفظ أسرع الأوقات، ولا يُحتسبان إلا للمسافة إن قيست.',
      one: 'حُفظ نشاط سابق واحد قبل حفظ أسرع الأوقات، ولا يُحتسب إلا للمسافة إن قيست.',
      zero: 'لا توجد أنشطة سابقة.',
    );
    return '$_temp0';
  }

  @override
  String get runBestsNoneYet =>
      'لا شيء بعد: تأتي من الأنشطة المحفوظة التي قاسها GPS';

  @override
  String runBestPill(String label) {
    return 'أفضل رقم شخصي · $label';
  }

  @override
  String runRecordLongest(String kind, String distance) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'أطول مشي لك حتى الآن، $distance',
      'other': 'أطول جري لك حتى الآن، $distance',
    });
    return '$_temp0';
  }

  @override
  String runRecordFastest(String kind, String benchmark, String time) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'أسرع مشي لك لمسافة $benchmark حتى الآن، $time',
      'other': 'أسرع جري لك لمسافة $benchmark حتى الآن، $time',
    });
    return '$_temp0';
  }

  @override
  String runRecordsTwo(String first, String second) {
    return '$first و$second';
  }

  @override
  String runRecordsThree(String first, String second, String third) {
    return '$first، $second و$third';
  }

  @override
  String runActivityWhen(String date, String year, String time) {
    return '$date، $year · $time';
  }

  @override
  String get runExportGpx => 'تصدير GPX';

  @override
  String get runDistanceNotRecorded => 'لم تُسجَّل المسافة';

  @override
  String get runDistanceTyped => 'المسافة (مكتوبة)';

  @override
  String get runDistanceCorrected => 'المسافة (مصحّحة)';

  @override
  String get runTime => 'الوقت';

  @override
  String runTimeSaid(String duration) {
    return 'الوقت $duration';
  }

  @override
  String runElapsed(String time) {
    return 'المنقضي $time';
  }

  @override
  String get runElevationGainNotMeasured => 'الارتفاع المكتسب غير مقيس';

  @override
  String runElevationGain(String value) {
    return 'الارتفاع المكتسب $value';
  }

  @override
  String get runTabOverview => 'نظرة عامة';

  @override
  String get runTabSplits => 'المقاطع';

  @override
  String get runTabCharts => 'الرسوم البيانية';

  @override
  String get runSyncPending => 'محفوظ على هذا الهاتف، في انتظار المزامنة';

  @override
  String get runSyncReview => 'يحتاج إلى مراجعتك في حسابي › المزامنة';

  @override
  String get runSyncSaved => 'محفوظ في حسابك';

  @override
  String get runRouteSyncSaved => 'المسار محفوظ في حسابك';

  @override
  String get runRouteSyncNone => 'لا يوجد مسار للمزامنة';

  @override
  String get runRouteSyncKept => 'المسار محفوظ على الهاتف الذي سجّله';

  @override
  String get runRouteSyncAttention => 'رفع المسار يحتاج إلى انتباه';

  @override
  String get runRouteSyncWaiting => 'المسار على هذا الهاتف، في انتظار الرفع';

  @override
  String get runAvgSpeed => 'متوسط السرعة';

  @override
  String get runElevationLoss => 'الارتفاع المفقود';

  @override
  String get runMeasuredByGps => 'مقيسة بـ GPS';

  @override
  String get runGpsPointsUsed => 'نقاط GPS المستخدمة';

  @override
  String runGpsPointsRejected(String points, int count) {
    return '$points ($count مستبعدة لعدم دقتها)';
  }

  @override
  String get runGaps => 'الانقطاعات';

  @override
  String runGapsValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مقطع دون GPS، غير محتسبة',
      many: '$count مقطعًا دون GPS، غير محتسبة',
      few: '$count مقاطع دون GPS، غير محتسبة',
      two: 'مقطعان دون GPS، غير محتسبين',
      one: 'مقطع واحد دون GPS، غير محتسب',
      zero: 'لا مقاطع دون GPS',
    );
    return '$_temp0';
  }

  @override
  String get runBeforeRoutes => 'قبل حفظ المسارات';

  @override
  String runBeforeRoutesValue(String distance) {
    return '$distance دون مسار';
  }

  @override
  String get runSummary => 'الملخص';

  @override
  String get runRoute => 'المسار';

  @override
  String get runPartialRoute =>
      'لم يُسجَّل جزء من هذا المسار. تغطي المسافة والوتيرة ما قاسه GPS فقط.';

  @override
  String runIntervalsRunsCompleted(int done, int total) {
    return 'الجري المكتمل: $done من $total';
  }

  @override
  String runEndedEarly(String time) {
    return 'انتهت مبكرًا (المخطط $time)';
  }

  @override
  String get runNoSplits => 'لا مقاطع: لا توجد مسافة GPS.';

  @override
  String get runSelectSplit => 'اختر مقطعًا لرؤيته على الخريطة.';

  @override
  String runSplitLast(int number, String distance) {
    return '$number · آخر $distance';
  }

  @override
  String get runPartialSplit => 'مقطع جزئي';

  @override
  String get runShownOnMap => 'معروض على الخريطة';

  @override
  String get runNoCharts => 'لا رسوم بيانية: لم يُسجَّل مسار GPS.';

  @override
  String get runChartPace => 'الوتيرة';

  @override
  String runChartPaceNote(String step) {
    return 'كل $step؛ الأسرع أعلى. الانقطاعات فجوات أو إيقافات مؤقتة.';
  }

  @override
  String get runChartPaceTooShort => 'المسافة قليلة جدًا لرسم الوتيرة.';

  @override
  String get runChartElevation => 'الارتفاع';

  @override
  String get runGainNotMeasured => 'الارتفاع المكتسب غير مقيس';

  @override
  String runGainShort(String value) {
    return 'ارتفاع مكتسب $value';
  }

  @override
  String get runNoAltitude =>
      'لم يُبلغ هذا الهاتف عن ارتفاع دقيق بما يكفي للرسم.';

  @override
  String runChartSaid(String from, String to, String distance) {
    return 'رسم بياني من $from إلى $to على مسافة $distance';
  }

  @override
  String get runSaveChanges => 'حفظ التغييرات';

  @override
  String get runEditSaveFailed =>
      'تعذّر حفظ ذلك على هذا الهاتف. لا تزال تغييراتك هنا.';

  @override
  String runDeleteTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'حذف هذا المشي؟',
      'other': 'حذف هذا الجري؟',
    });
    return '$_temp0';
  }

  @override
  String runDeleteBody(String kind, String date) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'يُحذف مشي $date ومساره من هذا الهاتف ومن حسابك.',
      'other': 'يُحذف جري $date ومساره من هذا الهاتف ومن حسابك.',
    });
    return '$_temp0';
  }

  @override
  String runDeleteAction(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'حذف المشي',
      'other': 'حذف الجري',
    });
    return '$_temp0';
  }

  @override
  String get runDeleteFailed => 'تعذّر الحذف على هذا الهاتف. لم يتغيّر شيء.';

  @override
  String get runGpxFailed => 'تعذّر إنشاء ملف GPX على هذا الهاتف.';

  @override
  String get runNoRouteLegacy =>
      'سُجِّل قبل أن يحفظ GoHard المسارات. وقته ومسافته كما حُفظا.';

  @override
  String get runNoRouteManual => 'وُقِّت دون GPS؛ وكُتبت المسافة.';

  @override
  String runNoRoutePositions(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'لم يُسجَّل أي موقع GPS لهذا المشي.',
      'other': 'لم يُسجَّل أي موقع GPS لهذا الجري.',
    });
    return '$_temp0';
  }

  @override
  String get runFilterAll => 'الكل';

  @override
  String runInProgress(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'مشي قيد التقدم',
      'other': 'جري قيد التقدم',
    });
    return '$_temp0';
  }

  @override
  String runStartedOn(String date) {
    return 'بدأ في $date';
  }

  @override
  String get runThisWeek => 'هذا الأسبوع';

  @override
  String get runThisMonth => 'هذا الشهر';

  @override
  String runHistoryEmpty(String filter) {
    String _temp0 = intl.Intl.selectLogic(filter, {
      'run': 'لا يوجد جري بعد',
      'walk': 'لا يوجد مشي بعد',
      'other': 'لا توجد أنشطة بعد',
    });
    return '$_temp0';
  }

  @override
  String runHistoryEmptyBody(String filter) {
    String _temp0 = intl.Intl.selectLogic(filter, {
      'run': 'يظهر هنا كل جري محفوظ.',
      'walk': 'يظهر هنا كل مشي محفوظ.',
      'other': 'يظهر هنا كل جري ومشي محفوظ.',
    });
    return '$_temp0';
  }

  @override
  String get runStartOne => 'ابدأ واحدًا';

  @override
  String runTotalsSaid(
    String label,
    int count,
    String distance,
    String duration,
  ) {
    return '$label: $count محفوظة، $distance، $duration من النشاط';
  }

  @override
  String runTotalsSaidPartial(
    String label,
    int count,
    String distance,
    String duration,
  ) {
    return '$label: $count محفوظة، $distance حيث المسافة معروفة، $duration من النشاط';
  }

  @override
  String runTotalsLine(int count, String duration) {
    return '$count · $duration من النشاط';
  }

  @override
  String runNotificationTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'يسجّل GoHard نشاط المشي',
      'other': 'يسجّل GoHard نشاط الجري',
    });
    return '$_temp0';
  }

  @override
  String runNotificationText(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'افتح GoHard للإيقاف المؤقت أو الإنهاء. يُستخدم الموقع لهذا المشي فقط.',
      'other': 'افتح GoHard للإيقاف المؤقت أو الإنهاء. يُستخدم الموقع لهذا الجري فقط.',
    });
    return '$_temp0';
  }

  @override
  String get runNotificationChannel => 'تسجيل الجري / المشي';

  @override
  String get runMapRoute => 'خريطة المسار';

  @override
  String get runMapFollowing => 'يتتبّع موقعك';

  @override
  String get runMapRecenter => 'إعادة التوسيط';

  @override
  String get runMapFit => 'ملاءمة المسار';

  @override
  String get runMapZoomIn => 'تكبير';

  @override
  String get runMapZoomOut => 'تصغير';

  @override
  String get runMapNoTiles => 'مسار مرسوم دون خريطة';

  @override
  String get runMapExpand => 'تكبير الخريطة';

  @override
  String get stepsTitle => 'الخطوات';

  @override
  String get stepsCount => 'عدّ الخطوات';

  @override
  String get stepsCountSubtitle =>
      'بمستشعر الحركة في هذا الهاتف: أثناء الجري أو المشي، وإجمالي اليوم. لا يُحتسب المشي دون هاتفك.';

  @override
  String get stepsMotionNotAllowed => 'الوصول إلى الحركة غير مسموح به بعد.';

  @override
  String get stepsMotionBlocked =>
      'الوصول إلى الحركة متوقف لـ GoHard. شغّله من إعدادات الهاتف.';

  @override
  String get stepsNoCounter =>
      'لا يحتوي هذا الهاتف على عدّاد خطوات. يسجّل الجري / المشي كل شيء آخر.';

  @override
  String get stepsAllow => 'السماح';

  @override
  String get stepsSettings => 'الإعدادات';

  @override
  String get stepsGoalLabel => 'هدف الخطوات اليومي (اختياري)';

  @override
  String get stepsGoalHelper => 'رقمك الخاص. اتركه فارغًا لعدم تحديد هدف.';

  @override
  String get stepsOnToday => 'إظهار الخطوات في اليوم';

  @override
  String get stepsOnTodaySubtitle =>
      'يؤثر فقط فيما يعرضه اليوم. لا يتغيّر العدّ أو الوصول.';

  @override
  String stepsFooter(String source) {
    return 'يُقرأ إجمالي اليوم من $source ويبقى على هذا الهاتف: لا يُرسل إلى حسابك أبدًا. تُحفظ خطوات الجري أو المشي معه وتُزامَن مع حسابك. لا يُجمع الاثنان معًا أبدًا.';
  }

  @override
  String get stepsOff => 'الخطوات متوقفة';

  @override
  String get stepsOn => 'الخطوات مُفعّلة';

  @override
  String get stepsChecking => 'جارٍ التحقق…';

  @override
  String get stepsSimulated => 'محاكاة (نسخة اختبار)';

  @override
  String get stepsCounted => 'تُعدّ بهذا الهاتف';

  @override
  String get stepsMotionNeeded => 'يلزم الوصول إلى الحركة';

  @override
  String get stepsMotionOff => 'الوصول إلى الحركة متوقف';

  @override
  String get stepsNotOnPhone => 'غير متاح على هذا الهاتف';

  @override
  String get stepsEnable => 'تفعيل';

  @override
  String stepsPartOfTime(String steps) {
    return '$steps (جزء من الوقت)';
  }

  @override
  String get stepsNotCountedMotion => 'غير محتسبة: الوصول إلى الحركة متوقف';

  @override
  String get stepsNotCountedSensor => 'غير محتسبة: لا يوجد مستشعر خطوات';

  @override
  String get stepsNotCounted => 'غير محتسبة';

  @override
  String get stepsNotRecorded => 'غير مسجَّلة';

  @override
  String get stepsDailyUnavailableIos =>
      'لا يستطيع هذا الـ iPhone عدّ الخطوات.';

  @override
  String get stepsDailyUnavailableAndroid =>
      'تأتي الخطوات اليومية على Android من Health Connect، وهو غير متاح على هذا الهاتف.';

  @override
  String get stepsSourceIphone => 'هذا الـ iPhone';

  @override
  String get stepsSourceSimulated => 'هذا الهاتف (محاكاة)';

  @override
  String get shellPassCardOverline => 'خطة التدريب';

  @override
  String shellPassCardSemantics(
    String shape,
    String title,
    String week,
    String count,
    String caption,
    String percent,
  ) {
    String _temp0 = intl.Intl.selectLogic(shape, {
      'weekPercent': '$title. $week. $count $caption، $percent.',
      'week': '$title. $week. $count $caption.',
      'percent': '$title. $count $caption، $percent.',
      'other': '$title. $count $caption.',
    });
    return '$_temp0';
  }

  @override
  String get shellUpdateTitle => 'حدّث GoHard للمتابعة';

  @override
  String get shellUpdateBody =>
      'هذا الإصدار من التطبيق أقدم مما يقبله خادم حسابك، لذا توقفت المزامنة.';

  @override
  String get shellUpdateSavedHere =>
      'كل ما حفظته على هذا الهاتف لا يزال موجودًا.';

  @override
  String shellUpdateSavedPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'كل ما حفظته على هذا الهاتف لا يزال موجودًا، بما في ذلك $count تغيير ينتظر المزامنة. ستتم مزامنتها بعد التحديث.',
      many:
          'كل ما حفظته على هذا الهاتف لا يزال موجودًا، بما في ذلك $count تغييرًا ينتظر المزامنة. ستتم مزامنتها بعد التحديث.',
      few:
          'كل ما حفظته على هذا الهاتف لا يزال موجودًا، بما في ذلك $count تغييرات تنتظر المزامنة. ستتم مزامنتها بعد التحديث.',
      two: 'كل ما حفظته على هذا الهاتف لا يزال موجودًا، بما في ذلك تغييران ينتظران المزامنة. ستتم مزامنتهما بعد التحديث.',
      one: 'كل ما حفظته على هذا الهاتف لا يزال موجودًا، بما في ذلك تغيير واحد ينتظر المزامنة. ستتم مزامنته بعد التحديث.',
      zero: 'كل ما حفظته على هذا الهاتف لا يزال موجودًا.',
    );
    return '$_temp0';
  }

  @override
  String get shellUpdateCheckAgain => 'تحقّق مجددًا';

  @override
  String get shellConfigTitle => 'غير مُهيّأ';

  @override
  String get shellConfigBody =>
      'لا يحتوي هذا الإصدار على خادم افتراضي عمدًا. شغّله باستخدام سكربت التطوير ليعرف أي واجهة برمجة يستخدم.';

  @override
  String get shellCantSyncDetail =>
      'لم تنجح آخر محاولة للوصول إلى حسابك. قد يكون السبب اتصال هذا الهاتف أو الخادم.';

  @override
  String shellReviewBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count تغيير محفوظ يحتاج إلى مراجعتك. لم يُفقد شيء. اضغط للمراجعة.',
      many:
          '$count تغييرًا محفوظًا يحتاج إلى مراجعتك. لم يُفقد شيء. اضغط للمراجعة.',
      few:
          '$count تغييرات محفوظة تحتاج إلى مراجعتك. لم يُفقد شيء. اضغط للمراجعة.',
      two: 'تغييران محفوظان يحتاجان إلى مراجعتك. لم يُفقد شيء. اضغط للمراجعة.',
      one: 'تغيير محفوظ واحد يحتاج إلى مراجعتك. لم يُفقد شيء. اضغط للمراجعة.',
      zero: 'لا توجد تغييرات تحتاج إلى مراجعتك.',
    );
    return '$_temp0';
  }

  @override
  String get authFillEveryField => 'املأ جميع الحقول للمتابعة.';

  @override
  String get authCreateAccountTitle => 'إنشاء حساب';

  @override
  String get authWelcomeBack => 'مرحبًا بعودتك';

  @override
  String get authRegisterLead =>
      'اعرف ما عليك فعله بعد ذلك، واحتفظ بسجل لما أنجزته فعلًا.';

  @override
  String get authSignInLead => 'سجّل الدخول لتتابع من حيث توقفت.';

  @override
  String get authTagline => 'خطّط.\nسجّل.\nواصل.';

  @override
  String get authNoticeExpired =>
      'انتهت صلاحية تسجيل دخولك. سجّل الدخول مجددًا لمتابعة المزامنة؛ كل ما حُفظ على هذا الهاتف لا يزال موجودًا.';

  @override
  String get authNoticeAccountDeleted => 'حُذف حسابك وبياناته.';

  @override
  String get authNameLabel => 'اسمك';

  @override
  String get authEmailLabel => 'البريد الإلكتروني';

  @override
  String get authPasswordLabel => 'كلمة المرور';

  @override
  String get authHidePassword => 'إخفاء كلمة المرور';

  @override
  String get authShowPassword => 'إظهار كلمة المرور';

  @override
  String get authCreateAccountButton => 'إنشاء حساب';

  @override
  String get authSignInButton => 'تسجيل الدخول';

  @override
  String get authToggleToSignIn => 'لدي حساب بالفعل · تسجيل الدخول';

  @override
  String get authToggleToRegister => 'جديد على GoHard؟ أنشئ حسابًا';

  @override
  String get setupCoachTitle => 'اختر مدرّبك';

  @override
  String get setupCoachSubtitle =>
      'ليون أو ليونا: المساعدة نفسها في الحالتين، يتغيّر المظهر فقط. يمكنك تغيير ذلك لاحقًا من المظهر.';

  @override
  String get setupNotNow => 'ليس الآن';

  @override
  String setupCoachHello(String name) {
    return 'أنا $name. اضغط عليّ في أي شاشة عندما تحتاج إلى مساعدة.';
  }

  @override
  String get setupHi => 'مرحبًا!';

  @override
  String setupHiName(String name) {
    return 'مرحبًا $name!';
  }

  @override
  String get setupFeaturesTitle => 'ميزات اختيارية';

  @override
  String get setupFeaturesSubtitle =>
      'فعّل ما تريد الآن، أو لاحقًا من حسابي. لا يطلب الهاتف الإذن إلا عند استخدام ميزة تحتاج إليه.';

  @override
  String get setupWeatherTitle => 'الطقس في اليوم';

  @override
  String get setupWeatherSubtitle =>
      'استخدم موقعك التقريبي، أو اختر مدينة دون مشاركته.';

  @override
  String get setupRemindersTitle => 'تذكيرات التدريب';

  @override
  String get setupRemindersSubtitle =>
      'في الأيام التي فيها حصة تدريبية مخطط لها. يُطلب إذن الإشعارات عند تفعيل ذلك.';

  @override
  String get setupBarcodeTitle => 'مسح الرموز الشريطية';

  @override
  String get setupBarcodeSubtitle =>
      'جاهز في التغذية. يُطلب إذن الكاميرا عند أول مسح.';

  @override
  String get setupGpsTitle => 'الجري باستخدام GPS';

  @override
  String get setupGpsSubtitle => 'جاهز في اليوم. يُطلب الموقع عند بدء الجري.';

  @override
  String get setupPermissionsFootnote =>
      'يمكن تغيير أي شيء تسمح به أو ترفضه لاحقًا من إعدادات الهاتف؛ ويعرض حسابي › أذونات الهاتف ما هو مسموح الآن.';

  @override
  String setupStep(int step, int total) {
    return 'الخطوة $step من $total';
  }

  @override
  String todayGreetingNamed(String part, String name) {
    String _temp0 = intl.Intl.selectLogic(part, {
      'morning': 'صباح الخير، $name!',
      'afternoon': 'نهارك سعيد، $name!',
      'other': 'مساء الخير، $name!',
    });
    return '$_temp0';
  }

  @override
  String todayGreetingPlain(String part) {
    String _temp0 = intl.Intl.selectLogic(part, {
      'morning': 'صباح الخير!',
      'afternoon': 'نهارك سعيد!',
      'other': 'مساء الخير!',
    });
    return '$_temp0';
  }

  @override
  String get todayLineSaved => 'حُفظت حصتك التدريبية. عمل رائع.';

  @override
  String get todayLineResume => 'حصتك التدريبية جاهزة للاستئناف.';

  @override
  String todayLineDue(String title) {
    return '$title مخطط لها اليوم.';
  }

  @override
  String get todayLineFinished => 'اكتملت حصة اليوم التدريبية.';

  @override
  String get todayLinePartial => 'حُفظت حصة اليوم التدريبية.';

  @override
  String get todayLineSkipped => 'تم تخطي حصة اليوم التدريبية.';

  @override
  String get todayLineRest => 'اليوم يوم راحة مخطط له.';

  @override
  String get todayLinePaused => 'خطتك متوقفة مؤقتًا اليوم.';

  @override
  String get todayCoachStepsIntro =>
      'هل تريد تتبّع حركتك اليومية؟ فعّل الخطوات من هنا.';

  @override
  String get todayCoachEnableSteps => 'تفعيل الخطوات';

  @override
  String get todayCoachNeedHand => 'هل تحتاج إلى مساعدة اليوم؟';

  @override
  String get todaySkyNeedsPermission => 'لم يُسمح بالموقع بعد';

  @override
  String get todaySkyDenied => 'الموقع غير مسموح به';

  @override
  String get todaySkyServicesOff => 'خدمة الموقع متوقفة';

  @override
  String get todaySkyTimeout => 'لم يُحدَّد الموقع في الوقت المناسب';

  @override
  String get todaySkyOffline => 'تعذّر الوصول إلى الطقس';

  @override
  String get todaySkyUnavailable => 'الطقس غير متاح';

  @override
  String get todaySkyNoCity => 'اختر مدينة';

  @override
  String todaySkyWeather(String temperature, String condition) {
    return '$temperature · $condition';
  }

  @override
  String todaySkyScenic(String reason) {
    return 'مشهد طبيعي · $reason';
  }

  @override
  String get todaySkyHint => 'يفتح إعداد خلفية اليوم';

  @override
  String get todayCantSyncDetailNothingWaiting =>
      'لم تنجح آخر محاولة للوصول إلى حسابك. قد يكون السبب اتصال هذا الهاتف أو الخادم. ما تراه هو المحفوظ على هذا الهاتف. لا شيء ينتظر المزامنة.';

  @override
  String get todayCantSyncDetailWaiting =>
      'لم تنجح آخر محاولة للوصول إلى حسابك. قد يكون السبب اتصال هذا الهاتف أو الخادم. ما تراه هو المحفوظ على هذا الهاتف. تُحفظ تغييراتك هنا وتُزامَن تلقائيًا عندما يستجيب الحساب.';

  @override
  String get todayTrainingError =>
      'تعذّرت قراءة تدريبك من هذا الهاتف. اسحب للأسفل للمحاولة مجددًا.';

  @override
  String get todayTrainingLoading => 'جارٍ تحميل تدريبك…';

  @override
  String get todayStatusInProgress => 'قيد التنفيذ';

  @override
  String get todayStatusCompleted => 'مكتملة';

  @override
  String get todayStatusPartly => 'مكتملة جزئيًا';

  @override
  String get todayStatusSkipped => 'تم تخطيها اليوم';

  @override
  String get todayStatusMissed => 'فائتة';

  @override
  String get todayStatusPaused => 'متوقفة مؤقتًا';

  @override
  String get todayStatusDue => 'مستحقة اليوم';

  @override
  String get todayStatusSavedForLater => 'محفوظة لوقت لاحق';

  @override
  String get todayStatusRestDay => 'يوم راحة مخطط له';

  @override
  String get todayStatusPlanPaused => 'الخطة متوقفة مؤقتًا';

  @override
  String todayStatusStarts(String date) {
    return 'تبدأ في $date';
  }

  @override
  String get todayStatusBlockReview => 'الكتلة جاهزة للمراجعة';

  @override
  String get todayStatusDraftReview => 'خطتك جاهزة للمراجعة';

  @override
  String get todayNextNone => 'لا توجد حصص تدريبية أخرى مجدولة في هذه الكتلة.';

  @override
  String todayNextRotation(String title) {
    return 'التالية في دورتك: $title.';
  }

  @override
  String todayNextRotationDay(String title, String day) {
    return 'التالية في دورتك: $title · $day.';
  }

  @override
  String todayNext(String title, String day) {
    return 'التالية: $title · $day.';
  }

  @override
  String get todayDetailsLink => 'التفاصيل';

  @override
  String get todayDetailsSaid => 'تفاصيل الحصة التدريبية';

  @override
  String get todayWorkoutLabel => 'الحصة التدريبية';

  @override
  String todayExerciseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تمرين',
      many: '$count تمرينًا',
      few: '$count تمارين',
      two: 'تمرينان',
      one: 'تمرين واحد',
      zero: 'لا تمارين',
    );
    return '$_temp0';
  }

  @override
  String todayPlannedSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مجموعة مخطط لها',
      many: '$count مجموعة مخطط لها',
      few: '$count مجموعات مخطط لها',
      two: 'مجموعتان مخطط لهما',
      one: 'مجموعة واحدة مخطط لها',
      zero: 'لا مجموعات مخطط لها',
    );
    return '$_temp0';
  }

  @override
  String todayRotationStep(int position, int total) {
    return 'الخطوة $position من $total';
  }

  @override
  String todaySessionNumber(int number) {
    return 'الحصة $number';
  }

  @override
  String todayWeekNumber(int number) {
    return 'الأسبوع $number';
  }

  @override
  String todayMinutesPlanned(int minutes) {
    return '$minutes د مخطط لها';
  }

  @override
  String todaySetsRingLabel(int counted, int planned) {
    return 'المجموعات المسجّلة: $counted من $planned مخطط لها';
  }

  @override
  String todayOfSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'من $count مجموعة',
      many: 'من $count مجموعة',
      few: 'من $count مجموعات',
      two: 'من مجموعتين',
      one: 'من مجموعة واحدة',
      zero: 'من 0 مجموعة',
    );
    return '$_temp0';
  }

  @override
  String get todayRecordedCaption => 'مسجّل';

  @override
  String todaySetsRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'سُجِّلت $count مجموعة',
      many: 'سُجِّلت $count مجموعة',
      few: 'سُجِّلت $count مجموعات',
      two: 'سُجِّلت مجموعتان',
      one: 'سُجِّلت مجموعة واحدة',
      zero: 'لم تُسجَّل أي مجموعة',
    );
    return '$_temp0';
  }

  @override
  String get todayNoExercise => 'لم يُضف أي تمرين بعد';

  @override
  String get todayResumeWorkout => 'استئناف الحصة التدريبية';

  @override
  String get todayStartWorkout => 'بدء الحصة التدريبية';

  @override
  String get todayResolvedSkipped =>
      'تم تخطيها: لم يُسجَّل لها شيء ولا تُحتسب تدريبًا.';

  @override
  String get todayResolvedFinished =>
      'اكتملت: سُجِّلت كل المجموعات المخطط لها.';

  @override
  String get todayResolvedPartial =>
      'اكتملت جزئيًا: لم يُسجَّل بعض العمل المخطط له.';

  @override
  String get todayBlockLast => 'كانت هذه آخر حصة تدريبية في هذه الكتلة.';

  @override
  String get todayUnskipSaved => 'لم تعد متخطاة.';

  @override
  String get todayUndoSkip => 'التراجع عن التخطي';

  @override
  String get todayReviewBlock => 'مراجعة هذه الكتلة';

  @override
  String get todayTrainNow => 'تدرّب على هذه الآن';

  @override
  String get todayViewPlan => 'عرض الخطة';

  @override
  String todayAlsoToday(String status) {
    return 'أيضًا اليوم · $status';
  }

  @override
  String todayMissedUnresolved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حصة تدريبية سابقة لم تُحسم',
      many: '$count حصة تدريبية سابقة لم تُحسم',
      few: '$count حصص تدريبية سابقة لم تُحسم',
      two: 'حصتان تدريبيتان سابقتان لم تُحسما',
      one: 'حصة تدريبية سابقة واحدة لم تُحسم',
      zero: 'لا توجد حصص سابقة معلّقة',
    );
    return '$_temp0';
  }

  @override
  String get todayRestDayTitle => 'يوم راحة';

  @override
  String get todayRestChosen =>
      'اخترت الراحة اليوم. لم يُتخطَّ شيء ودورتك تنتظرك.';

  @override
  String todayRestMissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حصة تدريبية سابقة لم تُحسم؛ انقلها أو تخطّها متى شئت.',
      many: '$count حصة تدريبية سابقة لم تُحسم؛ انقلها أو تخطّها متى شئت.',
      few: '$count حصص تدريبية سابقة لم تُحسم؛ انقلها أو تخطّها متى شئت.',
      two: 'حصتان تدريبيتان سابقتان لم تُحسما؛ انقلهما أو تخطّهما متى شئت.',
      one: 'حصة تدريبية سابقة واحدة لم تُحسم؛ انقلها أو تخطّها متى شئت.',
      zero: 'لا توجد حصص سابقة معلّقة.',
    );
    return '$_temp0';
  }

  @override
  String get todayResolveMissed => 'حسم التدريب الفائت';

  @override
  String get todayTrainToday => 'التدرّب اليوم';

  @override
  String get todayPausedText =>
      'لا يُتوقع أي حصص تدريبية أثناء توقف الخطة مؤقتًا، ولا يُحتسب شيء فائتًا.';

  @override
  String get todayResumePlan => 'استئناف الخطة';

  @override
  String todayStartsLaterText(String date) {
    return 'تبدأ خطتك في $date. لا شيء مستحق قبل ذلك.';
  }

  @override
  String get todayBlockReviewText =>
      'وصلت هذه الكتلة إلى نهايتها أو لم يتبقَّ فيها شيء. راجع ما سُجِّل فعلًا واختر الخطوة التالية.';

  @override
  String get todayDraftText =>
      'لم تبدأ هذه المسودة بعد. لا شيء مجدول حتى تبدأها.';

  @override
  String get todayReviewPlan => 'مراجعة خطتك';

  @override
  String get todayNoPlanTitle => 'لا توجد خطة نشطة';

  @override
  String get todayNoPlanText =>
      'ابدأ من تقسيم مألوف أو أنشئ تقسيمك الخاص وراجعه قبل الالتزام، أو تدرّب يدويًا اليوم فقط.';

  @override
  String get todayCreatePlan => 'إنشاء خطتي';

  @override
  String get todayStartManual => 'بدء حصة تدريبية يدوية';

  @override
  String todayParkedSubtitle(String date) {
    return 'محفوظة لوقت لاحق · بدأت في $date';
  }

  @override
  String get todayManualWorkout => 'حصة تدريبية يدوية';

  @override
  String get todayPlannedWorkout => 'حصة تدريبية مخطط لها';

  @override
  String todayPlannedWorkoutFrom(String date) {
    return 'حصة تدريبية مخطط لها من $date';
  }

  @override
  String get todayUnderOneMinute => 'أقل من دقيقة';

  @override
  String todayActivityPaused(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'المشي متوقف مؤقتًا',
      'other': 'الجري متوقف مؤقتًا',
    });
    return '$_temp0';
  }

  @override
  String todayActivityInterrupted(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'انقطع المشي',
      'other': 'انقطع الجري',
    });
    return '$_temp0';
  }

  @override
  String todayActivityNotSaved(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'لم يُحفظ المشي بعد',
      'other': 'لم يُحفظ الجري بعد',
    });
    return '$_temp0';
  }

  @override
  String todayActivityInProgress(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'المشي جارٍ',
      'other': 'الجري جارٍ',
    });
    return '$_temp0';
  }

  @override
  String todayActivityCompleted(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'اكتمل المشي',
      'other': 'اكتمل الجري',
    });
    return '$_temp0';
  }

  @override
  String todayStartedOn(String date) {
    return 'بدأ في $date';
  }

  @override
  String get todayStartedToday => 'بدأ اليوم';

  @override
  String get todayCompletedWhen => 'اليوم';

  @override
  String get todayRunResume => 'استئناف';

  @override
  String get todayRunStartNew => 'بدء جديد';

  @override
  String get todayRunStart => 'ابدأ';

  @override
  String get todayNoRunWalk => 'لا جري ولا مشي اليوم';

  @override
  String get todayRunWalkLabel => 'الجري / المشي';

  @override
  String get todayStepsLabel => 'الخطوات';

  @override
  String get todayStepsTrack => 'تتبّع خطواتك';

  @override
  String get todayStepsCountWithPhone => 'احسبها بهاتفك.';

  @override
  String get todayStepsEnable => 'تفعيل';

  @override
  String get todayStepsReading => 'جارٍ قراءة الخطوات';

  @override
  String todayStepsUpdated(String time) {
    return 'حُدِّث $time';
  }

  @override
  String get todayStepsSetGoal => 'تحديد هدف';

  @override
  String get todayStepsEditGoal => 'تعديل الهدف';

  @override
  String get todayStepsSetGoalSaid => 'تحديد هدف للخطوات';

  @override
  String get todayStepsEditGoalSaid => 'تعديل هدف الخطوات';

  @override
  String get todayStepsNone => 'لم تُسجَّل أي خطوات اليوم';

  @override
  String get todayStepsBlocked => 'الوصول متوقف. اسمح به من الإعدادات.';

  @override
  String get todayStepsAllowHint => 'اسمح بالوصول لرؤية خطوات اليوم.';

  @override
  String get todayStepsSettings => 'الإعدادات';

  @override
  String get todayStepsAllow => 'السماح';

  @override
  String get todayStepsFailed => 'تعذّرت قراءة الخطوات الآن.';

  @override
  String get todayStepsOffSaid => 'الخطوات. تتبّع خطواتك: احسبها بهاتفك.';

  @override
  String todayStepsSaid(String value, String details) {
    return 'خطوات اليوم: $value. $details';
  }

  @override
  String get todayStepsNotKnown => 'غير معروف';

  @override
  String todayStepsOpens(String said) {
    return '$said يفتح الخطوات.';
  }

  @override
  String todayStepsOfGoal(String goal) {
    return 'من $goal';
  }

  @override
  String get todayStepsGoalLabel => 'هدف الخطوات';

  @override
  String get todayStepsSimulated => 'محاكاة (إصدار تجريبي)';

  @override
  String get todayNutritionLabel => 'التغذية';

  @override
  String get todayFoodError => 'تعذّرت قراءة طعام اليوم من هذا الهاتف.';

  @override
  String get todayLoading => 'جارٍ التحميل…';

  @override
  String get todayNoFood => 'لم يُسجَّل أي طعام اليوم';

  @override
  String todayDailyGoal(String goals) {
    return 'هدفك اليومي: $goals';
  }

  @override
  String get todayLogFood => 'تسجيل طعام';

  @override
  String get todayJournal => 'السجل';

  @override
  String get todayJournalSaid => 'سجل الطعام';

  @override
  String get todayRecordedTodayOverline => 'سُجِّل اليوم';

  @override
  String todaySetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مجموعة',
      many: '$count مجموعة',
      few: '$count مجموعات',
      two: 'مجموعتان',
      one: 'مجموعة واحدة',
      zero: 'لا مجموعات',
    );
    return '$_temp0';
  }

  @override
  String weatherCondition(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'c0': 'سماء صافية',
      'c1': 'صافٍ في الغالب',
      'c2': 'غائم جزئيًا',
      'c3': 'ملبّد بالغيوم',
      'c45': 'ضباب',
      'c48': 'ضباب متجمّد',
      'c51': 'رذاذ خفيف',
      'c53': 'رذاذ معتدل',
      'c55': 'رذاذ كثيف',
      'c56': 'رذاذ متجمّد خفيف',
      'c57': 'رذاذ متجمّد كثيف',
      'c61': 'مطر خفيف',
      'c63': 'مطر معتدل',
      'c65': 'مطر غزير',
      'c66': 'مطر متجمّد خفيف',
      'c67': 'مطر متجمّد غزير',
      'c71': 'تساقط ثلوج خفيف',
      'c73': 'تساقط ثلوج معتدل',
      'c75': 'تساقط ثلوج كثيف',
      'c77': 'حبيبات ثلجية',
      'c80': 'زخات مطر خفيفة',
      'c81': 'زخات مطر معتدلة',
      'c82': 'زخات مطر عنيفة',
      'c85': 'زخات ثلج خفيفة',
      'c86': 'زخات ثلج كثيفة',
      'c95': 'عاصفة رعدية',
      'c96': 'عاصفة رعدية مع بَرَد خفيف',
      'c97': 'عاصفة رعدية شديدة',
      'c99': 'عاصفة رعدية مع بَرَد كثيف',
      'other': 'الطقس',
    });
    return '$_temp0';
  }

  @override
  String weatherFamily(String family) {
    String _temp0 = intl.Intl.selectLogic(family, {
      'clear': 'صافٍ',
      'partly': 'غائم جزئيًا',
      'cloudy': 'ملبّد بالغيوم',
      'fog': 'ضباب',
      'rain': 'مطر',
      'snow': 'ثلج',
      'storm': 'عاصفة رعدية',
      'other': 'الطقس',
    });
    return '$_temp0';
  }

  @override
  String weatherTemperatureC(int degrees) {
    return '$degrees°م';
  }

  @override
  String weatherTemperatureF(int degrees) {
    return '$degrees°ف';
  }

  @override
  String get weatherFallbackNoAnswer => 'لا يوجد طقس بعد';

  @override
  String get weatherFallbackOtherPlace => 'الطقس لمكان آخر';

  @override
  String get weatherFallbackStale => 'الطقس قديم';

  @override
  String get weatherFallbackAhead => 'وقت الطقس متقدّم';

  @override
  String get weatherFallbackUnknownCode => 'طقس غير معروف';

  @override
  String get weatherFallbackNoArt => 'لا يوجد مشهد لهذا الطقس';

  @override
  String get weatherBackgroundScenic => 'مشهد طبيعي';

  @override
  String get weatherBackgroundWeather => 'الطقس';

  @override
  String get weatherBackgroundPlain => 'سادة';

  @override
  String get weatherSummaryAutomatic => 'الطقس · تلقائي';

  @override
  String weatherSummaryCity(String city) {
    return 'الطقس · $city';
  }

  @override
  String get weatherBackgroundTitle => 'خلفية اليوم';

  @override
  String get weatherBackgroundSubtitle =>
      'يستخدمها الجزء العلوي من اليوم فقط. تُطبَّق التغييرات فورًا.';

  @override
  String get weatherBackgroundScenicDetail =>
      'مشهد غروب زخرفي. يعمل دون اتصال.';

  @override
  String get weatherBackgroundWeatherDetail =>
      'مشهد للطقس الحالي في المكان الذي تختاره. الغروب عند عدم توفره.';

  @override
  String get weatherBackgroundPlainDetail => 'لون الصفحة السادة.';

  @override
  String get weatherLocationSection => 'الموقع';

  @override
  String get weatherAutomatic => 'تلقائي';

  @override
  String get weatherAutomaticDetail =>
      'الموقع التقريبي لهذا الهاتف، بدقة نحو 10 كم';

  @override
  String get weatherSelectedCity => 'المدينة المختارة';

  @override
  String get weatherSearchForCity => 'ابحث عن مدينة';

  @override
  String get weatherChangeCity => 'تغيير المدينة';

  @override
  String get weatherNowSection => 'الآن';

  @override
  String get weatherConsentTitle => 'استخدام موقعك التقريبي؟';

  @override
  String get weatherConsentBody =>
      'يستخدم GoHard موقع هذا الهاتف فقط لاختيار مشهد طقس لأعلى صفحة اليوم. يُقرَّب إلى نحو 10 كم قبل أن يغادر الهاتف ولا يُحفظ كسجل. يمكنك اختيار مدينة بدلًا من ذلك.';

  @override
  String get weatherNotNow => 'ليس الآن';

  @override
  String get weatherChooseCity => 'اختر مدينة';

  @override
  String get weatherIssueNeedsPermission =>
      'يحتاج الوضع التلقائي إلى إذن لاستخدام الموقع التقريبي لهذا الهاتف.';

  @override
  String get weatherUseMyLocation => 'استخدام موقعي';

  @override
  String get weatherIssueDenied =>
      'لم يُسمح بالموقع. اختر مدينة، أو حاول مجددًا.';

  @override
  String get weatherIssueDeniedForever =>
      'الموقع متوقف لـ GoHard. اسمح به من الإعدادات، أو اختر مدينة.';

  @override
  String get weatherOpenSettings => 'فتح الإعدادات';

  @override
  String get weatherIssueServicesOff =>
      'خدمة الموقع متوقفة على هذا الهاتف. شغّلها، أو اختر مدينة.';

  @override
  String get weatherLocationSettings => 'إعدادات الموقع';

  @override
  String get weatherIssueTimeout =>
      'لم يحدّد هذا الهاتف موقعه في الوقت المناسب. يظهر الغروب حتى يحدّده.';

  @override
  String get weatherIssueNoCity => 'اختر مدينة لترى طقسها.';

  @override
  String get weatherIssueUnreachable =>
      'تعذّر الوصول إلى الطقس الآن. يظهر الغروب حتى يتاح.';

  @override
  String get weatherApproximateLocation => 'موقعك التقريبي';

  @override
  String weatherAsOf(String time) {
    return 'حتى $time';
  }

  @override
  String weatherAsOfPlace(String time, String place) {
    return 'حتى $time · $place';
  }

  @override
  String get weatherChecking => 'جارٍ التحقق من الطقس…';

  @override
  String get weatherNone => 'لا يوجد طقس حالي. يُعرض مشهد الغروب الزخرفي.';

  @override
  String get weatherCreditMet =>
      'بيانات من MET Norway (api.met.no)، بترخيص CC BY 4.0: creativecommons.org/licenses/by/4.0. تُحوَّل رموز الطقس الخاصة بها هنا إلى رموز WMO.';

  @override
  String get weatherCreditOpenMeteo =>
      'بيانات الطقس من Open-Meteo.com، بترخيص CC BY 4.0: creativecommons.org/licenses/by/4.0.';

  @override
  String get weatherCreditDefault =>
      'بيانات الطقس من Open-Meteo.com، أو من MET Norway عند انشغاله (CC BY 4.0).';

  @override
  String get weatherModelData => 'الأحوال الجوية بيانات نموذجية.';

  @override
  String get weatherIllustrative =>
      'المشاهد توضيحية: ليست توقعات ولا منظرًا لموقعك.';

  @override
  String get weatherBasisTitle => 'ما يستند إليه المشهد';

  @override
  String get weatherNoCityChosen => 'لم تُختر مدينة';

  @override
  String get weatherAutomaticBasis => 'تلقائي (هذا الهاتف، بدقة نحو 10 كم)';

  @override
  String get weatherBasisLastAttempt => 'آخر محاولة';

  @override
  String get weatherBasisScene => 'المشهد';

  @override
  String weatherBasisSceneWeather(String key) {
    return '$key (طقس)';
  }

  @override
  String weatherBasisSceneScenic(String reason) {
    return 'مشهد طبيعي · $reason';
  }

  @override
  String get weatherBasisCondition => 'الحالة';

  @override
  String get weatherBasisSource => 'المصدر';

  @override
  String get weatherBasisDayNight => 'نهار أم ليل هناك';

  @override
  String get weatherDay => 'نهار';

  @override
  String get weatherNight => 'ليل';

  @override
  String get weatherNotGiven => 'غير محدد';

  @override
  String get weatherBasisValid => 'صالح';

  @override
  String weatherValidAt(String time, String ago) {
    return '$time ($ago)';
  }

  @override
  String get weatherBasisTimezone => 'المنطقة الزمنية هناك';

  @override
  String get weatherBasisFetched => 'جُلب';

  @override
  String get weatherBasisKeptFor => 'محفوظ لـ';

  @override
  String get weatherKeptThisCity => 'هذه المدينة';

  @override
  String get weatherKeptOther => 'إعداد موقع آخر';

  @override
  String get weatherJustNow => 'الآن';

  @override
  String weatherMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count دقيقة',
      many: 'منذ $count دقيقة',
      few: 'منذ $count دقائق',
      two: 'منذ دقيقتين',
      one: 'منذ دقيقة',
      zero: 'منذ أقل من دقيقة',
    );
    return '$_temp0';
  }

  @override
  String weatherHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count ساعة',
      many: 'منذ $count ساعة',
      few: 'منذ $count ساعات',
      two: 'منذ ساعتين',
      one: 'منذ ساعة',
      zero: 'منذ أقل من ساعة',
    );
    return '$_temp0';
  }

  @override
  String get weatherTypeTwoLetters => 'اكتب حرفين على الأقل.';

  @override
  String get weatherSearching => 'جارٍ البحث…';

  @override
  String weatherNoPlaces(String query) {
    return 'لم يُعثر على أماكن لـ «$query».';
  }

  @override
  String get weatherCitySearchFailed => 'تعذّر البحث عن المدن الآن.';

  @override
  String get weatherCityLabel => 'المدينة';

  @override
  String get weatherSearchTooltip => 'بحث';

  @override
  String todayOccasionStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'inProgress': 'قيد التنفيذ',
      'finished': 'مكتملة',
      'partial': 'جزئية',
      'skipped': 'تم تخطيها',
      'missed': 'فائتة',
      'due': 'مستحقة',
      'upcoming': 'مخطط لها',
      'other': 'متوقفة مؤقتًا',
    });
    return '$_temp0';
  }

  @override
  String get shellCantSyncLabel => 'تتعذّر المزامنة الآن';

  @override
  String shellWaitingToSync(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تغيير ينتظر المزامنة',
      many: '$count تغييرًا ينتظر المزامنة',
      few: '$count تغييرات تنتظر المزامنة',
      two: 'تغييران ينتظران المزامنة',
      one: 'تغيير واحد ينتظر المزامنة',
      zero: 'لا تغييرات تنتظر المزامنة',
    );
    return '$_temp0';
  }

  @override
  String shellCantSyncWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تتعذّر المزامنة الآن · $count تغيير ينتظر المزامنة',
      many: 'تتعذّر المزامنة الآن · $count تغييرًا ينتظر المزامنة',
      few: 'تتعذّر المزامنة الآن · $count تغييرات تنتظر المزامنة',
      two: 'تتعذّر المزامنة الآن · تغييران ينتظران المزامنة',
      one: 'تتعذّر المزامنة الآن · تغيير واحد ينتظر المزامنة',
      zero: 'تتعذّر المزامنة الآن',
    );
    return '$_temp0';
  }

  @override
  String workoutTargetSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مجموعة',
      many: '$count مجموعة',
      few: '$count مجموعات',
      two: 'مجموعتان',
      one: 'مجموعة واحدة',
      zero: 'لا مجموعات',
    );
    return '$_temp0';
  }

  @override
  String workoutTargetRepRange(String range) {
    return '$range تكرار';
  }

  @override
  String workoutTargetReps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تكرار',
      many: '$count تكرارًا',
      few: '$count تكرارات',
      two: 'تكراران',
      one: 'تكرار واحد',
      zero: '$count تكرار',
    );
    return '$_temp0';
  }

  @override
  String get workoutNoTarget => 'لا هدف';

  @override
  String get workoutOutcomeFull => 'مكتملة';

  @override
  String get workoutOutcomePartial => 'مكتملة جزئيًا';

  @override
  String get workoutOutcomeNoData => 'لم يُسجَّل أي تدريب';

  @override
  String get workoutOutcomeManual => 'مسجّلة';

  @override
  String get workoutOutcomeOpen => 'قيد التنفيذ';

  @override
  String get workoutSetBodyweight => 'وزن الجسم';

  @override
  String workoutSetLoadReps(String load, int reps) {
    return '$load × $reps';
  }

  @override
  String workoutSetLoadRepsTime(String load, int reps, String time) {
    return '$load × $reps · $time';
  }

  @override
  String get workoutInvalidLoadFormat =>
      'أدخل الوزن رقمًا يساوي صفرًا أو أكثر، أو اترك الحقل فارغًا لوزن الجسم.';

  @override
  String get workoutInvalidLoadRange => 'أدخل وزنًا يساوي صفرًا أو أكثر.';

  @override
  String get workoutInvalidNothingDone =>
      'أدخل التكرارات أو المدة التي أنجزتها فعلًا.';

  @override
  String get workoutInvalidOutOfRange => 'هذه القيمة خارج النطاق المسموح.';

  @override
  String get workoutInvalidHasSets => 'احذف المجموعات المسجّلة له أولًا.';

  @override
  String get workoutAllWorkoutsLink => 'كل الحصص التدريبية';

  @override
  String get workoutSelectSaveFailed =>
      'تعذّر حفظ تغيير التمرين على هذا الهاتف. لم تتغيّر مجموعاتك ولا ما أدخلته؛ حاول مرة أخرى.';

  @override
  String get workoutUseLastConfirmTitle => 'هل تريد استبدال ما كتبته؟';

  @override
  String get workoutUseLastConfirmBody =>
      'ستعرض خانة هذه المجموعة قيم الحصة السابقة بدلًا من ذلك. لا يُسجَّل شيء حتى تضغط «سجّل المجموعة».';

  @override
  String get workoutUseLastValues => 'استخدم القيم السابقة';

  @override
  String workoutUseLastValuesSemantic(String set) {
    return 'استخدم القيم السابقة: $set';
  }

  @override
  String get workoutUseLastKeepMine => 'أبقِ قيمي';

  @override
  String workoutSetSavedSnack(String set) {
    return 'حُفظت على هذا الهاتف: $set';
  }

  @override
  String get workoutUndo => 'تراجع';

  @override
  String get workoutSetNotSaved =>
      'لم تُحفظ. ما أدخلته ما زال هنا. اضغط مرة أخرى لإعادة المحاولة.';

  @override
  String get workoutEditSetTitle => 'تعديل المجموعة';

  @override
  String get workoutLoadLabel => 'الوزن';

  @override
  String get workoutSecondsLabel => 'الثواني';

  @override
  String get workoutRepsLabel => 'التكرارات';

  @override
  String get workoutTimeLabel => 'المدة';

  @override
  String get workoutSecondsUnit => 'ث';

  @override
  String workoutFieldWithUnit(String label, String unit) {
    return '$label ($unit)';
  }

  @override
  String get workoutDeleteSet => 'حذف المجموعة';

  @override
  String get workoutSetRemoved => 'حُذفت المجموعة.';

  @override
  String get workoutSetEditFailed =>
      'تعذّر حفظ هذا التغيير على هذا الهاتف. لم تتغيّر المجموعة.';

  @override
  String get workoutFinishNoDataTitle => 'لم يُسجَّل أي تدريب';

  @override
  String get workoutFinishTitle => 'هل تريد إنهاء الحصة التدريبية؟';

  @override
  String get workoutFinishNoDataBodyPlanned =>
      'لم تُسجَّل أي مجموعة. يمكنك حفظ هذه الحصة كسجل بلا تدريب: لا تُحتسب تدريبًا وتبقى الحصة المخطط لها متاحة. الوقت المنقضي وحده ليس تدريبًا.';

  @override
  String get workoutFinishNoDataBodyManual =>
      'لم تُسجَّل أي مجموعة. يمكنك حفظ هذه الحصة كسجل بلا تدريب: لا تُحتسب تدريبًا. الوقت المنقضي وحده ليس تدريبًا.';

  @override
  String workoutFinishSummary(int sets, int exercises) {
    String _temp0 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets مجموعة',
      many: '$sets مجموعة',
      few: '$sets مجموعات',
      two: 'مجموعتان',
      one: 'مجموعة واحدة',
      zero: 'صفر مجموعات',
    );
    String _temp1 = intl.Intl.pluralLogic(
      exercises,
      locale: localeName,
      other: '$exercises تمرين',
      many: '$exercises تمرينًا',
      few: '$exercises تمارين',
      two: 'تمرينين',
      one: 'تمرين واحد',
      zero: 'صفر تمارين',
    );
    return 'سُجّلت $_temp0 في $_temp1.';
  }

  @override
  String workoutFinishMissing(String names) {
    return 'لم تُسجَّل بالكامل: $names. يمكنك الإنهاء مع ذلك؛ ستُحفظ الحصة كمكتملة جزئيًا.';
  }

  @override
  String get workoutListSeparator => '، ';

  @override
  String get workoutKeepTraining => 'تابع التدريب';

  @override
  String get workoutSaveWithoutTraining => 'احفظ بلا تدريب';

  @override
  String get workoutFinishButton => 'إنهاء الحصة التدريبية';

  @override
  String get workoutFinishFailed =>
      'تعذّر إنهاء الحصة التدريبية على هذا الهاتف. لم يتغيّر شيء. حاول مرة أخرى.';

  @override
  String get workoutAddMovement => 'إضافة تمرين';

  @override
  String workoutReplaceMovementTitle(String name) {
    return 'استبدال $name';
  }

  @override
  String get workoutRemoveTitle => 'هل تريد حذف هذه الحصة التدريبية؟';

  @override
  String workoutRemoveOpenBody(String title) {
    return 'سيؤدي هذا إلى حذف «$title» وكل مجموعة مسجّلة فيها. هذه هي الطريقة الوحيدة لحذف حصة تدريبية؛ لا تُحذف تلقائيًا أبدًا.';
  }

  @override
  String get workoutRemoveAction => 'حذف الحصة التدريبية';

  @override
  String get workoutMissingTitle =>
      'هذه الحصة التدريبية غير موجودة على هذا الهاتف';

  @override
  String get workoutMissingBody => 'ربما حُذفت. لم يتغيّر أي شيء آخر.';

  @override
  String get workoutHelpSemantic => 'مساعدة في تسجيل هذه الحصة التدريبية';

  @override
  String get workoutHelpTitle => 'تسجيل المجموعات';

  @override
  String get workoutHelpBody =>
      'سجّل كل مجموعة فور إنهائها؛ يبدأ مؤقت الراحة بعدها تلقائيًا. «الحصة السابقة» هي ما أنجزته فعلًا من قبل، و«استخدم القيم السابقة» يملأ الخانات فقط. «حفظ لوقت لاحق» يحتفظ بكل شيء.';

  @override
  String get workoutOptionsTooltip => 'خيارات الحصة التدريبية';

  @override
  String get workoutReplaceThisMovement => 'استبدال هذا التمرين';

  @override
  String get workoutRemoveThisMovement => 'إزالة هذا التمرين';

  @override
  String get workoutSaveForLater => 'حفظ لوقت لاحق';

  @override
  String workoutTimeSemantic(String duration) {
    return 'مدة الحصة التدريبية $duration';
  }

  @override
  String workoutTimePausedSemantic(String duration) {
    return 'مدة الحصة التدريبية $duration، متوقفة مؤقتًا';
  }

  @override
  String get workoutResume => 'استئناف';

  @override
  String get workoutPause => 'إيقاف مؤقت';

  @override
  String get workoutParkedStatus =>
      'محفوظة لوقت لاحق. كل ما سُجّل محفوظ؛ استأنفها لتسجيل المزيد.';

  @override
  String get workoutResumeWorkout => 'استئناف الحصة التدريبية';

  @override
  String get workoutPausedStatus =>
      'الحصة التدريبية متوقفة مؤقتًا. يتوقف الوقت والراحة حتى تستأنف.';

  @override
  String get workoutNeedsReviewStatus =>
      'محفوظة على هذا الهاتف؛ تحتاج هذه الحصة إلى مراجعة قبل مزامنتها. راجع إشعار المراجعة أسفل الشاشة.';

  @override
  String workoutSetsRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'سُجّلت $count مجموعة',
      many: 'سُجّلت $count مجموعة',
      few: 'سُجّلت $count مجموعات',
      two: 'سُجّلت مجموعتان',
      one: 'سُجّلت مجموعة واحدة',
      zero: 'لم تُسجَّل أي مجموعة',
    );
    return '$_temp0';
  }

  @override
  String workoutPlannedSetsRecorded(int counted, int planned) {
    return 'سُجّلت $counted من أصل $planned من المجموعات المخطط لها';
  }

  @override
  String get workoutPlannedSetsRail => 'المجموعات المخطط لها المسجّلة';

  @override
  String get workoutNoMovementsTitle => 'لا توجد تمارين بعد';

  @override
  String get workoutNoMovementsBody => 'أضف تمرينًا لتبدأ تسجيل المجموعات.';

  @override
  String workoutMovementPosition(int index, int total) {
    return 'التمرين $index من $total';
  }

  @override
  String workoutMovementPositionExtra(int index, int total) {
    return 'التمرين $index من $total · إضافي';
  }

  @override
  String workoutSubstitutedNote(String name) {
    return 'يُسجَّل باسم $name بدلًا من التمرين المخطط له.';
  }

  @override
  String get workoutAbout => 'حول التمرين';

  @override
  String workoutAboutSemantic(String name) {
    return 'حول $name';
  }

  @override
  String get workoutTargetInWorkout => 'الهدف في هذه الحصة';

  @override
  String get workoutRestEnded => 'انتهت الراحة';

  @override
  String get workoutRestOverline => 'راحة';

  @override
  String get workoutRestFromPrevious => 'راحة · من التمرين السابق';

  @override
  String workoutRestSemantic(String duration) {
    return 'راحة، متبقٍّ $duration';
  }

  @override
  String get workoutRestAdd30 => 'إضافة 30 ث';

  @override
  String get workoutRestDismiss => 'إغلاق';

  @override
  String get workoutRestSkip => 'تخطي الراحة';

  @override
  String workoutNextSetOverline(int number) {
    return 'المجموعة $number · لم تُسجَّل بعد';
  }

  @override
  String get workoutTargetReachedLast =>
      'سُجّل العدد المستهدف من المجموعات. هذا آخر تمرين: أضف مجموعة أخرى، أو أنهِ الحصة عند الاستعداد.';

  @override
  String get workoutTargetReached =>
      'سُجّل العدد المستهدف من المجموعات. أضف مجموعة أخرى، أو انتقل إلى التالي عند الاستعداد.';

  @override
  String get workoutRecordSet => 'سجّل المجموعة';

  @override
  String get workoutRecordAnotherSet => 'سجّل مجموعة أخرى';

  @override
  String workoutNextExercise(String name) {
    return 'التمرين التالي · $name';
  }

  @override
  String get workoutRecordedSetsOverline => 'المجموعات المسجّلة';

  @override
  String get workoutNoRecordedSets =>
      'لا شيء بعد. الأهداف والحصة السابقة والاقتراحات ليست مجموعات مسجّلة.';

  @override
  String workoutSetRowTitle(int number, String set) {
    return '$number.  $set';
  }

  @override
  String get workoutSetNeedsReview => 'تحتاج إلى مراجعة';

  @override
  String get workoutSetPending =>
      'مسجّلة · محفوظة على هذا الهاتف، المزامنة معلّقة';

  @override
  String get workoutSetRecorded => 'مسجّلة';

  @override
  String get workoutAllMovementsOverline => 'كل التمارين';

  @override
  String workoutMovementSetsRecorded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مجموعة مسجّلة',
      many: '$count مجموعة مسجّلة',
      few: '$count مجموعات مسجّلة',
      two: 'مجموعتان مسجّلتان',
      one: 'مجموعة واحدة مسجّلة',
      zero: 'لم تُسجَّل أي مجموعة',
    );
    return '$_temp0';
  }

  @override
  String workoutMovementSetsOfTarget(int count, int target) {
    return '$count من $target مجموعات مسجّلة';
  }

  @override
  String workoutMovementCurrent(String status) {
    return '$status · الحالي';
  }

  @override
  String get workoutHistoryLoading => 'جارٍ قراءة حصصك السابقة…';

  @override
  String get workoutHistoryUnavailable =>
      'تعذّرت قراءة حصصك السابقة على هذا الهاتف حاليًا.';

  @override
  String get workoutHistoryNoIdentity =>
      'لا يوجد سجل: هذا التمرين غير مرتبط بتمرين محفوظ، لذا لا تتم المطابقة بالاسم.';

  @override
  String get workoutHistoryNone => 'لا توجد حصة سابقة مسجّلة.';

  @override
  String workoutCompareLastLabeled(String value) {
    return 'الحصة السابقة: $value';
  }

  @override
  String workoutCompareTodayLabeled(String value) {
    return 'اليوم: $value';
  }

  @override
  String workoutCompareRecordedSemantic(String set) {
    return 'مسجّلة: $set';
  }

  @override
  String get workoutCompareNext => 'التالية · لم تُسجَّل بعد';

  @override
  String get workoutCompareNotYet => 'لم تُسجَّل بعد';

  @override
  String workoutCompareSetNumber(int number) {
    return 'المجموعة $number';
  }

  @override
  String get workoutCompareSet => 'المجموعة';

  @override
  String get workoutCompareToday => 'اليوم';

  @override
  String get workoutLastTime => 'الحصة السابقة';

  @override
  String workoutLastTimeOn(String date) {
    return 'الحصة السابقة · $date';
  }

  @override
  String get workoutAllSessions => 'كل الحصص';

  @override
  String get workoutAllSessionsSemantic => 'كل الحصص السابقة';

  @override
  String get workoutHistorySheetCaption =>
      'الحصص السابقة من الأحدث إلى الأقدم: حصص تُحتسب تدريبًا، مطابقة بهذا التمرين وموضعه في الحصة.';

  @override
  String get workoutPreviewGoneTitle => 'لم تعد هذه الحصة التدريبية ضمن الخطة';

  @override
  String get workoutPreviewGoneBody =>
      'تغيّرت الخطة منذ فتحها. لم يبدأ أو يُسجَّل أي شيء.';

  @override
  String workoutPreviewSession(int number) {
    return 'الحصة $number';
  }

  @override
  String workoutPreviewWeek(int number) {
    return 'الأسبوع $number';
  }

  @override
  String workoutPreviewExerciseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تمرين',
      many: '$count تمرينًا',
      few: '$count تمارين',
      two: 'تمرينان',
      one: 'تمرين واحد',
      zero: 'لا تمارين',
    );
    return '$_temp0';
  }

  @override
  String workoutPreviewPlannedSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مجموعة مخطط لها',
      many: '$count مجموعة مخطط لها',
      few: '$count مجموعات مخطط لها',
      two: 'مجموعتان مخطط لهما',
      one: 'مجموعة واحدة مخطط لها',
      zero: 'لا مجموعات مخطط لها',
    );
    return '$_temp0';
  }

  @override
  String get workoutPreviewToday => 'اليوم';

  @override
  String workoutPreviewMinutesPlanned(int minutes) {
    return '$minutes د مخطط لها';
  }

  @override
  String get workoutStart => 'ابدأ الحصة التدريبية';

  @override
  String get workoutPreviewViewRecorded => 'عرض ما سُجّل';

  @override
  String get workoutPreviewMoreOptions => 'خيارات أخرى';

  @override
  String get workoutPreviewMoreOptionsSemantic =>
      'نقل هذه الحصة أو تخطيها أو تعديلها';

  @override
  String get workoutPreviewExercises => 'التمارين';

  @override
  String get workoutPreviewNoExercises =>
      'لا توجد تمارين مخطط لها في هذه الحصة.';

  @override
  String workoutPreviewSeeAll(int count) {
    return 'عرض كل التمارين ($count)';
  }

  @override
  String get workoutPreviewPlanPaused =>
      'الخطة متوقفة مؤقتًا. استأنفها لتبدأ حصصها.';

  @override
  String get workoutPreviewSkipped => 'تم تخطيها. لم يُسجَّل لها شيء.';

  @override
  String get workoutPreviewRotationOrder =>
      'يسير التناوب بالترتيب: تأتي هذه الحصة بعد الحصص التي تسبقها.';

  @override
  String get workoutPreviewCannotStart =>
      'لا يمكن بدء هذه الحصة الآن. تعرض «خيارات أخرى» ما يمكن فعله بها.';

  @override
  String get workoutPreviewFooter =>
      '«الحصة السابقة» هي ما سجّلته فعلًا من قبل. لا يُسجَّل شيء هنا حتى تبدأ.';

  @override
  String workoutPreviewTarget(String load) {
    return 'الهدف $load';
  }

  @override
  String get workoutSetATarget => 'حدّد هدفًا';

  @override
  String get workoutReviewTarget => 'مراجعة الهدف';

  @override
  String workoutTargetForSemantic(String name) {
    return 'الهدف لتمرين $name';
  }

  @override
  String get workoutOutcomeFullExplain =>
      'سُجّل لكل تمرين مخطط له العدد المستهدف من المجموعات.';

  @override
  String get workoutOutcomePartialExplain =>
      'سُجّل تدريب فعلي. لم يُسجَّل جزء من العمل المخطط له؛ وهو موضّح أدناه.';

  @override
  String get workoutOutcomeNoDataExplainPlanned =>
      'لم يُسجَّل أي تدريب، لذا لا تُحتسب تدريبًا وما زالت الحصة المخطط لها متاحة.';

  @override
  String get workoutOutcomeNoDataExplainManual =>
      'لم يُسجَّل أي تدريب، لذا لا تُحتسب تدريبًا.';

  @override
  String get workoutOutcomeManualExplain =>
      'سُجّلت كتدريب يدوي. لا تُحتسب لحصة مخطط لها.';

  @override
  String get workoutOutcomeOpenExplain =>
      'هذه الحصة ما زالت مفتوحة. لا تنتهي تلقائيًا أبدًا.';

  @override
  String workoutRemoveRecordedBody(String title, String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مجموعاتها المسجّلة الـ$count',
      many: 'مجموعاتها المسجّلة الـ$count',
      few: 'مجموعاتها المسجّلة الـ$count',
      two: 'مجموعتيها المسجّلتين',
      one: 'مجموعتها المسجّلة',
      zero: 'لا مجموعات مسجّلة',
    );
    return 'سيؤدي هذا إلى حذف «$title» بتاريخ $date و$_temp0 من سجلك.';
  }

  @override
  String workoutDateManual(String date) {
    return '$date · يدوية';
  }

  @override
  String get workoutSyncPending => 'محفوظ على هذا الهاتف · المزامنة معلّقة';

  @override
  String get workoutDetailNeedsReview =>
      'محفوظة على هذا الهاتف؛ تحتاج إلى مراجعتك قبل مزامنتها.';

  @override
  String get workoutFactTime => 'المدة';

  @override
  String get workoutFactSets => 'المجموعات';

  @override
  String get workoutFactMovements => 'التمارين';

  @override
  String workoutPlannedTarget(String target) {
    return 'المخطط · $target';
  }

  @override
  String get workoutExerciseNotRecorded => 'لم يُسجَّل.';

  @override
  String get workoutExerciseNoSets => 'لا توجد مجموعات مسجّلة.';

  @override
  String get workoutDetailEmptyTitle => 'لم يُسجَّل شيء';

  @override
  String get workoutDetailEmptyBody => 'لا تحتوي هذه الحصة على تمارين.';

  @override
  String get workoutHistoryTitle => 'سجل الحصص التدريبية';

  @override
  String get workoutHistoryEmptyTitle => 'لا توجد حصص تدريبية بعد';

  @override
  String get workoutHistoryEmptyBody =>
      'ستظهر هنا الحصص التي تسجّلها مع ما أنجزته فعلًا.';

  @override
  String workoutSetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مجموعة',
      many: '$count مجموعة',
      few: '$count مجموعات',
      two: 'مجموعتان',
      one: 'مجموعة واحدة',
      zero: 'صفر مجموعات',
    );
    return '$_temp0';
  }

  @override
  String get workoutManualTag => 'يدوية';

  @override
  String workoutStillOpenTitle(String title) {
    return '«$title» ما زالت مفتوحة';
  }

  @override
  String get workoutStillOpenBody =>
      'يمكن أن تكون حصة واحدة فقط قيد التنفيذ في كل مرة. استأنفها أو احفظها لوقت لاحق. الحفظ لوقت لاحق يحتفظ بكل مجموعة مسجّلة ولا ينهيها أبدًا.';

  @override
  String get workoutStillOpenPark => 'احفظها لوقت لاحق وتابع';

  @override
  String get workoutStillOpenResume => 'استأنفها';

  @override
  String get workoutStartFailed =>
      'تعذّر بدء الحصة التدريبية على هذا الهاتف. لم يُسجَّل شيء. حاول مرة أخرى.';

  @override
  String get workoutPickerTitle => 'اختر تمرينًا';

  @override
  String get workoutPickerSearch => 'ابحث عن التمارين';

  @override
  String get workoutPickerCatalogEmpty =>
      'لم تُنزَّل قائمة التمارين إلى هذا الهاتف بعد. يمكنك مع ذلك إنشاء تمرينك الخاص.';

  @override
  String get workoutPickerMuscle => 'المجموعة العضلية';

  @override
  String get workoutPickerEquipment => 'المعدات';

  @override
  String get workoutPickerNoMatch =>
      'لا يوجد تمرين مطابق. جرّب اسمًا أو مرشحًا آخر، أو أنشئ تمرينك الخاص.';

  @override
  String get workoutPickerTimedTag => 'بالوقت';

  @override
  String get workoutPickerYourExercise => 'تمرينك';

  @override
  String get workoutPickerCreate => 'أنشئ تمرينك الخاص';

  @override
  String workoutPickerCreateNamed(String name) {
    return 'أنشئ «$name» كتمرين خاص بك';
  }

  @override
  String get workoutPickerCreateSubtitle => 'خاص بحسابك. يحتفظ بسجله الخاص.';

  @override
  String get workoutCustomTitle => 'تمرينك الخاص';

  @override
  String get workoutSaveFailedRetry =>
      'تعذّر الحفظ على هذا الهاتف. حاول مرة أخرى.';

  @override
  String get workoutCustomCaption =>
      'لا يرى تمارينك الخاصة أحد غيرك. إعادة تسميتها لاحقًا لا تغيّر أبدًا ما سجّلته.';

  @override
  String get workoutCustomName => 'الاسم';

  @override
  String get workoutCustomTimed => 'بالوقت';

  @override
  String get workoutCustomTimedHelp =>
      'يُثبَّت أو يُؤدّى لمدة، مثل البلانك، بدلًا من عدّ التكرارات.';

  @override
  String get workoutCustomSave => 'احفظ التمرين';

  @override
  String get workoutManualTitle => 'حصة تدريبية يدوية';

  @override
  String get workoutManualCaption =>
      'تدرّب دون خطة. يُسجَّل هذا كتدريب فعلي ولا يُحتسب أبدًا لحصة مخطط لها.';

  @override
  String get workoutManualDefaultName => 'حصة تدريبية';

  @override
  String get workoutManualMovements => 'التمارين';

  @override
  String get workoutManualNone =>
      'لا شيء بعد. يمكنك أيضًا إضافة تمارين بعد البدء.';

  @override
  String workoutManualRemove(String name) {
    return 'إزالة $name';
  }

  @override
  String workoutProgressionDaysBoth(String date) {
    return 'كلتاهما في $date';
  }

  @override
  String workoutProgressionDaysPair(String first, String second) {
    return '$first و$second';
  }

  @override
  String workoutProgressionQualified(
    String workout,
    String days,
    int sets,
    String exercise,
    String target,
    int top,
    String range,
  ) {
    return 'في آخر حصتين من $workout ($days) سجّلت كل المجموعات الـ$sets من $exercise بوزن $target مع $top تكرارات أو أكثر، وهو الحد الأعلى لنطاقك $range.';
  }

  @override
  String get workoutProgressionConfigureIncrement =>
      'اختر زيادة الوزن التي تسمح بها معداتك لترى الهدف التالي.';

  @override
  String workoutProgressionIncrementTooLarge(String increment) {
    return 'زيادتك البالغة $increment أكبر من 5% من هذا الهدف، لذا لا يقترحها GoHard تلقائيًا. يمكنك مع ذلك مراجعة الهدف بنفسك.';
  }

  @override
  String workoutProgressionBelowTop(String workout, int top, String target) {
    return 'كانت مجموعة في إحدى آخر حصتين من $workout أقل من $top تكرارات بوزن $target.';
  }

  @override
  String workoutProgressionSetsMissing(
    String workout,
    int sets,
    String exercise,
  ) {
    return 'سُجّلت في إحدى آخر حصتين من $workout مجموعات من $exercise أقل من $sets.';
  }

  @override
  String workoutProgressionExtraSets(
    String workout,
    int sets,
    String exercise,
  ) {
    return 'في إحدى آخر حصتين من $workout أكثر من $sets مجموعات من $exercise، ولا تُميَّز مجموعات الإحماء، لذا لا يمكن مقارنتها.';
  }

  @override
  String workoutProgressionLoadUnknown(String workout) {
    return 'لا يوجد وزن مسجّل لمجموعة في إحدى آخر حصتين من $workout.';
  }

  @override
  String workoutProgressionLoadDiffers(String workout, String target) {
    return 'استُخدم في إحدى آخر حصتين من $workout وزن غير $target.';
  }

  @override
  String workoutProgressionPartial(String workout) {
    return 'حُفظت إحدى آخر حصتين من $workout كمكتملة جزئيًا.';
  }

  @override
  String workoutProgressionNotAsPlanned(String workout, String exercise) {
    return 'لم تتضمن إحدى آخر حصتين من $workout تمرين $exercise كما خُطط له.';
  }

  @override
  String workoutProgressionStays(String target) {
    return 'يبقى الهدف عند $target.';
  }

  @override
  String workoutProgressionTargetChanged(String workout, String target) {
    return 'تغيّر هدفك منذ آخر حصة من $workout. يلزم إكمال حصتين بوزن $target قبل النظر في زيادة.';
  }

  @override
  String workoutProgressionNeedTwo(String workout, String target, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'سُجّلت $count حصة',
      many: 'سُجّلت $count حصة',
      few: 'سُجّلت $count حصص',
      two: 'سُجّلت حصتان',
      one: 'سُجّلت حصة واحدة',
      zero: 'لم تُسجَّل أي حصة',
    );
    return 'يلزم إكمال حصتين من $workout بوزن $target قبل النظر في زيادة؛ $_temp0 حتى الآن.';
  }

  @override
  String workoutProgressionNoLoadTarget(String workout) {
    return 'لا يوجد وزن مستهدف لهذا التمرين في $workout. حدّد واحدًا إن أردت مقارنة الحصص به.';
  }

  @override
  String workoutProgressionNoRange(String workout) {
    return 'لا يوجد لهذا التمرين عدد مجموعات ونطاق تكرارات في $workout للمقارنة بهما.';
  }

  @override
  String get workoutProgressionTimed =>
      'هذا التمرين بالوقت، لذا لا يحسب GoHard وزنًا له. يمكنك تحديد الأهداف بنفسك.';

  @override
  String get workoutProgressionBodyweight =>
      'لا يحسب GoHard الأوزان لتمارين وزن الجسم أو التمارين المساعَدة. يمكنك تحديد الأهداف بنفسك.';

  @override
  String get workoutProgressionNoIdentity =>
      'هذا التمرين غير مرتبط بتمرين محفوظ، لذا لا تُقارن حصصه.';

  @override
  String get workoutNextTimeHeader => 'في المرة القادمة';

  @override
  String get workoutNextTimeHelpLabel => 'حول الأهداف التالية';

  @override
  String workoutNextTimeCoachIncrease(String exercise) {
    return 'بلغت الحد الأعلى لنطاق تكراراتك في آخر حصتين قابلتين للمقارنة من $exercise. يمكنك مراجعة هدف تالٍ اختياري.';
  }

  @override
  String workoutNextTimeCoachIncrement(String exercise) {
    return 'بلغت الحد الأعلى لنطاق تكراراتك في آخر حصتين قابلتين للمقارنة من $exercise. أخبرني بزيادة الوزن المتاحة لك لأحدد هدفًا تاليًا.';
  }

  @override
  String get workoutProgressionHowTitle => 'كيف تعمل زيادة الأحمال';

  @override
  String workoutNextTimeRowReview(String change) {
    return '$change · مراجعة';
  }

  @override
  String get workoutChooseIncrement => 'اختر زيادة الوزن';

  @override
  String get workoutCurrentTarget => 'الهدف الحالي';

  @override
  String get workoutProposed => 'المقترح';

  @override
  String get workoutReviewNextTarget => 'مراجعة الهدف التالي';

  @override
  String get workoutKeepCurrentTarget => 'أبقِ الهدف الحالي';

  @override
  String workoutKeptTarget(String load) {
    return 'أُبقي على $load. لم يتغيّر شيء في خطتك.';
  }

  @override
  String get workoutSaveFailedNothingChanged =>
      'تعذّر حفظ ذلك على هذا الهاتف. لم يتغيّر شيء؛ حاول مرة أخرى.';

  @override
  String get workoutNoNextTarget => 'لا يوجد وزن مستهدف تالٍ';

  @override
  String workoutNextTargetValue(String load) {
    return 'الهدف التالي · $load';
  }

  @override
  String get workoutReviewSuggestion => 'مراجعة الاقتراح';

  @override
  String get workoutReview => 'مراجعة';

  @override
  String workoutSetNextTargetSemantic(String name) {
    return 'حدّد هدفًا تاليًا لتمرين $name';
  }

  @override
  String workoutReviewNextTargetSemantic(String name) {
    return 'راجع الهدف التالي لتمرين $name';
  }

  @override
  String get workoutNextTargetTitle => 'الهدف التالي';

  @override
  String get workoutTargetLoadError =>
      'أدخل وزنًا أكبر من صفر، أو اتركه فارغًا لعدم تحديد وزن مستهدف.';

  @override
  String get workoutTargetRangeError =>
      'استخدم من 1 إلى 20 مجموعة ونطاق تكرارات من 1 إلى 100، والرقم الأصغر أولًا.';

  @override
  String get workoutTargetSaveFailed =>
      'تعذّر الحفظ على هذا الهاتف. لم يتغيّر شيء؛ حاول مرة أخرى.';

  @override
  String get workoutTargetRestored => 'استُعيد الهدف السابق.';

  @override
  String get workoutTargetGone =>
      'لم يعد هذا التمرين ضمن تلك الحصة من الخطة، لذا لا يوجد هدف تالٍ لمراجعته. لم يتغيّر شيء.';

  @override
  String workoutTargetScope(String workout) {
    return 'يُطبَّق من المرة القادمة التي تبدأ فيها $workout إلى أن تغيّره. تحتفظ حصة اليوم والحصص السابقة بما سُجّل فيها.';
  }

  @override
  String workoutReviewCurrent(String load, String prescription) {
    return 'الهدف الحالي: $load · $prescription';
  }

  @override
  String get workoutNoWeightTarget => 'لا يوجد وزن مستهدف';

  @override
  String workoutTargetSaved(String scope) {
    return 'حُفظ الهدف التالي. $scope';
  }

  @override
  String get workoutEditNextTarget => 'تعديل الهدف التالي';

  @override
  String workoutRestorePrevious(String target) {
    return 'استعادة الهدف السابق ($target)';
  }

  @override
  String get workoutSaveNextTarget => 'احفظ الهدف التالي';

  @override
  String workoutUseLoadFromNext(String load) {
    return 'استخدم $load من الحصة القادمة';
  }

  @override
  String get workoutYourLastSessions => 'حصصك الأخيرة';

  @override
  String workoutSessionLine(String date, String sets) {
    return '$date: $sets';
  }

  @override
  String get workoutNotRecordedLower => 'لم يُسجَّل';

  @override
  String workoutSuggestedLine(String proposed, String increment) {
    return 'المقترح: $proposed، أي زيادة واحدة قدرها $increment. يُقترح الوزن فقط؛ لا تتغيّر المجموعات والتكرارات إلا إذا عدّلتها.';
  }

  @override
  String get workoutWeightLabel => 'الوزن';

  @override
  String workoutUseLastRecordedLoad(String load) {
    return 'استخدم آخر وزن مسجّل ($load)';
  }

  @override
  String get workoutSetsLabel => 'المجموعات';

  @override
  String get workoutRepsFrom => 'التكرارات من';

  @override
  String get workoutRepsTo => 'التكرارات إلى';

  @override
  String get workoutRepsToShort => 'إلى';

  @override
  String workoutIncrementChange(String increment) {
    return 'زيادة الوزن $increment · تغيير';
  }

  @override
  String get workoutNoChangeToSave => 'لا تغيير لحفظه';

  @override
  String get workoutIncrementTitle => 'زيادة الوزن';

  @override
  String workoutIncrementRangeError(String max) {
    return 'أدخل زيادة أكبر من صفر وحتى $max.';
  }

  @override
  String workoutIncrementCaption(String exercise) {
    return 'هي الزيادة التي يضيفها GoHard عندما يقترح هدفًا أثقل لتمرين $exercise، وفي تلك الحالة فقط. اختر أصغر زيادة تسمح بها الأقراص أو الدمبلز أو الجهاز. تختلف الصالات الرياضية، لذا لا يُختار لك شيء.';
  }

  @override
  String get workoutIncrementConvention =>
      'يحفظ GoHard الوزن تمامًا كما تسجّله. اتبع الطريقة نفسها في مجموعاتك: إن كنت تسجّل الدمبل لكل يد، فأدخل الزيادة لكل يد؛ وللبار، أدخل التغيير الكلي على البار.';

  @override
  String workoutIncrementSaved(String increment) {
    return 'المحفوظ: $increment';
  }

  @override
  String workoutIncrementSavedPending(String increment) {
    return 'المحفوظ: $increment · المزامنة معلّقة';
  }

  @override
  String get workoutIncrementAnother => 'زيادة أخرى';

  @override
  String get workoutIncrementLocalOnly =>
      'محفوظ على هذا الهاتف. خادم حسابك لا يحفظ الزيادات بعد؛ ستتم المزامنة بعد تحديثه.';

  @override
  String get workoutChooseStep => 'اختر زيادة';

  @override
  String workoutSaveStep(String increment) {
    return 'احفظ $increment';
  }

  @override
  String get workoutIncrementRemove => 'إزالة هذه الزيادة';

  @override
  String get workoutProgressionHelp1 =>
      'الهدف هو ما تخطط لرفعه. «الحصة السابقة» هي ما سجّلته من قبل. يعرض «اليوم» المجموعات التي تسجّلها فعلًا فقط. لا تسجّل الاقتراحات أي مجموعة أبدًا.';

  @override
  String get workoutProgressionHelp2 =>
      'ينظر GoHard إلى آخر حصتين من الحصة نفسها في الخطة. إذا تضمّنت كلتاهما كل المجموعات المخطط لها لتمرين ما بالوزن المستهدف وبتكرارات عند الحد الأعلى للنطاق، يقترح الهدف مضافًا إليه زيادة وزن واحدة اخترتها.';

  @override
  String get workoutProgressionHelp3 =>
      'لا يعود أبدًا إلى ما قبل هاتين الحصتين، ولا يضيف مجموعات أو يغيّر التكرارات أو يستبدل التمارين، ولا يخفّض الوزن من تلقاء نفسه. تبقى أهداف التمارين بالوقت وبوزن الجسم والمساعَدة يدوية.';

  @override
  String get workoutProgressionHelp4 =>
      'لا تُقترح تلقائيًا زيادة تتجاوز 5% من الهدف الحالي؛ ويمكنك مع ذلك تحديد الهدف بنفسك. هذا الحد اختيار من GoHard وليس حدًا للسلامة.';

  @override
  String get workoutProgressionHelp5 =>
      'لا تدل التكرارات على الجهد أو الأداء الفني أو الألم أو التعافي. الاقتراح اختياري: راجعه أو عدّله أو أبقِ هدفك الحالي. لا يتغيّر شيء حتى تؤكد.';

  @override
  String get workoutProgressionHelpSources =>
      'الإرشادات المنشورة: يصف بيان موقف ACSM لعام 2009 رفع الحمل بنحو 2–10% عندما تستطيع أداء تكرار أو تكرارين أكثر من هدفك في حصتين متتاليتين. ويوصي بيان موقف ACSM لعام 2026 بتدريب المقاومة التدريجي، ويشير إلى أن زيادة الحمل المستمرة مهمة أساسًا للتقدم على المدى الأطول. قاعدة GoHard (الحد الأعلى لنطاقك في آخر حصتين، وزيادة واحدة اخترتها، وبحد أقصى 5%) اختيار خاص به؛ ولا تختبرها أيٌّ من الورقتين ولا تثبت صحتها.';

  @override
  String progressCoachWorkoutsOfTarget(int count, int target) {
    return 'سُجّلت $count من أصل $target حصص تدريبية هذا الأسبوع.';
  }

  @override
  String progressCoachRunWalkOfTarget(int count, int target) {
    return 'سُجّلت $count من أصل $target جلسات جري أو مشي هذا الأسبوع.';
  }

  @override
  String progressCoachSoFar(int workouts, int activities) {
    String _temp0 = intl.Intl.pluralLogic(
      workouts,
      locale: localeName,
      other: '$workouts حصة',
      many: '$workouts حصة',
      few: '$workouts حصص',
      two: 'حصتان',
      one: 'حصة واحدة',
      zero: 'لا حصص',
    );
    String _temp1 = intl.Intl.pluralLogic(
      activities,
      locale: localeName,
      other: '$activities جلسة جري أو مشي',
      many: '$activities جلسة جري أو مشي',
      few: '$activities جلسات جري أو مشي',
      two: 'جلستا جري أو مشي',
      one: 'جلسة جري أو مشي واحدة',
      zero: 'لا جري أو مشي',
    );
    return 'هذا الأسبوع حتى الآن: سُجّلت $_temp0 و$_temp1.';
  }

  @override
  String progressCoachSoFarSetGoals(int workouts, int activities) {
    String _temp0 = intl.Intl.pluralLogic(
      workouts,
      locale: localeName,
      other: '$workouts حصة',
      many: '$workouts حصة',
      few: '$workouts حصص',
      two: 'حصتان',
      one: 'حصة واحدة',
      zero: 'لا حصص',
    );
    String _temp1 = intl.Intl.pluralLogic(
      activities,
      locale: localeName,
      other: '$activities جلسة جري أو مشي',
      many: '$activities جلسة جري أو مشي',
      few: '$activities جلسات جري أو مشي',
      two: 'جلستا جري أو مشي',
      one: 'جلسة جري أو مشي واحدة',
      zero: 'لا جري أو مشي',
    );
    return 'هذا الأسبوع حتى الآن: سُجّلت $_temp0 و$_temp1. حدّد أهدافًا أسبوعية أدناه إن أردت هدفًا.';
  }

  @override
  String get progressCoachNothingYet =>
      'لم يُسجَّل شيء هذا الأسبوع بعد. حدّد أهدافًا أسبوعية أدناه إن أردت هدفًا.';

  @override
  String get progressCoachContextLabel => 'تقدّمك';

  @override
  String get progressStrengthTrends => 'اتجاهات القوة';

  @override
  String get progressSeeAll => 'عرض الكل';

  @override
  String get progressSeeAllTrendsSemantic => 'عرض كل اتجاهات التمارين';

  @override
  String get progressNoStableTrend =>
      'لا يوجد بعد تمرين ذو هوية ثابتة له مجموعات مسجّلة. التمارين المكتوبة نصًا حرًا ليس لها اتجاه.';

  @override
  String get progressNoTrainingTitle => 'لم يُسجَّل أي تدريب بعد';

  @override
  String get progressNoTrainingBody =>
      'تُبنى الاتجاهات فقط من الحصص التي تسجّلها فعلًا. لا يوجد ما يُعرض حتى ذلك الحين.';

  @override
  String get progressStartManual => 'ابدأ حصة تدريبية يدوية';

  @override
  String get progressBodyLink => 'تقدّم الجسم';

  @override
  String get progressBodyLinkSemantic => 'افتح تقدّم الجسم: الوزن والقياسات';

  @override
  String get progressPlanHeader => 'هل ألتزم بخطتي؟';

  @override
  String get progressNoPrimary =>
      'ليست لديك خطة رئيسية حاليًا. التدريب اليدوي يُحتسب تدريبًا مع ذلك.';

  @override
  String get progressNothingDue => 'لم يحن موعد أي حصة مخطط لها بعد.';

  @override
  String progressDueRecorded(int recorded, int due) {
    return 'سُجّلت $recorded من أصل $due حصص مستحقة';
  }

  @override
  String get progressDueRail => 'الحصص المستحقة المسجّلة';

  @override
  String progressAdherenceBreakdown(
    int full,
    int partial,
    int skipped,
    int missed,
  ) {
    return '$full مكتملة · $partial جزئية · $skipped تم تخطيها · $missed فائتة';
  }

  @override
  String get progressPlansLink => 'الخطط';

  @override
  String get progressViewPlan => 'اعرض خطتك';

  @override
  String get progressOpenPlanSemantic => 'افتح التدريب، الخطة';

  @override
  String get progressGoalsSeparate =>
      'الأهداف الأسبوعية منفصلة: لا تجدول حصة مخطط لها ولا تنقلها ولا تكملها أبدًا.';

  @override
  String get progressConsistencyHeader => 'هل أنا منتظم؟';

  @override
  String progressConsistencyCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حصة',
      many: '$count حصة',
      few: '$count حصص',
      two: 'حصتان',
      one: 'حصة واحدة',
      zero: 'لا حصص',
    );
    return 'أيام التدريب المسجّل في كل أسبوع من الأسابيع الثمانية الأخيرة. المجموع: $_temp0.';
  }

  @override
  String progressConsistencySemantic(String days) {
    return 'أيام التدريب في كل أسبوع، من الأقدم: $days';
  }

  @override
  String get progressWorkoutsLabel => 'الحصص التدريبية';

  @override
  String get progressRunWalkLabel => 'الجري / المشي';

  @override
  String progressWorkoutCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حصة',
      many: '$count حصة',
      few: '$count حصص',
      two: 'حصتان',
      one: 'حصة واحدة',
      zero: 'لا حصص',
    );
    return '$_temp0';
  }

  @override
  String progressRunWalkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جلسة جري أو مشي',
      many: '$count جلسة جري أو مشي',
      few: '$count جلسات جري أو مشي',
      two: 'جلستا جري أو مشي',
      one: 'جلسة جري أو مشي واحدة',
      zero: 'لا جري أو مشي',
    );
    return '$_temp0';
  }

  @override
  String progressRunCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جلسة جري',
      many: '$count جلسة جري',
      few: '$count جلسات جري',
      two: 'جلستا جري',
      one: 'جلسة جري واحدة',
      zero: 'لا جري',
    );
    return '$_temp0';
  }

  @override
  String progressWalkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جلسة مشي',
      many: '$count جلسة مشي',
      few: '$count جلسات مشي',
      two: 'جلستا مشي',
      one: 'جلسة مشي واحدة',
      zero: 'لا مشي',
    );
    return '$_temp0';
  }

  @override
  String progressGoalSaidNoTarget(String what, String counted) {
    return '$what: $counted هذا الأسبوع، بلا هدف.';
  }

  @override
  String progressGoalSaidTarget(String what, int count, int target) {
    return '$what: $count من $target هذا الأسبوع.';
  }

  @override
  String get progressThisWeek => 'هذا الأسبوع';

  @override
  String get progressWeeklyRhythm => 'إيقاعك الأسبوعي';

  @override
  String get progressEditGoals => 'تعديل الأهداف';

  @override
  String get progressSetGoals => 'حدّد أهدافًا أسبوعية';

  @override
  String get progressEditGoalsSemantic => 'تعديل الأهداف الأسبوعية';

  @override
  String get progressGoalsUnavailable =>
      'الأهداف الأسبوعية غير متاحة على خادم حسابك بعد، لذا لا يمكن حفظ أي منها. ما زالت أعدادك معروضة.';

  @override
  String get progressGoalsPending =>
      'الأهداف محفوظة على هذا الهاتف · المزامنة معلّقة';

  @override
  String get progressGoalsReview =>
      'غُيّرت أهداف هذا الأسبوع أيضًا على جهاز آخر. راجعها من الإشعار أسفل الشاشة.';

  @override
  String progressCountRecorded(int count) {
    return '$count مسجّلة';
  }

  @override
  String progressCountOfTarget(int count, int target) {
    return '$count من $target';
  }

  @override
  String progressCountOfTargetReached(int count, int target) {
    return '$count من $target · تحقّق';
  }

  @override
  String progressGoalRail(String label) {
    return 'هدف $label';
  }

  @override
  String get progressGoalsTitle => 'الأهداف الأسبوعية';

  @override
  String get progressGoalsSaveFailed =>
      'تعذّر حفظ أهدافك على هذا الهاتف. لم يتغيّر شيء.';

  @override
  String get progressGoalsCleared =>
      'أُزيلت الأهداف الأسبوعية بدءًا من هذا الأسبوع.';

  @override
  String get progressGoalsSaved => 'حُفظت الأهداف الأسبوعية.';

  @override
  String progressGoalRangeError(int min, int max) {
    return 'استخدم عددًا صحيحًا من $min إلى $max، أو اترك الحقل فارغًا.';
  }

  @override
  String progressGoalFieldHelper(int min, int max) {
    return 'من $min إلى $max أسبوعيًا، أو فارغ لعدم تحديد هدف';
  }

  @override
  String get progressGoalsHelper =>
      'هذه أهداف نشاط أسبوعية. تبقى خطة تدريبك كما هي.';

  @override
  String progressGoalsApply(String range) {
    return 'تُطبَّق بدءًا من هذا الأسبوع ($range) إلى أن تغيّرها. تحتفظ الأسابيع السابقة بأهدافها. اترك الحقل فارغًا لعدم تحديد هدف.';
  }

  @override
  String get progressGoalWorkoutsField => 'الحصص التدريبية في الأسبوع';

  @override
  String get progressGoalRunWalkField => 'جلسات الجري والمشي في الأسبوع';

  @override
  String get progressGoalsSave => 'احفظ الأهداف';

  @override
  String progressRecapLinkSemantic(String range) {
    return 'ملخص الأسبوع الماضي، $range';
  }

  @override
  String progressRecapLinkSemanticOlder(String range) {
    return 'ملخص الأسبوع الماضي، $range. الأسابيع السابقة في الداخل.';
  }

  @override
  String get progressRecapLinkTitle => 'ملخص الأسبوع الماضي';

  @override
  String progressRecapLinkOlder(String range) {
    return '$range · الأسابيع السابقة في الداخل';
  }

  @override
  String progressTrendPreviewSemantic(
    String name,
    String value,
    String date,
    String metric,
    int count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حصة معروضة',
      many: '$count حصة معروضة',
      few: '$count حصص معروضة',
      two: 'حصتان معروضتان',
      one: 'حصة واحدة معروضة',
      zero: 'لا حصص معروضة',
    );
    return '$name. آخر نتيجة مسجّلة $value في $date. $metric. $_temp0.';
  }

  @override
  String progressLatestRecordedOn(String date) {
    return 'آخر تسجيل · $date';
  }

  @override
  String get progressLatestRecorded => 'آخر تسجيل';

  @override
  String progressRepsValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تكرار',
      many: '$count تكرارًا',
      few: '$count تكرارات',
      two: 'تكراران',
      one: 'تكرار واحد',
      zero: '$count تكرار',
    );
    return '$_temp0';
  }

  @override
  String progressMetricLoad(int reps) {
    return 'وزن أفضل مجموعة · $reps تكرار';
  }

  @override
  String get progressMetricReps => 'أكبر عدد تكرارات في مجموعة · دون وزن إضافي';

  @override
  String get progressMetricDuration => 'أطول مدة مسجّلة';

  @override
  String get progressMetricNone => 'لا يوجد مقياس قابل للمقارنة';

  @override
  String get progressNoChange => 'لا تغيير';

  @override
  String progressChangeReps(String signed, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$signed تكرار',
      many: '$signed تكرارًا',
      few: '$signed تكرارات',
      two: '$signed تكرار',
      one: '$signed تكرار',
      zero: '$signed تكرار',
    );
    return '$_temp0';
  }

  @override
  String get progressRange4Weeks => '4 أسابيع';

  @override
  String get progressRange12Weeks => '12 أسبوعًا';

  @override
  String get progressRangeAll => 'الكل';

  @override
  String progressRangeWords(String range) {
    String _temp0 = intl.Intl.selectLogic(range, {
      'weeks4': 'في آخر 4 أسابيع',
      'weeks12': 'في آخر 12 أسبوعًا',
      'other': 'في كل سجلك',
    });
    return '$_temp0';
  }

  @override
  String progressNoSessionRange(String rangeWords) {
    return 'لا توجد حصة $rangeWords';
  }

  @override
  String get progressTrendsTitle => 'اتجاهات التمارين';

  @override
  String get progressTrendsSubtitle => 'التمارين التي سجّلتها، الأحدث أولًا';

  @override
  String get progressTrendsSearch => 'ابحث في تمارينك';

  @override
  String get progressTrendsEmptyTitle => 'لم يُسجَّل شيء بعد';

  @override
  String get progressTrendsEmptyBody =>
      'يظهر التمرين هنا بعد أن تتضمن حصة مكتملة مجموعات مسجّلة منه.';

  @override
  String get progressTrendsNoMatchTitle => 'لا توجد نتائج';

  @override
  String progressTrendsNoMatchBody(String query) {
    return 'لا يطابق أيٌّ من تمارينك المسجّلة «$query».';
  }

  @override
  String progressTrendRowSubtitle(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حصة',
      many: '$count حصة',
      few: '$count حصص',
      two: 'حصتان',
      one: 'حصة واحدة',
      zero: 'لا حصص',
    );
    return '$_temp0 · الأخيرة في $date';
  }

  @override
  String get progressReadErrorTitle => 'تعذّرت القراءة';

  @override
  String get progressReadErrorBody =>
      'تعذّرت قراءة سجلاتك على هذا الهاتف الآن. لم يتغيّر شيء؛ حاول مرة أخرى.';

  @override
  String get progressNoRecordedSetsTitle => 'لا توجد مجموعات مسجّلة';

  @override
  String get progressNoRecordedSetsBody =>
      'لم تعد لهذا التمرين مجموعات مسجّلة في حصة مكتملة.';

  @override
  String get progressNoRecordedSetsAnyMore =>
      'لم تعد لهذا التمرين مجموعات مسجّلة.';

  @override
  String get progressCompareSetsOf => 'قارن مجموعات من';

  @override
  String get progressNothingComparable =>
      'لا تحتوي هذه المجموعات على تكرارات بوزن أو تكرارات وحدها أو مدة مسجّلة، لذا لا يوجد ما يُقارن في الرسم. كل حصة مسجّلة مدرجة أدناه.';

  @override
  String get progressRecordedOnly => 'الحصص المسجّلة فقط';

  @override
  String get progressFirstToLatest => 'من الأولى إلى الأخيرة، في هذه الفترة';

  @override
  String progressEmptyRangeLoad(int reps, String rangeWords) {
    return 'لا توجد حصة فيها مجموعة من $reps تكرار $rangeWords. اختر فترة أطول أو عدد تكرارات آخر.';
  }

  @override
  String progressEmptyRange(String rangeWords) {
    return 'لا توجد حصة $rangeWords. اختر فترة أطول.';
  }

  @override
  String progressChartSemantic(
    String metric,
    String rangeWords,
    int count,
    String points,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حصة',
      many: '$count حصة',
      few: '$count حصص',
      two: 'حصتان',
      one: 'حصة واحدة',
      zero: 'لا حصص',
    );
    return '$metric، $rangeWords: $_temp0. $points.';
  }

  @override
  String get progressOnePoint =>
      'حصة واحدة قابلة للمقارنة حتى الآن. يتطلب التغيير حصتين على الأقل.';

  @override
  String get progressSessionsInRange => 'الحصص في هذه الفترة';

  @override
  String progressRowsExplainLoad(int reps) {
    return 'كل صف هو أثقل مجموعة من $reps تكرار في تلك الحصة، معروضة بعدد التكرارات نفسه.';
  }

  @override
  String get progressRowsExplain =>
      'كل صف هو أفضل مجموعة في تلك الحصة وفق هذا المقياس.';

  @override
  String progressExcludedLoad(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مجموعة مسجّلة بلا تكرارات ووزن معًا ليست في هذا الرسم.',
      many: '$count مجموعة مسجّلة بلا تكرارات ووزن معًا ليست في هذا الرسم.',
      few: '$count مجموعات مسجّلة بلا تكرارات ووزن معًا ليست في هذا الرسم.',
      two: 'مجموعتان مسجّلتان بلا تكرارات ووزن معًا ليستا في هذا الرسم.',
      one: 'مجموعة مسجّلة واحدة بلا تكرارات ووزن معًا ليست في هذا الرسم.',
      zero: 'لا مجموعات بلا تكرارات ووزن معًا',
    );
    return '$_temp0';
  }

  @override
  String progressExcludedReps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مجموعة مسجّلة بوزن أو بلا تكرارات ليست في هذا الرسم.',
      many: '$count مجموعة مسجّلة بوزن أو بلا تكرارات ليست في هذا الرسم.',
      few: '$count مجموعات مسجّلة بوزن أو بلا تكرارات ليست في هذا الرسم.',
      two: 'مجموعتان مسجّلتان بوزن أو بلا تكرارات ليستا في هذا الرسم.',
      one: 'مجموعة مسجّلة واحدة بوزن أو بلا تكرارات ليست في هذا الرسم.',
      zero: 'لا مجموعات بوزن أو بلا تكرارات',
    );
    return '$_temp0';
  }

  @override
  String progressExcludedDuration(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مجموعة مسجّلة بلا مدة مسجّلة ليست في هذا الرسم.',
      many: '$count مجموعة مسجّلة بلا مدة مسجّلة ليست في هذا الرسم.',
      few: '$count مجموعات مسجّلة بلا مدة مسجّلة ليست في هذا الرسم.',
      two: 'مجموعتان مسجّلتان بلا مدة مسجّلة ليستا في هذا الرسم.',
      one: 'مجموعة مسجّلة واحدة بلا مدة مسجّلة ليست في هذا الرسم.',
      zero: 'لا مجموعات بلا مدة مسجّلة',
    );
    return '$_temp0';
  }

  @override
  String progressAllSessionsLink(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كل الحصص الـ$count ومجموعاتها',
      many: 'كل الحصص الـ$count ومجموعاتها',
      few: 'كل الحصص الـ$count ومجموعاتها',
      two: 'الحصتان ومجموعاتهما',
      one: 'الحصة الوحيدة ومجموعاتها',
      zero: 'كل الحصص والمجموعات',
    );
    return '$_temp0';
  }

  @override
  String get progressSessionsTitle => 'الحصص';

  @override
  String get progressAllSessionsSubtitle => 'كل حصة مسجّلة، الأحدث أولًا';

  @override
  String get progressRecapTitle => 'الملخص الأسبوعي';

  @override
  String get progressPreviousWeek => 'الأسبوع السابق';

  @override
  String get progressNextWeek => 'الأسبوع التالي';

  @override
  String progressRecapLastWeek(String range) {
    return 'الأسبوع الماضي · $range';
  }

  @override
  String progressRecapWeekOf(String range) {
    return 'أسبوع $range';
  }

  @override
  String progressRecapSemLastWeek(String range) {
    return 'الأسبوع الماضي $range.';
  }

  @override
  String progressRecapSemWeekOf(String range) {
    return 'أسبوع $range.';
  }

  @override
  String get progressRecapSemNoActivity => 'لم يُسجَّل أي نشاط.';

  @override
  String progressRecapSemRecorded(String list) {
    return 'سُجّل: $list.';
  }

  @override
  String progressRecapSemDistance(String kind, String distance) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walking': 'مسافة المشي',
      'running': 'مسافة الجري',
      'other': 'مسافة الجري / المشي',
    });
    return '$_temp0: $distance.';
  }

  @override
  String progressRecapSemDistanceIncomplete(String kind, String distance) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walking': 'مسافة المشي',
      'running': 'مسافة الجري',
      'other': 'مسافة الجري / المشي',
    });
    return '$_temp0: $distance، بعض المسافات غير مسجّلة.';
  }

  @override
  String progressRecapSemActive(String duration) {
    return 'الوقت النشط: $duration.';
  }

  @override
  String get progressNotRecorded => 'غير مسجّل';

  @override
  String get progressRecapHeading => 'أسبوعك كما سُجّل';

  @override
  String get progressRecapEmpty => 'لم يُسجَّل أي نشاط هذا الأسبوع.';

  @override
  String progressRecapWorkoutsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حصة تدريبية',
      many: 'حصة تدريبية',
      few: 'حصص تدريبية',
      two: 'حصتان تدريبيتان',
      one: 'حصة تدريبية',
      zero: 'حصص تدريبية',
    );
    return '$_temp0';
  }

  @override
  String progressRecapWalks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'جلسة مشي',
      many: 'جلسة مشي',
      few: 'جلسات مشي',
      two: 'جلستا مشي',
      one: 'جلسة مشي',
      zero: 'جلسات مشي',
    );
    return '$_temp0';
  }

  @override
  String progressRecapRuns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'جلسة جري',
      many: 'جلسة جري',
      few: 'جلسات جري',
      two: 'جلستا جري',
      one: 'جلسة جري',
      zero: 'جلسات جري',
    );
    return '$_temp0';
  }

  @override
  String get progressRecapRunsAndWalks => 'جري ومشي';

  @override
  String progressRecapDistanceLabel(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walking': 'مسافة المشي',
      'running': 'مسافة الجري',
      'other': 'مسافة الجري / المشي',
    });
    return '$_temp0';
  }

  @override
  String progressRecapTimeLabel(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walking': 'وقت المشي',
      'running': 'وقت الجري',
      'other': 'وقت الجري / المشي',
    });
    return '$_temp0';
  }

  @override
  String progressRecapIncomplete(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نشاط بلا مسافة مسجّلة وليست ضمن المجموع.',
      many: '$count نشاطًا بلا مسافة مسجّلة وليست ضمن المجموع.',
      few: '$count أنشطة بلا مسافة مسجّلة وليست ضمن المجموع.',
      two: 'نشاطان بلا مسافة مسجّلة وليسا ضمن المجموع.',
      one: 'نشاط واحد بلا مسافة مسجّلة وليس ضمن المجموع.',
      zero: 'لا أنشطة بلا مسافة.',
    );
    return '$_temp0';
  }

  @override
  String get progressRecapTargets => 'أهدافك الأسبوعية';

  @override
  String get progressRecapNoGoals => 'لم تُحدَّد أهداف لهذا الأسبوع.';

  @override
  String get progressRecapHighlight => 'أبرز تقدّم في القوة';

  @override
  String progressRecapHighlightSubtitle(String dates, int reps) {
    return '$dates · مسجّل عند $reps تكرار';
  }

  @override
  String progressListJoin(String head, String last) {
    return '$head و$last';
  }

  @override
  String progressRecapCoachEmpty(String range) {
    return 'لم يُسجَّل أي نشاط في أسبوع $range.';
  }

  @override
  String progressRecapCoach(String list, String range) {
    return 'سجّلت $list في أسبوع $range.';
  }

  @override
  String get progressRecapSessions => 'حصص هذا الأسبوع';

  @override
  String progressRecapNothingBetween(String start, String end) {
    return 'لم يُسجَّل شيء بين $start و$end.';
  }

  @override
  String progressTargetRowSemantic(String label, int count, int target) {
    return '$label: $count من $target.';
  }

  @override
  String progressTargetRowSemanticReached(String label, int count, int target) {
    return '$label: $count من $target، تحقّق.';
  }

  @override
  String get accountErrorPasswordTooLong =>
      'كلمة المرور هذه أطول من 256 حرفًا. استخدم كلمة أقصر.';

  @override
  String get accountErrorPasswordMismatch =>
      'كلمتا المرور الجديدتان غير متطابقتين.';

  @override
  String get accountErrorCodeIncomplete => 'أدخل أرقام الرمز الثمانية كلها.';

  @override
  String get accountErrorCodeInvalid =>
      'هذا الرمز غير صحيح. تحقّق من آخر رسالة من GoHard أو اطلب رمزًا جديدًا.';

  @override
  String get accountErrorCodeExpired =>
      'انتهت صلاحية هذا الرمز. اطلب رمزًا جديدًا.';

  @override
  String get accountErrorCodeAttempts =>
      'محاولات كثيرة جدًا لهذا الرمز. اطلب رمزًا جديدًا.';

  @override
  String accountErrorCooldown(int seconds) {
    return 'انتظر $seconds ث قبل طلب رمز آخر.';
  }

  @override
  String get accountEmailUnavailable =>
      'الاسترداد عبر البريد الإلكتروني غير متاح بعد. حسابك وبياناتك في أمان؛ حاول لاحقًا.';

  @override
  String get accountErrorEmailBusy =>
      'يرسل GoHard رسائل كثيرة جدًا الآن. حاول مرة أخرى بعد بضع دقائق.';

  @override
  String get accountErrorResetExpired =>
      'انتهت صلاحية إعادة التعيين هذه أو استُخدمت من قبل. اطلب رمزًا جديدًا للبدء من جديد.';

  @override
  String get accountErrorNotSupported =>
      'خادم حسابك لا يوفّر هذه الميزة بعد. لم يتغيّر شيء.';

  @override
  String get accountErrorUncertainReset =>
      'تعذّر تأكيد التغيير. جرّب تسجيل الدخول بكلمة المرور الجديدة؛ وإن لم ينجح ذلك فاطلب رمزًا جديدًا.';

  @override
  String get accountErrorUncertainChange =>
      'تعذّر التأكد من تغيير كلمة المرور. لم يُفقد شيء على هذا الهاتف. إذا طُلب منك تسجيل الدخول، فجرّب كلمة المرور الجديدة أولًا.';

  @override
  String get codeFieldLabel => 'الرمز المكوَّن من 8 أرقام';

  @override
  String get codeFieldHelper =>
      'من الرسالة التي أرسلها إليك GoHard. يمكنك لصقه.';

  @override
  String get codeResend => 'إعادة إرسال الرمز';

  @override
  String codeResendIn(int seconds) {
    return 'إعادة الإرسال بعد $seconds ث';
  }

  @override
  String get codeDeliveryNote =>
      'قد يستغرق وصوله دقيقة. تحقّق من مجلد الرسائل غير المرغوب فيها أيضًا.';

  @override
  String get newPasswordLabel => 'كلمة المرور الجديدة';

  @override
  String get newPasswordConfirmLabel => 'تأكيد كلمة المرور الجديدة';

  @override
  String get currentPasswordLabel => 'كلمة المرور الحالية';

  @override
  String get passwordRule =>
      '15 حرفًا على الأقل. بضع كلمات غير مترابطة تفي بالغرض؛ وكل الأحرف مسموح بها.';

  @override
  String get authForgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get authNoticePasswordChanged =>
      'تم تغيير كلمة مرورك. سجّل الدخول بكلمة المرور الجديدة؛ كل ما على هذا الهاتف لا يزال موجودًا.';

  @override
  String get resetTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get resetEmailLead =>
      'أدخل البريد الإلكتروني لحسابك. إذا كان هناك حساب يستخدمه، فسنرسل إليه رمز إعادة التعيين.';

  @override
  String get resetSendCode => 'إرسال الرمز';

  @override
  String get resetCodeTitle => 'أدخل الرمز';

  @override
  String resetCodeLead(String email) {
    return 'إذا كان هناك حساب يستخدم $email، فقد أرسلنا إليه رمزًا من 8 أرقام. وهو صالح لمدة 10 دقائق.';
  }

  @override
  String get resetUseAnotherEmail => 'استخدام بريد إلكتروني آخر';

  @override
  String get resetPasswordTitle => 'كلمة مرور جديدة';

  @override
  String get resetPasswordLead =>
      'اختر كلمة مرورك الجديدة. سيتم تسجيل الخروج من جميع الأجهزة.';

  @override
  String get resetSetPassword => 'حفظ كلمة المرور';

  @override
  String get resetGoToSignIn => 'الانتقال إلى تسجيل الدخول';

  @override
  String get changePasswordTitle => 'تغيير كلمة المرور';

  @override
  String get changePasswordLead =>
      'يتحقّق GoHard من كلمة مرورك الحالية قبل تغيير أي شيء.';

  @override
  String get changePasswordSignsOut =>
      'تغييرها يسجّل خروجك من كل الأجهزة، ومنها هذا الهاتف. تبقى بياناتك على هذا الهاتف وتُزامَن مجددًا عند تسجيل الدخول.';

  @override
  String get changePasswordButton => 'تغيير كلمة المرور';

  @override
  String get changePasswordConfirmTitle => 'تسجيل الخروج من كل مكان؟';

  @override
  String get changePasswordConfirmBody =>
      'بعد التغيير ستسجّل الدخول مجددًا بكلمة المرور الجديدة، على هذا الهاتف وكل الأجهزة الأخرى.';

  @override
  String get changePasswordOffline =>
      'يتطلّب تغيير كلمة المرور اتصالًا. لا يُحفَظ شيء لوقت لاحق.';

  @override
  String get verifyTitle => 'تأكيد البريد الإلكتروني';

  @override
  String verifyLead(String email) {
    return 'سنرسل رمزًا من 8 أرقام إلى $email لتأكيد أنه يخصّك.';
  }

  @override
  String get verifySend => 'إرسال الرمز';

  @override
  String get verifyConfirm => 'تأكيد';

  @override
  String get verifyLater => 'لاحقًا';

  @override
  String get verifyVerified => 'تم تأكيد بريدك الإلكتروني.';

  @override
  String get verifyDone => 'تم تأكيد البريد الإلكتروني';

  @override
  String get meEmail => 'البريد الإلكتروني';

  @override
  String get meEmailVerified => 'مؤكَّد';

  @override
  String get meEmailNotVerified => 'غير مؤكَّد';

  @override
  String get mePassword => 'كلمة المرور';

  @override
  String get mePasswordSubtitle => 'تغيير كلمة المرور';

  @override
  String get accountErrorRegistrationUnavailable =>
      'لا يمكن إنشاء حساب جديد الآن لأن تأكيد البريد الإلكتروني غير متاح. لم يُنشأ أي شيء؛ حاول لاحقًا.';

  @override
  String get verifyGateTitle => 'أكّد بريدك الإلكتروني';

  @override
  String verifyGateLead(String email) {
    return 'أدخل الرمز المكوّن من 8 أرقام الذي أرسلناه إلى $email.';
  }

  @override
  String get verifyGateWhy =>
      'تأكيد بريدك الإلكتروني ضروري لإكمال إعداد حسابك. إنه يؤكّد أن هذا العنوان يخصّك ولا يغيّر شيئًا آخر.';

  @override
  String get verifyCheckAgain => 'التحقّق مجددًا';

  @override
  String get verifyGateSignOut => 'تسجيل الخروج أو استخدام حساب آخر';

  @override
  String get verifyGateSignOutTitle => 'تسجيل الخروج؟';

  @override
  String get verifyGateSignOutBody =>
      'يبقى هذا الحساب كما هو بانتظار التأكيد. سجّل الدخول مجددًا في أي وقت لتأكيده.';

  @override
  String get verifyScope =>
      'التأكيد يُثبت أن هذا العنوان يخصّك. لا يغيّر شيئًا آخر.';

  @override
  String verifyGraceWhy(String date) {
    return 'أكّده قبل $date لتستمر المزامنة. إنه يؤكّد أن هذا العنوان يخصّك ولا يغيّر شيئًا آخر.';
  }

  @override
  String get verifyPausedWhy =>
      'المزامنة متوقفة حتى تؤكّد. كل ما تحفظه يبقى على هذا الهاتف ويُرسَل بعد التأكيد.';

  @override
  String todayVerifyBy(String date) {
    return 'أكّد بريدك الإلكتروني قبل $date لتستمر المزامنة.';
  }

  @override
  String get todayVerifyPaused =>
      'أكّد بريدك الإلكتروني لتستأنف المزامنة. ما تحفظه يبقى على هذا الهاتف.';

  @override
  String get todayVerifyAction => 'تأكيد';

  @override
  String meEmailVerifyBy(String date) {
    return 'يجب التأكيد قبل $date';
  }

  @override
  String get meEmailPaused => 'المزامنة متوقفة حتى التأكيد';

  @override
  String get eatHistoryTrendsSubtitle => 'راجع ما تتناوله أسبوعيًا أو شهريًا';

  @override
  String get eatHistoryTrendsSaid =>
      'السجل والاتجاهات. راجع ما تتناوله أسبوعيًا أو شهريًا';

  @override
  String get trainRecentWorkouts => 'الحصص الأخيرة';

  @override
  String get trainViewAllHistory => 'عرض السجل كله';

  @override
  String get trainViewAllHistorySaid => 'عرض سجل الحصص كله';

  @override
  String get mealsLibraryTitle => 'الوجبات والوصفات المحفوظة';

  @override
  String get mealsFromAddFoodSubtitle =>
      'عدة أطعمة دفعة واحدة، مع مراجعة الكميات أولًا';

  @override
  String mealsForContext(String meal, String date) {
    return 'يُسجَّل في $meal · $date';
  }

  @override
  String get mealsTabMeals => 'الوجبات';

  @override
  String get mealsTabRecipes => 'الوصفات';

  @override
  String get mealsNewMeal => 'وجبة جديدة';

  @override
  String get mealsNewRecipe => 'وصفة جديدة';

  @override
  String get mealsEditMeal => 'تعديل الوجبة';

  @override
  String get mealsEditRecipe => 'تعديل الوصفة';

  @override
  String get mealsSearchHint => 'ابحث بالاسم';

  @override
  String mealsNoMatch(String query) {
    return 'لا شيء محفوظ يطابق «$query».';
  }

  @override
  String get mealsEmptyMealsTitle => 'لا وجبات محفوظة بعد';

  @override
  String get mealsEmptyMealsBody =>
      'تحفظ الوجبة عدة أطعمة بكمياتها المعتادة، مثل بيضتين و60 غ من الشوفان. عند تسجيلها يمكنك تغيير الكميات أولًا.';

  @override
  String get mealsEmptyRecipesTitle => 'لا وصفات بعد';

  @override
  String get mealsEmptyRecipesBody =>
      'الوصفة هي كمية كاملة من المكونات وعدد الحصص التي تعطيها. تسجّل الحصة التي تناولتها.';

  @override
  String get mealsUntitled => 'بلا اسم';

  @override
  String get mealsUnsavedDraft => 'تغييرات غير محفوظة';

  @override
  String mealsFoodsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count طعام',
      many: '$count طعامًا',
      few: '$count أطعمة',
      two: 'طعامان',
      one: 'طعام واحد',
      zero: 'لا أطعمة',
    );
    return '$_temp0';
  }

  @override
  String mealsIngredientsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مكوّن',
      many: '$count مكوّنًا',
      few: '$count مكونات',
      two: 'مكوّنان',
      one: 'مكوّن واحد',
      zero: 'لا مكونات',
    );
    return '$_temp0';
  }

  @override
  String mealsMakesServings(num count, String value) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تعطي $value حصة',
      many: 'تعطي $value حصة',
      few: 'تعطي $value حصص',
      two: 'تعطي حصتين',
      one: 'تعطي حصة واحدة',
      zero: 'تعطي $value حصة',
    );
    return '$_temp0';
  }

  @override
  String mealsServingsAmount(num count, String value) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$value حصة',
      many: '$value حصة',
      few: '$value حصص',
      two: 'حصتان',
      one: 'حصة واحدة',
      zero: '$value حصة',
    );
    return '$_temp0';
  }

  @override
  String mealsPerServing(String value) {
    return '$value لكل حصة';
  }

  @override
  String mealsMenuLabel(String name) {
    return 'خيارات $name';
  }

  @override
  String get mealsDuplicate => 'تكرار';

  @override
  String mealsCopyName(String name) {
    return '$name (نسخة)';
  }

  @override
  String mealsDeleteTitle(String name) {
    return 'حذف $name؟';
  }

  @override
  String get mealsDeleteBody =>
      'ستُزال من الوجبات والوصفات المحفوظة. ما سجّلته منها من قبل يبقى كما هو تمامًا.';

  @override
  String get mealsDeleted => 'حُذفت. ما سجّلته لم يتغيّر.';

  @override
  String get mealsServerUnavailable =>
      'خادم حسابك لا يدعم الوجبات والوصفات المحفوظة بعد. تبقى المسودات على هذا الهاتف، وينتظر الحفظ والتسجيل حتى يدعمها.';

  @override
  String get mealsHelpLabel => 'مساعدة حول الوجبات والوصفات';

  @override
  String get mealsCoachLibrary =>
      'تحفظ الوجبة الأطعمة وكمياتها المعتادة. عند تسجيلها يمكنك أولًا تنصيف أي منها أو مضاعفته أو تغييره.';

  @override
  String get mealsCoachRecipe =>
      'الوصفة تقسم الكمية الكاملة إلى عدد الحصص الذي تختاره.';

  @override
  String get eatHintMeals =>
      'تأكل هذا كثيرًا؟ احفظ الوجبة وعدّل الكميات في المرة القادمة.';

  @override
  String get mealsSaved => 'وجبتك في «الوجبات والوصفات المحفوظة».';

  @override
  String get mealsSavedRecipe => 'وصفتك في «الوجبات والوصفات المحفوظة».';

  @override
  String get mealsSaveAsMeal => 'حفظ كوجبة';

  @override
  String mealsSaveAsMealSaid(String meal) {
    return 'حفظ $meal كوجبة محفوظة';
  }

  @override
  String get mealsNameLabel => 'الاسم';

  @override
  String get mealsFoodsHeading => 'الأطعمة';

  @override
  String get mealsIngredientsHeading => 'المكونات (الكمية كاملة)';

  @override
  String get mealsAddFood => 'إضافة طعام';

  @override
  String get mealsAddIngredient => 'إضافة مكوّن';

  @override
  String mealsRemoveFood(String name) {
    return 'إزالة $name';
  }

  @override
  String get mealsServingsLabel => 'عدد الحصص التي تعطيها الكمية';

  @override
  String get mealsServingsHelper => 'بقدر ما تقسمها. لا يُخمَّن شيء.';

  @override
  String get mealsWeightLabel => 'وزن الكمية بعد التحضير (اختياري)';

  @override
  String get mealsWeightHelper =>
      'زِنها بعد تحضيرها لتسجيل الحصص بالغرامات. لا يُستخدم وزن المكونات النيئة لذلك أبدًا.';

  @override
  String get mealsTotalHeading => 'الوجبة كاملة';

  @override
  String get mealsBatchHeading => 'الكمية كاملة';

  @override
  String get mealsPerServingHeading => 'حصة واحدة';

  @override
  String get mealsSomeMissing =>
      'بعض الأطعمة بلا قيمة لعنصر غذائي: الأرقام الموسومة «معروف» هي مجموع المعروف، وليست مجاميع كاملة.';

  @override
  String get mealsSaveAsNew => 'حفظ كجديد';

  @override
  String get mealsDiscard => 'تجاهل التغييرات';

  @override
  String get mealsDiscardTitle => 'تجاهل تغييراتك؟';

  @override
  String get mealsDiscardBody => 'تبقى النسخة المحفوظة كما كانت.';

  @override
  String get mealsDiscardBodyNew =>
      'ستُزال هذه الوجبة غير المحفوظة من هذا الهاتف.';

  @override
  String get mealsResumed => 'عادت تغييراتك غير المحفوظة السابقة.';

  @override
  String get mealsChangedElsewhereTitle => 'تغيّر على جهاز آخر';

  @override
  String get mealsChangedElsewhereBody =>
      'تغيّر هذا على جهاز آخر منذ أن بدأت. هل تحفظ نسختك فوقه؟';

  @override
  String get mealsSaveMine => 'احفظ نسختي';

  @override
  String get mealsDeletedElsewhere =>
      'حُذف هذا على جهاز آخر. استخدم «حفظ كجديد» للاحتفاظ به.';

  @override
  String get mealsProblemNoName => 'أعطها اسمًا.';

  @override
  String get mealsProblemNameTooLong =>
      'الاسم طويل جدًا (120 حرفًا على الأكثر).';

  @override
  String get mealsProblemNoFoods => 'أضف طعامًا واحدًا على الأقل.';

  @override
  String get mealsProblemTooMany => '30 طعامًا على الأكثر.';

  @override
  String get mealsProblemBadQuantity => 'يجب أن تكون كل كمية أكبر من 0.';

  @override
  String get mealsProblemBadServings =>
      'أدخل عدد الحصص التي تعطيها الكمية (أكثر من 0، وحتى 1000).';

  @override
  String get mealsProblemBadWeight =>
      'أدخل الوزن النهائي بالغرامات (أكثر من 0) أو اتركه فارغًا.';

  @override
  String get mealsProblemTooLarge => 'هذا أكبر من أن يُحفظ. أزل بعض الأطعمة.';

  @override
  String get mealsProblemBadMultiplier => 'أدخل مضاعِفًا أكبر من 0، وحتى 20.';

  @override
  String get mealsProblemBadPortion => 'أدخل الكمية التي تناولتها (أكثر من 0).';

  @override
  String get foodProblemTooLarge => 'تفاصيل هذا الطعام أكبر من أن تُحفظ.';

  @override
  String get mealsUseAmount => 'استخدم هذه الكمية';

  @override
  String get mealsReviewNote => 'راجع الكميات. لا يُسجَّل شيء حتى تؤكّد.';

  @override
  String get mealsAmountsHeading => 'الكميات هذه المرة';

  @override
  String get mealsMultiplierCustom => 'غير ذلك…';

  @override
  String get mealsMultiplierTitle => 'ضاعف كل الكميات';

  @override
  String get mealsMultiplierLabel => 'المضاعِف';

  @override
  String mealsMultiplierSaid(String value) {
    return '$value ضعف كل كمية';
  }

  @override
  String get mealsLogMeal => 'سجّل الوجبة';

  @override
  String get mealsLogPortion => 'سجّل الحصة';

  @override
  String mealsLogged(String meal) {
    return 'سُجّل في $meal.';
  }

  @override
  String get mealsPortionChanged => 'حُدّثت الحصة.';

  @override
  String get mealsUpdateSaved => 'حدّث الوجبة المحفوظة';

  @override
  String get mealsUpdateTitle => 'تحديث الوجبة المحفوظة؟';

  @override
  String mealsUpdateBody(String name) {
    return 'تصبح الكميات المعروضة كميات $name المحفوظة، كوجبة واحدة. لا يُسجَّل شيء، ولا يتغيّر ما سجّلته من قبل.';
  }

  @override
  String get mealsUpdated => 'حُدّثت الوجبة المحفوظة. لم يُسجَّل شيء.';

  @override
  String get mealsSaveAsNewTitle => 'حفظ كوجبة جديدة';

  @override
  String mealsSaveAsNewBody(String name) {
    return 'تُحفظ الكميات المعروضة كوجبة جديدة واحدة. تبقى $name كما هي، ولا يُسجَّل شيء.';
  }

  @override
  String get mealsSavedNew => 'حُفظت كوجبة جديدة. لم يُسجَّل شيء.';

  @override
  String get mealsPortionHeading => 'الكمية التي تناولتها';

  @override
  String get mealsPortionAmount => 'الكمية';

  @override
  String get mealsMeasureServings => 'حصص';

  @override
  String get mealsMeasureGrams => 'غرامات';

  @override
  String get mealsNoWeight =>
      'لتسجيل الغرامات، أضف وزن الكمية بعد التحضير إلى الوصفة.';

  @override
  String mealsThisPortion(String amount) {
    return 'هذه الحصة: $amount';
  }

  @override
  String get mealsThisTimeIngredients => 'المكونات هذه المرة (الكمية كاملة)';

  @override
  String get mealsThisTimeNote =>
      'التغييرات هنا لهذه الحصة فقط. تبقى الوصفة المحفوظة كما هي.';

  @override
  String get mealsThisTimeChanged =>
      'تغيّر لهذه الحصة فقط. لتغيير الوصفة نفسها استخدم «تعديل الوصفة».';

  @override
  String get mealsThisTimeTotal => 'هذه المرة';

  @override
  String get eatOutTitle => 'تناول الطعام في الخارج';

  @override
  String get eatOutEntrySubtitle => 'قوائم كندية موثّقة: اختر طلبًا أو حسّنه';

  @override
  String get eatOutPanelBody => 'اعثر على طلب من مطعم يناسب أهدافك.';

  @override
  String get eatOutPanelAction => 'اختر مطعمًا';

  @override
  String get eatHintEatingOut =>
      'ستأكل في الخارج اليوم؟ يمكنني مساعدتك في اختيار طلب أو تحسين الطلب الذي تريده.';

  @override
  String get eatHintEatingOutAction => 'اعثر على طلب';

  @override
  String eatOutForContext(String meal, String date) {
    return 'لـ$meal · $date';
  }

  @override
  String eatOutChainContext(String chain, String meal, String date) {
    return '$chain · كندا · $meal · $date';
  }

  @override
  String get eatOutChooseChain => 'اختر مطعمًا';

  @override
  String eatOutChainCanada(String chain) {
    return '$chain · كندا';
  }

  @override
  String eatOutChainOptions(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count خيار موثّق',
      many: '$count خيارًا موثّقًا',
      few: '$count خيارات موثّقة',
      two: 'خياران موثّقان',
      one: 'خيار موثّق واحد',
      zero: 'لا خيارات موثّقة',
    );
    return '$_temp0 · تم التحقق في $date';
  }

  @override
  String get eatOutChainUnavailable =>
      'لم تُضَف القائمة بعد: لا توجد بيانات موثّقة';

  @override
  String eatOutChainNotYet(String chain) {
    return 'لا توجد قائمة موثّقة لـ$chain بعد';
  }

  @override
  String get eatOutChainBlocked =>
      'لا يعرض GoHard إلا الأصناف التي تأتي قيمها الغذائية من المعلومات الكندية التي تنشرها السلسلة نفسها. لم يتسنَّ بعد قراءة البيانات الرسمية لهذه السلسلة، لذلك لا يُعرض شيء بدل التخمين. ويمكنك تسجيل إدخالك الخاص من إضافة طعام.';

  @override
  String get eatOutChangeChain => 'تغيير المطعم';

  @override
  String get eatOutCoverageNote =>
      'مجموعة مختارة من الأصناف المعتادة، وليست القائمة كاملة. ولا تبيع كل الفروع كل الأصناف. الأسعار والطلب والتوصيل ليست جزءًا من GoHard.';

  @override
  String eatOutAskLabel(String guide) {
    return 'اسأل $guide عن تناول الطعام في الخارج';
  }

  @override
  String get eatOutAskHint =>
      'أخبرني بما تريد، مثلًا: أبقِ حلقات البطاطس، وبروتين أكثر';

  @override
  String get eatOutAskUnavailable =>
      'الطلب بالكلمات غير متاح على هذا الخادم. الأهداف والقائمة والاقتراحات كلها تعمل من دونه.';

  @override
  String get eatOutAskInvalid =>
      'تعذّر إرسال هذا الطلب. اختصره (حتى 600 حرف) وأرسله مرة أخرى.';

  @override
  String get eatOutProblemLimit =>
      'لقد طلبت كثيرًا اليوم. سيعود الطلب بالكلمات لاحقًا، والأهداف والقائمة ما زالت تعمل.';

  @override
  String get eatOutProblemBusy =>
      'المساعد مشغول الآن. طلبك محفوظ، حاول مرة أخرى بعد قليل.';

  @override
  String get eatOutProblemUnreached =>
      'تعذّر إرسال طلبك: قد يكون السبب اتصال هذا الهاتف أو الخادم. الطلب محفوظ، والقائمة تعمل دون اتصال.';

  @override
  String get eatOutProblemUnavailable =>
      'المساعد غير متاح الآن. طلبك محفوظ، والأهداف والقائمة ما زالت تعمل.';

  @override
  String get eatOutStale =>
      'تغيّر طلبك أو أهدافك أثناء قراءتي. لم يتغيّر شيء: أرسل الطلب مرة أخرى لاستخدام ما لديك الآن.';

  @override
  String get eatOutMenuChanged =>
      'حُدِّثت القائمة على الخادم. حدّثها هنا قبل أن تسأل مرة أخرى.';

  @override
  String get eatOutUpdateMenu => 'تحديث القائمة';

  @override
  String eatOutSwitchTo(String chain) {
    return 'الانتقال إلى $chain';
  }

  @override
  String get eatOutCoachIntro =>
      'ستأكل في الخارج؟ أخبرني إلى أين أنت ذاهب وما تريد الإبقاء عليه.';

  @override
  String eatOutCoachChain(String chain) {
    return 'حدّد حدًا للسعرات أو هدفًا للبروتين، أو أخبرني بما تريده في $chain. سأعرض طلبات تناسبه.';
  }

  @override
  String get eatOutCoachImprove =>
      'تريد تغيير شيء في طلبك؟ أخبرني بما أبقيه وما يهمك أكثر.';

  @override
  String get eatOutCoachReading => 'أقرأ طلبك…';

  @override
  String get eatOutCoachUnderstood =>
      'هذا ما فهمته: راجع أهدافك أدناه وغيّر ما أخطأت فيه. كل رقم يأتي من القائمة الموثّقة.';

  @override
  String eatOutCoachUnknown(String names) {
    return 'لم أجد $names في هذه القائمة.';
  }

  @override
  String get eatOutCoachUnsupported =>
      'لديّ قوائم موثّقة للمطاعم المدرجة هنا فقط، لذلك لا يمكنني المساعدة في ذلك.';

  @override
  String get eatOutCoachContradiction =>
      'طلبك يتضمن أمرين يلغي أحدهما الآخر. أيهما أحتفظ به؟';

  @override
  String get eatOutCoachClarify =>
      'هل يمكنك التوضيح أكثر؟ مثلًا حدّ للسعرات، أو الصنف والحجم المقصودين.';

  @override
  String eatOutCoachAsks(String question) {
    return '$question';
  }

  @override
  String get eatOutYourTargets => 'أهدافك';

  @override
  String get eatOutNoTargetsYet => 'لا شيء بعد. لا يُختار شيء نيابةً عنك.';

  @override
  String eatOutChipMax(String kcal) {
    return 'حتى $kcal سعرة';
  }

  @override
  String eatOutChipMin(String kcal) {
    return '$kcal سعرة على الأقل';
  }

  @override
  String eatOutChipProtein(String grams) {
    return '$grams غ بروتين على الأقل';
  }

  @override
  String eatOutChipKeep(String name, int count) {
    return 'إبقاء $name × $count';
  }

  @override
  String eatOutChipExclude(String name) {
    return 'بدون $name';
  }

  @override
  String eatOutChipPrefer(String kind) {
    return 'تفضيل: $kind';
  }

  @override
  String eatOutChipAvoid(String kind) {
    return 'تجنّب: $kind';
  }

  @override
  String eatOutRemoveTarget(String target) {
    return 'إزالة $target';
  }

  @override
  String get eatOutHelpChoose => 'ساعدني في الاختيار';

  @override
  String eatOutYourOrder(int count) {
    return 'طلبك ($count)';
  }

  @override
  String get eatOutNoTargetsTitle => 'ما الذي يجب أن يناسبه الطلب؟';

  @override
  String get eatOutNoTargetsBody =>
      'حدّد حدًا للسعرات أو هدفًا للبروتين، أو اسألني بكلماتك. يمكنك أيضًا أن تبني طلبًا بنفسك.';

  @override
  String get eatOutSetTargets => 'تحديد الأهداف';

  @override
  String eatOutSortedBy(String priority) {
    return 'الترتيب حسب: $priority';
  }

  @override
  String get eatOutPriorityProtein => 'الأكثر بروتينًا';

  @override
  String get eatOutPriorityCalories => 'الأقل سعرات';

  @override
  String get eatOutPriorityClosest => 'الأقرب إلى حدّ السعرات';

  @override
  String get eatOutNoneFits =>
      'لا شيء يناسب كل أهدافك. هذه الأقرب، مع ما ينقص كلًا منها. لا تتغيّر الأصناف التي أبقيتها أو استبعدتها أبدًا.';

  @override
  String get eatOutNothingPossible =>
      'لا يمكن بناء طلب بهذه الخيارات. أزل صنفًا أو نوعًا مستبعدًا.';

  @override
  String get eatOutContradiction =>
      'الحد الأدنى أعلى من الحد الأقصى، أو صنف مُبقى ومستبعد في آن واحد. غيّر أحدهما.';

  @override
  String eatOutLine(int count, String name) {
    return '$count × $name';
  }

  @override
  String eatOutProteinValue(String grams) {
    return '$grams غ بروتين';
  }

  @override
  String get eatOutFits => 'يناسب أهدافك المحددة.';

  @override
  String eatOutKeeps(String names) {
    return 'يُبقي $names.';
  }

  @override
  String eatOutMisses(String misses) {
    return 'لا يحقق: $misses';
  }

  @override
  String eatOutMissOver(String kcal) {
    return '$kcal سعرة فوق حدّك';
  }

  @override
  String eatOutMissUnder(String kcal) {
    return '$kcal سعرة تحت حدّك الأدنى';
  }

  @override
  String eatOutMissProtein(String grams) {
    return 'ينقص $grams غ بروتين';
  }

  @override
  String eatOutVersusOrder(String kcal, String protein) {
    return 'مقارنةً بطلبك: $kcal سعرة، $protein غ بروتين';
  }

  @override
  String get eatOutUseOrder => 'استخدم هذا الطلب';

  @override
  String get eatOutUseInstead => 'استخدمه بدل طلبي';

  @override
  String get eatOutOrderEmptyTitle => 'لا أصناف بعد';

  @override
  String get eatOutOrderEmptyBody =>
      'أضف أصنافًا من القائمة أو اختر اقتراحًا. لا يُسجَّل شيء قبل مراجعتك.';

  @override
  String get eatOutAddFromMenu => 'إضافة من القائمة';

  @override
  String eatOutMenuTitle(String chain) {
    return 'قائمة $chain · كندا';
  }

  @override
  String get eatOutMenuFilter => 'تصفية القائمة';

  @override
  String eatOutAddItem(String name) {
    return 'إضافة $name';
  }

  @override
  String eatOutInOrder(int count) {
    return '$count في الطلب';
  }

  @override
  String eatOutEach(String kcal) {
    return '$kcal سعرة للواحد';
  }

  @override
  String eatOutLess(String name) {
    return 'واحد أقل من $name';
  }

  @override
  String eatOutMore(String name) {
    return 'واحد أكثر من $name';
  }

  @override
  String eatOutCountSaid(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صنف',
      many: '$count صنفًا',
      few: '$count أصناف',
      two: 'صنفان',
      one: 'صنف واحد',
      zero: 'لا أصناف',
    );
    return '$_temp0';
  }

  @override
  String eatOutNoLongerListed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صنف لم تعد في هذه القائمة.',
      many: '$count صنفًا لم تعد في هذه القائمة.',
      few: '$count أصناف لم تعد في هذه القائمة.',
      two: 'صنفان لم يعودا في هذه القائمة.',
      one: 'صنف واحد لم يعد في هذه القائمة.',
      zero: 'كل الأصناف ما زالت في القائمة.',
    );
    return '$_temp0';
  }

  @override
  String get eatOutRemoveThem => 'إزالة';

  @override
  String get eatOutOrderTotal => 'إجمالي الطلب';

  @override
  String eatOutSodium(String mg) {
    return 'الصوديوم $mg ملغ';
  }

  @override
  String get eatOutReview => 'المراجعة والتسجيل';

  @override
  String eatOutOrderName(String chain) {
    return 'طلب $chain';
  }

  @override
  String eatOutSourceLine(String source, String published, String checked) {
    return 'المصدر: $source. تاريخ النشر: $published. تم التحقق في $checked.';
  }

  @override
  String get eatOutNotStated => 'غير مذكور';

  @override
  String get eatOutCustomNote =>
      'تُحسب الأصناف والأحجام المدرجة فقط. أي تعديل مثل بدون صلصة أو جبن إضافي ليست له قيم موثّقة، فلا يمكن حسابه بدقة.';

  @override
  String get eatOutOwnEstimate => 'سجّل تقديرك الخاص بدلًا من ذلك';

  @override
  String get eatOutTargetsTitle => 'أهداف هذا الطلب';

  @override
  String get eatOutTargetsNote =>
      'لهذه الوجبة فقط، وليست أهدافك اليومية. اترك أي حقل فارغًا.';

  @override
  String get eatOutTargetMax => 'الحد الأقصى للسعرات';

  @override
  String get eatOutTargetMin => 'الحد الأدنى للسعرات';

  @override
  String get eatOutTargetProtein => 'الحد الأدنى للبروتين';

  @override
  String get eatOutSortLabel => 'عندما تناسب عدة طلبات، اعرض أولًا';

  @override
  String get eatOutSortAutomatic => 'تلقائي (حسب أهدافك)';

  @override
  String get eatOutApplyTargets => 'استخدم هذه الأهداف';

  @override
  String get eatOutTargetsInvalid =>
      'استخدم أعدادًا صحيحة: السعرات من 100 إلى 4000 (الحد الأدنى من 0)، والبروتين من 1 إلى 300 غ.';

  @override
  String get eatOutKindSandwich => 'شطيرة';

  @override
  String get eatOutKindWrap => 'لفافة';

  @override
  String get eatOutKindSalad => 'سلطة';

  @override
  String get eatOutKindBowl => 'وعاء';

  @override
  String get eatOutKindBreakfast => 'فطور';

  @override
  String get eatOutKindPizza => 'بيتزا';

  @override
  String get eatOutKindChicken => 'دجاج';

  @override
  String get eatOutKindSide => 'طبق جانبي';

  @override
  String get eatOutKindDessert => 'حلوى';

  @override
  String get eatOutKindDrink => 'مشروب';

  @override
  String eatOutChainOfficial(String chain) {
    return 'المعلومات الغذائية المنشورة من $chain كندا';
  }

  @override
  String eatOutPublished(String date) {
    return 'نُشر $date';
  }

  @override
  String eatOutChecked(String date) {
    return 'تم التحقق $date';
  }

  @override
  String eatOutBuildNote(String note) {
    return 'التحضير المعتاد: $note';
  }

  @override
  String get eatOutSodiumLabel => 'الصوديوم';

  @override
  String get eatOutFibreLabel => 'الألياف';

  @override
  String get eatOutSatFatLabel => 'الدهون المشبعة';
}
