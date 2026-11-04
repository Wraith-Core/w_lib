import React, { useEffect, useRef, useState } from 'react';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { fetchNui } from '../../utils/fetchNui';
import { InputProps, OptionValue } from '../../typings';
import { Glyph, Head, Layer, Panel, play } from '../../wc/Panel';
import Icon from '../../wc/Icon';
import DateFields from '../../components/DateFields';
import PaletteField from '../../components/PaletteField';
import WSelect from '../../components/WSelect';
import { useLocales } from '../../providers/LocaleProvider';

type Row = InputProps['rows'][number] & Record<string, any>;

/** `allow` (a character class body, 'A-Za-z0-9 '): a text field drops every other character as it is typed or
 *  pasted - a script that needs a name in Latin letters only says so, and the field cannot take anything else. */
const allowCache = new Map<string, RegExp | null>();
const onlyAllowed = (allow: unknown, value: string): string => {
  if (typeof allow !== 'string' || allow === '') return value;
  let re = allowCache.get(allow);
  if (re === undefined) {
    try { re = new RegExp(`[^${allow}]`, 'gu'); } catch { re = null; }
    allowCache.set(allow, re);
  }
  return re ? value.replace(re, '') : value;
};

const sizeClass = (size?: string) =>
  size === 'lg' || size === 'xl' ? ' is-lg' : size === 'xs' || size === 'sm' ? ' is-sm' : '';

/** The label line: icon, text, and the red asterisk a required field carries. */
const FieldLabel: React.FC<{ row: Row }> = ({ row }) => (
  <>
    <span className="lb-label">
      {row.icon && <Icon icon={row.icon} />}
      {row.label}
      {row.required && <span className="req">*</span>}
    </span>
    {row.description && <span className="lb-desc">{row.description}</span>}
  </>
);

