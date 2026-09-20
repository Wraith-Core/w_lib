/**
 * The developer drawer's own wording, in both directions.
 *
 * ★ Kept here and NOT in locales/*.json. Those files are the library's public strings, shipped
 *   to every consumer and translated thirteen ways; the drawer is browser-only scaffolding that
 *   no player ever sees. Putting its labels there would ask a translator to work on a panel
 *   that never reaches the game, and would grow every locale file by thirty dead keys.
 *
 * ★ The labels are SHORT because each one now sits under a heading that supplies its subject.
 *   They used to repeat it -- 'Context menu: submenu (back arrow)' under no heading at all --
 *   and in Arabic that punctuation was the worst of it: a colon and a bracket between two
 *   Arabic runs are bidi-neutral, so they were reordered on screen and the label came out as
 *   'الكونتكست منيو: قائمة فرعيّة (سهم رجو:'. Dropping the prefix removes the ambiguity at the
 *   source rather than papering over it with direction marks.
 *
 * ⚠️ Dev only, like the drawer itself -- <Dev /> renders behind isEnvBrowser(), so none of this
 *    is in a production bundle.
 */

const en = {
  drawer: 'Developer drawer',

  // ── groups ──────────────────────────────────────────────────────────────
  gDirection: 'Direction',
  gPanel: 'Dashboard',
  gDialogs: 'Dialogs',
  gMenus: 'Menus',
  gNotices: 'Notifications',
  gScreenText: 'On-screen text',
  gVoice: 'Voice',
  gProgress: 'Progress',
  gPrompt: 'Prompt',
  gMinigames: 'Minigames',
  gGizmo: 'Gizmo',

  // ── direction ───────────────────────────────────────────────────────────
  arabic: 'العربية — RTL',
  english: 'English — LTR',

  // ── dialogs ─────────────────────────────────────────────────────────────
  panelConsole: 'Admin console (nav + blocks)',
  panelCraftAdmin: 'Crafting admin (folding categories)',
  panelMarketplace: 'Marketplace (cards + form)',
  panelCinema: 'Cinema (dots + chips + schedule)',
  panelKingdom: 'Kingdom (crest + ledger)',
  panelAdmin: 'Admin, simple list',
  panelCrafting: 'Crafting bench',
  panelBusy: 'Bench, mid-craft',
  panelShop: 'Shop',
  panelTrade: 'Trade',
  panelMarket: 'Black market',
  panelAuction: 'Auction house',
  panelClose: 'Close it',

  inputDialog: 'Input dialog',
  alertDialog: 'Alert dialog',

  // ── menus ───────────────────────────────────────────────────────────────
  contextMenu: 'Context menu',
  contextSub: 'Context submenu',
  listMenu: 'List menu',
  radial: 'Radial menu',
  radialSub: 'Radial submenu',
  radialHide: 'Close the wheel',

  // ── notifications ───────────────────────────────────────────────────────
  notifyKinds: 'The four kinds',
  notifyPositions: 'Every position',
  notifyShapes: 'Awkward shapes',
  noticePlain: 'RDR notice, no background',
  noticeVariants: 'RDR notice, plate and colours',
  noticeLaw: 'Law banner: wanted / witness',

  // ── on-screen text ──────────────────────────────────────────────────────
  textui: 'TextUI',
  noticeText: '2D and 3D world text',
  noticeClear: 'Clear the text',

  // ── progress ────────────────────────────────────────────────────────────
  voicePlay: 'Play an exchange',
  voiceHide: 'Clear it',

  progressBar: 'Progress bar',

  // ── prompt ──────────────────────────────────────────────────────────────
  promptShow: 'Show the group',
  promptHide: 'Hide',

  // ── minigames ───────────────────────────────────────────────────────────
  lockpick: 'Lockpick',
  qte: 'Quick-time event',
  minigameHide: 'Hide',

  // ── gizmo ───────────────────────────────────────────────────────────────
  gizmoOpen: 'Open',
  gizmoTranslate: 'Translate',
  gizmoRotate: 'Rotate',
  gizmoClose: 'Close',
};

/** ★ The two direction buttons keep their own names in both tables -- a language is named in
 *    itself, so 'العربية' does not become 'Arabic' when the panel is in English. */
const ar: typeof en = {
  drawer: 'درج التطوير',

  gDirection: 'الاتجاه',
  gPanel: 'الداشبورد',
  gDialogs: 'الحوارات',
  gMenus: 'القوائم',
  gNotices: 'الإشعارات',
  gScreenText: 'نصّ الشاشة',
  gVoice: 'الصوت',
  gProgress: 'التقدّم',
  gPrompt: 'الأزرار',
  gMinigames: 'الألعاب المصغّرة',
  gGizmo: 'أداة التحريك',

  arabic: 'العربية — RTL',
  english: 'English — LTR',

  panelConsole: 'لوحة الإدارة (قائمة وكتل)',
  panelCraftAdmin: 'لوحة تحكم التصنيع (تصنيفات تنطوي)',
  panelMarketplace: 'السوق (بطاقات ونموذج)',
  panelCinema: 'السينما (مؤشّرات وجدولة)',
  panelKingdom: 'المملكة (شعار وسجلّ)',
  panelAdmin: 'الإدارة، قائمة بسيطة',
  panelCrafting: 'طاولة التصنيع',
  panelBusy: 'الطاولة أثناء العمل',
  panelShop: 'متجر',
  panelTrade: 'مقايضة',
  panelMarket: 'السوق السوداء',
  panelAuction: 'دار المزاد',
  panelClose: 'أغلقه',

  inputDialog: 'حوار الإدخال',
  alertDialog: 'حوار التنبيه',

  contextMenu: 'كونتكست منيو',
  contextSub: 'كونتكست منيو فرعيّة',
  listMenu: 'قائمة عاديّة',
  radial: 'قائمة دائريّة',
  radialSub: 'قائمة دائريّة فرعيّة',
  radialHide: 'أغلق العجلة',

  notifyKinds: 'الأنواع الأربعة',
  notifyPositions: 'كلّ المواضع',
  notifyShapes: 'أشكال صعبة',
  noticePlain: 'إشعار ريد ام بلا خلفيّة',
  noticeVariants: 'إشعار ريد ام بلوح وألوان',
  noticeLaw: 'لافتة القانون: مطلوب / شاهد',

  textui: 'نصّ الشاشة',
  noticeText: 'نصّ على الشاشة وفي العالم',
  noticeClear: 'امسح النصّ',

  voicePlay: 'شغّل محادثة',
  voiceHide: 'امسحها',

  progressBar: 'شريط التقدّم',

  promptShow: 'أظهر المجموعة',
  promptHide: 'أخفِ',

  lockpick: 'فتح القفل',
  qte: 'اختبار السرعة',
  minigameHide: 'أخفِ',

  gizmoOpen: 'افتح',
  gizmoTranslate: 'إزاحة',
  gizmoRotate: 'تدوير',
  gizmoClose: 'أغلق',
};

export type DevText = typeof en;

export const devText = (rtl: boolean): DevText => (rtl ? ar : en);
