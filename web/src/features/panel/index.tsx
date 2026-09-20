import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { fetchNui } from '../../utils/fetchNui';
import { useLocales } from '../../providers/LocaleProvider';
import { Dashboard, DashboardActions, DashboardBody, DashboardHeader, DashboardSearch } from '../../wc/Dashboard';
import Icon from '../../wc/Icon';
import { Bar, Glyph, play } from '../../wc/Panel';
import Blocks, { Block } from './Blocks';
import './panel.css';

/**
 * ============================================================================
 * The panel -- one dashboard, described from Lua.
 *
 * ★ WHY THIS EXISTS: every script here wants the same interface -- a titled panel, a list of
 *   things, the selected thing in detail, and a row of actions. Written per resource that is a
 *   React app, a build step and a frame each time, and eight of them drift apart within a month.
 *   Described instead, a script sends a table and gets w_crafting's interface.
 *
 * ⚠️ It is a DESCRIPTION, not a component tree. Lua cannot send functions across the NUI
 *    boundary (the same limit that made the context menu use `event` + `args`), so every action
 *    is an id that comes back on a callback. Anything that needs to compute while the panel is
 *    open updates it by sending a new description.
 * ============================================================================
 */

interface Meta {
  label: string;
  value?: string | number;
  progress?: number;
}

interface Detail {
  title?: string;
  image?: string;
  description?: string;
  /** A short state line beside the name -- 'In stock', 'Locked', 'Offline'. */
  tag?: string;
  /** Draws the tag in red: missing, locked, banned. */
  tagBad?: boolean;
  stats?: Meta[];
  rows?: Meta[];
  /**
   * What this costs, needs, or is made of -- and it is ONE field for all three on purpose.
   * A crafting recipe's materials, a shop's price and a trade's offer are the same list of
   * item / label / amount, and giving each its own field would be three names for one thing.
   */
  requirements?: Requirement[];
  requirementsLabel?: string;
  /** Seconds left, counted down by the UI. */
  endsIn?: number;
  endsInLabel?: string;
}

interface Requirement {
  label: string;
  amount?: string | number;
  icon?: string;
  image?: string;
  /** Red, and the action should usually be disabled with it: not enough, not carried. */
  missing?: boolean;
}

interface Tab {
  id: string;
  label: string;
  icon?: string;
}

/** The action row while something is running -- crafting, a purchase settling, a trade pending. */
interface Progress {
  label?: string;
  image?: string;
  /** 0-100. */
  value?: number;
  info?: string;
  cancelLabel?: string;
}

interface Item {
  id: string | number;
  title: string;
  description?: string;
  icon?: string;
  image?: string;
  disabled?: boolean;
  /** Rows carrying the same group are drawn under one heading. */
  group?: string;
  meta?: Meta[];
  detail?: Detail;
  /** Seconds left, counted down by the UI. An auction lot, a black-market window. */
  endsIn?: number;
}

interface Action {
  id: string;
  label: string;
  icon?: string;
  primary?: boolean;
  disabled?: boolean;
  /**
   * Asks for a number before firing -- a bid, a quantity, a stake. Its value rides along on
   * panelAction, so the script gets the amount and the action in one callback.
   */
  input?: { min?: number; max?: number; step?: number; value?: number; placeholder?: string };
}

interface PanelState {
  id?: string;
  title?: string;
  subtitle?: string;
  icon?: string;
  logo?: string;
  theme?: string;
  search?: boolean;
  searchPlaceholder?: string;
  items?: Item[];
  actions?: Action[];
  hints?: Array<{ key: string; label: string }>;
  /** Free text shown at the far end of the header -- money, a level, a horse's name. */
  aside?: string;
  /** Shown in the detail pane when nothing is selected. */
  emptyText?: string;
  /** The heading above the bars -- 'Statistics', 'Condition', whatever they are. */
  statsLabel?: string;
  /** Sections across the top of the list: admin areas, shop departments, trade sides. */
  tabs?: Tab[];
  activeTab?: string;
  /** While this is set the action row is replaced by it and the actions are unreachable. */
  progress?: Progress;
  /** Seconds left on the whole panel -- a market window closing. Shown in the header. */
  countdown?: number;

