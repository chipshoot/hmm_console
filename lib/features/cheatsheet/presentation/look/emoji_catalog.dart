/// The emoji picker's curated grid. Keywords are SEARCH vocabulary, not copy:
/// both languages are always searched, whatever the UI locale, so a bilingual
/// user can type either. Code points are escaped so a variation selector
/// (U+FE0F) can never be lost by an editor.
enum EmojiGroup { vehicle, health, home, books, work, travel, money, misc }

class EmojiEntry {
  const EmojiEntry(this.emoji, this.group, this.en, this.zh);

  final String emoji;
  final EmojiGroup group;

  /// Lower-case English keywords; the first is the accessible name.
  final List<String> en;

  /// Chinese keywords; the first is the accessible name in zh.
  final List<String> zh;
}

class EmojiCatalog {
  const EmojiCatalog._();

  static const List<EmojiEntry> entries = [
    // Vehicle
    EmojiEntry(
      '\u{1F697}',
      EmojiGroup.vehicle,
      ['car', 'vehicle', 'auto'],
      ['汽车', '车'],
    ),
    EmojiEntry('\u{1F699}', EmojiGroup.vehicle, ['suv', 'jeep'], ['越野车', '车']),
    EmojiEntry(
      '\u{1F3CD}️',
      EmojiGroup.vehicle,
      ['motorcycle', 'motorbike'],
      ['摩托车'],
    ),
    EmojiEntry('\u{1F6B2}', EmojiGroup.vehicle, ['bicycle', 'bike'], ['自行车']),
    EmojiEntry(
      '⛽',
      EmojiGroup.vehicle,
      ['fuel', 'gas', 'petrol'],
      ['加油', '汽油'],
    ),
    EmojiEntry(
      '\u{1F527}',
      EmojiGroup.vehicle,
      ['wrench', 'repair', 'service'],
      ['维修', '扳手'],
    ),
    EmojiEntry(
      '\u{1F6DE}',
      EmojiGroup.vehicle,
      ['tire', 'tyre', 'wheel'],
      ['轮胎', '车轮'],
    ),
    EmojiEntry(
      '\u{1F6A6}',
      EmojiGroup.vehicle,
      ['traffic light', 'road'],
      ['红绿灯', '交通'],
    ),
    // Health
    EmojiEntry('⚕️', EmojiGroup.health, ['medical', 'health'], ['医疗', '健康']),
    EmojiEntry(
      '\u{1F48A}',
      EmojiGroup.health,
      ['pill', 'medicine', 'drug'],
      ['药', '药丸'],
    ),
    EmojiEntry(
      '\u{1FA7A}',
      EmojiGroup.health,
      ['stethoscope', 'doctor'],
      ['医生', '听诊器'],
    ),
    EmojiEntry(
      '\u{1F3E5}',
      EmojiGroup.health,
      ['hospital', 'clinic'],
      ['医院', '诊所'],
    ),
    EmojiEntry(
      '\u{1F9B7}',
      EmojiGroup.health,
      ['tooth', 'dentist', 'dental'],
      ['牙齿', '牙医'],
    ),
    EmojiEntry(
      '\u{1FA79}',
      EmojiGroup.health,
      ['bandage', 'first aid'],
      ['创可贴', '急救'],
    ),
    EmojiEntry('❤️', EmojiGroup.health, ['heart', 'love'], ['心', '爱']),
    EmojiEntry('\u{1F9EC}', EmojiGroup.health, ['dna', 'gene'], ['基因']),
    // Home
    EmojiEntry('\u{1F3E0}', EmojiGroup.home, ['home', 'house'], ['家', '房子']),
    EmojiEntry('\u{1F511}', EmojiGroup.home, ['key', 'lock'], ['钥匙']),
    EmojiEntry(
      '\u{1F6CB}️',
      EmojiGroup.home,
      ['couch', 'sofa', 'furniture'],
      ['沙发', '家具'],
    ),
    EmojiEntry(
      '\u{1F9F9}',
      EmojiGroup.home,
      ['broom', 'cleaning'],
      ['扫帚', '清洁'],
    ),
    EmojiEntry(
      '\u{1F4A1}',
      EmojiGroup.home,
      ['light bulb', 'idea'],
      ['灯泡', '想法'],
    ),
    EmojiEntry(
      '\u{1F50C}',
      EmojiGroup.home,
      ['plug', 'electric', 'power'],
      ['插头', '电'],
    ),
    EmojiEntry(
      '\u{1F6BF}',
      EmojiGroup.home,
      ['shower', 'bathroom'],
      ['淋浴', '浴室'],
    ),
    EmojiEntry('\u{1F331}', EmojiGroup.home, ['plant', 'garden'], ['植物', '花园']),
    // Books & learning
    EmojiEntry(
      '\u{1F4D6}',
      EmojiGroup.books,
      ['book', 'read', 'reading'],
      ['书', '阅读'],
    ),
    EmojiEntry(
      '\u{1F4DA}',
      EmojiGroup.books,
      ['books', 'library'],
      ['书籍', '图书馆'],
    ),
    EmojiEntry(
      '\u{1F4DD}',
      EmojiGroup.books,
      ['memo', 'note', 'notes'],
      ['笔记', '备忘'],
    ),
    EmojiEntry(
      '\u{1F393}',
      EmojiGroup.books,
      ['graduation', 'school', 'study'],
      ['毕业', '学校', '学习'],
    ),
    EmojiEntry('✏️', EmojiGroup.books, ['pencil', 'write'], ['铅笔', '写']),
    EmojiEntry(
      '\u{1F9E0}',
      EmojiGroup.books,
      ['brain', 'learn', 'memory'],
      ['大脑', '记忆'],
    ),
    EmojiEntry(
      '\u{1F52C}',
      EmojiGroup.books,
      ['microscope', 'science'],
      ['显微镜', '科学'],
    ),
    EmojiEntry(
      '\u{1F5E3}️',
      EmojiGroup.books,
      ['language', 'speak'],
      ['语言', '说话'],
    ),
    // Work
    EmojiEntry(
      '\u{1F4BC}',
      EmojiGroup.work,
      ['work', 'briefcase', 'job'],
      ['工作', '公文包'],
    ),
    EmojiEntry(
      '\u{1F4BB}',
      EmojiGroup.work,
      ['laptop', 'computer'],
      ['电脑', '笔记本电脑'],
    ),
    EmojiEntry(
      '\u{1F4C5}',
      EmojiGroup.work,
      ['calendar', 'date'],
      ['日历', '日期'],
    ),
    EmojiEntry(
      '\u{1F4CA}',
      EmojiGroup.work,
      ['bar chart', 'report'],
      ['图表', '报告'],
    ),
    EmojiEntry(
      '\u{1F4CE}',
      EmojiGroup.work,
      ['paperclip', 'attachment'],
      ['回形针', '附件'],
    ),
    EmojiEntry('☎️', EmojiGroup.work, ['telephone', 'call'], ['电话']),
    EmojiEntry('\u{1F4E7}', EmojiGroup.work, ['email', 'mail'], ['邮件', '电子邮件']),
    EmojiEntry(
      '\u{1F5C2}️',
      EmojiGroup.work,
      ['folder', 'dividers', 'files'],
      ['文件夹', '文件'],
    ),
    // Travel
    EmojiEntry('✈️', EmojiGroup.travel, ['plane', 'flight'], ['飞机', '航班']),
    EmojiEntry(
      '\u{1F9F3}',
      EmojiGroup.travel,
      ['luggage', 'suitcase'],
      ['行李', '行李箱'],
    ),
    EmojiEntry('\u{1F5FA}️', EmojiGroup.travel, ['map', 'world'], ['地图']),
    EmojiEntry('\u{1F3E8}', EmojiGroup.travel, ['hotel'], ['酒店', '旅馆']),
    EmojiEntry(
      '\u{1F6C2}',
      EmojiGroup.travel,
      ['passport', 'customs', 'border'],
      ['护照', '海关', '边境'],
    ),
    EmojiEntry('\u{1F686}', EmojiGroup.travel, ['train', 'rail'], ['火车', '铁路']),
    EmojiEntry(
      '\u{1F3D6}️',
      EmojiGroup.travel,
      ['beach', 'vacation', 'holiday'],
      ['海滩', '度假'],
    ),
    EmojiEntry('\u{1F3AB}', EmojiGroup.travel, ['ticket'], ['票', '门票']),
    // Money
    EmojiEntry(
      '\u{1F4B0}',
      EmojiGroup.money,
      ['money', 'savings'],
      ['钱', '存款'],
    ),
    EmojiEntry(
      '\u{1F4B3}',
      EmojiGroup.money,
      ['credit card', 'bank card'],
      ['信用卡', '银行卡'],
    ),
    EmojiEntry('\u{1F3E6}', EmojiGroup.money, ['bank'], ['银行']),
    EmojiEntry(
      '\u{1F9FE}',
      EmojiGroup.money,
      ['receipt', 'invoice'],
      ['收据', '发票'],
    ),
    EmojiEntry('\u{1F4B5}', EmojiGroup.money, ['cash', 'dollar'], ['现金', '美元']),
    EmojiEntry(
      '\u{1F4C8}',
      EmojiGroup.money,
      ['invest', 'growth', 'stocks'],
      ['投资', '增长', '股票'],
    ),
    EmojiEntry('\u{1FA99}', EmojiGroup.money, ['coin'], ['硬币']),
    EmojiEntry(
      '\u{1F6E1}️',
      EmojiGroup.money,
      ['insurance', 'shield'],
      ['保险', '保护'],
    ),
    // Misc
    EmojiEntry(
      '⭐',
      EmojiGroup.misc,
      ['star', 'favourite', 'favorite'],
      ['星', '收藏'],
    ),
    EmojiEntry('\u{1F4CC}', EmojiGroup.misc, ['pin', 'pushpin'], ['图钉', '置顶']),
    EmojiEntry('✅', EmojiGroup.misc, ['done', 'check'], ['完成', '勾']),
    EmojiEntry('⚠️', EmojiGroup.misc, ['warning', 'caution'], ['警告', '注意']),
    EmojiEntry(
      '\u{1F512}',
      EmojiGroup.misc,
      ['lock', 'private', 'secret'],
      ['锁', '私密'],
    ),
    EmojiEntry('\u{1F381}', EmojiGroup.misc, ['gift', 'present'], ['礼物']),
    EmojiEntry('\u{1F436}', EmojiGroup.misc, ['dog', 'pet'], ['狗', '宠物']),
    EmojiEntry(
      '\u{1F37D}️',
      EmojiGroup.misc,
      ['food', 'restaurant', 'dinner'],
      ['食物', '餐厅'],
    ),
  ];

  static List<EmojiEntry> inGroup(EmojiGroup group) => [
    for (final e in entries)
      if (e.group == group) e,
  ];

  /// Case-insensitive substring match on either language's keywords, or the
  /// emoji itself. An empty query returns everything.
  static List<EmojiEntry> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return [
      for (final e in entries)
        if (e.emoji == q ||
            e.en.any((k) => k.contains(q)) ||
            e.zh.any((k) => k.contains(q)))
          e,
    ];
  }
}
