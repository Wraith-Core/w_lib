import { debugData } from '../../../utils/debugData';
import { wcAsset } from '../../../wc/bootstrap';

/**
 * The dashboard, in the four shapes it was asked to cover.
 *
 * ★ They are all ONE description. Nothing below sets a mode or picks a layout -- an admin panel
 *   is a list with tabs, a shop is a list with prices, a bench is a list with materials and a
 *   progress row, a trade is two sides shown as requirements. If any of these needed a flag of
 *   its own the template would not be general, it would be four templates sharing a file.
 */

const ART = () => wcAsset('assets/images/icons/item.png');

const show = (data: unknown) => debugData([{ action: 'showPanel', data }]);

/* ── admin ────────────────────────────────────────────────────────────────── */

export const debugPanelAdmin = () =>
  show({
    id: 'admin',
    title: 'Administration',
    subtitle: '38 players online',
    icon: 'menu_icon_rank',
    aside: 'Sheriff',
    searchPlaceholder: 'Search by name or id',
    emptyText: 'Pick a player to see their record',
    statsLabel: 'Standing',
    tabs: [
      { id: 'online', label: 'Online' },
      { id: 'reports', label: 'Reports' },
      { id: 'bans', label: 'Bans' },
    ],
    activeTab: 'online',
    items: [
      {
        id: 12,
        title: 'Arthur Morgan',
        description: 'id 12 · Valentine',
        icon: 'blip_camp',
        group: 'Van der Linde',
        meta: [{ label: 'Ping', value: '42ms' }],
        detail: {
          title: 'Arthur Morgan',
          image: ART(),
          tag: 'Clean record',
          description: 'id 12 · Valentine',
          rows: [
            { label: 'Playtime', value: '46h' },
            { label: 'Warnings', value: 0 },
            { label: 'Money', value: '$1,204' },
          ],
          stats: [
            { label: 'Honour', progress: 78 },
            { label: 'Health', progress: 92 },
          ],
        },
      },
      {
        id: 27,
        title: 'Micah Bell',
        description: 'id 27 · Strawberry',
        icon: 'blip_camp',
        group: 'Van der Linde',
        meta: [{ label: 'Ping', value: '210ms' }],
        detail: {
          title: 'Micah Bell',
          image: ART(),
          tag: 'Three warnings',
          tagBad: true,
          description: 'id 27 · Strawberry',
          rows: [
            { label: 'Playtime', value: '12h' },
            { label: 'Warnings', value: 3 },
            { label: 'Money', value: '$88' },
          ],
          stats: [
            { label: 'Honour', progress: 11 },
            { label: 'Health', progress: 64 },
          ],
        },
      },
      { id: 31, title: 'Sadie Adler', description: 'id 31 · Annesburg', icon: 'blip_camp', group: 'Van der Linde' },
    ],
    actions: [
      { id: 'goto', label: 'Go to', icon: 'star', primary: true },
      { id: 'kick', label: 'Kick', icon: 'cross' },
    ],
    hints: [
      { key: '↑↓', label: 'Browse' },
      { key: 'Enter', label: 'Go to' },
      { key: 'Esc', label: 'Close' },
    ],
  });

/* ── crafting ─────────────────────────────────────────────────────────────── */

export const debugPanelCrafting = () =>
  show({
    id: 'bench',
    title: 'Blacksmith',
    subtitle: 'Valentine',
    icon: 'blip_shop_blacksmith',
    theme: 'campfire',
    aside: 'Level 7',
    searchPlaceholder: 'Search recipes',
    emptyText: 'Pick a recipe',
    items: [
      {
        id: 'knife',
        title: 'Hunting Knife',
        description: 'A blade that holds an edge',
        icon: 'blip_shop_blacksmith',
        group: 'Blades',
        detail: {
          title: 'Hunting Knife',
          image: ART(),
          tag: 'Materials ready',
          rows: [
            { label: 'Time', value: '20s' },
            { label: 'Level', value: 4 },
            { label: 'Yield', value: '×1' },
          ],
          requirementsLabel: 'Materials',
          requirements: [
            { label: 'Iron Ore', amount: '3 / 6', icon: 'blip_ammo_bullets' },
            { label: 'Oak Handle', amount: '1 / 2', icon: 'blip_campfire' },
          ],
        },
      },
      {
        id: 'horseshoe',
        title: 'Horseshoe',
        description: 'Four to a horse',
        icon: 'blip_shop_blacksmith',
        group: 'Tack',
        detail: {
          title: 'Horseshoe',
          image: ART(),
          tag: 'Missing iron',
          tagBad: true,
          rows: [
            { label: 'Time', value: '8s' },
            { label: 'Level', value: 1 },
            { label: 'Yield', value: '×4' },
          ],
          requirementsLabel: 'Materials',
          requirements: [{ label: 'Iron Ore', amount: '0 / 2', icon: 'blip_ammo_bullets', missing: true }],
        },
      },
    ],
    actions: [{ id: 'craft', label: 'Craft', icon: 'tick', primary: true }],
    hints: [
      { key: '↑↓', label: 'Browse' },
      { key: 'Enter', label: 'Craft' },
      { key: 'Esc', label: 'Close' },
    ],
  });

