import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class KlipioLanguage {
  const KlipioLanguage(this.id, this.locale, this.name, this.nativeName);

  final String id;
  final Locale locale;
  final String name;
  final String nativeName;

  String get label => name == nativeName ? name : '$name — $nativeName';
}

abstract final class KlipioLanguages {
  static const all = <KlipioLanguage>[
    KlipioLanguage('en', Locale('en'), 'English', 'English'),
    KlipioLanguage('km', Locale('km'), 'Khmer', 'ខ្មែរ'),
    KlipioLanguage('ja', Locale('ja'), 'Japanese', '日本語'),
    KlipioLanguage('vi', Locale('vi'), 'Vietnamese', 'Tiếng Việt'),
    KlipioLanguage('ko', Locale('ko'), 'Korean', '한국어'),
    KlipioLanguage('zh', Locale('zh'), 'Chinese', '中文'),
    KlipioLanguage('sv', Locale('sv'), 'Swedish', 'Svenska'),
    KlipioLanguage('fil', Locale('fil'), 'Filipino', 'Filipino'),
    KlipioLanguage('hi', Locale('hi'), 'Hindi', 'हिन्दी'),
    KlipioLanguage('pt_BR', Locale('pt', 'BR'), 'Brazilian Portuguese',
        'Português do Brasil'),
    KlipioLanguage('es', Locale('es'), 'Spanish', 'Español'),
    KlipioLanguage('fr', Locale('fr'), 'French', 'Français'),
    KlipioLanguage('de', Locale('de'), 'German', 'Deutsch'),
    KlipioLanguage('it', Locale('it'), 'Italian', 'Italiano'),
    KlipioLanguage('ar', Locale('ar'), 'Arabic', 'العربية'),
    KlipioLanguage('th', Locale('th'), 'Thai', 'ไทย'),
    KlipioLanguage('id', Locale('id'), 'Indonesian', 'Bahasa Indonesia'),
    KlipioLanguage('ms', Locale('ms'), 'Malay', 'Bahasa Melayu'),
    KlipioLanguage('tr', Locale('tr'), 'Turkish', 'Türkçe'),
    KlipioLanguage('pl', Locale('pl'), 'Polish', 'Polski'),
    KlipioLanguage('uk', Locale('uk'), 'Ukrainian', 'Українська'),
    KlipioLanguage('nl', Locale('nl'), 'Dutch', 'Nederlands'),
    KlipioLanguage('bn', Locale('bn'), 'Bengali', 'বাংলা'),
    KlipioLanguage('ur', Locale('ur'), 'Urdu', 'اردو'),
  ];

  static KlipioLanguage fromId(String value) {
    final normalized = switch (value) {
      'English' => 'en',
      String v when v.toLowerCase().startsWith('khmer') => 'km',
      _ => value,
    };
    return all.firstWhere((item) => item.id == normalized,
        orElse: () => all.first);
  }

  static Locale localeFor(String id) => fromId(id).locale;
  static List<Locale> get supportedLocales =>
      all.map((item) => item.locale).toList(growable: false);
}

class KlipioLocalizations {
  const KlipioLocalizations(this.locale);

  final Locale locale;

  static KlipioLocalizations of(BuildContext context) =>
      Localizations.of<KlipioLocalizations>(context, KlipioLocalizations) ??
      const KlipioLocalizations(Locale('en'));

  String tr(String source) {
    final code = locale.countryCode == 'BR' ? 'pt_BR' : locale.languageCode;
    return _translations[code]?[source] ?? source;
  }

  static const LocalizationsDelegate<KlipioLocalizations> delegate =
      _KlipioLocalizationsDelegate();
}

class _KlipioLocalizationsDelegate
    extends LocalizationsDelegate<KlipioLocalizations> {
  const _KlipioLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => KlipioLanguages.supportedLocales
      .any((item) => item.languageCode == locale.languageCode);

  @override
  Future<KlipioLocalizations> load(Locale locale) =>
      SynchronousFuture(KlipioLocalizations(locale));

  @override
  bool shouldReload(_KlipioLocalizationsDelegate old) => false;
}

