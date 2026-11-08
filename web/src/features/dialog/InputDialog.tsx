import React, { useEffect, useRef, useState } from 'react';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { fetchNui } from '../../utils/fetchNui';
import { InputProps, OptionValue } from '../../typings';
import { play } from '../../wc/sound';
import { Card, cls, KitIcon, latinDigits, Txt, useKit } from '../../kit/ui';
import DateFields from '../../components/DateFields';
import PaletteField from '../../components/PaletteField';
import WSelect from '../../components/WSelect';

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

const sizeClass = (size?: string) => (size === 'lg' || size === 'xl' ? 'is-lg' : size === 'xs' || size === 'sm' ? 'is-sm' : undefined);

/** The label line (icon, text, the red mark a required field carries) and the help line under the control. */
const FieldLabel: React.FC<{ row: Row }> = ({ row }) => (
  <span className="wf-label">
    {row.icon && <span className="wk-ico"><KitIcon icon={row.icon} /></span>}
    <Txt s={row.label} />
    {row.required && <span className="wk-req">*</span>}
  </span>
);
const Help: React.FC<{ row: Row }> = ({ row }) => (row.description ? <span className="wk-help"><Txt s={row.description} /></span> : null);

const InputDialog: React.FC = () => {
  const { rtl, t } = useKit();
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
    <div className={cls('wf', 'wk-dialog', rtl && 'is-rtl')}>
      <div className="wk-veil" />

      <div className={cls('wk-dialog-col', sizeClass(data.options?.size))}>
        <Card focus i={0}>
          <div className="wf-h"><Txt s={data.heading} /></div>

          <div className="wk-form">
            {rows.map((row, i) => {
              const type = String(row.type || 'input').toLowerCase();
              const first = i === 0 ? (el: any) => (firstField.current = el) : undefined;

              if (type === 'checkbox') {
                /* the pause menu's on / off row: the whole row is the switch, red when on */
                return (
                  <div className="wf-field" key={i}>
                    <button
                      type="button"
                      ref={first}
                      className="wf-switch-row wk-switch"
                      disabled={row.disabled}
                      aria-pressed={Boolean(values[i])}
                      onClick={() => { set(i, !values[i]); play('hover'); }}
                    >
                      <span>
                        <Txt s={row.label} />
                        {row.required && <span className="wk-req">*</span>}
                      </span>
                      <span className="wf-switch" data-on={values[i] ? 'true' : 'false'}>{values[i] ? t('on') : t('off')}</span>
                    </button>
                    <Help row={row} />
                  </div>
                );
              }

              if (type === 'select' || type === 'multi-select') {
                const multi = type === 'multi-select';

                return (
                  <div className="wf-field" key={i}>
                    <FieldLabel row={row} />
                    {multi ? (
                      // a multi-select is drawn open in the page (size=4): no popup, so the native one stays
                      <select
                        ref={first}
                        className="wk-multi"
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
                      <span className="wk-selectbox">
                        <WSelect
                          buttonRef={first}
                          value={String(values[i] ?? '')}
                          allowEmpty
                          placeholder={t('choose')}
                          disabled={row.disabled}
                          ariaLabel={row.label}
                          options={(row.options || []).map((o: any) => {
                            const value = o?.value != null ? o.value : o;
                            return { value: String(value), label: latinDigits(String(o?.label != null ? o.label : value)) };
                          })}
                          onChange={(v) => set(i, v)}
                        />
                      </span>
                    )}
                    <Help row={row} />
                  </div>
                );
              }

              if (type === 'slider') {
                // ★ How far the paper runs along the track: a native track has no fill of its own.
                const lo = Number(row.min ?? 0);
                const hi = Number(row.max ?? 100);
                const fill = hi > lo ? Math.min(100, Math.max(0, ((Number(values[i]) - lo) / (hi - lo)) * 100)) : 0;

                return (
                  <div className="wf-field" key={i}>
                    <FieldLabel row={row} />
                    <div className="wk-slider" style={{ '--wk-fill': `${fill}%` } as React.CSSProperties}>
                      <input
                        ref={first}
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
                  <div className="wf-field" key={i}>
                    <FieldLabel row={row} />
                    <textarea
                      ref={first}
                      className="wf-input wf-textarea"
                      dir="auto"
                      placeholder={row.placeholder || ''}
                      disabled={row.disabled}
                      required={row.required}
                      minLength={row.minLength}
                      maxLength={row.maxLength}
                      value={values[i] ?? ''}
                      onChange={(e) => set(i, e.target.value)}
                    />
                    <Help row={row} />
                  </div>
                );
              }

              if (type === 'date') {
                // ★ Day, month by name, year -- see components/DateFields for why not the native
                //   box. It hands back the native box's own "YYYY-MM-DD" (or "" until complete).
                return (
                  <div className="wf-field" key={i}>
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
                    <Help row={row} />
                  </div>
                );
              }

              if (type === 'color') {
                // ★ The palette's eight tones, not the machine's full-spectrum picker (see
                //   components/PaletteField). The row keeps its default until a tone is picked.
                return (
                  <div className="wf-field" key={i}>
                    <FieldLabel row={row} />
                    <PaletteField
                      value={values[i]}
                      rtl={rtl}
                      label={row.label}
                      disabled={row.disabled}
                      firstRef={first}
                      onChange={(v) => set(i, v)}
                    />
                    <Help row={row} />
                  </div>
                );
              }

              if (type === 'number') {
                /* the kit's stepper: minus, the value, plus - always left to right like the figures in it */
                return (
                  <div className="wf-field" key={i}>
                    <FieldLabel row={row} />
                    <div className="wf-stepper wk-num" dir="ltr">
                      <button type="button" className="wf-stepper-arrow" tabIndex={-1} aria-label="-" disabled={row.disabled} onClick={() => spin(i, row, -1)}>
                        <span className="wk-pm">−</span>
                      </button>
                      <input
                        ref={first}
                        className="wk-num-input"
                        type="number"
                        placeholder={row.placeholder || ''}
                        disabled={row.disabled}
                        required={row.required}
                        min={row.min}
                        max={row.max}
                        step={row.step}
                        value={values[i] ?? ''}
                        onChange={(e) => set(i, e.target.value)}
                      />
                      <button type="button" className="wf-stepper-arrow" tabIndex={-1} aria-label="+" disabled={row.disabled} onClick={() => spin(i, row, 1)}>
                        <span className="wk-pm">+</span>
                      </button>
                    </div>
                    <Help row={row} />
                  </div>
                );
              }

              const htmlType = type === 'time' ? 'time' : row.password ? 'password' : 'text';

              return (
                <div className="wf-field" key={i}>
                  <FieldLabel row={row} />
                  <input
                    ref={first}
                    className={cls('wf-input', (type === 'time' || row.allow) && 'is-num')}
                    type={htmlType}
                    placeholder={row.placeholder || ''}
                    disabled={row.disabled}
                    required={row.required}
                    minLength={row.minLength}
                    maxLength={row.maxLength}
                    value={values[i] ?? ''}
                    dir={row.allow || type === 'time' ? 'ltr' : 'auto'}
                    spellCheck={false}
                    onChange={(e) => set(i, onlyAllowed(row.allow, e.target.value))}
                  />
                  <Help row={row} />
                </div>
              );
            })}
          </div>
        </Card>

        {/* ★ Confirm is FIRST in the DOM, which puts it at the inline start (the right in Arabic): the focus order
            is the visual order. Confirm is the red band; cancel a plain band. */}
        <Card i={1} className="wk-actions-wrap" bodyClass="wk-actbar">
          <div className="wk-acts">
            <button type="button" className="wk-btn is-main" onClick={submit}>
              <Txt s={t('confirm')} />
            </button>
            {data.options?.allowCancel !== false && (
              <button type="button" className="wk-btn" onClick={() => close(null)}>
                <Txt s={t('cancel')} />
              </button>
            )}
          </div>
          <div className="wk-hints" aria-hidden="true">
            <span className="wk-hint"><span className="wk-key">Enter</span><Txt s={t('confirm')} /></span>
            {data.options?.allowCancel !== false && <span className="wk-hint"><span className="wk-key">Esc</span><Txt s={t('cancel')} /></span>}
          </div>
        </Card>
      </div>
    </div>
  );
};

export default InputDialog;