/** The same bench, mid-craft: the action row gives way to the progress row. */
export const debugPanelBusy = () =>
  show({
    id: 'bench',
    title: 'Blacksmith',
    subtitle: 'Valentine',
    icon: 'blip_shop_blacksmith',
    theme: 'campfire',
    aside: 'Level 7',
    emptyText: 'Pick a recipe',
    items: [{ id: 'knife', title: 'Hunting Knife', icon: 'blip_shop_blacksmith', group: 'Blades' }],
    actions: [{ id: 'craft', label: 'Craft', icon: 'tick', primary: true }],
    progress: { label: 'Hunting Knife', image: ART(), value: 62, info: '8s left', cancelLabel: 'Cancel' },
  });

/* ── shop ─────────────────────────────────────────────────────────────────── */

export const debugPanelShop = () =>
  show({
    id: 'gunsmith',
    title: 'Gunsmith',
    subtitle: 'Valentine',
    icon: 'blip_shop_gunsmith',
    theme: 'shop',
    aside: '$142.50',
    searchPlaceholder: 'Search the stock',
    emptyText: 'Pick something from the counter',
    statsLabel: 'Statistics',
    items: [
      {
        id: 'cattleman',
        title: 'Cattleman Revolver',
        description: 'Six shots, and cheap to feed',
        icon: 'blip_shop_gunsmith',
        group: 'Sidearms',
        meta: [{ label: 'Price', value: '$45.00' }],
        detail: {
          title: 'Cattleman Revolver',
          image: ART(),
          tag: '4 in stock',
          description: 'The plainest revolver on the frontier.',
          rows: [
            { label: 'Ammunition', value: '.45' },
            { label: 'In stock', value: 4 },
            { label: 'Price', value: '$45.00' },
          ],
          stats: [
            { label: 'Damage', progress: 42 },
            { label: 'Range', progress: 35 },
            { label: 'Accuracy', progress: 61 },
          ],
          requirementsLabel: 'Cost',
          requirements: [{ label: 'Cash', amount: '$45.00', icon: 'menu_icon_rank' }],
        },
      },
      {
        id: 'carbine',
        title: 'Carbine Repeater',
        description: 'For work at a distance',
        icon: 'blip_ammo_bullets',
        group: 'Long arms',
        meta: [{ label: 'Price', value: '$104.00' }],
        detail: {
          title: 'Carbine Repeater',
          image: ART(),
          tag: 'Costs more than you carry',
          tagBad: true,
          rows: [
            { label: 'Ammunition', value: '.44' },
            { label: 'In stock', value: 1 },
            { label: 'Price', value: '$104.00' },
          ],
          stats: [
            { label: 'Damage', progress: 71 },
            { label: 'Range', progress: 78 },
            { label: 'Accuracy', progress: 69 },
          ],
          requirementsLabel: 'Cost',
          requirements: [{ label: 'Cash', amount: '$104.00', icon: 'menu_icon_rank', missing: true }],
        },
      },
      { id: 'rolling', title: 'Rolling Block Rifle', description: 'Out of stock', icon: 'blip_ammo_bullets', group: 'Long arms', disabled: true },
    ],
    actions: [
      { id: 'buy', label: 'Buy', icon: 'tick', primary: true },
      { id: 'inspect', label: 'Inspect', icon: 'star' },
    ],
    hints: [
      { key: '↑↓', label: 'Browse' },
      { key: 'Enter', label: 'Buy' },
      { key: 'Esc', label: 'Close' },
    ],
  });

