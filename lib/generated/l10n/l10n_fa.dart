// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get apiUrlV1Tip =>
      'مشابه https://api.openai.com/v1. ادامه استفاده از این نشانی؟';

  @override
  String get assistant => 'دستیار';

  @override
  String get attention => 'توجه';

  @override
  String get audio => 'صوتی';

  @override
  String get auto => 'خودکار';

  @override
  String get autoCheckUpdate => 'بررسی خودکار به‌روزرسانی';

  @override
  String get autoRmDupChat => 'حذف خودکار گفت‌وگوهای تکراری';

  @override
  String get autoScrollBottom => 'پیمایش خودکار به پایین';

  @override
  String get backupTip => 'لطفاً فایل‌های پشتیبان را خصوصی و ایمن نگه دارید!';

  @override
  String get balance => 'موجودی';

  @override
  String get calcTokenLen => 'محاسبه طول توکن';

  @override
  String get changeModelTip =>
      'کلیدهای مختلف ممکن است به لیست‌های متفاوتی از مدل‌ها دسترسی داشته باشند، بنابراین اگر سازوکار را متوجه نمی‌شوید و خطا گرفتید، بازنشانی مدل توصیه می‌شود.';

  @override
  String get chat => 'گفت‌وگو';

  @override
  String get chatHistoryLength => 'طول تاریخچه گفت‌وگو';

  @override
  String get chatHistoryTip => 'استفاده به عنوان زمینه گفت‌وگو';

  @override
  String get clickSwitch => 'برای تغییر کلیک کنید';

  @override
  String get clickToCheck => 'برای بررسی کلیک کنید';

  @override
  String get clipboard => 'حافظه موقت';

  @override
  String get codeBlock => 'بلوک کد';

  @override
  String get colorSeedTip => 'دانه رنگ است، نه خود رنگ';

  @override
  String get compress => 'فشرده‌سازی';

  @override
  String get compressImgTip => 'برای گفت‌وگو و اشتراک‌گذاری';

  @override
  String get contributor => 'مشارکت‌کنندگان';

  @override
  String get copied => 'کپی شد';

  @override
  String get current => 'جاری';

  @override
  String get custom => 'سفارشی';

  @override
  String get day => 'روز';

  @override
  String get defaulT => 'پیش‌فرض';

  @override
  String delFmt(Object id, Object type) {
    return 'حذف $type($id)؟';
  }

  @override
  String get delete => 'حذف';

  @override
  String get deleteConfirm => 'تأیید قبل از حذف';

  @override
  String get editor => 'ویرایشگر';

  @override
  String emptyFields(Object fields) {
    return '$fields خالی است';
  }

  @override
  String get emptyTrash => 'خالی کردن زباله‌دان';

  @override
  String get emptyTrashTip =>
      '==0، حذف در راه‌اندازی بعدی. <0 حذف خودکار انجام نشود.';

  @override
  String fileNotFound(Object file) {
    return 'فایل($file) یافت نشد';
  }

  @override
  String fileTooLarge(Object size) {
    return 'فایل خیلی بزرگ است: $size';
  }

  @override
  String get followChatModel => 'دنبال کردن مدل گفت‌وگو';

  @override
  String get fontSize => 'اندازه قلم';

  @override
  String get fontSizeSettingTip => 'فقط برای بلوک‌های کد اعمال می‌شود';

  @override
  String get freeCopy => 'کپی رایگان';

  @override
  String get genChatTitle => 'تولیدکننده عنوان گفت‌وگو';

  @override
  String get genTitle => 'تولید عنوان';

  @override
  String get headTailMode => 'سر-ته';

  @override
  String get headTailModeTip =>
      'فقط «پرامپت + اولین پیام کاربر + ورودی جاری» را به عنوان زمینه ارسال کن.\n\nاین برای ترجمه مفید است زیرا توکن ذخیره می‌کند.';

  @override
  String get help => 'راهنما';

  @override
  String get history => 'تاریخچه';

  @override
  String historyToolHelp(Object keywords) {
    return 'بارگذاری گفت‌وگوهای حاوی کلیدواژه‌های $keywords به عنوان زمینه؟';
  }

  @override
  String get historyToolTip => 'بارگذاری تاریخچه گفت‌وگوها به عنوان زمینه';

  @override
  String get hour => 'ساعت';

  @override
  String get httpToolTip => 'ارسال درخواست HTTP، مثلاً جستجوی محتوای وب';

  @override
  String get ignoreContextConstraint => 'نادیده گرفتن محدودیت زمینه';

  @override
  String get ignoreTip => 'نادیده گرفتن نکات';

  @override
  String get image => 'تصویر';

  @override
  String initChatHelp(Object issue, Object unilink) {
    return '### 📖 نکته\n- سرپیمایش در صفحه گفت‌وگو برای جابه‌جایی بین تاریخچه گفت‌وگوها.\n- فشار طولانی روی گفت‌وگو برای کپی رایگان داده خام مارک‌داون / حذف / غیره.\n- نحوه استفاده از URL Scheme را اینجا ببینید $unilink\n\n### 🔍 راهنما\n- اگر باگی پیدا کردید، لطفاً از [Github Issue]($issue) استفاده کنید.';
  }

  @override
  String invalidLinkFmt(Object uri) {
    return 'پیوند نامعتبر: $uri';
  }

  @override
  String get joinBeta => 'پیوستن به برنامه بتا';

  @override
  String get languageName => 'فارسی';

  @override
  String get license => 'مجوز';

  @override
  String get licenseMenuItem => 'مجوزهای منبع‌باز';

  @override
  String get list => 'لیست';

  @override
  String get manual => 'راهنما';

  @override
  String get memory => 'حافظه';

  @override
  String memoryAdded(Object str) {
    return 'حافظه اضافه شد: $str';
  }

  @override
  String memoryTip(Object txt) {
    return 'آیتم [$txt] به خاطر سپرده شود؟';
  }

  @override
  String get message => 'پیام';

  @override
  String get migrationV1UrlTip => 'آیا \"/v1\" به انتهای پیکربندی اضافه شود؟';

  @override
  String get minute => 'دقیقه';

  @override
  String get model => 'مدل';

  @override
  String get modelRegExpTip =>
      'اگر نام مدل مطابقت داشت، از ابزارها استفاده کن.';

  @override
  String get more => 'بیشتر';

  @override
  String get multiModel => 'چندمدلی';

  @override
  String get myOtherApps => 'سایر برنامه‌های من';

  @override
  String get needOpenAIKey => 'لطفاً ابتدا کلید OpenAI را وارد کنید.';

  @override
  String get needRestart => 'برای اعمال نیاز به راه‌اندازی مجدد';

  @override
  String get newChat => 'گفت‌وگوی جدید';

  @override
  String get noDuplication => 'بدون تکرار';

  @override
  String notSupported(Object val) {
    return '$val پشتیبانی نمی‌شود';
  }

  @override
  String get onMsgCome => 'وقتی پیام جدید می‌رسد';

  @override
  String get onSwitchChat => 'وقتی گفت‌وگو عوض می‌شود';

  @override
  String get onlyRestoreHistory =>
      'فقط تاریخچه‌ها را بازیابی کن (به جز نشانی api / کلید مخفی)';

  @override
  String get onlySyncOnLaunch => 'همگام‌سازی فقط در زمان راه‌اندازی';

  @override
  String get other => 'سایر';

  @override
  String get participant => 'شرکت‌کننده';

  @override
  String get passwd => 'رمز عبور';

  @override
  String get privacy => 'حریم خصوصی';

  @override
  String get privacyTip => 'این برنامه هیچ داده‌ای جمع‌آوری نمی‌کند.';

  @override
  String get profile => 'نمایه';

  @override
  String get promptsSettingsItem => 'پرامپت‌ها';

  @override
  String get quickShareTip =>
      'این پیوند را در دستگاه دیگر باز کنید تا پیکربندی فعلی سریعاً وارد شود.';

  @override
  String get raw => 'خام';

  @override
  String get refresh => 'بازسازی';

  @override
  String get regExp => 'عبارت باقاعده';

  @override
  String get remember30s => 'به خاطر سپردن ۳۰ ثانیه';

  @override
  String get rename => 'تغییر نام';

  @override
  String get replay => 'بازپخش';

  @override
  String get replayTip =>
      'پیام‌های بازپخش‌شده و تمام پیام‌های بعد از آن پاک خواهند شد.';

  @override
  String get res => 'منبع';

  @override
  String restoreOpenaiTip(Object url) {
    return 'مستندات را اینجا ببینید $url';
  }

  @override
  String get rmDuplication => 'حذف تکراری‌ها';

  @override
  String rmDuplicationFmt(Object count) {
    return 'مطمئنی $count آیتم حذف شود؟';
  }

  @override
  String get route => 'مسیر';

  @override
  String get save => 'ذخیره';

  @override
  String get saveErrChat => 'ذخیره گفت‌وگو همراه با خطاها';

  @override
  String get saveErrChatTip =>
      'گفت‌وگو را بعد از هر پیام فرستاده یا دریافت‌شده حتی اگر خطا داشته باشد ذخیره کن.';

  @override
  String get scrollSwitchChat => 'پیمایش برای جابه‌جایی گفت‌وگو';

  @override
  String get search => 'جستجو';

  @override
  String get secretKey => 'کلید مخفی';

  @override
  String get share => 'اشتراک‌گذاری';

  @override
  String get shareFrom => 'اشتراک از';

  @override
  String get skipSameTitle =>
      'رد شدن از گفت‌وگوهایی که عنوانشان با گفت‌وگوهای محلی یکی است.';

  @override
  String get softWrap => 'بازه نرم';

  @override
  String get stt => 'تبدیل صدا به متن';

  @override
  String sureRestoreFmt(Object time) {
    return 'آیا از بازیابی پشتیبان($time) مطمئن هستید؟';
  }

  @override
  String get switcher => 'تغییردهنده';

  @override
  String syncConflict(Object a, Object b) {
    return 'تعارض همگام‌سازی: نمی‌توان $a و $b را همزمان روشن کرد.';
  }

  @override
  String get system => 'سیستم';

  @override
  String get text => 'متن';

  @override
  String get themeColorSeed => 'دانه رنگ تم';

  @override
  String get themeMode => 'حالت تم';

  @override
  String get thirdParty => 'شخص ثالث';

  @override
  String get tool => 'ابزار';

  @override
  String toolConfirmFmt(Object tool) {
    return 'آیا استفاده از ابزار $tool مجاز است؟';
  }

  @override
  String get toolFinishTip => 'فراخوانی ابزارها کامل شد';

  @override
  String toolHttpReqHelp(Object host) {
    return 'داده را از شبکه دریافت می‌کند. در این مدت با $host ارتباط برقرار می‌کند.';
  }

  @override
  String get toolHttpReqName => 'درخواست HTTP';

  @override
  String get tts => 'تبدیل متن به گفتار';

  @override
  String get unsupported => 'پشتیبانی نمی‌شود';

  @override
  String get untitled => 'بدون عنوان';

  @override
  String get update => 'به‌روزرسانی';

  @override
  String get usage => 'میزان استفاده';

  @override
  String get user => 'کاربر';

  @override
  String weeksAgo(Object weeks) {
    return '$weeks هفته پیش';
  }

  @override
  String get wrap => 'بسته‌بندی';
}