  /**
   * A grouped sidebar in place of the item list -- Overview / Players / World, the shape an
   * admin panel wants. When this is set the browser column becomes navigation and the content
   * comes from `blocks` instead of from a selected item's detail.
   */
  nav?: NavGroup[];
  activeNav?: string;
  /**
   * The unit counted under the tabs -- 'recipes', 'players', 'lots'. Without it the tally is
   * left off entirely rather than guessed at, since 'items' is wrong in most panels.
   */
  navCountLabel?: string;

  /**
   * The content, composed. When present it replaces the fixed detail pane entirely.
   *
   * ★ This is what makes the panel general. A shop needs the built-in detail; an admin section
   *   needs stat tiles over a log table; a marketplace needs a card grid beside a sell form.
   *   Rather than a layout per script, a script names the pieces and their order.
   */
  blocks?: Block[];
}

/**
 * A section of the browser column: a heading that folds open, and rows under it.
 *
 * ★ This is w_crafting's category, described. The crafting menu groups its recipes under
 *   collapsible headings that carry a lock, a count and the level that unlocks them, with
 *   public/private tabs above and a running total beneath -- and a panel that only drew flat
 *   headings could not be that menu, only something resembling it. Every field below exists
 *   because the crafting browser draws it.
 */
interface NavGroup {
  /** Stable across redraws -- the open/closed state is keyed on it. Falls back to the label. */
  id?: string;
  label?: string;
  /** 🔒 on the heading and a red edge down its side: a job-gated section. */
  private?: boolean;
  /** Sits at the end of the heading beside the count -- 'Level 15'. */
  levelLabel?: string;
  /** Which tab shows this group. Groups without one show under every tab. */
  scope?: string;
  /** Open on arrival. With none set anywhere, the first group opens. */
  expanded?: boolean;
  items: Array<{
    id: string;
    label: string;
    icon?: string;
    image?: string;
    count?: number | string;
    /** A second line under the label -- what the row makes, what it costs. */
    description?: string;
    /**
     * ★ Extra text the search matches but never draws.
     *
     *   w_crafting's search finds a recipe by what it is MADE OF, not only by its name -- a
     *   player looking for what to do with a pile of iron types 'iron'. The ingredients are not
     *   in the row's label and should not be, so they travel here.
     */
    search?: string;
    disabled?: boolean;
  }>;
}

/**
 * Seconds as a clock: 2:07, or 1:04:22 once it passes an hour.
 *
 * ⚠️ dir="ltr" wherever this is rendered. A time is digits and colons, all bidi-neutral, so an
 *    Arabic panel would otherwise reorder them.
 */
const asClock = (total: number) => {
  const t = Math.max(0, Math.floor(total));
  const h = Math.floor(t / 3600);
  const m = Math.floor((t % 3600) / 60);
  const sec = t % 60;

  const mm = h ? String(m).padStart(2, '0') : String(m);
  return `${h ? `${h}:` : ''}${mm}:${String(sec).padStart(2, '0')}`;
};

/** Rows in order, but gathered under their group headings. */
const grouped = (items: Item[]) => {
  const out: Array<{ group?: string; items: Item[] }> = [];

  for (const item of items) {
    const last = out[out.length - 1];
    if (last && last.group === item.group) last.items.push(item);
    else out.push({ group: item.group, items: [item] });
  }

  return out;
};

/**
 * Plain facts, as the tiles w_crafting uses for time / level / XP / yield.
 *
 * ⚠️ NOT a full-width label-and-value row. That is what this was, and across a detail pane six
 *    hundred pixels wide it put the label against one edge and its value against the other with
 *    a gulf between them -- four readings that had to be tracked one at a time instead of taken
 *    in at a glance. A tile keeps a value next to its own label.
 */
const MetaTiles: React.FC<{ rows?: Meta[] }> = ({ rows }) =>
  rows?.length ? (
    <div className="wc-meta wl-panel-meta">
      {rows.map((row, i) => (
        <div className="wc-meta-tile" key={`${row.label}-${i}`}>
          <span className="wc-meta-value" dir="ltr">
            {row.value}
          </span>
          <span className="wc-meta-label">{row.label}</span>
        </div>
      ))}
    </div>
  ) : null;

