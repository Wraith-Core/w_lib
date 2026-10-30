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
 */
export interface WSelectOption { value: string; label?: string }

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
}> = ({ value, options, onChange, disabled, placeholder, allowEmpty, ariaLabel, buttonRef }) => {
  const [open, setOpen] = React.useState(false);
  const [hot, setHot] = React.useState(-1);
  const [box, setBox] = React.useState<{ left: number; width: number; top?: number; bottom?: number; maxHeight: number } | null>(null);
  const btn = React.useRef<HTMLButtonElement | null>(null);
  const list = React.useRef<HTMLUListElement | null>(null);

  const all: WSelectOption[] = allowEmpty ? [{ value: '', label: placeholder ?? '' }, ...options] : options;
  const current = all.find((o) => o.value === value);
  const label = current ? current.label ?? current.value : placeholder ?? '';

  const place = React.useCallback(() => {
    const r = btn.current?.getBoundingClientRect();
    if (!r) return;
    const below = window.innerHeight - r.bottom - 8, above = r.top - 8;
    const want = Math.min(280, all.length * 34 + 8);
    const up = below < want && above > below;
    setBox({ left: r.left, width: r.width, maxHeight: Math.max(120, Math.min(280, up ? above : below)),
      ...(up ? { bottom: window.innerHeight - r.top + 2 } : { top: r.bottom + 2 }) });
  }, [all.length]);

  const openList = () => {
    if (disabled) return;
    place();
    setHot(Math.max(0, all.findIndex((o) => o.value === value)));
    setOpen(true);
  };
  const close = () => setOpen(false);
  const pick = (i: number) => {
    const o = all[i];
    close();
    btn.current?.focus();
    if (o && o.value !== value) onChange(o.value);
  };

  // outside click, scroll or resize closes it (the button may have moved)
  React.useEffect(() => {
    if (!open) return;
    const down = (e: MouseEvent) => {
      if (btn.current?.contains(e.target as Node) || list.current?.contains(e.target as Node)) return;
      close();
    };
    const away = (e: Event) => { if (!list.current?.contains(e.target as Node)) close(); };
    document.addEventListener('mousedown', down, true);
    window.addEventListener('scroll', away, true);
    window.addEventListener('resize', close);
    return () => {
      document.removeEventListener('mousedown', down, true);
      window.removeEventListener('scroll', away, true);
      window.removeEventListener('resize', close);
    };
  }, [open]);

  // keep the highlighted row in view
  React.useEffect(() => {
    if (open && hot >= 0) (list.current?.children[hot] as HTMLElement | undefined)?.scrollIntoView({ block: 'nearest' });
  }, [open, hot]);

  // ⚠️ The dialog submits on Enter and the panel closes on Esc from window listeners. A button does not
  //    always keep the focus after a click (the key then starts at <body>), so while the list is open its
  //    keys are taken at the window's CAPTURE phase -- before any of those listeners -- and stopped there.
  const hotRef = React.useRef(hot);
  hotRef.current = hot;
  React.useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      const handled = () => { e.preventDefault(); e.stopImmediatePropagation(); };
      if (e.key === 'Escape') { handled(); close(); }
      else if (e.key === 'ArrowDown') { handled(); setHot((h) => Math.min(all.length - 1, h + 1)); }
      else if (e.key === 'ArrowUp') { handled(); setHot((h) => Math.max(0, h - 1)); }
      else if (e.key === 'Enter' || e.key === ' ') { handled(); if (hotRef.current >= 0) pick(hotRef.current); }
      else if (e.key === 'Tab') close();
    };
    window.addEventListener('keydown', onKey, true);
    return () => window.removeEventListener('keydown', onKey, true);
  }, [open, all.length]);

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
        <span className="w-select-label">{label}</span>
        <span className="w-select-caret" aria-hidden="true" />
      </button>
      {open && box && createPortal(
        <ul
          ref={list}
          role="listbox"
          className="w-select-list"
          style={{ left: box.left, width: box.width, top: box.top, bottom: box.bottom, maxHeight: box.maxHeight }}
          dir={document.documentElement.dir || undefined}
        >
          {all.map((o, i) => (
            <li
              key={`${o.value}-${i}`}
              role="option"
              aria-selected={o.value === value}
              className={`w-select-option${o.value === value ? ' is-selected' : ''}${i === hot ? ' is-hot' : ''}`}
              onMouseEnter={() => setHot(i)}
              onMouseDown={(e) => { e.preventDefault(); pick(i); }}
            >
              {o.label ?? o.value}
            </li>
          ))}
        </ul>,
        document.body,
      )}
    </>
  );
};

export default WSelect;