/* ── trade ────────────────────────────────────────────────────────────────── */

export const debugPanelTrade = () =>
  show({
    id: 'trade',
    title: 'Trade',
    subtitle: 'with Sadie Adler',
    icon: 'blip_camp_tent',
    aside: 'Waiting',
    search: false,
    emptyText: 'Pick something to offer',
    tabs: [
      { id: 'mine', label: 'What you offer' },
      { id: 'theirs', label: 'What they offer' },
    ],
    activeTab: 'mine',
    items: [
      {
        id: 'pelt',
        title: 'Perfect Deer Pelt',
        description: 'Worth a good deal',
        icon: 'blip_camp',
        meta: [{ label: 'Have', value: 2 }],
        detail: {
          title: 'Perfect Deer Pelt',
          image: ART(),
          tag: 'On the table',
          rows: [
            { label: 'You have', value: 2 },
            { label: 'Offering', value: 1 },
            { label: 'Value', value: '$18.00' },
          ],
          requirementsLabel: 'On the table',
          requirements: [
            { label: 'Perfect Deer Pelt ×1', amount: 'you', icon: 'blip_camp' },
            { label: 'Cash $12.00', amount: 'them', icon: 'menu_icon_rank' },
          ],
        },
      },
      {
        id: 'tonic',
        title: 'Potent Health Tonic',
        description: 'Three of them',
        icon: 'blip_campfire',
        meta: [{ label: 'Have', value: 3 }],
        detail: {
          title: 'Potent Health Tonic',
          image: ART(),
          rows: [
            { label: 'You have', value: 3 },
            { label: 'Offering', value: 0 },
            { label: 'Value', value: '$4.50' },
          ],
          requirementsLabel: 'On the table',
          requirements: [
            { label: 'Perfect Deer Pelt ×1', amount: 'you', icon: 'blip_camp' },
            { label: 'Cash $12.00', amount: 'them', icon: 'menu_icon_rank' },
          ],
        },
      },
    ],
    actions: [
      { id: 'accept', label: 'Accept', icon: 'tick', primary: true },
      { id: 'offer', label: 'Add to offer', icon: 'star' },
    ],
    hints: [
      { key: '↑↓', label: 'Browse' },
      { key: 'Enter', label: 'Accept' },
      { key: 'Esc', label: 'Close' },
    ],
  });

/* ── black market ─────────────────────────────────────────────────────────── */

/**
 * ★ A shop whose window closes. The only thing making it a black market rather than the gunsmith
 *   is `countdown` on the panel and the goods it happens to be selling -- no mode, no flag. If it
 *   needed one, the template would not be general.
 */
export const debugPanelBlackMarket = () =>
  show({
    id: 'blackmarket',
    title: 'Black Market',
    subtitle: 'Behind the saloon',
    icon: 'blip_camp_tent',
    countdown: 424,
    searchPlaceholder: 'Search the crates',
    emptyText: 'Pick something from the crates',
    statsLabel: 'Risk',
    items: [
      {
        id: 'moonshine',
        title: 'Case of Moonshine',
        description: 'No questions asked',
        icon: 'blip_campfire',
        group: 'Contraband',
        meta: [{ label: 'Price', value: '$60.00' }],
        detail: {
          title: 'Case of Moonshine',
          image: ART(),
          tag: 'Two crates left',
          rows: [
            { label: 'Stock', value: 2 },
            { label: 'Price', value: '$60.00' },
          ],
          stats: [
            { label: 'Heat', progress: 64 },
            { label: 'Demand', progress: 81 },
          ],
          requirementsLabel: 'Cost',
          requirements: [{ label: 'Cash', amount: '$60.00', icon: 'menu_icon_rank' }],
        },
      },
      {
        id: 'rifle',
        title: 'Unmarked Rifle',
        description: 'Serial filed off',
        icon: 'blip_ammo_bullets',
        group: 'Arms',
        meta: [{ label: 'Price', value: '$240.00' }],
        detail: {
          title: 'Unmarked Rifle',
          image: ART(),
          tag: 'More than you carry',
          tagBad: true,
          rows: [
            { label: 'Stock', value: 1 },
            { label: 'Price', value: '$240.00' },
          ],
          stats: [
            { label: 'Heat', progress: 92 },
            { label: 'Demand', progress: 47 },
          ],
          requirementsLabel: 'Cost',
          requirements: [{ label: 'Cash', amount: '$240.00', icon: 'menu_icon_rank', missing: true }],
        },
      },
    ],
    actions: [{ id: 'buy', label: 'Buy', icon: 'tick', primary: true, input: { min: 1, max: 2, value: 1 } }],
    hints: [
      { key: '↑↓', label: 'Browse' },
      { key: 'Enter', label: 'Buy' },
      { key: 'Esc', label: 'Close' },
    ],
  });