/**
 * The cost / materials / offer list, on w_crafting's ingredient row.
 *
 * ★ .wc-ing is a three-column grid -- picture, name, amount -- which is exactly the shape of a
 *   recipe's material, a shop item's price and a trade's side. One row type, three uses.
 */
const Requirements: React.FC<{ rows?: Requirement[]; heading?: string }> = ({ rows, heading }) =>
  rows?.length ? (
    <>
      <div className="wc-section-title">
        <span>{heading}</span>
        <span className="wc-hr-thin" />
      </div>

      <div className="wc-ingredients wc-scroll">
        {rows.map((row, i) => (
          <div className="wc-ing" key={`${row.label}-${i}`}>
            <span className="wc-slot">
              <Icon icon={row.image ?? row.icon} fallback="menu_bar" />
            </span>

            <span className="wc-ing-label">{row.label}</span>

            {row.amount != null && (
              <span className="wc-ing-amount" dir="ltr" style={row.missing ? { color: 'var(--wc-red)' } : undefined}>
                {row.amount}
              </span>
            )}
          </div>
        ))}
      </div>
    </>
  ) : null;

/** Bars, under a ruled heading -- w_crafting's section pattern. */
const StatRows: React.FC<{ rows?: Meta[]; heading?: string }> = ({ rows, heading }) =>
  rows?.length ? (
    <>
      <div className="wc-section-title">
        <span>{heading}</span>
        <span className="wc-hr-thin" />
      </div>

      <div className="wl-panel-stats">
        {rows.map((row, i) => (
          <div className="wl-panel-row" key={`${row.label}-${i}`}>
            <span className="wl-panel-row-label">{row.label}</span>
            <Bar ratio={(row.progress ?? 0) / 100} bright />
          </div>
        ))}
      </div>
    </>
  ) : null;

/**
 * The amount an action asks for, drawn with the input dialog's own field and steppers.
 *
 * ★ .lb-input and .lb-spin are already in lib-ui.css -- reused rather than restyled, so a bid
 *   box and a dialog's number field are the same control wherever the player meets them.
 */
const AmountField: React.FC<{
  spec: NonNullable<Action['input']>;
  value: number;
  onChange: (value: number) => void;
}> = ({ spec, value, onChange }) => {
  const step = spec.step ?? 1;

  const clamp = (n: number) =>
    Math.min(spec.max ?? Number.MAX_SAFE_INTEGER, Math.max(spec.min ?? 0, Number.isFinite(n) ? n : spec.min ?? 0));

  return (
    <div className="lb-input wl-panel-amount">
      <input
        type="number"
        dir="ltr"
        value={value}
        min={spec.min}
        max={spec.max}
        step={step}
        placeholder={spec.placeholder}
        onChange={(e) => onChange(clamp(Number(e.target.value)))}
      />

      <span className="lb-spin">
        <button type="button" className="lb-spin-btn is-up" aria-label="+" onClick={() => onChange(clamp(value + step))} />
        <button type="button" className="lb-spin-btn is-down" aria-label="-" onClick={() => onChange(clamp(value - step))} />
      </span>
    </div>
  );
};

