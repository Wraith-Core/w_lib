import React from 'react';
import { ALL_TONES, nearestTone } from '../utils/palette';

/**
 * ============================================================================
 * A colour field that offers the palette and nothing else, in place of <input type="color">.
 *
 * ★ The owner's rule: every interface is ink and paper, as the game's are. A native colour box
 *   opens the machine's full-spectrum picker, so a house colour, a banner, a zone could come
 *   back any hue at all -- and every screen that later draws it would carry that hue. The
 *   choice here is the eight tones of the theme (tokens.css), paper down to ink. Red is not
 *   offered: it is the theme's mark for danger, not a colour to own.
 *
 * ⚠️ THE VALUE IS UNTOUCHED UNTIL THE PLAYER PICKS. A colour saved by an older build (any hue)
 *    is shown by its nearest tone, but the field hands nothing back until a swatch is chosen --
 *    so opening and saving a form never rewrites a stored colour behind anyone's back. A pick
 *    reports "#rrggbb", the shape the native box reported.
 * ============================================================================
 */

const NAMES: Record<'ar' | 'en', string[]> = {
  ar: ['ورقي', 'ورقي خافت', 'ورقي باهت', 'حبر فاتح', 'حبر', 'حبر داكن', 'حبر أدكن', 'أسود'],
  en: ['Paper', 'Paper, dim', 'Paper, faint', 'Ink, light', 'Ink', 'Ink, deep', 'Ink, deeper', 'Black'],
};

const PaletteField: React.FC<{
  value: unknown;
  onChange: (hex: string) => void;
  disabled?: boolean;
  label?: string;
  rtl?: boolean;
  firstRef?: (el: HTMLButtonElement | null) => void;
}> = ({ value, onChange, disabled, label, rtl, firstRef }) => {
  const on = nearestTone(value);
  const names = NAMES[rtl ? 'ar' : 'en'];

  return (
    <span className="lb-swatches" role="radiogroup" aria-label={label}>
      {ALL_TONES.map((tone, i) => {
        const selected = tone === on;
        const pick = () => onChange(tone.toLowerCase());
        return (
          <button
            key={tone}
            ref={i === 0 ? firstRef : undefined}
            type="button"
            role="radio"
            aria-checked={selected}
            aria-label={names[i]}
            title={names[i]}
            className={`lb-swatch${selected ? ' is-on' : ''}`}
            style={{ ['--lb-swatch' as string]: tone }}
            disabled={disabled}
            onClick={pick}
            onKeyDown={(e) => {
              // ⚠️ Enter picks the swatch here and goes no further: the dialog submits on an
              //    Enter that reaches the window, and would send the value from before the pick.
              if (e.key === 'Enter') {
                e.preventDefault();
                e.stopPropagation();
                pick();
              }
            }}
          />
        );
      })}
    </span>
  );
};

export default PaletteField;
