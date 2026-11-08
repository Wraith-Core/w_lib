import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { fetchNui } from '../../utils/fetchNui';
import { play } from '../../wc/sound';
import { cls, Gauge, GlyphCross, GlyphDown, GlyphLock, GlyphSearch, KitIcon, Txt, useKit } from '../../kit/ui';
import Blocks, { AmountField, Block, Slot } from './Blocks';

/**
 * ============================================================================
 * The panel -- one board, described from Lua (lib.showPanel).
 *
 * ★ WHY THIS EXISTS: every script here wants the same interface -- a titled panel, a list of
 *   things, the selected thing in detail, and a row of actions. Described instead of written, a
 *   script sends a table and gets the board.
 *
 * ★ 4.4.0: drawn on the board kit, as w_crafting's board (the wide layout): the masthead (the title as the mark,
 *   close at its end), the list card on the start side (tabs, search, the tally, sections that fold), the detail
 *   card filling the rest (the blocks on a 12-column grid), and the actions strip under it (the main button on
 *   the red band). The row under the mouse is lit (the paper band); the PICKED row is the red band.
 *
 * ⚠️ It is a DESCRIPTION, not a component tree. Lua cannot send functions across the NUI
 *    boundary, so every action is an id that comes back on a callback. The contract is unchanged:
 *    showPanel (a description, or false) / hidePanel in; panelClose, panelSelect id, panelAction
 *    {action, item, amount}, panelTab id, panelNav id, panelField {id, value}, panelCancel out.
 *    Keys: arrows pick the next row (and tell Lua at once), Enter runs the primary action, Escape
 *    closes; inside a field Escape and Enter only leave the field.
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
  /** Draws the tag as a bad state: missing, locked, banned. */
  tagBad?: boolean;
  stats?: Meta[];
  rows?: Meta[];
  /** What this costs, needs, or is made of -- ONE field for all three on purpose. */
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
  /** Marked, and the action should usually be disabled with it: not enough, not carried. */
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
  /** Not in the original contract, honoured when a script sends it: a button that takes something away. */
  danger?: boolean;
  /** Asks for a number before firing -- a bid, a quantity, a stake. Its value rides along on panelAction. */
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
  /** The side column only as wide as its widest row (w_playernames' list of name plates). */
  navFit?: boolean;
  /** A grouped sidebar in place of the item list; the content then comes from `blocks`. */
  nav?: NavGroup[];
  activeNav?: string;
  /** The unit counted under the tabs -- 'recipes', 'players', 'lots'. Without it the tally is left off. */
  navCountLabel?: string;
  /** The content, composed. When present it replaces the fixed detail pane entirely. */
  blocks?: Block[];
}

/** A section of the browser column: a heading that folds open, and rows under it (w_crafting's category). */
interface NavGroup {
  /** Stable across redraws -- the open/closed state is keyed on it. Falls back to the label. */
  id?: string;
  label?: string;
  /** A lock on the heading and a red edge down its side: a job-gated section. */
  private?: boolean;
  /** Sits at the end of the heading beside the count -- 'Level 15'. */
  levelLabel?: string;
  /** Which tab shows this group. Groups without one show under every tab. */
  scope?: string;
  /** Open on arrival. With none set anywhere, the first group opens. */
  expanded?: boolean;
  /** The row count as a quiet "(31)" beside the name instead of at the end. */
  countInline?: boolean;
  items: Array<{
    id: string;
    label: string;
    icon?: string;
    image?: string;
    count?: number | string;
    /** A second line under the label. */
    description?: string;
    /** A wide picture as the row (w_playernames: each player's name plate). */
    picture?: string;
    /** A row with a picture: a small line under it. */
    caption?: string;
    /** Extra text the search matches but never draws (what a recipe is made of). */
    search?: string;
    disabled?: boolean;
  }>;
}

