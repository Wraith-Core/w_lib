import React from 'react';
import { createPortal } from 'react-dom';
import './WSelect.css';

/**
 * A single-choice dropdown drawn by the page, in place of <select>.
 *
 * ! Why not <select>: in the game's browser (CEF, rendered off-screen) a native select opens its
 *   list as a separate popup widget, and the game never paints that widget properly -- it came up
 *   as a box of coloured noise over the panel, the options unreadable. Everything here is page DOM.
 *
 * * The list is portalled to <body> and placed with fixed coordinates from the button, so no
 *   scrolling block clips it and no transformed dialog (translate(-50%,-50%)) moves it. It opens
 *   downward, or upward when there is more room above, and scrolls past ~8 rows.
 * * Mouse, and keys: Enter / Space / arrows open it; arrows move, Enter picks, Esc closes (Esc is
 *   kept from reaching the panel, so it closes the list and not the whole panel).
 * * A long list (more than SEARCH_FROM options, or `searchable`) opens with a search box on top: typing filters
 *   the options by their label and value. An option may carry an `image`, drawn small before its label (and on
 *   the button for the chosen one) -- w_playernames' list of w_map blips is both.
 * * `grid` (a number of columns) opens a menu in the middle of the screen instead of a list under the button:
 *   the search bar, then the options as tiles -- the picture, its name below. Arrows move across and down.
 */
export interface WSelectOption { value: string; label?: string; image?: string }

const SEARCH_FROM = 12;