/// Drop-in localized text for fixed UI labels. Dynamic user/media text is kept
/// unchanged, and missing translations safely fall back to English.
class KText extends StatelessWidget {
  const KText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) => Text(
        KlipioLocalizations.of(context).tr(data),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
}

const Map<String, Map<String, String>> _translations = {
  'km': {
    'Home': 'ទំព័រដើម',
    'Settings': 'ការកំណត់',
    'Create project': 'បង្កើតគម្រោង',
    'Open project': 'បើកគម្រោង',
    'Add media': 'បន្ថែមមេឌៀ',
    'AI Captions': 'ចំណងជើង AI',
    'Split': 'កាត់',
    'Undo': 'មិនធ្វើវិញ',
    'Redo': 'ធ្វើវិញ',
    'Save': 'រក្សាទុក',
    'Export': 'នាំចេញ',
    'Language': 'ភាសា',
    'Cancel': 'បោះបង់',
    'Next': 'បន្ទាប់',
    'Back': 'ត្រឡប់',
    'Install': 'ដំឡើង',
    'Finish': 'បញ្ចប់'
  },
  'ja': {
    'Home': 'ホーム',
    'Settings': '設定',
    'Create project': 'プロジェクトを作成',
    'Open project': 'プロジェクトを開く',
    'Add media': 'メディアを追加',
    'AI Captions': 'AI字幕',
    'Split': '分割',
    'Undo': '元に戻す',
    'Redo': 'やり直す',
    'Save': '保存',
    'Export': '書き出し',
    'Language': '言語',
    'Cancel': 'キャンセル'
  },
  'vi': {
    'Home': 'Trang chủ',
    'Settings': 'Cài đặt',
    'Create project': 'Tạo dự án',
    'Open project': 'Mở dự án',
    'Add media': 'Thêm phương tiện',
    'AI Captions': 'Phụ đề AI',
    'Split': 'Tách',
    'Undo': 'Hoàn tác',
    'Redo': 'Làm lại',
    'Save': 'Lưu',
    'Export': 'Xuất',
    'Language': 'Ngôn ngữ',
    'Cancel': 'Hủy'
  },
  'ko': {
    'Home': '홈',
    'Settings': '설정',
    'Create project': '프로젝트 만들기',
    'Open project': '프로젝트 열기',
    'Add media': '미디어 추가',
    'AI Captions': 'AI 자막',
    'Split': '분할',
    'Undo': '실행 취소',
    'Redo': '다시 실행',
    'Save': '저장',
    'Export': '내보내기',
    'Language': '언어',
    'Cancel': '취소'
  },
  'zh': {
    'Home': '主页',
    'Settings': '设置',
    'Create project': '创建项目',
    'Open project': '打开项目',
    'Add media': '添加媒体',
    'AI Captions': 'AI 字幕',
    'Split': '分割',
    'Undo': '撤销',
    'Redo': '重做',
    'Save': '保存',
    'Export': '导出',
    'Language': '语言',
    'Cancel': '取消'
  },
  'sv': {
    'Home': 'Hem',
    'Settings': 'Inställningar',
    'Create project': 'Skapa projekt',
    'Open project': 'Öppna projekt',
    'Add media': 'Lägg till media',
    'AI Captions': 'AI-undertexter',
    'Split': 'Dela',
    'Undo': 'Ångra',
    'Redo': 'Gör om',
    'Save': 'Spara',
    'Export': 'Exportera',
    'Language': 'Språk',
    'Cancel': 'Avbryt'
  },
  'fil': {
    'Home': 'Home',
    'Settings': 'Mga Setting',
    'Create project': 'Gumawa ng proyekto',
    'Open project': 'Buksan ang proyekto',
    'Add media': 'Magdagdag ng media',
    'AI Captions': 'AI Caption',
    'Split': 'Hatiin',
    'Undo': 'I-undo',
    'Redo': 'Ulitin',
    'Save': 'I-save',
    'Export': 'I-export',
    'Language': 'Wika',
    'Cancel': 'Kanselahin'
  },
  'hi': {
    'Home': 'होम',
    'Settings': 'सेटिंग्स',
    'Create project': 'प्रोजेक्ट बनाएँ',
    'Open project': 'प्रोजेक्ट खोलें',
    'Add media': 'मीडिया जोड़ें',
    'AI Captions': 'AI कैप्शन',
    'Split': 'विभाजित करें',
    'Undo': 'पूर्ववत करें',
    'Redo': 'फिर करें',
    'Save': 'सहेजें',
    'Export': 'निर्यात',
    'Language': 'भाषा',
    'Cancel': 'रद्द करें'
  },
  'pt_BR': {
    'Home': 'Início',
    'Settings': 'Configurações',
    'Create project': 'Criar projeto',
    'Open project': 'Abrir projeto',
    'Add media': 'Adicionar mídia',
    'AI Captions': 'Legendas por IA',
    'Split': 'Dividir',
    'Undo': 'Desfazer',
    'Redo': 'Refazer',
    'Save': 'Salvar',
    'Export': 'Exportar',
    'Language': 'Idioma',
    'Cancel': 'Cancelar'
  },
  'es': {
    'Home': 'Inicio',
    'Settings': 'Configuración',
    'Create project': 'Crear proyecto',
    'Open project': 'Abrir proyecto',
    'Add media': 'Añadir medios',
    'AI Captions': 'Subtítulos con IA',
    'Split': 'Dividir',
    'Undo': 'Deshacer',
    'Redo': 'Rehacer',
    'Save': 'Guardar',
    'Export': 'Exportar',
    'Language': 'Idioma',
    'Cancel': 'Cancelar'
  },
  'fr': {
    'Home': 'Accueil',
    'Settings': 'Paramètres',
    'Create project': 'Créer un projet',
    'Open project': 'Ouvrir un projet',
    'Add media': 'Ajouter un média',
    'AI Captions': 'Sous-titres IA',
    'Split': 'Scinder',
    'Undo': 'Annuler',
    'Redo': 'Rétablir',
    'Save': 'Enregistrer',
    'Export': 'Exporter',
    'Language': 'Langue',
    'Cancel': 'Annuler'
  },
  'de': {
    'Home': 'Start',
    'Settings': 'Einstellungen',
    'Create project': 'Projekt erstellen',
    'Open project': 'Projekt öffnen',
    'Add media': 'Medien hinzufügen',
    'AI Captions': 'KI-Untertitel',
    'Split': 'Teilen',
    'Undo': 'Rückgängig',
    'Redo': 'Wiederholen',
    'Save': 'Speichern',
    'Export': 'Exportieren',
    'Language': 'Sprache',
    'Cancel': 'Abbrechen'
  },
  'it': {
    'Home': 'Home',
    'Settings': 'Impostazioni',
    'Create project': 'Crea progetto',
    'Open project': 'Apri progetto',
    'Add media': 'Aggiungi media',
    'AI Captions': 'Sottotitoli IA',
    'Split': 'Dividi',
    'Undo': 'Annulla',
    'Redo': 'Ripeti',
    'Save': 'Salva',
    'Export': 'Esporta',
    'Language': 'Lingua',
    'Cancel': 'Annulla'
  },
  'ar': {
    'Home': 'الرئيسية',
    'Settings': 'الإعدادات',
    'Create project': 'إنشاء مشروع',
    'Open project': 'فتح مشروع',
    'Add media': 'إضافة وسائط',
    'AI Captions': 'ترجمة بالذكاء الاصطناعي',
    'Split': 'تقسيم',
    'Undo': 'تراجع',
    'Redo': 'إعادة',
    'Save': 'حفظ',
    'Export': 'تصدير',
    'Language': 'اللغة',
    'Cancel': 'إلغاء'
  },
  'th': {
    'Home': 'หน้าหลัก',
    'Settings': 'การตั้งค่า',
    'Create project': 'สร้างโปรเจกต์',
    'Open project': 'เปิดโปรเจกต์',
    'Add media': 'เพิ่มสื่อ',
    'AI Captions': 'คำบรรยาย AI',
    'Split': 'แบ่ง',
    'Undo': 'เลิกทำ',
    'Redo': 'ทำซ้ำ',
    'Save': 'บันทึก',
    'Export': 'ส่งออก',
    'Language': 'ภาษา',
    'Cancel': 'ยกเลิก'
  },
  'id': {
    'Home': 'Beranda',
    'Settings': 'Pengaturan',
    'Create project': 'Buat proyek',
    'Open project': 'Buka proyek',
    'Add media': 'Tambah media',
    'AI Captions': 'Teks AI',
    'Split': 'Pisahkan',
    'Undo': 'Urungkan',
    'Redo': 'Ulangi',
    'Save': 'Simpan',
    'Export': 'Ekspor',
    'Language': 'Bahasa',
    'Cancel': 'Batal'
  },
  'ms': {
    'Home': 'Laman utama',
    'Settings': 'Tetapan',
    'Create project': 'Cipta projek',
    'Open project': 'Buka projek',
    'Add media': 'Tambah media',
    'AI Captions': 'Kapsyen AI',
    'Split': 'Pisah',
    'Undo': 'Buat asal',
    'Redo': 'Buat semula',
    'Save': 'Simpan',
    'Export': 'Eksport',
    'Language': 'Bahasa',
    'Cancel': 'Batal'
  },
  'tr': {
    'Home': 'Ana Sayfa',
    'Settings': 'Ayarlar',
    'Create project': 'Proje oluştur',
    'Open project': 'Proje aç',
    'Add media': 'Medya ekle',
    'AI Captions': 'Yapay zekâ altyazıları',
    'Split': 'Böl',
    'Undo': 'Geri al',
    'Redo': 'Yinele',
    'Save': 'Kaydet',
    'Export': 'Dışa aktar',
    'Language': 'Dil',
    'Cancel': 'İptal'
  },
  'pl': {
    'Home': 'Strona główna',
    'Settings': 'Ustawienia',
    'Create project': 'Utwórz projekt',
    'Open project': 'Otwórz projekt',
    'Add media': 'Dodaj multimedia',
    'AI Captions': 'Napisy AI',
    'Split': 'Podziel',
    'Undo': 'Cofnij',
    'Redo': 'Ponów',
    'Save': 'Zapisz',
    'Export': 'Eksportuj',
    'Language': 'Język',
    'Cancel': 'Anuluj'
  },
  'uk': {
    'Home': 'Головна',
    'Settings': 'Налаштування',
    'Create project': 'Створити проєкт',
    'Open project': 'Відкрити проєкт',
    'Add media': 'Додати медіа',
    'AI Captions': 'Субтитри ШІ',
    'Split': 'Розділити',
    'Undo': 'Скасувати',
    'Redo': 'Повторити',
    'Save': 'Зберегти',
    'Export': 'Експортувати',
    'Language': 'Мова',
    'Cancel': 'Скасувати'
  },
  'nl': {
    'Home': 'Start',
    'Settings': 'Instellingen',
    'Create project': 'Project maken',
    'Open project': 'Project openen',
    'Add media': 'Media toevoegen',
    'AI Captions': 'AI-ondertiteling',
    'Split': 'Splitsen',
    'Undo': 'Ongedaan maken',
    'Redo': 'Opnieuw',
    'Save': 'Opslaan',
    'Export': 'Exporteren',
    'Language': 'Taal',
    'Cancel': 'Annuleren'
  },
  'bn': {
    'Home': 'হোম',
    'Settings': 'সেটিংস',
    'Create project': 'প্রকল্প তৈরি করুন',
    'Open project': 'প্রকল্প খুলুন',
    'Add media': 'মিডিয়া যোগ করুন',
    'AI Captions': 'AI ক্যাপশন',
    'Split': 'বিভক্ত করুন',
    'Undo': 'পূর্বাবস্থায়',
    'Redo': 'পুনরায়',
    'Save': 'সংরক্ষণ',
    'Export': 'রপ্তানি',
    'Language': 'ভাষা',
    'Cancel': 'বাতিল'
  },
  'ur': {
    'Home': 'ہوم',
    'Settings': 'ترتیبات',
    'Create project': 'پروجیکٹ بنائیں',
    'Open project': 'پروجیکٹ کھولیں',
    'Add media': 'میڈیا شامل کریں',
    'AI Captions': 'AI کیپشن',
    'Split': 'تقسیم',
    'Undo': 'کالعدم',
    'Redo': 'دوبارہ',
    'Save': 'محفوظ کریں',
    'Export': 'برآمد',
    'Language': 'زبان',
    'Cancel': 'منسوخ'
  },
};