/* ── auction ──────────────────────────────────────────────────────────────── */

/**
 * ★ Every lot carries its own `endsIn`, and the frame counts all of them down from ONE interval.
 *   The requirements list becomes the bid history -- picture, who, how much -- which is the same
 *   three columns a recipe's materials are.
 */
export const debugPanelAuction = () =>
  show({
    id: 'auction',
    title: 'Auction House',
    subtitle: 'Saint Denis',
    icon: 'menu_icon_rank',
    aside: '$1,204',
    searchPlaceholder: 'Search the lots',
    emptyText: 'Pick a lot',
    tabs: [
      { id: 'live', label: 'Live' },
      { id: 'mine', label: 'Your bids' },
      { id: 'won', label: 'Won' },
    ],
    activeTab: 'live',
    items: [
      {
        id: 'lot-1',
        title: 'Legendary Bear Pelt',
        description: 'Bid by Sadie Adler',
        icon: 'blip_camp',
        group: 'Closing soon',
        endsIn: 26,
        meta: [{ label: 'Bid', value: '$310' }],
        detail: {
          title: 'Legendary Bear Pelt',
          image: ART(),
          tag: 'You are outbid',
          tagBad: true,
          endsIn: 26,
          endsInLabel: 'Ends in',
          rows: [
            { label: 'Current bid', value: '$310' },
            { label: 'Your bid', value: '$290' },
            { label: 'Bids', value: 7 },
          ],
          requirementsLabel: 'Recent bids',
          requirements: [
            { label: 'Sadie Adler', amount: '$310', icon: 'blip_camp' },
            { label: 'You', amount: '$290', icon: 'menu_icon_rank' },
            { label: 'Charles Smith', amount: '$275', icon: 'blip_camp' },
          ],
        },
      },
      {
        id: 'lot-2',
        title: 'Gold Pocket Watch',
        description: 'No bids yet',
        icon: 'blip_time_of_day',
        group: 'Open',
        endsIn: 903,
        meta: [{ label: 'Bid', value: '$45' }],
        detail: {
          title: 'Gold Pocket Watch',
          image: ART(),
          tag: 'Opening bid',
          endsIn: 903,
          endsInLabel: 'Ends in',
          rows: [
            { label: 'Current bid', value: '$45' },
            { label: 'Your bid', value: '--' },
            { label: 'Bids', value: 0 },
          ],
          requirementsLabel: 'Recent bids',
          requirements: [{ label: 'No bids yet', amount: '--', icon: 'menu_bar' }],
        },
      },
    ],
    actions: [
      { id: 'bid', label: 'Place bid', icon: 'tick', primary: true, input: { min: 320, step: 10, value: 320 } },
      { id: 'watch', label: 'Watch', icon: 'star' },
    ],
    hints: [
      { key: '↑↓', label: 'Browse' },
      { key: 'Enter', label: 'Place bid' },
      { key: 'Esc', label: 'Close' },
    ],
  });

/* ── the composed panels: nav + blocks ────────────────────────────────────── */

/**
 * The admin console -- the hardest of the five, and the reason blocks exist.
 *
 * ★ Nothing here is an "admin layout". It is a grouped sidebar, four stat tiles, a table and a
 *   row of buttons -- named in that order. The marketplace below uses the same pieces in a
 *   different order and comes out a marketplace.
 */
