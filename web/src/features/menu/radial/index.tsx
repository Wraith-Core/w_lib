import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useNuiEvent } from '../../../hooks/useNuiEvent';
import { fetchNui } from '../../../utils/fetchNui';
import { useLocales } from '../../../providers/LocaleProvider';
import Glyph from '../../../wc/Glyph';
import Icon from '../../../wc/Icon';
import { play } from '../../../wc/sound';
import { R_DEAD, R_ICON, R_OUT, angleOf, seatAt, seatStyle } from './geometry';
import './radial.css';

/**
 * The radial menu, rebuilt on w_wheel's wheel.
 *
 * ═══ What changed and why ═══
 *
 * It used to be a ring of rectangles, each carrying its own icon and label -- a list menu bent
 * into a circle. The game does not draw a wheel that way and neither does w_wheel: options are
 * discs on a thin ring, and only the one under the cursor is named, in the centre. Reading a
 * wheel is meant to be a glance at one word, not a lap around seven boxes.
 *
 * ═══ Selection is by angle, not by hover ═══
 *
 * Wherever the cursor lands outside the centre disc, the seat lying in that direction is
 * picked however far away it is. Making each bubble a hover target would force the player to
 * land on a small disc -- slow and fussy in a way nobody who has played RDR2 expects.
 */

interface RadialItem {
  label: string;
  icon?: string | [string, string];
  menu?: string;
  iconWidth?: number;
  iconHeight?: number;
}

interface RadialState {
  items: RadialItem[];
  sub?: boolean;
  /** The submenu we came back from, so its seat is highlighted on arrival. */
  option?: string;
}

const RadialMenu: React.FC = () => {
  const { locale } = useLocales();
  const [state, setState] = useState<RadialState | null>(null);
  const [hover, setHover] = useState(-1);

  const surfaceRef = useRef<HTMLDivElement>(null);
  /* The pointer handler fires far more often than React renders, so the current seat is read
     from a ref -- otherwise every mouse move would re-play the hover tick. */
  const hoverRef = useRef(-1);
  const stateRef = useRef<RadialState | null>(null);

  stateRef.current = state;

  const items = state?.items ?? [];

  const setSeat = useCallback((next: number) => {
    if (next === hoverRef.current) return;
    hoverRef.current = next;
    setHover(next);
    if (next >= 0) play('hover');
  }, []);

  useNuiEvent<RadialState | false | null>('openRadialMenu', (data) => {
    if (!data) {
      hoverRef.current = -1;
      setHover(-1);
      return setState(null);
    }

    setState(data);
    play('open');

    // Returning from a submenu puts the cursor back on the option that opened it.
    const from = data.option ? data.items.findIndex((item) => item.menu === data.option) : -1;
    hoverRef.current = from;
    setHover(from);
  });

  const close = useCallback(() => {
    play('close');
    hoverRef.current = -1;
    setHover(-1);
    setState(null);
    fetchNui('radialClose');
  }, []);

  /** The centre is the way out: back into the parent wheel, or out of the menu entirely. */
  const exit = useCallback(() => {
    if (!stateRef.current?.sub) return close();
    play('select');
    fetchNui('radialBack');
  }, [close]);

  const choose = useCallback((seat: number) => {
    if (seat < 0 || !stateRef.current?.items[seat]) return;
    play('select');
    fetchNui('radialClick', seat);
  }, []);

  const onMove = useCallback(
    (e: React.MouseEvent<HTMLDivElement>) => {
      const box = surfaceRef.current?.getBoundingClientRect();
      const count = stateRef.current?.items.length ?? 0;
      if (!box || !count) return;

      // The surface is square, so one scale converts pixels into the 200-unit drawing box.
      const scale = Math.min(box.width, box.height) / 2 / R_OUT;
      const dx = (e.clientX - (box.left + box.width / 2)) / scale;
      const dy = (e.clientY - (box.top + box.height / 2)) / scale;

      setSeat(Math.hypot(dx, dy) < R_DEAD ? -1 : seatAt(count, angleOf(dx, dy)));
    },
    [setSeat]
  );

  useEffect(() => {
    if (!state) return;

    const onKey = (e: KeyboardEvent) => {
      const count = stateRef.current?.items.length ?? 0;

      switch (e.key) {
        case 'Escape':
          e.preventDefault();
          return close();
        case 'Backspace':
          e.preventDefault();
          return exit();
        case 'Enter':
          e.preventDefault();
          return choose(hoverRef.current);
        // The arrow keys walk the ring, for anyone not driving this with a mouse.
        case 'ArrowRight':
        case 'ArrowDown':
          e.preventDefault();
          if (count) setSeat((hoverRef.current + 1 + count) % count);
          return;
        case 'ArrowLeft':
        case 'ArrowUp':
          e.preventDefault();
          if (count) setSeat((hoverRef.current - 1 + count) % count);
          return;
      }
    };

    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [state, close, exit, choose, setSeat]);

  if (!state) return null;

  const named = hover >= 0 ? items[hover] : undefined;

  return (
    <div className="lb-layer" data-layer="radial">
      <div className="lb-radial">
        <div
          className="lb-radial-surface"
          ref={surfaceRef}
          onMouseMove={onMove}
          onMouseLeave={() => setSeat(-1)}
          onClick={() => choose(hoverRef.current)}
        >
          {/* The thin ring passing through the bubble centres */}
          <svg className="lb-radial-svg" viewBox={`${-R_OUT} ${-R_OUT} ${R_OUT * 2} ${R_OUT * 2}`}>
            <circle cx="0" cy="0" r={R_ICON} className="lb-radial-ring" />
          </svg>

          <div className="lb-radial-overlay">
            {items.map((item, i) => {
              const classes = ['lb-radial-bubble', i === hover ? 'is-selected' : '', item.menu ? 'is-menu' : '']
                .filter(Boolean)
                .join(' ');

              return (
                <div className={classes} style={seatStyle(i, items.length)} key={`${item.label}-${i}`}>
                  <span className="lb-radial-face">
                    <Icon
                      icon={item.icon}
                      style={
                        item.iconWidth || item.iconHeight
                          ? { width: item.iconWidth, height: item.iconHeight }
                          : undefined
                      }
                    />
                  </span>
                </div>
              );
            })}
          </div>

          {/* ★ The centre is both the readout and the way out. It sits inside the deadzone, so
              resting the cursor on it clears the selection and a click here can never fire an
              option by accident. */}
          <button type="button" className="lb-radial-center" onClick={exit}>
            {named ? (
              <>
                <span className="lb-radial-title">{named.label}</span>
                <i className="lb-radial-rule" />
              </>
            ) : (
              <span className="lb-radial-hint">{locale.ui.move_select || 'Move to Select'}</span>
            )}

            {state.sub ? (
              <span className="lb-radial-exit lb-back-arrow" aria-label={locale.ui.back || 'Back'} />
            ) : (
              <Glyph tex="cross" className="lb-radial-exit" />
            )}
          </button>
        </div>
      </div>
    </div>
  );
};

export default RadialMenu;
