import React, { useEffect, useRef, useState } from 'react';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { fetchNui } from '../../utils/fetchNui';
import { InputProps, OptionValue } from '../../typings';
import { Glyph, Head, Layer, Panel, play } from '../../wc/Panel';
import Icon from '../../wc/Icon';
import { useLocales } from '../../providers/LocaleProvider';

type Row = InputProps['rows'][number] & Record<string, any>;

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
  const { locale } = useLocales();
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
              return (
                <div className="lb-field" key={i}>
                  <label className="lb-check">
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
                    <select
                      ref={first}
                      multiple={multi}
                      size={multi ? 4 : undefined}
                      disabled={row.disabled}
                      required={row.required}
                      value={values[i] ?? (multi ? [] : '')}
                      onChange={(e) =>
                        set(i, multi ? Array.from(e.target.selectedOptions, (o) => o.value) : e.target.value)
                      }
                    >
                      {!multi && <option value="" />}
                      {(row.options || []).map((o: any, k: number) => {
                        const value = o?.value != null ? o.value : o;
                        return (
                          <option key={k} value={value}>
                            {o?.label != null ? o.label : value}
                          </option>
                        );
                      })}
                    </select>
                  </div>
                </div>
              );
            }

            if (type === 'slider') {
              return (
                <div className="lb-field" key={i}>
                  <FieldLabel row={row} />
                  <div className="lb-slider">
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

            const htmlType =
              type === 'number' ? 'number'
              : type === 'color' ? 'color'
              : type === 'date' ? 'date'
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
                    onChange={(e) => set(i, type === 'number' ? e.target.value : e.target.value)}
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
