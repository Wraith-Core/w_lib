/**
 * Arabic for the developer panel's demo content.
 *
 * ★ Applied in debugData and debugType, so every mock in the drawer is covered by one pass
 *   rather than each file carrying its own pair of strings. The mocks stay written in English
 *   and readable; the translation happens on the way out.
 *
 * ⚠️ Dev only. It never runs in game -- the emitters it lives in are already behind
 *    isEnvBrowser(), and the real payloads come from Lua, which does its own localisation.
 *
 * ★ Keyed by the exact English string. A miss leaves the original in place, which is the right
 *   failure: an untranslated label is legible, a wrong guess is not.
 */
const AR: Record<string, string> = {
  // stations and headings
  Stables: 'الإسطبلات',
  'Kentucky Saddler': 'كنتاكي سادلر',
  'Horse breed': 'سلالة الحصان',
  'Saddle wear': 'حالة السرج',

  // rows
  'Option 1': 'الخيار ١',
  'Option 2': 'الخيار ٢',
  'Option 3': 'الخيار ٣',
  'Empty button': 'زر فارغ',
  'Example button': 'زر تجريبي',
  'Example button description': 'وصف الزر التجريبي',
  'Menu button': 'زر قائمة',
  'Event button': 'زر حدث',
  'Takes you to another menu': 'ينقلك إلى قائمة أخرى',
  'It also has metadata support': 'ويدعم البيانات الوصفية',
  'Open a menu and send event data': 'يفتح قائمة ويرسل بيانات الحدث',
  'Tooltip description 1': 'وصف التلميح ١',
  'Side scroll general description': 'وصف عام للتمرير الجانبي',

  // stats
  Feed: 'العلف',
  Condition: 'الحالة',
  Water: 'الماء',
  Stamina: 'القدرة',
  Coat: 'الفروة',
  'Feed left: 30%': 'المتبقّي من العلف: ٣٠٪',
  'Condition: 80%': 'الحالة: ٨٠٪',

  // controls
  Cancel: 'إلغاء',
  Confirm: 'تأكيد',
  Close: 'إغلاق',
  Back: 'رجوع',
  Nice: 'ممتاز',
  'Value 1': 'القيمة ١',

  // notices
  Success: 'تمّ',
  Error: 'خطأ',
  Warning: 'تنبيه',
  Inform: 'إفادة',
  'Contraband sorted': 'تمّ فرز البضاعة',
  Refused: 'مرفوض',
  'Not enough on you.': 'ما معك ما يكفي.',
  'The batch was collected.': 'تمّ استلام الدفعة.',
  'Not enough on you for that.': 'ما معك ما يكفي لهذا.',
  'The lock is holding.': 'القفل صامد.',
  'Sorting started.': 'بدأ الفرز.',

  // dialogs -- alert
  'Word from the camp': 'خبر من المخيم',
  // The demo's body text carries a literal newline; the key must match it exactly.
  'The stage runs at dawn.  \n **Markdown** works here too.': 'العربة تنطلق عند الفجر.  \n و**تنسيق النصّ** يعمل هنا أيضًا.',
  Ok: 'موافق',
  'Not ok': 'غير موافق',

  '[E] - Open the saddlebags  \n [G] - Do something else': '[E] - افتح خرج السرج  \n [G] - افعل شيئًا آخر',

  // dialogs -- input
  // ⚠️ Renamed from the upstream demo's 'Police locker' and its PIN pad -- a RedM library
  //    should not teach a modern police vocabulary in its own test panel.
  'Tack room': 'غرفة العُدَد',
  'Stall number': 'رقم المربط',
  'Tack type': 'نوع العُدّة',
  'Lock combination': 'توليفة القفل',
  'Opening time': 'وقت الفتح',
  'Number counter': 'عدّاد',
  'Slide bar': 'شريط تمرير',
  'Some checkbox': 'خانة اختيار',
  'Some other checkbox': 'خانة اختيار أخرى',
  Price: 'السعر',
  'Description that tells you what this input field does': 'وصف يشرح ما يفعله هذا الحقل',


  // menu rows
  'Arabian': 'عربي',
  'Tennessee Walker': 'تنسي ووكر',
  'Andalusian': 'أندلسي',
  'Calm and sure-footed': 'هادئ وثابت الخطو',
  'Feed left': 'المتبقّي من العلف',

  // radial
  'Honour': 'الشرف',
  'Hand mirror': 'مرآة يد',
  'Pitch the tent': 'انصب الخيمة',
  'Light the fire': 'أوقد النار',
  'Rest until morning': 'استرح حتّى الصباح',
  'Lock the chest': 'أقفل الصندوق',
  'Camp standing': 'مكانة المخيم',
  'Brush the coat': 'امسح الفروة',
  'Raises the coat back towards full': 'يرفع الفروة نحو الكمال',
  'Feed the horse': 'أطعم الحصان',
  'Costs one bale of hay': 'يكلّف حزمة قشّ',
  'Water the horse': 'اسقِ الحصان',
  'Saddlebags': 'خرج السرج',
  'Sell the horse': 'بع الحصان',
  'This cannot be undone': 'لا يمكن التراجع عن هذا',
  'Campfire': 'موقد النار',
  'Blacksmith': 'الحدّاد',
  'Gunsmith': 'صانع البنادق',
  'Ammunition': 'الذخيرة',
  'A label long enough to show how the centre wraps it': 'عنوان طويل بما يكفي ليظهر كيف يلتفّ في المنتصف',
  'Camp': 'المخيم',
  'External icon': 'أيقونة خارجية',

  // progress
  'Using Lockpick': 'يفتح القفل',
  'Mending a saddle': 'يُصلح السرج',

  // notices -- shapes that stress the layout
  'Title only': 'عنوان فقط',
  'Description only, no title.': 'وصف فقط، بلا عنوان.',
  'Custom icon': 'أيقونة مخصّصة',
  'Uses a named icon rather than the type default.': 'يستخدم أيقونة بالاسم بدل أيقونة النوع.',
  'A long one': 'إشعار طويل',
  'Long enough to wrap more than once, so the toast has to grow downwards and keep the icon aligned to the first line rather than to the middle of the block.': 'طويل بما يكفي ليلتفّ أكثر من مرّة، فينمو الإشعار إلى الأسفل وتبقى الأيقونة محاذية للسطر الأوّل لا لمنتصف الكتلة.',
  'position': 'الموضع',

  // floating RDR notice
  Wanted: 'مطلوب',
  'Bounty $10.00': 'الجائزة $10.00',
  Witness: 'شاهد',
  'Unarmed Assault': 'اعتداء بلا سلاح',
  Valentine: 'فالنتاين',
  'The Heartlands, New Hanover': 'ذا هارتلاندز، نيو هانوفر',
  '25 × weed_raw': '٢٥ × weed_raw',
  'No title, no icon — description only.': 'بلا عنوان وبلا أيقونة — وصف فقط.',
  'Screen text — drawText2D': 'نصّ على الشاشة — drawText2D',
  'World text — drawText3D': 'نصّ في العالم — drawText3D',

  // dashboard
  'Search the stock': 'ابحث في البضاعة',
  'Pick something from the counter': 'اختر شيئًا من المنضدة',
  'Sidearms': 'مسدّسات',
  'Long arms': 'بنادق',
  'Supplies': 'مؤن',
  'Cattleman Revolver': 'مسدّس كاتلمان',
  'Six shots, and cheap to feed': 'ستّ طلقات، وذخيرته رخيصة',
  'The plainest revolver on the frontier, and the one most likely to be in a holster.': 'أبسط مسدّس في الحدود، وأكثرها وجودًا في القراب.',
  'Schofield Revolver': 'مسدّس شوفيلد',
  'Heavier, and it shows': 'أثقل، ويظهر ذلك',
  'Slower out of the holster, but it settles an argument in one.': 'أبطأ خروجًا من القراب، لكنّه يحسم الخلاف بطلقة.',
  'Carbine Repeater': 'بندقية كارباين',
  'For work at a distance': 'للعمل عن بُعد',
  'A rifle you can carry all day and still shoot straight with at dusk.': 'بندقية تحملها يومًا كاملًا وتصيب بها عند الغسق.',
  'Rolling Block Rifle': 'بندقية رولنغ بلوك',
  'Out of stock': 'نفِدت',
  'Gun Oil': 'زيت السلاح',
  'Keeps a barrel honest': 'يُبقي الماسورة سليمة',
  'A cloth and a minute is all it takes to undo a week of rain.': 'خرقة ودقيقة تمحو أثر أسبوع من المطر.',
  'Damage': 'الضرر',
  'Range': 'المدى',
  'Fire rate': 'معدّل الرمي',
  'Accuracy': 'الدقّة',
  'In stock': 'المتوفّر',
  'Inspect': 'افحص',
  'Browse': 'تصفّح',


  // dashboard -- admin
  'Administration': 'الإدارة',
  '38 players online': '٣٨ لاعبًا متّصلًا',
  'Sheriff': 'المأمور',
  'Search by name or id': 'ابحث بالاسم أو الرقم',
  'Pick a player to see their record': 'اختر لاعبًا لترى سجلّه',
  'Standing': 'المكانة',
  'Online': 'المتّصلون',
  'Reports': 'البلاغات',
  'Bans': 'الحظر',
  'Arthur Morgan': 'آرثر مورغان',
  'Micah Bell': 'مايكا بيل',
  'Sadie Adler': 'سايدي أدلر',
  'Charles Smith': 'تشارلز سميث',
  'id 12 · Valentine': 'رقم ١٢ · فالنتاين',
  'id 27 · Strawberry': 'رقم ٢٧ · ستروبيري',
  'id 31 · Annesburg': 'رقم ٣١ · آنسبرغ',
  'Ping': 'الاستجابة',
  'Clean record': 'سجلّ نظيف',
  'Three warnings': 'ثلاثة إنذارات',
  'Playtime': 'مدّة اللعب',
  'Warnings': 'الإنذارات',
  'Money': 'المال',
  'Health': 'الصحّة',
  'Go to': 'انتقل إليه',
  'Kick': 'اطرده',

  // dashboard -- crafting
  'Level 7': 'المستوى ٧',
  'Search recipes': 'ابحث في الوصفات',
  'Pick a recipe': 'اختر وصفة',
  'Hunting Knife': 'سكّين صيد',
  'A blade that holds an edge': 'نصلٌ يحفظ حدّه',
  'Materials ready': 'الموادّ جاهزة',
  'Time': 'الزمن',
  'Level': 'المستوى',
  'Yield': 'الناتج',
  'Materials': 'الموادّ',
  'Iron Ore': 'خام الحديد',
  'Oak Handle': 'مقبض بلّوط',
  'Horseshoe': 'حدوة حصان',
  'Four to a horse': 'أربعٌ للحصان الواحد',
  'Missing iron': 'ينقصه حديد',
  'Craft': 'اصنع',
  '8s left': 'بقيت ٨ ثوانٍ',

  // dashboard -- shop
  'Statistics': 'الإحصاءات',
  '4 in stock': '٤ متوفّرة',
  'The plainest revolver on the frontier.': 'أبسط مسدّس في الحدود.',
  'Cost': 'التكلفة',
  'Cash': 'نقدًا',
  'Costs more than you carry': 'يكلّف أكثر ممّا تحمل',

  // dashboard -- trade
  'Trade': 'مقايضة',
  'with Sadie Adler': 'مع سايدي أدلر',
  'Waiting': 'بالانتظار',
  'Pick something to offer': 'اختر ما تعرضه',
  'What you offer': 'ما تعرضه',
  'What they offer': 'ما يعرضه',
  'Perfect Deer Pelt': 'جلد أيّل ممتاز',
  'Worth a good deal': 'يساوي الكثير',
  'Have': 'لديك',
  'On the table': 'على الطاولة',
  'You have': 'لديك',
  'Offering': 'تعرض',
  'Value': 'القيمة',
  'Perfect Deer Pelt ×1': 'جلد أيّل ممتاز ×١',
  'Cash $12.00': 'نقدًا $12.00',
  'Potent Health Tonic': 'مقوٍّ صحّيّ قويّ',
  'Three of them': 'ثلاثة منها',
  'Accept': 'اقبل',
  'Add to offer': 'أضف إلى العرض',

  // dashboard -- black market
  'Black Market': 'السوق السوداء',
  'Behind the saloon': 'خلف الحانة',
  'Search the crates': 'ابحث في الصناديق',
  'Pick something from the crates': 'اختر شيئًا من الصناديق',
  'Risk': 'الخطر',
  'Case of Moonshine': 'صندوق عرق مقطَّر',
  'No questions asked': 'بلا أسئلة',
  'Two crates left': 'بقي صندوقان',
  'Stock': 'المخزون',
  'Heat': 'السخونة',
  'Demand': 'الطلب',
  'Unmarked Rifle': 'بندقيّة بلا علامة',
  'Serial filed off': 'رقمها مبرود',
  'More than you carry': 'أكثر ممّا تحمل',

  // dashboard -- auction
  'Auction House': 'دار المزاد',
  'Saint Denis': 'سانت دينيس',
  'Search the lots': 'ابحث في القطع',
  'Pick a lot': 'اختر قطعة',
  'Live': 'جارٍ',
  'Your bids': 'مزايداتك',
  'Won': 'ربحتها',
  'Legendary Bear Pelt': 'جلد الدبّ الأسطوريّ',
  'Bid by Sadie Adler': 'زايدت عليه سايدي أدلر',
  'Bid': 'المزايدة',
  'You are outbid': 'زُوِيدَ عليك',
  'Ends in': 'ينتهي خلال',
  'Current bid': 'المزايدة الحاليّة',
  'Your bid': 'مزايدتك',
  'Bids': 'المزايدات',
  'Recent bids': 'آخر المزايدات',
  'You': 'أنت',
  'Gold Pocket Watch': 'ساعة جيب ذهبيّة',
  'No bids yet': 'لا مزايدات بعد',
  'Opening bid': 'مزايدة الافتتاح',
  'Place bid': 'زايد',
  'Watch': 'راقب',


  // dashboard -- admin console
  'Dashboard': 'لوحة القيادة',
  '38 online': '٣٨ متّصلًا',
  'Overview': 'نظرة عامّة',
  'Players': 'اللاعبون',
  'Whitelist': 'القائمة البيضاء',
  'World': 'العالم',
  'Live map': 'الخريطة الحيّة',
  'Teleports': 'نقاط الانتقال',
  'Blips': 'العلامات',
  'Right now': 'الآن',
  'Queue': 'الطابور',
  'Open reports': 'بلاغات مفتوحة',
  'Uptime': 'مدّة التشغيل',
  'Load': 'الحِمل',
  'Server tick': 'نبضة الخادم',
  'Memory': 'الذاكرة',
  'Entities': 'الكيانات',
  'Quick actions': 'إجراءات سريعة',
  'Announce': 'أعلِن',
  'Set weather': 'اضبط الطقس',
  'Restart': 'أعد التشغيل',
  'Recent log': 'آخر السجلّ',
  '124 entries': '١٢٤ مدخلًا',
  'Admin': 'المشرف',
  'Action': 'الإجراء',
  'Target': 'الهدف',

  // dashboard -- marketplace
  'Marketplace': 'السوق',
  'Sell': 'بيع',
  'Earnings': 'الأرباح',
  'Departments': 'الأقسام',
  'Everything': 'كلّ شيء',
  'Pelts and hides': 'الجلود والفراء',
  'Arms': 'الأسلحة',
  'Tonics': 'المقوّيات',
  'From your satchel': 'من حقيبتك',
  '11 items': '١١ غرضًا',
  'Express Rounds': 'طلقات إكسبريس',
  'Express Rounds ×20': 'طلقات إكسبريس ×٢٠',
  'List it': 'اعرضه',
  'Asking price': 'السعر المطلوب',
  'How many': 'الكمّيّة',
  'Runs for': 'يستمرّ',
  '6 hours': '٦ ساعات',
  '24 hours': '٢٤ ساعة',
  '3 days': '٣ أيّام',
  'Sell by auction': 'بِع بالمزاد',
  'List for sale': 'اعرض للبيع',
  'Clear': 'امسح',
  'Your listings': 'معروضاتك',
  '3 live': '٣ جارية',
  'Ends in 4h · 2 bids': 'ينتهي خلال ٤س · مزايدتان',
  'Ends in 19h · no bids': 'ينتهي خلال ١٩س · بلا مزايدات',
  'Withdraw': 'اسحبه',


  // dashboard -- cinema
  'Cinema': 'السينما',
  'Saint Denis Theatre': 'مسرح سانت دينيس',
  'On air': 'على الهواء',
  'Rooms': 'الصالات',
  'Main hall': 'الصالة الكبرى',
  'Balcony': 'الشرفة',
  'Private box': 'المقصورة الخاصّة',
  'The Iron Horse': 'الحصان الحديديّ',
  'Dawn Patrol': 'دوريّة الفجر',
  'Reel 2 of 4 · 18 watching': 'البكرة ٢ من ٤ · ١٨ مشاهدًا',
  'Playback': 'التشغيل',
  'Elapsed': 'المنقضي',
  'Transport': 'التحكّم',
  'Play': 'شغّل',
  'Pause': 'أوقف مؤقّتًا',
  'Stop': 'أوقف',
  'Tags': 'الوسوم',
  'Western': 'ويسترن',
  'Silent': 'صامت',
  'Newsreel': 'نشرة أخبار',
  'Screens': 'الشاشات',
  '3 rooms': '٣ صالات',
  'Playing · 18 seats taken': 'يعمل · ١٨ مقعدًا مشغولًا',
  'Idle': 'خامل',
  'Projector unreachable': 'جهاز العرض لا يستجيب',
  'Retry': 'أعد المحاولة',
  'Schedule a showing': 'جدوِل عرضًا',
  'Reel': 'البكرة',
  'Starts at': 'يبدأ في',
  'On': 'بتاريخ',
  'Repeat nightly': 'كرّره كلّ ليلة',

  // dashboard -- kingdoms
  'Kingdoms': 'الممالك',
  'House Beaumont': 'آل بومون',
  'The house': 'البيت',
  'Members': 'الأعضاء',
  'Treasury': 'الخزينة',
  'Banner': 'الرّاية',
  'Founded 1892 · Lemoyne': 'تأسّس ١٨٩٢ · لوموين',
  'Holdings': 'الأملاك',
  '2nd': 'الثاني',
  'Treasury ledger': 'سجلّ الخزينة',
  'last 30 days': 'آخر ٣٠ يومًا',
  'Day': 'اليوم',
  'Who': 'مَن',
  'What': 'ماذا',
  'Sum': 'المبلغ',
  'House name': 'اسم البيت',
  'Colour': 'اللون',
  'Motto': 'الشعار',
  'Iron before gold': 'الحديد قبل الذهب',
  'Save the banner': 'احفظ الرّاية',
  'Disband': 'حُلّ البيت',
  '14 Jun': '١٤ يونيو',
  '13 Jun': '١٣ يونيو',
  '11 Jun': '١١ يونيو',
  'Deposit': 'إيداع',
  'Upkeep': 'صيانة',


  // voice interaction
  'Barkeep': 'صاحب الحانة',
  'Stranger': 'غريب',
  'Listening': 'ينصت',
  'A whiskey': 'ويسكي',
  'A whiskey...': 'ويسكي...',
  'A whiskey, and keep it coming': 'ويسكي، ولا تتوقّف',
  'Comin’ right up.': 'حاضر حالًا.',
  'Saddle me a horse': 'أسرج لي حصانًا',
  'What is on tonight?': 'ماذا يُعرض الليلة؟',
  'Any work around here?': 'أفي عمل هنا؟',
  'Howdy': 'أهلًا',
  'Move along': 'امضِ في طريقك',


  // voice -- the 2D panel
  'You can say': 'يمكنك أن تقول',
  'Saloon': 'الحانة',
  'Always': 'دائمًا',


  // voice -- phrases with {slots}
  'the usual': 'المعتاد',
  'give me {item}': 'أعطني {item}',
  'what {category} do you have': 'أيّ {category} عندك',
  'buy {quantity} {item}': 'اشترِ {quantity} {item}',
  'do you have {item}': 'أعندك {item}',
  'howdy': 'أهلًا',

  // prompt
  Weed: 'حشيش',
  Talk: 'تحدّث',
  'Hold to pick up': 'اضغط مطوّلًا للالتقاط',
  Locked: 'مقفل',
  Buy: 'شراء',
  'Wraith Prompt': 'أزرار Wraith',
  'Second page': 'الصفحة الثانية',
  'Costs items': 'يكلّف أغراضًا',
};

/** Is the interface right-to-left right now? */
const isRtl = () => typeof document !== 'undefined' && document.documentElement.dir === 'rtl';

/**
 * Translate every string inside a mock payload, in place of nothing when the UI is LTR.
 * Walks arrays and objects; leaves anything that is not a known string exactly as it was.
 */
export const localiseDemo = <T>(value: T): T => {
  if (!isRtl()) return value;

  const walk = (node: unknown): unknown => {
    if (typeof node === 'string') return AR[node] ?? node;
    if (Array.isArray(node)) return node.map(walk);

    if (node && typeof node === 'object') {
      const out: Record<string, unknown> = {};
      for (const [k, v] of Object.entries(node)) out[k] = walk(v);
      return out;
    }

    return node;
  };

  return walk(value) as T;
};
