import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useNuiEvent } from '../../../hooks/useNuiEvent';
import { fetchNui } from '../../../utils/fetchNui';
import { play } from '../../../wc/sound';
import { Card, cls, Gauge, GlyphNext, GlyphPrev, HeadControl, isCriticalScheme, KitIcon, Txt, useKit } from '../../../kit/ui';

interface MenuItem {
  label: string;
  description?: string;
  icon?: string | [string, string];
  values?: Array<string | { label: string }>;
  checked?: boolean;
  progress?: number;
  colorScheme?: string;
  close?: boolean;
}

interface MenuState {
  title: string;
  items: MenuItem[];
  position?: string;
  canClose?: boolean;
  startItemIndex?: number;
}

/**
 * Where the menu docks. The kit docks at the board's edge on the inline START (the right in Arabic), so the four
 * corners ox_lib names are read in the reading direction: 'left' = the start side, 'right' = the end side, and an
 * Arabic screen mirrors them with everything else. top / bottom are kept. No position = top at the start.
 */
const dockClass = (position?: string) => {
  const p = String(position || 'top-left');
  return cls(/right/.test(p) && 'is-end', /bottom/.test(p) && 'is-bottom');
};

/**
 * The list menu, on the board kit (4.4.0): the same masthead + torn card as the context menu, the cursor row on
 * the paper band, a row's values on the kit's stepper, a tick row as the kit's on / off switch.
 *
 * ★ Keyboard-first, exactly as the build had it: up and down move the cursor, left and right
 *   turn a row's values, Enter confirms or ticks, Escape and Backspace close. The mouse works
 *   too, but the game's own menus are driven from the keyboard and this one keeps that.
 */
const ListMenu: React.FC = () => {
  const { rtl, t } = useKit();
  const listRef = useRef<HTMLDivElement | null>(null);
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

  /* the cursor row stays in view when the arrows move it past the card's edge */
  useEffect(() => {
    listRef.current?.querySelector<HTMLElement>(`[data-row="${index}"]`)?.scrollIntoView({ block: 'nearest' });
  }, [index]);

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

  const withIcons = menu.items.some((item) => item.icon);
  const dock = dockClass(menu.position);

  return (
    <div className={cls('wf', 'wk-menu', rtl && 'is-rtl')}>
      <div className={cls('wk-side-scrim', /is-end/.test(dock) && 'is-end')} />
      <div className={cls('wk-dock', dock)}>
        <header className="wf-mast wf-in">
          <span className="wf-mark"><Txt s={menu.title} /></span>
          <span className="wf-mast-rule" />
          {menu.canClose !== false && <HeadControl label={t('close')} onClick={() => close(null)} />}
        </header>

        <Card focus i={1}>
          <div className="wk-rows" ref={listRef}>
            {menu.items.map((item, i) => {
              const value = item.values?.[scroll[i] ?? 0];
              const valueText = value && typeof value === 'object' ? value.label : value;
              const lit = i === index || i === hover;

              return (
                <button
                  type="button"
                  key={i}
                  data-row={i}
                  /* ★ The paper band is the CURSOR (the arrows' row, Enter acts on it); the mouse only lights a row
                     the same way while it is over it. Nothing here is red: a list menu has no chosen row. */
                  className={cls('wf-row', 'wk-row', lit && 'is-here')}
                  onMouseEnter={() => setHover(i)}
                  onMouseLeave={() => setHover((h) => (h === i ? -1 : h))}
                  onClick={() => {
                    setIndex(i);
                    // The click lands before the state does, so confirm reads the ref we just set.
                    indexRef.current = i;
                    confirm();
                  }}
                >
                  {withIcons && (
                    <span className={cls('wk-ico', !item.icon && 'is-empty')}>
                      <KitIcon icon={item.icon} />
                    </span>
                  )}

                  <span className="wf-row-main">
                    <span className="wf-row-name"><Txt s={item.label} /></span>
                    {item.description && <span className="wk-desc"><Txt s={item.description} /></span>}
                    {typeof item.progress === 'number' && <Gauge value={item.progress} critical={isCriticalScheme(item.colorScheme)} />}
                  </span>

                  {item.values ? (
                    /* the kit's stepper: the game's own arrows either side of the value (they turn with the language).
                       ⚠️ Drawn, not pressed: left / right turn the value, and a click on the row confirms it, as before. */
                    <span className="wf-stepper" aria-hidden="true">
                      <span className="wf-stepper-arrow"><GlyphPrev /></span>
                      <span className="wf-stepper-value"><Txt s={valueText} /></span>
                      <span className="wf-stepper-arrow"><GlyphNext /></span>
                    </span>
                  ) : typeof item.checked === 'boolean' ? (
                    /* the pause menu's on / off: red when on */
                    <span className="wf-switch" data-on={item.checked ? 'true' : 'false'} role="checkbox" aria-checked={item.checked}>
                      {item.checked ? t('on') : t('off')}
                    </span>
                  ) : null}
                </button>
              );
            })}
          </div>
        </Card>
      </div>
    </div>
  );
};

export default ListMenu;
