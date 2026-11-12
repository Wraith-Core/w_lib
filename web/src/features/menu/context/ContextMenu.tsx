import React, { useEffect, useState } from 'react';
import { useNuiEvent } from '../../../hooks/useNuiEvent';
import { fetchNui } from '../../../utils/fetchNui';
import { ContextMenuProps, Option } from '../../../typings';
import { play } from '../../../wc/sound';
import { Card, cls, Gauge, GlyphNext, HeadControl, isCriticalScheme, KitIcon, keyList, Keys, Txt, useKit, Where } from '../../../kit/ui';

/**
 * The context menu, on the board kit (4.4.0): a masthead with the title at the start and the close / back control
 * at its end, then one torn card of rows, docked at the board's edge (inline start: the right in Arabic) inside
 * the 16:9 frame.
 *
 *   the row under the mouse   the paper band (hover only lights; a click acts)
 *   an icon                   bare, no box; the icon column is drawn only when a row has one
 *   progress                  a thin paper gauge, red only when the option's colorScheme says so
 *   arrow / menu              a chevron that turns with the language
 *
 * ★ The contract is unchanged: showContext / hideContext in; closeContext, openContext {id, back} and
 *   clickContext (the numeric index or the key) out; Escape closes unless canClose is false.
 *
 * ★ 4.5.0, the notebook (the builders' column look), every part optional:
 *     subtitle         a quiet line at the top of the card (where you are, what this is for)
 *     option.where     a place line under the row ("فالنتاين · 12 م منك"); option.whereMiss draws it as missing.
 *                      Lua turns option.coords into it by itself (lib.showContext, the w_lib place words).
 *     keys             [{ key, label }] the keys row at the bottom; without it: Esc close, Backspace back (a sub menu)
 *   Backspace goes back to the parent menu (when there is one), as the head's back arrow does.
 */

/** Options arrive either as an array (index is the id) or as an object (key is the id). */
const optionEntries = (options: ContextMenuProps['options']): Array<{ id: string | number; opt: Option }> => {
  if (Array.isArray(options)) return options.map((opt, i) => ({ id: i, opt }));
  if (options && typeof options === 'object') return Object.keys(options).map((k) => ({ id: k, opt: options[k] }));
  return [];
};

type MetaEntry = { label?: string; value?: unknown; progress?: number; colorScheme?: string };

/** Metadata in whichever of the three shapes Lua sent, as label: value pairs (and a gauge where one has progress). */
const metaEntries = (metadata: Option['metadata']): MetaEntry[] => {
  if (!metadata) return [];
  if (Array.isArray(metadata)) {
    return metadata.map((m) => (typeof m === 'object' && m !== null ? (m as MetaEntry) : { label: String(m) }));
  }
  if (typeof metadata === 'object') return Object.entries(metadata).map(([label, value]) => ({ label, value }));
  return [{ label: String(metadata) }];
};

/** label: value pairs on one quiet line; an entry with progress gets its own labelled gauge line under it */
const Meta: React.FC<{ metadata: Option['metadata'] }> = ({ metadata }) => {
  const rows = metaEntries(metadata);
  if (!rows.length) return null;
  const plain = rows.filter((m) => typeof m.progress !== 'number');
  const bars = rows.filter((m) => typeof m.progress === 'number');
  return (
    <>
      {plain.length > 0 && (
        <span className="wf-row-meta">
          {plain.map((m, i) => (
            <span key={i}>
              <Txt s={m.label} />
              {m.value != null && m.value !== '' && (
                <>
                  {m.label ? ': ' : ''}
                  <b className="wf-num">{String(m.value)}</b>
                </>
              )}
            </span>
          ))}
        </span>
      )}
      {bars.map((m, i) => (
        <span className="wk-metabar" key={`g${i}`}>
          <span className="wk-metabar-label"><Txt s={m.label} /></span>
          <Gauge value={m.progress} critical={isCriticalScheme(m.colorScheme)} />
          {m.value != null && m.value !== '' && <b className="wf-num wk-metabar-value">{String(m.value)}</b>}
        </span>
      ))}
    </>
  );
};