export const debugPanelConsole = () =>
  show({
    id: 'console',
    title: 'Administration',
    subtitle: 'Dashboard',
    icon: 'menu_icon_rank',
    aside: '38 online',
    nav: [
      {
        label: 'Overview',
        items: [
          { id: 'dashboard', label: 'Dashboard', icon: 'menu_icon_rank' },
          { id: 'statistics', label: 'Statistics', icon: 'rating_star' },
        ],
      },
      {
        label: 'Players',
        items: [
          { id: 'players', label: 'Players', icon: 'blip_camp', count: 38 },
          { id: 'whitelist', label: 'Whitelist', icon: 'lock' },
          { id: 'reports', label: 'Reports', icon: 'cross', count: 4 },
        ],
      },
      {
        label: 'World',
        items: [
          { id: 'livemap', label: 'Live map', icon: 'blip_camp_tent' },
          { id: 'teleports', label: 'Teleports', icon: 'blip_time_of_day' },
          { id: 'blips', label: 'Blips', icon: 'star' },
        ],
      },
    ],
    activeNav: 'dashboard',
    blocks: [
      {
        type: 'stats',
        title: 'Right now',
        items: [
          { label: 'Online', value: 38, icon: 'blip_camp' },
          { label: 'Queue', value: 6, icon: 'blip_time_of_day' },
          { label: 'Open reports', value: 4, icon: 'cross' },
          { label: 'Uptime', value: '18h', icon: 'rating_star' },
        ],
      },
      {
        type: 'bars',
        title: 'Load',
        span: 6,
        items: [
          { label: 'Server tick', progress: 34 },
          { label: 'Memory', progress: 61 },
          { label: 'Entities', progress: 78 },
        ],
      },
      {
        type: 'actions',
        title: 'Quick actions',
        span: 6,
        actions: [
          { id: 'announce', label: 'Announce', icon: 'star' },
          { id: 'weather', label: 'Set weather', icon: 'blip_time_of_day' },
          { id: 'restart', label: 'Restart', icon: 'cross', danger: true },
        ],
      },
      {
        type: 'table',
        title: 'Recent log',
        note: '124 entries',
        columns: [
          { key: 'time', label: 'Time' },
          { key: 'admin', label: 'Admin' },
          { key: 'action', label: 'Action' },
          { key: 'target', label: 'Target', align: 'end' },
        ],
        rows: [
          { time: '21:04', admin: 'Sadie Adler', action: 'Kicked', target: 'id 27' },
          { time: '20:58', admin: 'Charles Smith', action: 'Teleported', target: 'id 12' },
          { time: '20:41', admin: 'Sadie Adler', action: 'Gave item', target: 'id 31' },
          { time: '20:12', admin: 'Arthur Morgan', action: 'Warned', target: 'id 27' },
        ],
      },
    ],
    hints: [{ key: 'Esc', label: 'Close' }],
  });

/**
 * The marketplace -- the same pieces, a different order.
 *
 * ★ A card grid and a form side by side, which is a sell counter. No mode, no layout flag: the
 *   two blocks just happen to be six columns wide each, so they sit beside one another.
 */