const Panel: React.FC = () => {
  const { locale } = useLocales();
  const [state, setState] = useState<PanelState | null>(null);
  const [selected, setSelected] = useState<string | number | null>(null);
  const [search, setSearch] = useState('');
  /** Seconds since this description arrived -- the one clock every countdown reads from. */
  const [elapsed, setElapsed] = useState(0);
  /** What each amount field is currently set to, keyed by action id. */
  const [amounts, setAmounts] = useState<Record<string, number>>({});

  /* The key handler is registered once and reads through refs, so it never goes stale. */
  const stateRef = useRef<PanelState | null>(null);
  const selectedRef = useRef<string | number | null>(null);

  stateRef.current = state;
  selectedRef.current = selected;

  const items = state?.items ?? [];

  /**
   * ★ ONE interval for the whole panel, and it runs only while something is counting.
   *
   * ⚠️ The alternative was Lua pushing a fresh description every second. With twenty auction
   *    lots that is twenty full redraws a second across the NUI boundary to move some digits --
   *    and the list would rebuild under the player's cursor while they were reading it. The
   *    server still owns when a lot actually ends; this only draws the wait.
   */
  const counting =
    typeof state?.countdown === 'number' ||
    items.some((item) => typeof item.endsIn === 'number') ||
    typeof items.find((i) => i.id === selected)?.detail?.endsIn === 'number';

  useEffect(() => {
    if (!state || !counting) return;

    const id = setInterval(() => setElapsed((n) => n + 1), 1000);
    return () => clearInterval(id);
  }, [state, counting]);

  /* ★ Filtering is done here rather than in Lua. A search that has to cross the NUI boundary to
     redraw feels laggy at exactly the moment the player is typing fastest. */
  const visible = useMemo(() => {
    const needle = search.trim().toLowerCase();
    if (!needle) return items;

    return items.filter(
      (item) =>
        item.title.toLowerCase().includes(needle) || (item.description ?? '').toLowerCase().includes(needle)
    );
  }, [items, search]);

  /* ── the browser column, when it is navigation ──────────────────────────────────────────
     ★ Tabs and folding are answered HERE, not by Lua. w_crafting switches scope and opens a
       category without asking its client for anything, and a panel that took a round trip per
       fold would put a frame of lag on a control the player is dragging their eye down. The
       description says what the sections ARE; which one is open is the reader's business.
     ⚠️ `panelTab` still fires so a script CAN react (loading a tab's rows on demand). Ignoring
        it is the normal case and costs nothing -- the filtering has already happened. */
  const navKey = (group: NavGroup, i: number) => group.id ?? group.label ?? String(i);

  const [navTab, setNavTab] = useState<string | null>(null);
  const [opened, setOpened] = useState<string[] | null>(null);
  /** Which panel the folds belong to -- see the showPanel handler. */
  const panelIdRef = useRef<string | undefined>(undefined);

  const navSearching = state?.nav?.length ? search.trim().length > 0 : false;

  /** Groups on the active tab, with their rows narrowed by the search. */
  const navGroups = useMemo(() => {
    const groups = state?.nav ?? [];
    if (!groups.length) return [];

    const tab = navTab ?? state?.activeTab ?? state?.tabs?.[0]?.id;
    const needle = search.trim().toLowerCase();

    return groups
      .map((group, i) => ({
        group,
        key: navKey(group, i),
        items: needle
          ? group.items.filter(
              (item) =>
                item.label.toLowerCase().includes(needle) ||
                (item.search ?? '').toLowerCase().includes(needle)
            )
          : group.items,
      }))
      /* A group scoped to another tab is not on this one. An unscoped group is on all of them,
         which is what a panel with no tabs at all is made of. */
      .filter(({ group }) => !state?.tabs?.length || !group.scope || group.scope === tab)
      /* ⚠️ Empty groups vanish only while searching. Standing empty they are still the shape of
         the thing being edited -- a category with no recipes in it is a fact worth showing. */
      .filter(({ items }) => !needle || items.length > 0);
  }, [state?.nav, state?.tabs, state?.activeTab, navTab, search]);

  /**
   * Which sections are open: every match while searching, otherwise what the reader has folded,
   * and failing both the description's own choice -- or just the first one.
   */
  const expandedKeys = useMemo(() => {
    if (navSearching) return navGroups.map((g) => g.key);
    if (opened) return opened;

    const declared = navGroups.filter(({ group }) => group.expanded).map((g) => g.key);
    if (declared.length) return declared;

    return navGroups.length ? [navGroups[0].key] : [];
  }, [navSearching, navGroups, opened]);

  /* ⚠️ The first fold has to start from WHAT IS ON SCREEN, not from nothing. Until the reader
        touches a heading `opened` is null and the open set is a default -- the description's
        choice, or the first group. Seeding the toggle with [] instead would make that first
        click silently close whatever was already open, so folding a second category would
        collapse the first. */
  const expandedRef = useRef<string[]>([]);
  expandedRef.current = expandedKeys;

  const toggleNavGroup = useCallback((key: string) => {
    play('select');
    setOpened((prev) => {
      const base = prev ?? expandedRef.current;
      return base.includes(key) ? base.filter((k) => k !== key) : [...base, key];
    });
  }, []);

  const navTotal = useMemo(
    () => (state?.nav ?? []).reduce((n, group) => n + group.items.length, 0),
    [state?.nav]
  );

  /** Selectable nav rows, in drawn order — what the arrow keys walk. */
  const navRowsRef = useRef<string[]>([]);
  navRowsRef.current = useMemo(
    () =>
      navGroups
        .filter(({ group, key }) => expandedKeys.includes(key) || !group.label)
        .flatMap(({ items }) => items.filter((item) => !item.disabled).map((item) => item.id)),
    [navGroups, expandedKeys]
  );

  const current = visible.find((item) => item.id === selected) ?? null;

  const close = useCallback(() => {
    play('close');
    setState(null);
    setSelected(null);
    setSearch('');
    fetchNui('panelClose');
  }, []);

  const pick = useCallback((id: string | number) => {
    if (id === selectedRef.current) return;
    selectedRef.current = id;
    setSelected(id);
    play('hover');
    fetchNui('panelSelect', id);
  }, []);

  const amountsRef = useRef<Record<string, number>>({});
  amountsRef.current = amounts;

  const run = useCallback((action: Action) => {
    if (action.disabled) return void play('deny');
    play('select');

    // ★ The amount travels WITH the action, not as a separate callback. A bid is one decision.
    fetchNui('panelAction', {
      action: action.id,
      item: selectedRef.current,
      amount: action.input ? amountsRef.current[action.id] ?? action.input.min ?? 0 : undefined,
    });
  }, []);

  useNuiEvent<PanelState | false | null>('showPanel', (data) => {
    if (!data) return close();

    setState(data);
    play('open');
    setElapsed(0);
    setAmounts(
      Object.fromEntries(
        (data.actions ?? []).filter((a) => a.input).map((a) => [a.id, a.input?.value ?? a.input?.min ?? 0])
      )
    );

    // Keep the selection when the same panel is refreshed; start at the top when it is new.
    const first = data.items?.find((item) => !item.disabled);
    setSelected((prev) => (prev !== null && data.items?.some((i) => i.id === prev) ? prev : first?.id ?? null));

    /* ★ Folds survive a redraw, and MUST. Saving a recipe sends the whole description back, and
       resetting the browser there would throw the reader to the top of a collapsed list every
       time they committed an edit. A DIFFERENT panel is another matter -- its group keys mean
       nothing here -- so the folds go with the panel they belonged to.
       ⚠️ Compared against a ref, not against `state`: setState(data) above has already landed
          by the time any updater would run, so a panel would always look like itself. */
    if (panelIdRef.current !== data.id) {
      panelIdRef.current = data.id;
      setNavTab(null);
      setOpened(null);
    }
  });

  useNuiEvent('hidePanel', () => {
    setState(null);
    setSelected(null);
    setSearch('');
    setNavTab(null);
    setOpened(null);
  });

  useEffect(() => {
    if (!state) return;

    const onKey = (e: KeyboardEvent) => {
      /* ⚠️ A FIELD BEING TYPED INTO OWNS THE KEYBOARD.
       *
       *  This handler sits on window and used to swallow the arrows, Enter and Escape wherever
       *  they were pressed -- including inside a text or number field. So an admin editing a
       *  recipe could not touch the arrows to step a quantity (they moved the list instead),
       *  Enter saved the form half-typed, and Escape shut the whole panel.
       *
       *  ★ And it is why NUMBERS could not be typed at all. With NumLock off the numeric keypad
       *    reports 2 as ArrowDown and 8 as ArrowUp -- so on a keypad the digits themselves were
       *    being read as navigation and eaten before the field ever saw them. Nothing was wrong
       *    with the input; the panel was taking its keys.
       *
       *  Escape still has work to do here: it steps OUT of the field rather than out of the
       *  panel, which is the smaller of the two things it could mean while typing.
       */
      const target = e.target as HTMLElement | null;
      const typing =
        !!target &&
        (target.isContentEditable ||
          target.tagName === 'INPUT' ||
          target.tagName === 'TEXTAREA' ||
          target.tagName === 'SELECT');

      if (typing) {
        if (e.key === 'Escape' || e.key === 'Enter') {
          e.preventDefault();
          target.blur();
        }
        return;
      }

      const list = stateRef.current?.items ?? [];
      const at = list.findIndex((item) => item.id === selectedRef.current);

      switch (e.key) {
        case 'Escape':
          e.preventDefault();
          return close();

        case 'ArrowDown':
        case 'ArrowUp': {
          e.preventDefault();
          const step = e.key === 'ArrowDown' ? 1 : -1;

          /* ★ When the browser IS the nav, the arrows have to walk IT. w_crafting's menu is
             driven up and down with the keyboard and confirmed with Enter -- a player never has
             to touch the mouse -- and a panel standing in for that menu whose arrows moved
             nothing would be a worse bench, however identical it looked.
             ⚠️ Only rows in OPEN groups, and in the order they are drawn. Stepping into a folded
                category would move the selection somewhere the player cannot see. */
          if (navRowsRef.current.length) {
            const rows = navRowsRef.current;
            const here = rows.findIndex((id) => id === stateRef.current?.activeNav);
            const next = rows[(here + step + rows.length) % rows.length];

            if (next != null && next !== stateRef.current?.activeNav) {
              play('select');
              fetchNui('panelNav', next);
            }
            return;
          }

          if (!list.length) return;
          const next = list[(at + step + list.length) % list.length];
          if (next) pick(next.id);
          return;
        }

        case 'Enter': {
          e.preventDefault();
          // ★ Enter runs the action marked primary -- 'Craft' on the bench, 'Buy' in a shop.
          const primary = stateRef.current?.actions?.find((a) => a.primary) ?? stateRef.current?.actions?.[0];
          if (primary) run(primary);
          return;
        }
      }
    };

    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [state, close, pick, run]);

  if (!state) return null;

  const detail = current?.detail;

  return (
    <Dashboard theme={state.theme}>
      <DashboardHeader
        title={state.title}
        subtitle={state.subtitle}
        icon={state.icon}
        logo={state.logo}
        aside={
          state.aside || typeof state.countdown === 'number' ? (
            <span className="wl-panel-aside" dir={typeof state.countdown === 'number' ? 'ltr' : undefined}>
              {typeof state.countdown === 'number' ? asClock(state.countdown - elapsed) : state.aside}
            </span>
          ) : undefined
        }
        onClose={close}
        closeLabel={locale.ui.close || 'Close'}
      />

      <DashboardBody
        browser={
          state.nav?.length ? (
            /* ★ w_crafting's browser, not a likeness of it. The tabs, the tally, the headings
               that fold with a lock and a level on them -- every one of these is a control the
               crafting menu has, drawn from the same rules in wc-base.css. A panel that stopped
               at flat headings could stand in for that menu but never BE it, and the moment an
               admin console sits beside the bench it is meant to edit, the difference shows. */
            <div className="wc-grouped-browser">
              {state.tabs?.length ? (
                <div className="wc-scope-tabs" role="tablist">
                  {state.tabs.map((tab) => {
                    const active = tab.id === (navTab ?? state.activeTab ?? state.tabs?.[0]?.id);
                    return (
                      <button
                        type="button"
                        role="tab"
                        aria-selected={active}
                        key={tab.id}
                        className={`wc-scope-tab${active ? ' is-active' : ''}`}
                        onClick={() => {
                          play('select');
                          setNavTab(tab.id);
                          /* Filtering already happened above; this only lets a script that wants
                             to know -- to fetch a tab's rows on demand -- find out. */
                          fetchNui('panelTab', tab.id);
                        }}
                      >
                        {tab.icon && <Icon icon={tab.icon} />}
                        {tab.label}
                      </button>
                    );
                  })}
                </div>
              ) : null}

              {state.search !== false && (
                <DashboardSearch value={search} placeholder={state.searchPlaceholder} onChange={setSearch} />
              )}

              {state.navCountLabel ? (
                <span className="wc-count" dir="ltr">
                  {navGroups.reduce((n, g) => n + (expandedKeys.includes(g.key) ? g.items.length : 0), 0)}
                  {navSearching ? ` / ${navTotal}` : ''} {state.navCountLabel}
                </span>
              ) : null}

              {!navGroups.length ? (
                <div className="wc-empty">{state.emptyText}</div>
              ) : (
                <div className="wc-grouped-list wc-scroll">
                  {navGroups.map(({ group, key, items: rows }) => {
                    const open = expandedKeys.includes(key);
                    return (
                      <section className="wc-category-group" key={key}>
                        {group.label && (
                          <button
                            type="button"
                            className={`wc-category-toggle${open ? ' is-open' : ''}${
                              group.private ? ' is-private' : ''
                            }`}
                            aria-expanded={open}
                            onClick={() => toggleNavGroup(key)}
                          >
                            <span className="wc-category-chevron" aria-hidden="true">
                              {open ? '▾' : '▸'}
                            </span>
                            <span className="wc-category-name">
                              {group.private && (
                                <span className="wc-category-lock" aria-hidden="true">
                                  🔒
                                </span>
                              )}
                              {group.label}
                            </span>
                            <span className="wc-category-meta" dir="ltr">
                              <span className="wc-category-count">{rows.length}</span>
                              {group.levelLabel && <span className="wc-category-lvl">{group.levelLabel}</span>}
                            </span>
                          </button>
                        )}

                        {/* A group with no heading cannot be folded shut -- there is nothing to
                            click -- so it always shows. */}
                        {(open || !group.label) && (
                          <div className="wc-category-items" role="listbox" aria-label={group.label}>
                            {rows.map((item) => (
                              <button
                                type="button"
                                key={item.id}
                                disabled={item.disabled}
                                className={`wc-card${item.id === state.activeNav ? ' is-active' : ''}${
                                  item.disabled ? ' is-disabled' : ''
                                }`}
                                onClick={() => {
                                  play('select');
                                  fetchNui('panelNav', item.id);
                                }}
                              >
                                <span className="wc-slot">
                                  <Icon icon={item.image ?? item.icon} fallback="menu_bar" />
                                </span>
                                <span style={{ minWidth: 0 }}>
                                  <span className="wc-card-name">{item.label}</span>
                                  {item.description && <span className="lb-item-desc">{item.description}</span>}
                                </span>
                                {item.count != null && <span className="wc-category-count">{item.count}</span>}
                              </button>
                            ))}
                          </div>
                        )}
                      </section>
                    );
                  })}
                </div>
              )}
            </div>
          ) : (
          <>
            {state.tabs?.length ? (
              <div className="wc-scope-tabs">
                {state.tabs.map((tab) => (
                  <button
                    type="button"
                    key={tab.id}
                    className={`wc-scope-tab${tab.id === (state.activeTab ?? state.tabs?.[0]?.id) ? ' is-active' : ''}`}
                    onClick={() => {
                      play('select');
                      fetchNui('panelTab', tab.id);
                    }}
                  >
                    {tab.icon && <Icon icon={tab.icon} />}
                    {tab.label}
                  </button>
                ))}
              </div>
            ) : null}

            {state.search !== false && (
              <DashboardSearch value={search} placeholder={state.searchPlaceholder} onChange={setSearch} />
            )}

            <div className="wc-list wc-scroll wl-panel-list">
              {grouped(visible).map((block, gi) => (
                <React.Fragment key={`${block.group ?? ''}-${gi}`}>
                  {block.group && <div className="wl-panel-group">{block.group}</div>}

                  {block.items.map((item) => (
                    <button
                      type="button"
                      key={item.id}
                      className={`lb-item${item.disabled ? ' is-disabled' : ''}${
                        item.id === selected ? ' is-active' : ''
                      }`}
                      disabled={item.disabled}
                      onClick={() => pick(item.id)}
                    >
                      <span className={`lb-item-icon${item.icon || item.image ? '' : ' is-empty'}`}>
                        <Icon icon={item.image ?? item.icon} fallback="menu_bar" />
                      </span>

                      <span style={{ minWidth: 0 }}>
                        <span className="lb-item-title">{item.title}</span>
                        {item.description && <span className="lb-item-desc">{item.description}</span>}
                        {item.meta?.length || typeof item.endsIn === 'number' ? (
                          <span className="lb-meta">
                            {typeof item.endsIn === 'number' && (
                              <span dir="ltr" className={item.endsIn - elapsed <= 30 ? 'wl-panel-urgent' : undefined}>
                                {asClock(item.endsIn - elapsed)}
                              </span>
                            )}
                            {item.meta?.map((m, i) => (
                              <span key={i}>
                                {m.label}
                                {m.value != null && (
                                  <>
                                    : <b dir="ltr">{m.value}</b>
                                  </>
                                )}
                              </span>
                            ))}
                          </span>
                        ) : null}
                      </span>

                      <span />
                    </button>
                  ))}
                </React.Fragment>
              ))}
            </div>
          </>
          )
        }
      >
        {state.blocks?.length ? (
          <Blocks
            blocks={state.blocks}
            ctx={{
              selected,
              onPick: pick,
              onAction: (id, itemId) => {
                play('select');
                fetchNui('panelAction', { action: id, item: itemId ?? selectedRef.current });
              },
              onField: (id, value) => fetchNui('panelField', { id, value }),
            }}
          />
        ) : detail || current ? (
          /* ★ w_crafting's own detail layout: the picture beside the name, not above it; the
             facts as tiles; the bars under a ruled heading. Every class here is already in
             wc-base.css -- this is the crafting pane with the crafting taken out. */
          <div className="wc-detail-main">
            <div className="wc-preview">
              <span className="wc-slot">
                <Icon icon={detail?.image} fallback="menu_bar" />
              </span>

              <div>
                <h2 className="wc-preview-name">{detail?.title ?? current?.title}</h2>
                {(detail?.description || detail?.tag) && (
                  <div className="wc-preview-tags">
                    {detail?.tag && (
                      <span className={detail.tagBad ? 'wc-tag-locked' : 'wc-badge'}>
                        <Glyph tex={detail.tagBad ? 'cross' : 'tick'} />
                        {detail.tag}
                      </span>
                    )}
                    {detail?.description && <span>{detail.description}</span>}
                  </div>
                )}
              </div>
            </div>

            <MetaTiles
              rows={
                typeof detail?.endsIn === 'number'
                  ? [
                      { label: detail.endsInLabel ?? '', value: asClock(detail.endsIn - elapsed) },
                      ...(detail.rows ?? []),
                    ]
                  : detail?.rows
              }
            />
            <StatRows rows={detail?.stats} heading={state.statsLabel} />
            <Requirements rows={detail?.requirements} heading={detail?.requirementsLabel} />
          </div>
        ) : (
          <div className="wc-empty">
            <Glyph tex="menu_bar" />
            <p>{state.emptyText}</p>
          </div>
        )}

        <DashboardActions hints={state.progress ? undefined : state.hints}>
          {state.progress ? (
            /* ★ The actions are not merely disabled while something runs -- they are replaced.
               A greyed 'Craft' next to a filling bar invites a second press; nothing to press
               says the same thing without the invitation. */
            <>
              <div className="wc-progress">
                <span className="wc-slot">
                  <Icon icon={state.progress.image} fallback="menu_bar" />
                </span>

                <span>
                  <span className="wc-progress-name">{state.progress.label}</span>
                  {state.progress.info && (
                    <span className="wc-progress-info">
                      <b dir="ltr">{state.progress.info}</b>
                    </span>
                  )}
                  <Bar ratio={(state.progress.value ?? 0) / 100} bright />
                </span>
              </div>

              {state.progress.cancelLabel && (
                <button
                  type="button"
                  className="wc-cancel-btn"
                  onClick={() => {
                    play('deny');
                    fetchNui('panelCancel');
                  }}
                >
                  <Glyph tex="cross" />
                  {state.progress.cancelLabel}
                </button>
              )}
            </>
          ) : null}

          {!state.progress &&
            state.actions?.map((action) => (
              <React.Fragment key={action.id}>
                {action.input && (
                  <AmountField
                    spec={action.input}
                    value={amounts[action.id] ?? action.input.min ?? 0}
                    onChange={(value) => setAmounts((prev) => ({ ...prev, [action.id]: value }))}
                  />
                )}

                <button
                  type="button"
                  /* ★ Past three, the buttons narrow. See .wc-craft-btn.is-compact -- a panel
                     with six actions used to lay them off the edge of its own frame. */
                  className={`wc-craft-btn${action.primary ? '' : ' is-ghost'}${
                    (state.actions?.length ?? 0) > 3 ? ' is-compact' : ''
                  }`}
                  disabled={action.disabled}
                  onClick={() => run(action)}
                >
                  <span>
                    {action.icon && <Icon icon={action.icon} />}
                    {action.label}
                  </span>
                </button>
              </React.Fragment>
            ))}
        </DashboardActions>
      </DashboardBody>
    </Dashboard>
  );
};

export default Panel;