const ContextMenu: React.FC = () => {
  const { rtl, t } = useKit();
  const [visible, setVisible] = useState(false);
  const [data, setData] = useState<ContextMenuProps | null>(null);
  const [here, setHere] = useState<string | number | null>(null);

  const close = () => {
    if (data?.canClose === false) return play('deny');
    play('close');
    setVisible(false);
    setData(null);
    fetchNui('closeContext');
  };

  const back = () => {
    play('select');
    fetchNui('openContext', { id: data?.menu, back: true });
  };

  useNuiEvent('hideContext', () => {
    setVisible(false);
    setData(null);
  });

  useNuiEvent<ContextMenuProps>('showContext', (payload) => {
    setData(payload);
    setVisible(true);
    setHere(null);
    play('open');
  });

  useEffect(() => {
    if (!visible) return;

    const onKey = (e: KeyboardEvent) => {
      if (e.code === 'Escape') close();
      if (e.code === 'Backspace' && data?.menu) back();
    };

    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible, data]);

  if (!visible || !data) return null;

  const entries = optionEntries(data.options);
  const withIcons = entries.some(({ opt }) => opt.icon || opt.image);
  const keys =
    keyList(data.keys) ??
    [
      ...(data.canClose !== false ? [{ key: 'Esc', label: t('close') }] : []),
      ...(data.menu ? [{ key: 'Backspace', label: t('back') }] : []),
    ];

  return (
    <div className={cls('wf', 'wk-ctx', rtl && 'is-rtl')}>
      {/* always on the right, in every language (as before the board kit) */}
      <div className="wk-side-scrim is-end" />
      <div className="wk-dock is-end is-ctx">
        {/* ★ `menu` names the parent: then the control is the back arrow and there is no cross --
            one control answering one question. */}
        <header className="wf-mast wf-in">
          <span className="wf-mark"><Txt s={data.title} /></span>
          <span className="wf-mast-rule" />
          {data.menu ? (
            <HeadControl back label={t('back')} onClick={back} />
          ) : data.canClose !== false ? (
            <HeadControl label={t('close')} onClick={close} />
          ) : null}
        </header>

        <Card focus i={1}>
          {data.subtitle ? <div className="wk-kick"><Txt s={data.subtitle} /></div> : null}
          <div className="wk-rows" onMouseLeave={() => setHere(null)}>
            {entries.map(({ id, opt }) => {
              const disabled = opt.disabled === true;
              const readOnly = opt.readOnly === true;
              const live = !disabled && !readOnly;

              return (
                <button
                  type="button"
                  key={`context-${id}`}
                  className={cls('wf-row', 'wk-row', live && here === id && 'is-here', disabled && 'is-off', readOnly && 'is-static')}
                  disabled={!live}
                  onMouseEnter={() => live && setHere(id)}
                  onClick={() => {
                    play('select');
                    if (opt.menu) return void fetchNui('openContext', { id: opt.menu });
                    fetchNui('clickContext', typeof id === 'number' ? id : isNaN(Number(id)) ? id : Number(id));
                  }}
                >
                  {withIcons && (
                    <span className={cls('wk-ico', !(opt.image || opt.icon) && 'is-empty')}>
                      <KitIcon icon={opt.image ?? opt.icon} />
                    </span>
                  )}

                  <span className="wf-row-main">
                    <span className="wf-row-name"><Txt s={opt.title ?? String(id)} /></span>
                    {opt.description && <span className="wk-desc"><Txt s={opt.description} /></span>}
                    <Where text={opt.where} miss={opt.whereMiss === true} />
                    <Meta metadata={opt.metadata} />
                    {typeof opt.progress === 'number' && (
                      <Gauge value={opt.progress} critical={isCriticalScheme(opt.colorScheme)} />
                    )}
                  </span>

                  {(opt.arrow || opt.menu) && (
                    <span className="wk-chev wf-flip"><GlyphNext /></span>
                  )}
                </button>
              );
            })}
          </div>
          <Keys keys={keys} foot />
        </Card>
      </div>
    </div>
  );
};

export default ContextMenu;