export const debugPanelMarketplace = () =>
  show({
    id: 'marketplace',
    title: 'Marketplace',
    subtitle: 'Saint Denis',
    icon: 'blip_shop_gunsmith',
    aside: '$1,204',
    tabs: [
      { id: 'buy', label: 'Buy' },
      { id: 'sell', label: 'Sell' },
      { id: 'earnings', label: 'Earnings' },
    ],
    activeTab: 'sell',
    nav: [
      {
        label: 'Departments',
        items: [
          { id: 'all', label: 'Everything', icon: 'menu_bar', count: 42 },
          { id: 'pelts', label: 'Pelts and hides', icon: 'blip_camp', count: 11 },
          { id: 'arms', label: 'Arms', icon: 'blip_ammo_bullets', count: 8 },
          { id: 'tonics', label: 'Tonics', icon: 'blip_campfire', count: 23 },
        ],
      },
    ],
    activeNav: 'pelts',
    blocks: [
      {
        type: 'cards',
        title: 'From your satchel',
        note: '11 items',
        span: 7,
        items: [
          { id: 'pelt', label: 'Perfect Deer Pelt', sub: 'You have', value: 2, icon: 'blip_camp' },
          { id: 'bear', label: 'Legendary Bear Pelt', sub: 'You have', value: 1, icon: 'blip_camp' },
          { id: 'tonic', label: 'Potent Health Tonic', sub: 'You have', value: 3, icon: 'blip_campfire' },
          { id: 'ammo', label: 'Express Rounds', sub: 'You have', value: 48, icon: 'blip_ammo_bullets' },
        ],
      },
      {
        type: 'form',
        title: 'List it',
        span: 5,
        fields: [
          { id: 'price', label: 'Asking price', type: 'number', value: 45, min: 1 },
          { id: 'qty', label: 'How many', type: 'number', value: 1, min: 1, max: 2 },
          { id: 'duration', label: 'Runs for', type: 'select', value: '24', options: [
            { value: '6', label: '6 hours' },
            { value: '24', label: '24 hours' },
            { value: '72', label: '3 days' },
          ] },
          { id: 'auction', label: 'Sell by auction', type: 'checkbox', value: true },
        ],
      },
      {
        type: 'actions',
        span: 5,
        actions: [
          { id: 'list', label: 'List for sale', icon: 'tick' },
          { id: 'clear', label: 'Clear', icon: 'cross' },
        ],
      },
      {
        type: 'rows',
        title: 'Your listings',
        note: '3 live',
        span: 7,
        items: [
          { id: 1, label: 'Perfect Deer Pelt', sub: 'Ends in 4h · 2 bids', value: '$18', icon: 'blip_camp',
            actions: [{ id: 'pull', label: 'Withdraw', icon: 'cross', danger: true }] },
          { id: 2, label: 'Express Rounds ×20', sub: 'Ends in 19h · no bids', value: '$12', icon: 'blip_ammo_bullets',
            actions: [{ id: 'pull', label: 'Withdraw', icon: 'cross', danger: true }] },
        ],
      },
    ],
    hints: [{ key: 'Esc', label: 'Close' }],
  });

/* ── cinema ───────────────────────────────────────────────────────────────── */

/**
 * The cinema desk -- what wraith_cinema's admin panel is made of.
 *
 * ★ Status dots, a chip row, transport buttons and a schedule form. The dots earn their place
 *   here: a column of screens is read by colour, not by reading 'playing' four times.
 */
export const debugPanelCinema = () =>
  show({
    id: 'cinema',
    title: 'Cinema',
    subtitle: 'Saint Denis Theatre',
    icon: 'blip_time_of_day',
    aside: 'On air',
    nav: [
      {
        label: 'Rooms',
        items: [
          { id: 'main', label: 'Main hall', icon: 'blip_camp_tent' },
          { id: 'balcony', label: 'Balcony', icon: 'blip_camp' },
          { id: 'private', label: 'Private box', icon: 'lock' },
        ],
      },
    ],
    activeNav: 'main',
    blocks: [
      {
        type: 'hero',
        value: 'The Iron Horse',
        subtitle: 'Reel 2 of 4 · 18 watching',
        icon: 'blip_time_of_day',
      },
      {
        type: 'bars',
        title: 'Playback',
        span: 7,
        items: [{ label: 'Elapsed', progress: 46 }],
      },
      {
        type: 'actions',
        title: 'Transport',
        span: 5,
        actions: [
          { id: 'play', label: 'Play', icon: 'tick' },
          { id: 'pause', label: 'Pause', icon: 'menu_bar' },
          { id: 'stop', label: 'Stop', icon: 'cross', danger: true },
        ],
      },
      {
        type: 'chips',
        title: 'Tags',
        items: [
          { id: 'western', label: 'Western' },
          { id: 'silent', label: 'Silent' },
          { id: 'newsreel', label: 'Newsreel' },
        ],
      },
      {
        type: 'rows',
        title: 'Screens',
        note: '3 rooms',
        span: 6,
        items: [
          { id: 'main', label: 'Main hall', sub: 'Playing · 18 seats taken', dot: 'ok', value: '18/40',
            actions: [{ id: 'goto', label: 'Go to', icon: 'star' }] },
          { id: 'balcony', label: 'Balcony', sub: 'Idle', dot: 'warn', value: '0/12',
            actions: [{ id: 'goto', label: 'Go to', icon: 'star' }] },
          { id: 'private', label: 'Private box', sub: 'Projector unreachable', dot: 'bad', value: '--',
            actions: [{ id: 'retry', label: 'Retry', icon: 'cross' }] },
        ],
      },
      {
        type: 'form',
        title: 'Schedule a showing',
        span: 6,
        fields: [
          { id: 'reel', label: 'Reel', type: 'select', value: 'iron', options: [
            { value: 'iron', label: 'The Iron Horse' },
            { value: 'dawn', label: 'Dawn Patrol' },
          ] },
          { id: 'at', label: 'Starts at', type: 'time', value: '19:30' },
          { id: 'on', label: 'On', type: 'date', value: '1899-06-14' },
          { id: 'repeat', label: 'Repeat nightly', type: 'checkbox', value: false },
        ],
      },
    ],
    hints: [{ key: 'Esc', label: 'Close' }],
  });