const WSelect: React.FC<{
  value: string;
  options: WSelectOption[];
  onChange: (value: string) => void;
  disabled?: boolean;
  /** shown when the value is none of the options (and as the empty choice when `allowEmpty`) */
  placeholder?: string;
  allowEmpty?: boolean;
  ariaLabel?: string;
  buttonRef?: React.Ref<HTMLButtonElement>;
  /** a search box over the list; on by itself for a long list */
  searchable?: boolean;
  /** the search box's placeholder */
  searchPlaceholder?: string;
  /** open as a menu of tiles in this many columns (the picture, its name below), with a search bar */
  grid?: number;
  /** grid: 'lg' draws the tile menu nearly as big as a panel (bigger tiles, bigger pictures) -- a long catalogue */
  gridSize?: 'lg';
}> = ({ value, options, onChange, disabled, placeholder, allowEmpty, ariaLabel, buttonRef, searchable, searchPlaceholder, grid, gridSize }) => {
  const [open, setOpen] = React.useState(false);
  const [hot, setHot] = React.useState(-1);
  const [query, setQuery] = React.useState('');
  const [box, setBox] = React.useState<{ left: number; width: number; top?: number; bottom?: number; maxHeight: number } | null>(null);
  const btn = React.useRef<HTMLButtonElement | null>(null);
  const pop = React.useRef<HTMLDivElement | null>(null);
  const list = React.useRef<HTMLUListElement | null>(null);

  const all: WSelectOption[] = allowEmpty ? [{ value: '', label: placeholder ?? '' }, ...options] : options;
  const current = all.find((o) => o.value === value);
  const label = current ? current.label ?? current.value : placeholder ?? '';
  const cols = grid && grid > 0 ? Math.min(12, Math.floor(grid)) : 0;
  const search = cols ? true : searchable ?? all.length > SEARCH_FROM;

  const needle = query.trim().toLowerCase();
  const shown = React.useMemo(
    () => (needle ? all.filter((o) => `${o.label ?? ''} ${o.value}`.toLowerCase().includes(needle)) : all),
    [all, needle]
  );

  const place = React.useCallback(() => {
    const r = btn.current?.getBoundingClientRect();
    if (!r) return;
    const below = window.innerHeight - r.bottom - 8, above = r.top - 8;
    const want = Math.min(search ? 340 : 280, all.length * 34 + 8 + (search ? 44 : 0));
    const up = below < want && above > below;
    setBox({ left: r.left, width: r.width, maxHeight: Math.max(120, Math.min(search ? 340 : 280, up ? above : below)),
      ...(up ? { bottom: window.innerHeight - r.top + 2 } : { top: r.bottom + 2 }) });
  }, [all.length, search]);

  const openList = () => {
    if (disabled) return;
    place();
    setQuery('');
    setHot(Math.max(0, all.findIndex((o) => o.value === value)));
    setOpen(true);
  };
  const close = () => setOpen(false);
  const pick = (o: WSelectOption | undefined) => {
    close();
    btn.current?.focus();
    if (o && o.value !== value) onChange(o.value);
  };

  // outside click, scroll or resize closes it (the button may have moved)
  React.useEffect(() => {
    if (!open) return;
    const down = (e: MouseEvent) => {
      if (btn.current?.contains(e.target as Node) || pop.current?.contains(e.target as Node)) return;
      close();
    };
    const away = (e: Event) => { if (!pop.current?.contains(e.target as Node)) close(); };
    document.addEventListener('mousedown', down, true);
    window.addEventListener('scroll', away, true);
    window.addEventListener('resize', close);
    return () => {
      document.removeEventListener('mousedown', down, true);
      window.removeEventListener('scroll', away, true);
      window.removeEventListener('resize', close);
    };
  }, [open]);

  // typing a search starts again at the first match
  React.useEffect(() => { if (open && needle) setHot(0); }, [needle, open]);

  // keep the highlighted row in view
  React.useEffect(() => {
    if (open && hot >= 0) (list.current?.children[hot] as HTMLElement | undefined)?.scrollIntoView({ block: 'nearest' });
  }, [open, hot]);

  // ⚠️ The dialog submits on Enter and the panel closes on Esc from window listeners. A button does not
  //    always keep the focus after a click (the key then starts at <body>), so while the list is open its
  //    keys are taken at the window's CAPTURE phase -- before any of those listeners -- and stopped there.
  //    Letters (and Space, with a search box) are left alone: they are the search being typed.
  const hotRef = React.useRef(hot);
  hotRef.current = hot;
  const shownRef = React.useRef(shown);
  shownRef.current = shown;
  React.useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      const handled = () => { e.preventDefault(); e.stopImmediatePropagation(); };
      const n = shownRef.current.length;
      const row = cols || 1;
      // across a grid: left / right one tile (mirrored when the page reads right to left), up / down one row
      const rtl = document.documentElement.dir === 'rtl';
      if (e.key === 'Escape') { handled(); close(); }
      else if (e.key === 'ArrowDown') { handled(); setHot((h) => Math.min(n - 1, h + row)); }
      else if (e.key === 'ArrowUp') { handled(); setHot((h) => Math.max(0, h - row)); }
      else if (cols && (e.key === 'ArrowRight' || e.key === 'ArrowLeft')) {
        handled();
        const step = (e.key === 'ArrowRight') !== rtl ? 1 : -1;
        setHot((h) => Math.max(0, Math.min(n - 1, h + step)));
      }
      else if (e.key === 'Enter' || (e.key === ' ' && !search)) { handled(); if (hotRef.current >= 0) pick(shownRef.current[hotRef.current]); }
      else if (e.key === 'Tab') close();
      else if (search) e.stopImmediatePropagation();   // a letter for the search box, not for the panel's keys
    };
    window.addEventListener('keydown', onKey, true);
    return () => window.removeEventListener('keydown', onKey, true);
  }, [open, search, cols]);

  // closed: Enter / Space / an arrow on the focused button opens it (and is kept from the dialog's Enter)
  const onKey = (e: React.KeyboardEvent) => {
    if (disabled || open) return;
    if (e.key === 'Enter' || e.key === ' ' || e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault(); e.stopPropagation(); openList();
    }
  };

  return (
    <>
      <button
        type="button"
        ref={(el) => {
          btn.current = el;
          if (typeof buttonRef === 'function') buttonRef(el);
          else if (buttonRef) (buttonRef as React.MutableRefObject<HTMLButtonElement | null>).current = el;
        }}
        className={`w-select${open ? ' is-open' : ''}${current ? '' : ' is-empty'}`}
        disabled={disabled}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-label={ariaLabel}
        onClick={() => (open ? close() : openList())}
        onKeyDown={onKey}
      >
        {current?.image && <img className="w-select-img" src={current.image} alt="" draggable={false} />}
        <span className="w-select-label">{label}</span>
        <span className="w-select-caret" aria-hidden="true" />
      </button>
      {open && cols > 0 && createPortal(
        /* the tile menu: in the middle of the screen over a dim veil (a press on the veil closes it) */
        <div className="w-select-veil" onMouseDown={(e) => { if (e.target === e.currentTarget) close(); }}>
          <div
            ref={pop}
            className={`w-select-pop is-grid${gridSize === 'lg' ? ' is-lg' : ''}`}
            style={{ ['--w-select-cols' as string]: cols }}
            dir={document.documentElement.dir || undefined}
            role="dialog"
            aria-label={ariaLabel}
          >
            {ariaLabel && <div className="w-select-title">{ariaLabel}</div>}
            <input
              className="w-select-search"
              autoFocus
              value={query}
              placeholder={searchPlaceholder ?? '…'}
              onChange={(e) => setQuery(e.target.value)}
              spellCheck={false}
            />
            <ul ref={list} role="listbox" className="w-select-grid">
              {shown.map((o, i) => (
                <li
                  key={`${o.value}-${i}`}
                  role="option"
                  aria-selected={o.value === value}
                  title={o.label ?? o.value}
                  className={`w-select-tile${o.value === value ? ' is-selected' : ''}${i === hot ? ' is-hot' : ''}`}
                  onMouseEnter={() => setHot(i)}
                  onMouseDown={(e) => { e.preventDefault(); pick(o); }}
                >
                  <span className="w-select-tile-img">
                    {o.image && <img src={o.image} alt="" loading="lazy" draggable={false} />}
                  </span>
                  <span className="w-select-tile-name">{o.label ?? o.value}</span>
                </li>
              ))}
              {!shown.length && <li className="w-select-none">—</li>}
            </ul>
          </div>
        </div>,
        document.body,
      )}
      {open && !cols && box && createPortal(
        <div
          ref={pop}
          className={`w-select-pop${search ? ' has-search' : ''}`}
          style={{ left: box.left, width: box.width, top: box.top, bottom: box.bottom, maxHeight: box.maxHeight }}
          dir={document.documentElement.dir || undefined}
        >
          {search && (
            <input
              className="w-select-search"
              autoFocus
              value={query}
              placeholder={searchPlaceholder ?? '…'}
              onChange={(e) => setQuery(e.target.value)}
              spellCheck={false}
            />
          )}
          <ul ref={list} role="listbox" className="w-select-list">
            {shown.map((o, i) => (
              <li
                key={`${o.value}-${i}`}
                role="option"
                aria-selected={o.value === value}
                className={`w-select-option${o.value === value ? ' is-selected' : ''}${i === hot ? ' is-hot' : ''}`}
                onMouseEnter={() => setHot(i)}
                onMouseDown={(e) => { e.preventDefault(); pick(o); }}
              >
                {o.image && <img className="w-select-img" src={o.image} alt="" loading="lazy" draggable={false} />}
                <span className="w-select-text">{o.label ?? o.value}</span>
              </li>
            ))}
            {!shown.length && <li className="w-select-none">—</li>}
          </ul>
        </div>,
        document.body,
      )}
    </>
  );
};

export default WSelect;
