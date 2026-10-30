import React, { useEffect, useRef, useState } from 'react';
import WSelect from './WSelect';

/**
 * ============================================================================
 * A date as three fields -- day, month (by name), year -- in place of <input type="date">.
 *
 * ★ The browser's own date box draws its format from the machine, not from the game: an Arabic
 *   player saw "mm/dd/yyyy" in Latin letters, American order, and a calendar popup in the
 *   system's own look. Three fields read in the player's language, in the order a date is said
 *   (day, month, year -- mirrored for Arabic by the row itself), with the months by name.
 *
 * ⚠️ THE VALUE IS UNCHANGED. It is exactly what the native control produced: "YYYY-MM-DD" when
 *    the three parts make a real date, and "" while they do not (a half-typed date, the 31st of
 *    February). So every script that reads a date row -- InputDialog's inputData, a panel form's
 *    onField -- receives the same string it always did. A default in any other shape is left
 *    alone until the player edits the date: the parent only hears from this on an edit.
 *
 * ★ Digits: Western, always. An Arabic-Indic digit typed into the day or the year is taken as
 *   the Western one, so a player on an Arabic keyboard layout is not refused.
 * ============================================================================
 */

const MONTHS_AR = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
const MONTHS_EN = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

const WORDS = {
  ar: { day: 'اليوم', month: 'الشهر', year: 'السنة' },
  en: { day: 'Day', month: 'Month', year: 'Year' },
};

interface Parts {
  day: string;
  month: string;
  year: string;
}

const EMPTY: Parts = { day: '', month: '', year: '' };

/** Arabic-Indic (and Persian) digits to Western, anything that is not a digit dropped. */
const digits = (raw: string, max: number) =>
  raw
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660))
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06f0))
    .replace(/\D/g, '')
    .slice(0, max);

const parse = (value: unknown): Parts | null => {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(value ?? ''));
  if (!m) return null;
  return { year: m[1], month: String(Number(m[2])), day: String(Number(m[3])) };
};

/** "YYYY-MM-DD" when the parts are a real date, otherwise "" -- what the native input reports. */
const compose = ({ day, month, year }: Parts): string => {
  if (year.length !== 4 || !month || !day) return '';
  const y = Number(year);
  const m = Number(month);
  const d = Number(day);
  const last = new Date(Date.UTC(y, m, 0)).getUTCDate();
  if (!(m >= 1 && m <= 12) || !(d >= 1 && d <= last)) return '';
  return `${year}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
};

const DateFields: React.FC<{
  value: unknown;
  onChange: (value: string) => void;
  rtl?: boolean;
  disabled?: boolean;
  required?: boolean;
  /** Receives the day box, so a dialog can put the first focus on it. */
  firstRef?: (el: HTMLInputElement | null) => void;
  /** The panel's form wraps each field in a <label>; the field's own ids stay out of it. */
  label?: string;
}> = ({ value, onChange, rtl = false, disabled, required, firstRef, label }) => {
  const [parts, setParts] = useState<Parts>(() => parse(value) ?? EMPTY);
  const lastSent = useRef<string | null>(null);

  // ★ The prop wins only when it is new from outside -- not when it is the echo of our own edit
  //   (a half-typed date composes to "", and re-parsing that would wipe what was just typed).
  useEffect(() => {
    if (value === lastSent.current) return;
    setParts(parse(value) ?? EMPTY);
  }, [value]);

  const set = (patch: Partial<Parts>) => {
    const next = { ...parts, ...patch };
    setParts(next);
    const out = compose(next);
    lastSent.current = out;
    onChange(out);
  };

  const words = rtl ? WORDS.ar : WORDS.en;
  const months = rtl ? MONTHS_AR : MONTHS_EN;
  const named = (part: string) => (label ? `${label} - ${part}` : part);

  return (
    <div className="lb-date" dir={rtl ? 'rtl' : 'ltr'}>
      <span className="lb-input lb-date-day">
        <input
          ref={firstRef}
          type="text"
          inputMode="numeric"
          dir="ltr"
          autoComplete="off"
          placeholder={words.day}
          aria-label={named(words.day)}
          disabled={disabled}
          required={required}
          value={parts.day}
          onChange={(e) => set({ day: digits(e.target.value, 2) })}
        />
      </span>

      <span className="lb-input lb-date-month">
        {/* the page's own dropdown: a native <select> opens a popup the game paints as noise (WSelect) */}
        <WSelect
          ariaLabel={named(words.month)}
          disabled={disabled}
          value={parts.month}
          allowEmpty
          placeholder={words.month}
          options={months.map((name, i) => ({ value: String(i + 1), label: name }))}
          onChange={(v) => set({ month: v })}
        />
      </span>

      <span className="lb-input lb-date-year">
        <input
          type="text"
          inputMode="numeric"
          dir="ltr"
          autoComplete="off"
          placeholder={words.year}
          aria-label={named(words.year)}
          disabled={disabled}
          required={required}
          value={parts.year}
          onChange={(e) => set({ year: digits(e.target.value, 4) })}
        />
      </span>
    </div>
  );
};

export default DateFields;