/* ── kingdoms ─────────────────────────────────────────────────────────────── */

/**
 * A kingdom -- w_kingsdom's shape, which is already this shell plus a nav and a detail.
 *
 * ★ The hero block is why it exists: the header names the PANEL ('Kingdoms'), this names the
 *   subject inside it, and the crest colour tints the plate the emblem sits on.
 */
export const debugPanelKingdom = () =>
  show({
    id: 'kingdom',
    title: 'Kingdoms',
    subtitle: 'House Beaumont',
    icon: 'menu_icon_rank',
    aside: '$8,420',
    nav: [
      {
        label: 'The house',
        items: [
          { id: 'overview', label: 'Overview', icon: 'menu_icon_rank' },
          { id: 'members', label: 'Members', icon: 'blip_camp', count: 14 },
          { id: 'treasury', label: 'Treasury', icon: 'star' },
          { id: 'banner', label: 'Banner', icon: 'rating_star' },
        ],
      },
    ],
    activeNav: 'overview',
    blocks: [
      {
        type: 'hero',
        value: 'House Beaumont',
        subtitle: 'Founded 1892 · Lemoyne',
        icon: 'menu_icon_rank',
        color: '#7D7466',
      },
      {
        type: 'stats',
        items: [
          { label: 'Members', value: 14, icon: 'blip_camp' },
          { label: 'Treasury', value: '$8,420', icon: 'star' },
          { label: 'Holdings', value: 3, icon: 'blip_camp_tent' },
          { label: 'Standing', value: '2nd', icon: 'rating_star' },
        ],
      },
      {
        type: 'table',
        title: 'Treasury ledger',
        note: 'last 30 days',
        span: 7,
        columns: [
          { key: 'day', label: 'Day' },
          { key: 'who', label: 'Who' },
          { key: 'what', label: 'What' },
          { key: 'sum', label: 'Sum', align: 'end' },
        ],
        rows: [
          { day: '14 Jun', who: 'Sadie Adler', what: 'Deposit', sum: '+$400' },
          { day: '13 Jun', who: 'The house', what: 'Upkeep', sum: '-$120' },
          { day: '11 Jun', who: 'Charles Smith', what: 'Deposit', sum: '+$250' },
        ],
      },
      {
        type: 'form',
        title: 'Banner',
        span: 5,
        fields: [
          { id: 'name', label: 'House name', type: 'text', value: 'House Beaumont' },
          { id: 'colour', label: 'Colour', type: 'color', value: '#7D7466' },
          { id: 'motto', label: 'Motto', type: 'textarea', value: 'Iron before gold' },
        ],
      },
      {
        type: 'actions',
        span: 5,
        actions: [
          { id: 'save', label: 'Save the banner', icon: 'tick' },
          { id: 'disband', label: 'Disband', icon: 'cross', danger: true },
        ],
      },
    ],
    hints: [{ key: 'Esc', label: 'Close' }],
  });

export const debugPanelHide = () => debugData([{ action: 'hidePanel', data: {} }]);

/* ── crafting admin ───────────────────────────────────────────────────────────
   ★ The nav as w_crafting's own browser: scope tabs, a tally, and categories that
     fold -- each with its lock, its count and the level that unlocks it. This is
     the shape w_crafting/admin describes, so a change to either can be checked
     here against the bench it is meant to match. */

