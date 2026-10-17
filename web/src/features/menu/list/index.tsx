import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useNuiEvent } from '../../../hooks/useNuiEvent';
import { fetchNui } from '../../../utils/fetchNui';
import { Bar, Head, Layer, Panel, play } from '../../../wc/Panel';
import Icon from '../../../wc/Icon';

interface MenuItem {
  label: string;
  description?: string;
  icon?: string | [string, string];
  values?: Array<string | { label: string }>;
  checked?: boolean;
  progress?: number;
  close?: boolean;
}

interface MenuState {
  title: string;
  items: MenuItem[];
  position?: string;
  canClose?: boolean;
  startItemIndex?: number;
}

const posClass = (position?: string) => (position || 'top-left').replace(/[^a-z-]/g, '');

/**
 * The list menu, on the live build's markup (lb-menu / lb-menu-item / lb-menu-values).
 *
 * ★ Keyboard-first, exactly as the build had it: up and down move the cursor, left and right
 *   turn a row's values, Enter confirms or ticks, Escape and Backspace close. The mouse works
 *   too, but the game's own menus are driven from the keyboard and this one keeps that.
 */
const ListMenu: React.FC = () => {
  const [menu, setMenu] = useState<MenuState | null>(null);
  const [index, setIndex] = useState(0);
  // 4.0.2: the row under the mouse is only LIT (is-hover); it never moves the selected row (index), so Enter and the
  // arrows act on what was selected, not on the last row the mouse crossed. A click still picks and confirms its row.
  const [hover, setHover] = useState(-1);
  const [scroll, setScroll] = useState<Record<number, number>>({});

  /* The key handler is registered once; it reads through refs so it never goes stale. */
  const menuRef = useRef<MenuState | null>(null);
  const indexRef = useRef(0);
  const scrollRef = useRef<Record<number, number>>({});

  menuRef.current = menu;
  indexRef.current = index;
  scrollRef.current = scroll;

  useNuiEvent('closeMenu', () => setMenu(null));

  useNuiEvent<MenuState>('setMenu', (data) => {
    setMenu(data);
    setIndex(data.startItemIndex ?? 0);
    setHover(-1);
    setScroll({});
    play('open');
  });

  const move = useCallback((delta: number) => {
    const state = menuRef.current;
    if (!state) return;

    const next = (indexRef.current + delta + state.items.length) % state.items.length;

    setIndex(next);
    play('hover');
    fetchNui('changeSelected', [next, scrollRef.current[next] ?? null, 'isScroll']);
  }, []);

  const sideScroll = useCallback((delta: number) => {
    const state = menuRef.current;
    const at = indexRef.current;
    const item = state?.items[at];

    if (!item?.values) return;

    const count = item.values.length;
    const next = ((scrollRef.current[at] ?? 0) + delta + count) % count;

    setScroll((prev) => ({ ...prev, [at]: next }));
    play('hover');
    fetchNui('changeIndex', [at, next]);
  }, []);

  const confirm = useCallback(() => {
    const state = menuRef.current;
    const at = indexRef.current;
    const item = state?.items[at];
    if (!state || !item) return;

    // A tickbox row toggles rather than confirms -- Enter is the tick.
    if (typeof item.checked === 'boolean') {
      const checked = !item.checked;

      setMenu({ ...state, items: state.items.map((it, i) => (i === at ? { ...it, checked } : it)) });
      play('select');
      fetchNui('changeChecked', [at, checked]);
      return;
    }

    play('select');

    const payload = [at, item.values ? scrollRef.current[at] ?? 0 : null, false];

    // ⚠️ close !== false: a row closes the menu unless it says otherwise, which is how a menu
    //    of repeatable actions stays open between presses.
    if (item.close !== false) setMenu(null);

    fetchNui('confirmSelected', payload);
  }, []);

  const close = useCallback((key: string | null) => {
    const state = menuRef.current;
    if (!state || state.canClose === false) return;

    play('close');
    setMenu(null);
    fetchNui('closeMenu', key);
  }, []);

  useEffect(() => {
    if (!menu) return;

    const onKey = (e: KeyboardEvent) => {
      switch (e.key) {
        case 'ArrowDown': e.preventDefault(); return move(1);
        case 'ArrowUp': e.preventDefault(); return move(-1);
        case 'ArrowLeft': e.preventDefault(); return sideScroll(-1);
        case 'ArrowRight': e.preventDefault(); return sideScroll(1);
        case 'Enter': e.preventDefault(); return confirm();
        case 'Escape':
        case 'Backspace': e.preventDefault(); return close(e.key);
      }
    };

    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [menu, move, sideScroll, confirm, close]);

  if (!menu) return null;

  return (
    <Layer name="menu">
      <Panel className={`lb-menu pos-${posClass(menu.position)}`} onClose={menu.canClose !== false ? () => close(null) : undefined}>
        <Head title={menu.title} />

        <div className="lb-menu-list">
          {menu.items.map((item, i) => {
            const value = item.values?.[scroll[i] ?? 0];
            const valueText = value && typeof value === 'object' ? value.label : value;

            return (
              <button
                type="button"
                key={i}
                className={`lb-menu-item${i === index ? ' is-active' : ''}${i === hover && i !== index ? ' is-hover' : ''}`}
                onMouseEnter={() => setHover(i)}
                onMouseLeave={() => setHover((h) => (h === i ? -1 : h))}
                onClick={() => {
                  setIndex(i);
                  // The click lands before the state does, so confirm reads the ref we just set.
                  indexRef.current = i;
                  confirm();
                }}
              >
                <span className={`lb-item-icon${item.icon ? '' : ' is-empty'}`}>
                  <Icon icon={item.icon} fallback="menu_bar" />
                </span>

                <span style={{ minWidth: 0 }}>
                  <span className="lb-item-title">{item.label}</span>
                  {item.description && <span className="lb-item-desc">{item.description}</span>}
                  {typeof item.progress === 'number' && <Bar ratio={item.progress / 100} bright />}
                </span>

                {/* ⚠️ The arrows carry no texture of their own -- the stylesheet picks it from
                    the document direction, exactly as it already does for .lb-item-arrow and
                    .lb-back-arrow. Hard-coding a texture here is what made them point inwards:
                    the sheet is written RTL-first, so a fixed pair is right in one direction
                    and backwards in the other. */}
                {item.values ? (
                  <span className="lb-menu-values">
                    <span className="lb-values-prev" aria-hidden="true" />
                    <span>{valueText}</span>
                    <span className="lb-values-next" aria-hidden="true" />
                  </span>
                ) : typeof item.checked === 'boolean' ? (
                  /* ★ The theme's square: ink when off, paper with an ink centre when on (the class
                     draws it -- lib-ui.css .lb-check-box.wst-checked), inverted on the band. */
                  <span className={`lb-check-box${item.checked ? ' wst-checked' : ''}`} aria-checked={item.checked} role="checkbox" />
                ) : (
                  <span />
                )}
              </button>
            );
          })}
        </div>
      </Panel>
    </Layer>
  );
};

export default ListMenu;