const InputDialog: React.FC = () => {
  const { locale, rtl } = useLocales();
  const [data, setData] = useState<InputProps | null>(null);
  const [values, setValues] = useState<Record<number, any>>({});
  const firstField = useRef<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement | null>(null);

  useNuiEvent('closeInputDialog', () => setData(null));

  useNuiEvent<InputProps>('openDialog', (payload) => {
    // Seeded from the defaults so an untouched field still submits what Lua asked for.
    const seeded: Record<number, any> = {};

    (payload.rows as Row[]).forEach((row, i) => {
      const type = String(row.type || 'input').toLowerCase();
      if (type === 'checkbox') seeded[i] = Boolean(row.checked);
      else if (type === 'slider') seeded[i] = row.default ?? row.min ?? 0;
      else seeded[i] = row.default ?? '';
    });

    setValues(seeded);
    setData(payload);
    play('open');
  });

  useEffect(() => {
    if (data) setTimeout(() => firstField.current?.focus(), 30);
  }, [data]);

  const close = (result: OptionValue[] | null) => {
    play(result ? 'select' : 'close');
    setData(null);
    fetchNui('inputData', result);
  };

  const submit = () => {
    if (!data) return;
    close((data.rows as Row[]).map((_, i) => values[i]));
  };

  useEffect(() => {
    if (!data) return;

    const onKey = (e: KeyboardEvent) => {
      if (e.code === 'Escape') close(null);
      // ⚠️ Enter submits from a single-line field only: a textarea needs it for newlines.
      if (e.code === 'Enter' && (e.target as HTMLElement)?.tagName !== 'TEXTAREA') submit();
    };

    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [data, values]);

  if (!data) return null;

  const rows = data.rows as Row[];
  const set = (i: number, v: any) => setValues((prev) => ({ ...prev, [i]: v }));

  /** The RDR number stepper: the browser's own arrows are hidden in CSS and these replace them. */
  const spin = (i: number, row: Row, direction: 1 | -1) => {
    const step = Number(row.step) || 1;
    let next = (Number(values[i]) || 0) + step * direction;

    if (row.min != null && next < row.min) next = row.min;
    if (row.max != null && next > row.max) next = row.max;

    set(i, next);
    play('hover');
  };

  return (
    <Layer name="dialog">
      <div className="lb-scrim" />

      <Panel className={`lb-dialog${sizeClass(data.options?.size)}`}>
        <Head title={data.heading} />

        <div className="lb-dialog-body is-form">
          {rows.map((row, i) => {
            const type = String(row.type || 'input').toLowerCase();
            const first = i === 0 ? (el: any) => (firstField.current = el) : undefined;

            if (type === 'checkbox') {
              /* ★ wst-check: the native input IS the checkbox -- the theme's square (store-theme.css
                 .wst-check input), with the keyboard and the change event the browser gives it.
                 The drawn .lb-check-box stays in the markup for older sheets and is hidden. */
              return (
                <div className="lb-field" key={i}>
                  <label className="lb-check wst-check">
                    <input
                      type="checkbox"
                      checked={Boolean(values[i])}
                      disabled={row.disabled}
                      onChange={(e) => set(i, e.target.checked)}
                    />
                    <span className="lb-check-box">
                      <Glyph tex="tick" />
                    </span>
                    <span>{row.label}</span>
                  </label>
                  {row.description && <span className="lb-desc">{row.description}</span>}
                </div>
              );
            }

            if (type === 'select' || type === 'multi-select') {
              const multi = type === 'multi-select';

              return (
                <div className="lb-field" key={i}>
                  <FieldLabel row={row} />
                  <div className="lb-input">
                    {multi ? (
                      // a multi-select is drawn open in the page (size=4): no popup, so the native one stays
                      <select
                        ref={first}
                        multiple
                        size={4}
                        disabled={row.disabled}
                        required={row.required}
                        value={values[i] ?? []}
                        onChange={(e) => set(i, Array.from(e.target.selectedOptions, (o) => o.value))}
                      >
                        {(row.options || []).map((o: any, k: number) => {
                          const value = o?.value != null ? o.value : o;
                          return (
                            <option key={k} value={value}>
                              {o?.label != null ? o.label : value}
                            </option>
                          );
                        })}
                      </select>
                    ) : (
                      // the page's own dropdown: a native <select> opens a popup the game paints as noise
                      <WSelect
                        buttonRef={first}
                        value={String(values[i] ?? '')}
                        /* * the blank first choice only where "nothing" is an answer: a required list (or one with
                           `clearable = false`) had an empty row above its real choices that could be picked */
                        allowEmpty={!row.required && row.clearable !== false}
                        placeholder=""
                        disabled={row.disabled}
                        ariaLabel={row.label}
                        options={(row.options || []).map((o: any) => {
                          const value = o?.value != null ? o.value : o;
                          return { value: String(value), label: String(o?.label != null ? o.label : value) };
                        })}
                        onChange={(v) => set(i, v)}
                      />
                    )}
                  </div>
                </div>
              );
            }

            if (type === 'slider') {
              // ★ How far the paper runs along the track (lib-ui.css .lb-slider): the theme's
              //   slider draws its fill from this, since a native track has no fill of its own.
              const lo = Number(row.min ?? 0);
              const hi = Number(row.max ?? 100);
              const fill = hi > lo ? Math.min(100, Math.max(0, ((Number(values[i]) - lo) / (hi - lo)) * 100)) : 0;

              return (
                <div className="lb-field" key={i}>
                  <FieldLabel row={row} />
                  <div className="lb-slider" style={{ '--lb-fill': `${fill}%` } as React.CSSProperties}>
                    <input
                      type="range"
                      min={row.min ?? 0}
                      max={row.max ?? 100}
                      step={row.step || 1}
                      value={values[i]}
                      disabled={row.disabled}
                      onChange={(e) => set(i, Number(e.target.value))}
                    />
                    <b dir="ltr">{values[i]}</b>
                  </div>
                </div>
              );
            }

            if (type === 'textarea') {
              return (
                <div className="lb-field" key={i}>
                  <FieldLabel row={row} />
                  <div className="lb-input">
                    <textarea
                      ref={first}
                      placeholder={row.placeholder || ''}
                      disabled={row.disabled}
                      required={row.required}
                      value={values[i] ?? ''}
                      onChange={(e) => set(i, e.target.value)}
                    />
                  </div>
                </div>
              );
            }

            if (type === 'date') {
              // ★ Day, month by name, year -- see components/DateFields for why not the native
              //   box. It hands back the native box's own "YYYY-MM-DD" (or "" until complete).
              return (
                <div className="lb-field" key={i}>
                  <FieldLabel row={row} />
                  <DateFields
                    value={values[i]}
                    rtl={rtl}
                    label={row.label}
                    disabled={row.disabled}
                    required={row.required}
                    firstRef={first}
                    onChange={(v) => set(i, v)}
                  />
                </div>
              );
            }

            if (type === 'color') {
              // ★ The palette's eight tones, not the machine's full-spectrum picker (see
              //   components/PaletteField). The row keeps its default until a tone is picked.
              return (
                <div className="lb-field" key={i}>
                  <FieldLabel row={row} />
                  <PaletteField
                    value={values[i]}
                    rtl={rtl}
                    label={row.label}
                    disabled={row.disabled}
                    firstRef={first}
                    onChange={(v) => set(i, v)}
                  />
                </div>
              );
            }

            const htmlType =
              type === 'number' ? 'number'
              : type === 'time' ? 'time'
              : row.password ? 'password'
              : 'text';

            return (
              <div className="lb-field" key={i}>
                <FieldLabel row={row} />
                <div className="lb-input">
                  <input
                    ref={first}
                    type={htmlType}
                    placeholder={row.placeholder || ''}
                    disabled={row.disabled}
                    required={row.required}
                    min={type === 'number' ? row.min : undefined}
                    max={type === 'number' ? row.max : undefined}
                    step={type === 'number' ? row.step : undefined}
                    minLength={type !== 'number' ? row.minLength : undefined}
                    maxLength={type !== 'number' ? row.maxLength : undefined}
                    value={values[i] ?? ''}
                    dir={type !== 'number' && row.allow ? 'ltr' : undefined}
                    onChange={(e) => set(i, type === 'number' ? e.target.value : onlyAllowed(row.allow, e.target.value))}
                  />

                  {type === 'number' && (
                    <span className="lb-spin">
                      <button type="button" className="lb-spin-btn is-up" tabIndex={-1} aria-label="+" onClick={() => spin(i, row, 1)} />
                      <button type="button" className="lb-spin-btn is-down" tabIndex={-1} aria-label="-" onClick={() => spin(i, row, -1)} />
                    </span>
                  )}
                </div>
              </div>
            );
          })}
        </div>

        <div className="wc-hr-thin" />

        {/* ★ Confirm is FIRST in the DOM, which puts it at the inline start: on the right in
            Arabic and on the left in English. Reordering here rather than with CSS `order`
            keeps the focus order the same as the visual order, which is what a keyboard and a
            screen reader both follow. */}
        <div className="lb-actions">
          <button type="button" className="lb-btn" onClick={submit}>
            <span>
              <Glyph tex="tick" />
              {locale.ui.confirm}
            </span>
          </button>

          {data.options?.allowCancel !== false && (
            <button type="button" className="lb-btn-ghost" onClick={() => close(null)}>
              <span>
                <Glyph tex="cross" />
                {locale.ui.cancel}
              </span>
            </button>
          )}
        </div>
      </Panel>
    </Layer>
  );
};

export default InputDialog;