export const debugPanelCraftAdmin = () =>
  show({
    id: 'craftadmin:recipes:bench:ms_craft',
    title: 'طاولة الحدادة',
    subtitle: 'تعديل الوصفات',
    icon: 'blip_shop_blacksmith',
    theme: 'workshop',
    searchPlaceholder: 'ابحث عن وصفة…',
    navCountLabel: 'وصفة',
    emptyText: 'لا وصفات في هذا التصنيف',
    tabs: [
      { id: 'public', label: 'عام' },
      { id: 'private', label: 'خاص' },
    ],
    activeTab: 'public',
    nav: [
      {
        id: 'cat:ريفولفر',
        label: 'ريفولفر',
        private: true,
        levelLabel: 'المستوى 15',
        scope: 'private',
        items: [
          { id: 'recipe:1', label: 'كاتمان', description: 'WEAPON_REVOLVER_CATTLEMAN ×1 · 120s' },
          { id: 'recipe:2', label: 'شوفيلد', description: 'WEAPON_REVOLVER_SCHOFIELD ×1 · 150s', count: 'معدّلة' },
        ],
      },
      {
        id: 'cat:مبتدئ',
        label: 'مبتدئ',
        levelLabel: 'المستوى 0',
        scope: 'public',
        expanded: true,
        items: [
          { id: 'recipe:3', label: 'سكين', description: 'WEAPON_MELEE_KNIFE ×1 · 20s' },
          { id: 'recipe:4', label: 'حبل', description: 'WEAPON_LASSO ×1 · 15s' },
          { id: 'recipe:5', label: 'أسهم', description: 'ammoarrownormal ×5 · 20s', count: 'مضافة' },
        ],
      },
      {
        id: 'cat:حرفي',
        label: 'حرفي',
        levelLabel: 'المستوى 8',
        scope: 'public',
        items: [{ id: 'recipe:6', label: 'قوس', description: 'WEAPON_BOW ×1 · 30s' }],
      },
    ],
    activeNav: 'recipe:3',
    blocks: [
      { type: 'hero', title: 'سكين', subtitle: 'وصفة من الملف', icon: 'blip_shop_blacksmith' },
      {
        type: 'form',
        title: 'الناتج والتكلفة',
        fields: [
          { id: 'outputItem', label: 'العنصر الناتج', type: 'text', value: 'WEAPON_MELEE_KNIFE' },
          { id: 'outputAmount', label: 'الكميّة', type: 'number', value: 1 },
          { id: 'outputName', label: 'الاسم المعروض', type: 'text', value: 'سكين' },
          {
            id: 'category',
            label: 'التصنيف',
            type: 'select',
            value: 'مبتدئ',
            options: [
              { value: '', label: '— بلا تصنيف —' },
              { value: 'ريفولفر', label: 'ريفولفر 🔒' },
              { value: 'مبتدئ', label: 'مبتدئ' },
              { value: 'حرفي', label: 'حرفي' },
            ],
          },
          { id: 'time', label: 'الوقت (ثانية)', type: 'number', value: 20 },
          { id: 'level', label: 'المستوى المطلوب', type: 'number', value: 0 },
          { id: 'xp', label: 'الخبرة', type: 'number', value: 6 },
        ],
      },
      {
        type: 'form',
        title: 'المكوّنات',
        note: '2 مكوّن',
        fields: [
          { id: 'ing:1:item', label: 'مكوّن 1', type: 'text', value: 'iron', placeholder: 'اتركه فارغاً للحذف' },
          { id: 'ing:1:amount', label: 'الكميّة', type: 'number', value: 3 },
          { id: 'ing:2:item', label: 'مكوّن 2', type: 'text', value: 'wood', placeholder: 'اتركه فارغاً للحذف' },
          { id: 'ing:2:amount', label: 'الكميّة', type: 'number', value: 2 },
        ],
      },
      { type: 'actions', actions: [{ id: 'ing:add', label: 'إضافة مكوّن' }] },
    ],
    actions: [
      { id: 'recipe:save', label: 'حفظ', primary: true },
      { id: 'recipe:delete', label: 'إخفاء', danger: true },
      { id: 'recipe:new', label: 'وصفة جديدة' },
      { id: 'categories', label: 'التصنيفات' },
      { id: 'back', label: 'المحطّات' },
    ],
    hints: [
      { key: 'Enter', label: 'حفظ' },
      { key: 'Esc', label: 'خروج' },
    ],
  });