/**
 * Seconds as a clock: 2:07, or 1:04:22 once it passes an hour.
 * ⚠️ Drawn left to right wherever it is shown (.wk-fig): digits and colons are bidi-neutral.
 */
const asClock = (total: number) => {
  const t = Math.max(0, Math.floor(total));
  const h = Math.floor(t / 3600);
  const m = Math.floor((t % 3600) / 60);
  const sec = t % 60;

  const mm = h ? String(m).padStart(2, '0') : String(m);
  return `${h ? `${h}:` : ''}${mm}:${String(sec).padStart(2, '0')}`;
};

const low = (s: unknown) => (s == null ? '' : String(s).toLowerCase());

const Panel: React.FC = () => {
  const { rtl, t } = useKit();
  const [state, setState] = useState<PanelState | null>(null);
  const [selected, setSelected] = useState<string | number | null>(null);
  const [search, setSearch] = useState('');
  /** The row under the mouse: lit only (the paper band), never picked. */
  const [cursor, setCursor] = useState<string | null>(null);
  /** Seconds since this description arrived -- the one clock every countdown reads from. */
  const [elapsed, setElapsed] = useState(0);
  /** What each amount field is currently set to, keyed by action id. */
  const [amounts, setAmounts] = useState<Record<string, number>>({});

  /* The key handler is registered once and reads through refs, so it never goes stale. */
  const stateRef = useRef<PanelState | null>(null);
  const selectedRef = useRef<string | number | null>(null);
  const listRef = useRef<HTMLDivElement | null>(null);

  stateRef.current = state;
  selectedRef.current = selected;

  const items = state?.items ?? [];

  /**
   * ★ ONE interval for the whole panel, and it runs only while something is counting. The server still owns when
   *   a lot actually ends; this only draws the wait.
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

  /* ★ Filtering is done here rather than in Lua: a search that crosses the NUI boundary feels laggy. */
  const visible = useMemo(() => {
    const needle = search.trim().toLowerCase();
    if (!needle) return items;

    return items.filter((item) => low(item.title).includes(needle) || low(item.description).includes(needle));
  }, [items, search]);

  /* ── the browser column, when it is navigation ──
     ★ Tabs and folding are answered HERE, not by Lua (no round trip per fold). `panelTab` still fires so a script
       CAN react. */
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
          ? group.items.filter((item) => low(item.label).includes(needle) || low(item.search).includes(needle))
          : group.items,
      }))
      .filter(({ group }) => !state?.tabs?.length || !group.scope || group.scope === tab)
      /* ⚠️ Empty groups vanish only while searching. */
      .filter(({ items }) => !needle || items.length > 0);
  }, [state?.nav, state?.tabs, state?.activeTab, navTab, search]);

  /** Which sections are open: every match while searching, else the reader's folds, else the description's, else the first. */
  const expandedKeys = useMemo(() => {
    if (navSearching) return navGroups.map((g) => g.key);
    if (opened) return opened;

    const declared = navGroups.filter(({ group }) => group.expanded).map((g) => g.key);
    if (declared.length) return declared;

    return navGroups.length ? [navGroups[0].key] : [];
  }, [navSearching, navGroups, opened]);

  /* ⚠️ The first fold starts from WHAT IS ON SCREEN, not from nothing (see the 4.x note). */
  const expandedRef = useRef<string[]>([]);
  expandedRef.current = expandedKeys;

  const toggleNavGroup = useCallback((key: string) => {
    play('select');
    setOpened((prev) => {
      const base = prev ?? expandedRef.current;
      return base.includes(key) ? base.filter((k) => k !== key) : [...base, key];
    });
  }, []);

  const navTotal = useMemo(() => (state?.nav ?? []).reduce((n, group) => n + group.items.length, 0), [state?.nav]);

  /** Selectable nav rows, in drawn order — what the arrow keys walk (open groups only). */
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

    /* ⚠️ The open sound for an OPENING only: a redraw of the panel already on screen (same id) is silent. */
    const redraw = !!stateRef.current && stateRef.current.id === data.id;
    setState(data);
    if (!redraw) play('open');
    setElapsed(0);
    setAmounts(
      Object.fromEntries((data.actions ?? []).filter((a) => a.input).map((a) => [a.id, a.input?.value ?? a.input?.min ?? 0]))
    );

    // Keep the selection when the same panel is refreshed; start at the top when it is new.
    const first = data.items?.find((item) => !item.disabled);
    setSelected((prev) => (prev !== null && data.items?.some((i) => i.id === prev) ? prev : first?.id ?? null));

    /* ★ Folds survive a redraw of the same panel; a DIFFERENT panel starts clean. */
    if (panelIdRef.current !== data.id) {
      panelIdRef.current = data.id;
      setNavTab(null);
      setOpened(null);
      setCursor(null);
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
      /* ⚠️ A FIELD BEING TYPED INTO OWNS THE KEYBOARD (the keypad's 2 and 8 report as arrows with NumLock off).
         Escape and Enter step OUT of the field rather than out of the panel. */
      const target = e.target as HTMLElement | null;
      const typing =
        !!target &&
        (target.isContentEditable || target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.tagName === 'SELECT');

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

          /* ★ When the browser IS the nav, the arrows walk IT (open groups only, in drawn order). */
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

  /* the picked row stays in view when the arrows move it */
  const pickedKey = state?.nav?.length ? state?.activeNav : selected;
  useEffect(() => {
    if (pickedKey == null || !listRef.current) return;
    listRef.current.querySelector<HTMLElement>(`[data-row="${CSS.escape(String(pickedKey))}"]`)?.scrollIntoView({ block: 'nearest' });
  }, [pickedKey]);

  if (!state) return null;

  const isNav = !!state.nav?.length;
  const detail = current?.detail;
  const activeTab = navTab ?? state.activeTab ?? state.tabs?.[0]?.id;
  const many = (state.actions?.length ?? 0) > 4;
  const main = state.actions?.find((a) => a.primary) ?? state.actions?.[0];
  /* nothing to browse: one column, the masthead over the detail */
  const single = !isNav && items.length === 0 && !state.tabs?.length;
  const tally = navGroups.reduce((n, g) => n + (expandedKeys.includes(g.key) ? g.items.length : 0), 0);

  const aside =
    typeof state.countdown === 'number' ? (
      <span className="wf-mast-item wk-aside"><b className="wk-fig">{asClock(state.countdown - elapsed)}</b></span>
    ) : state.aside ? (
      <span className="wf-mast-item wk-aside"><Txt s={state.aside} /></span>
    ) : null;

  const mast = (
    <header className="wf-mast wf-in">
      {state.logo && (
        <img className="wk-logo" src={state.logo} alt="" draggable={false} onError={(e) => { e.currentTarget.style.display = 'none'; }} />
      )}
      <span className="wf-mark"><Txt s={state.title} /></span>
      <span className="wf-mast-rule" />
      {single && aside}
      <button type="button" className="wk-x" onClick={close} aria-label={t('close')} title={t('close')}>
        <GlyphCross />
      </button>
    </header>
  );

  const blockCtx = {
    selected,
    onPick: pick,
    onAction: (id: string, itemId?: string | number) => {
      play('select');
      fetchNui('panelAction', { action: id, item: itemId ?? selectedRef.current });
    },
    onField: (id: string, value: string | number | boolean) => fetchNui('panelField', { id, value }),
  };

  /* the selected item's own detail, drawn with the same blocks */
  const detailBlocks: Block[] | null =
    current || detail
      ? [
          {
            type: 'hero',
            value: detail?.title ?? current?.title,
            subtitle: detail?.description,
            image: detail?.image ?? current?.image,
            icon: current?.icon,
            tag: detail?.tag,
            tagBad: detail?.tagBad,
          },
          ...((typeof detail?.endsIn === 'number' || detail?.rows?.length)
            ? [{
                type: 'stats' as const,
                items: [
                  ...(typeof detail?.endsIn === 'number' ? [{ label: detail.endsInLabel ?? '', value: asClock(detail.endsIn - elapsed) }] : []),
                  ...(detail?.rows ?? []),
                ],
              }]
            : []),
          ...(detail?.stats?.length ? [{ type: 'bars' as const, title: state.statsLabel, items: detail.stats }] : []),
          ...(detail?.requirements?.length
            ? [{
                type: 'requirements' as const,
                title: detail.requirementsLabel,
                items: detail.requirements.map((r) => ({ label: r.label, value: r.amount, image: r.image, icon: r.icon, danger: r.missing })),
              }]
            : []),
        ]
      : null;

  return (
    <div className={cls('wf', 'wk-board', rtl && 'is-rtl')} data-theme={state.theme}>
      <div className="wk-scrim" />
      <div className={cls('wk-layout', single && 'is-single')}>
        {/* ── the list ── */}
        {!single && (
          <section className={cls('wk-side', state.navFit && 'is-fit')}>
            {mast}

            <div className="wf-wrap wk-list-wrap is-focus wf-in" style={{ ['--i' as string]: 1 }}>
              <div className="wf-tick" />
              <div className="wf-card">
                <div className="wf-card-body wk-list">
                  {(state.icon || state.subtitle || (isNav && state.navCountLabel)) && (
                    <div className="wk-list-head">
                      {state.icon && <span className="wk-head-ico"><KitIcon icon={state.icon} /></span>}
                      <span className="wf-kicker"><Txt s={state.subtitle} /></span>
                      {isNav && state.navCountLabel && (
                        <span className="wk-tally">
                          <b className="wk-fig">{tally}</b>
                          {navSearching ? <> {t('of')} <b className="wk-fig">{navTotal}</b></> : null} <Txt s={state.navCountLabel} />
                        </span>
                      )}
                    </div>
                  )}

                  {state.tabs?.length ? (
                    <div className="wf-tabs wk-tabs" role="tablist">
                      {state.tabs.map((tab) => {
                        const active = tab.id === activeTab;
                        return (
                          <button
                            key={tab.id}
                            type="button"
                            role="tab"
                            aria-selected={active}
                            className={cls('wf-tab', active && 'is-active')}
                            onClick={() => {
                              play('select');
                              /* a nav panel filters by itself; an item panel's tab is the script's to answer */
                              if (isNav) setNavTab(tab.id);
                              setCursor(null);
                              fetchNui('panelTab', tab.id);
                            }}
                          >
                            {tab.icon && <span className="wk-btn-ico"><KitIcon icon={tab.icon} /></span>}
                            <Txt s={tab.label} />
                          </button>
                        );
                      })}
                    </div>
                  ) : null}

                  {state.search !== false && (
                    <label className="wf-search">
                      <GlyphSearch />
                      <input
                        value={search}
                        placeholder={state.searchPlaceholder || t('search')}
                        dir="auto"
                        spellCheck={false}
                        onChange={(e) => { setSearch(e.target.value); setCursor(null); }}
                      />
                      {search && (
                        <button type="button" className="wk-search-x" onClick={() => setSearch('')} aria-label={t('close')}>
                          <GlyphCross />
                        </button>
                      )}
                    </label>
                  )}

                  <div className="wk-list-rows" ref={listRef} onMouseLeave={() => setCursor(null)}>
                    {isNav ? (
                      navGroups.length ? (
                        navGroups.map(({ group, key, items: rows }) => {
                          const open = expandedKeys.includes(key) || !group.label;
                          return (
                            <section className={cls('wk-group', group.private && 'is-private')} key={key}>
                              {group.label && (
                                <button
                                  type="button"
                                  className={cls('wk-group-head', open && 'is-open')}
                                  aria-expanded={open}
                                  onClick={() => toggleNavGroup(key)}
                                >
                                  <span className="wk-fold"><GlyphDown /></span>
                                  {group.private && <span className="wk-lock"><GlyphLock /></span>}
                                  <span className="wk-group-name">
                                    <Txt s={group.label} />
                                    {group.countInline && <span className="wk-group-inline wk-fig">({rows.length})</span>}
                                  </span>
                                  <span className="wk-group-rule" />
                                  {group.levelLabel && <span className="wf-tag"><Txt s={group.levelLabel} /></span>}
                                  {!group.countInline && <span className="wk-group-count wk-fig">{rows.length}</span>}
                                </button>
                              )}
                              {open &&
                                rows.map((row) => (
                                  <button
                                    key={row.id}
                                    type="button"
                                    data-row={row.id}
                                    disabled={row.disabled}
                                    title={row.picture ? row.label : undefined}
                                    aria-label={row.picture ? row.label : undefined}
                                    className={cls(
                                      'wf-row',
                                      'wk-prow',
                                      row.picture && 'is-picture',
                                      cursor === row.id && 'is-here',
                                      row.id === state.activeNav && 'is-sel',
                                      row.disabled && 'is-off'
                                    )}
                                    onMouseEnter={() => setCursor(row.id)}
                                    onClick={() => {
                                      play('select');
                                      fetchNui('panelNav', row.id);
                                    }}
                                  >
                                    {row.picture ? (
                                      <>
                                        <img src={row.picture} alt="" draggable={false} />
                                        {row.caption && <span className="wk-caption"><Txt s={row.caption} /></span>}
                                      </>
                                    ) : (
                                      <>
                                        <Slot image={row.image} icon={row.icon} />
                                        <span className="wf-row-main">
                                          <span className="wf-row-name"><Txt s={row.label} /></span>
                                          {row.description && <span className="wf-row-meta"><Txt s={row.description} /></span>}
                                        </span>
                                        {row.count != null && row.count !== '' && (
                                          <span className="wf-row-end"><Txt s={row.count} /></span>
                                        )}
                                      </>
                                    )}
                                  </button>
                                ))}
                            </section>
                          );
                        })
                      ) : (
                        <div className="wf-empty"><Txt s={state.emptyText || t('nothing')} /></div>
                      )
                    ) : visible.length ? (
                      visible.map((item, i) => {
                        const left = typeof item.endsIn === 'number' ? item.endsIn - elapsed : null;
                        return (
                          <React.Fragment key={String(item.id)}>
                            {item.group && item.group !== visible[i - 1]?.group && (
                              <div className={cls('wf-sec', 'wk-sec', 'wk-list-sec', i === 0 && 'is-first')}><span className="wk-sec-title"><Txt s={item.group} /></span></div>
                            )}
                            <button
                              type="button"
                              data-row={String(item.id)}
                              disabled={item.disabled}
                              className={cls(
                                'wf-row',
                                'wk-prow',
                                cursor === String(item.id) && 'is-here',
                                item.id === selected && 'is-sel',
                                item.disabled && 'is-off'
                              )}
                              onMouseEnter={() => setCursor(String(item.id))}
                              onClick={() => pick(item.id)}
                            >
                              <Slot image={item.image} icon={item.icon} />
                              <span className="wf-row-main">
                                <span className="wf-row-name"><Txt s={item.title} /></span>
                                {(item.description || item.meta?.length || left !== null) && (
                                  <span className="wf-row-meta">
                                    {left !== null && <b className={cls('wk-fig', left <= 30 && 'wk-urgent')}>{asClock(left)}</b>}
                                    {item.description && <span><Txt s={item.description} /></span>}
                                    {item.meta?.map((m, k) => (
                                      <span key={k}>
                                        <Txt s={m.label} />
                                        {m.value != null && <>: <b className="wf-num">{m.value}</b></>}
                                      </span>
                                    ))}
                                  </span>
                                )}
                              </span>
                            </button>
                          </React.Fragment>
                        );
                      })
                    ) : (
                      <div className="wf-empty"><Txt s={state.emptyText || t('nothing')} /></div>
                    )}
                  </div>
                </div>
              </div>
            </div>
          </section>
        )}

        {/* ── the detail and the actions ── */}
        <section className="wk-main">
          {single ? (
            mast
          ) : (
            /* the same height as the list's masthead, so both columns start on one line */
            <header className="wf-mast wk-main-mast wf-in">
              <span className="wf-mast-rule" />
              {aside}
            </header>
          )}

          <div className="wf-wrap wk-detail-wrap wf-in" style={{ ['--i' as string]: 2 }}>
            <div className="wf-card">
              <div className="wf-card-body wk-detail">
                {state.blocks?.length ? (
                  <Blocks blocks={state.blocks} ctx={blockCtx} />
                ) : detailBlocks ? (
                  <Blocks blocks={detailBlocks} ctx={blockCtx} />
                ) : (
                  <div className="wk-empty"><Txt s={state.emptyText || t('nothing')} /></div>
                )}
              </div>
            </div>
          </div>

          {state.progress || state.actions?.length || state.hints?.length ? (
            <div className="wf-wrap wk-actions-wrap wf-in" style={{ ['--i' as string]: 3 }}>
              <div className="wf-card">
                <div className="wf-card-body wk-actbar">
                  {state.progress ? (
                    /* ★ The actions are not merely disabled while something runs -- they are replaced. */
                    <div className="wk-busy">
                      <Slot image={state.progress.image} />
                      <span className="wk-busy-main">
                        <span className="wk-busy-name">
                          <Txt s={state.progress.label} />
                          {state.progress.info && <> · <b className="wf-num">{state.progress.info}</b></>}
                        </span>
                        <Gauge value={state.progress.value} />
                      </span>
                      {state.progress.cancelLabel && (
                        <button
                          type="button"
                          className="wk-btn"
                          onClick={() => {
                            play('deny');
                            fetchNui('panelCancel');
                          }}
                        >
                          <Txt s={state.progress.cancelLabel} />
                        </button>
                      )}
                    </div>
                  ) : (
                    <div className="wk-acts">
                      {state.actions?.map((a) => (
                        <div className="wk-act-cell" key={a.id}>
                          {a.input && (
                            <AmountField
                              spec={a.input}
                              label={t('amount')}
                              value={amounts[a.id] ?? a.input.min ?? 0}
                              onChange={(n) => setAmounts((p) => ({ ...p, [a.id]: n }))}
                            />
                          )}
                          <button
                            type="button"
                            className={cls('wk-btn', a.primary && 'is-main', a.danger && 'wk-danger', many && 'is-small')}
                            aria-disabled={a.disabled ? 'true' : undefined}
                            onClick={() => run(a)}
                          >
                            {a.icon && <span className="wk-btn-ico"><KitIcon icon={a.icon} /></span>}
                            <span><Txt s={a.label} /></span>
                          </button>
                        </div>
                      ))}
                    </div>
                  )}
                  {!state.progress && state.hints?.length ? (
                    <div className="wk-hints">
                      {state.hints.map((h, i) => {
                        const k = String(h.key).toLowerCase();
                        const act = k === 'esc' || k === 'escape' ? close : k === 'enter' && main ? () => run(main) : undefined;
                        return (
                          <button type="button" key={i} className="wk-hint" onClick={act} disabled={!act}>
                            <span className="wk-key">{h.key}</span>
                            <Txt s={h.label} />
                          </button>
                        );
                      })}
                    </div>
                  ) : null}
                </div>
              </div>
            </div>
          ) : null}
        </section>
      </div>
    </div>
  );
};

export default Panel;
