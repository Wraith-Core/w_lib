import React, { useEffect, useState } from 'react';
import { useNuiEvent } from '../../../hooks/useNuiEvent';
import { fetchNui } from '../../../utils/fetchNui';
import { useLocales } from '../../../providers/LocaleProvider';
import { ContextMenuProps, Option } from '../../../typings';
import { Bar, Head, Layer, Panel, play } from '../../../wc/Panel';
import Icon from '../../../wc/Icon';

/**
 * The context menu, rebuilt on the markup the live build draws (lb-panel / lb-head / lb-item),
 * so lib-ui.css styles it without a single rule being adapted.
 *
 * ⚠️ The Mantine version this replaces produced its own class names and its own layout, which
 *    is why it arrived looking like a web page: the stylesheet had nothing to attach to.
 */

/** Options arrive either as an array (index is the id) or as an object (key is the id). */
const optionEntries = (options: ContextMenuProps['options']): Array<{ id: string | number; opt: Option }> => {
  if (Array.isArray(options)) return options.map((opt, i) => ({ id: i, opt }));
  if (options && typeof options === 'object') return Object.keys(options).map((k) => ({ id: k, opt: options[k] }));
  return [];
};

/** Metadata renders as label: value pairs, in whichever of the three shapes Lua sent. */
const MetaRows: React.FC<{ metadata: Option['metadata'] }> = ({ metadata }) => {
  if (!metadata) return null;

  const rows: React.ReactNode[] = [];

  if (Array.isArray(metadata)) {
    metadata.forEach((m, i) =>
      rows.push(
        typeof m === 'object' && m !== null ? (
          <span key={i}>
            {m.label}
            {m.value != null && (
              <>
                : <b dir="ltr">{m.value}</b>
              </>
            )}
          </span>
        ) : (
          <span key={i}>{String(m)}</span>
        )
      )
    );
  } else if (typeof metadata === 'object') {
    Object.entries(metadata).forEach(([k, v], i) =>
      rows.push(
        <span key={i}>
          {k}: <b dir="ltr">{String(v)}</b>
        </span>
      )
    );
  } else {
    rows.push(<span key={0}>{String(metadata)}</span>);
  }

  return rows.length ? <span className="lb-meta">{rows}</span> : null;
};

/**
 * ★ The icon slot is drawn for every row, filled or not. The crafting list keeps one visual
 *   rhythm down the column; letting rows without an icon close up would break the alignment
 *   the eye follows. An empty slot shows the faint menu_bar rule instead.
 */
const ItemIcon: React.FC<{ icon?: Option['icon']; image?: string }> = ({ icon, image }) => (
  <span className={`lb-item-icon${image || icon ? '' : ' is-empty'}`}>
    <Icon icon={image ?? icon} fallback="menu_bar" />
  </span>
);

const ContextMenu: React.FC = () => {
  const { locale } = useLocales();
  const [visible, setVisible] = useState(false);
  const [data, setData] = useState<ContextMenuProps | null>(null);

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
    play('open');
  });

  useEffect(() => {
    if (!visible) return;

    const onKey = (e: KeyboardEvent) => {
      if (e.code === 'Escape') close();
    };

    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible, data]);

  if (!visible || !data) return null;

  return (
    <Layer name="context">
      {/* ★ `menu` names the parent. When there is one the tab carries the back arrow and the
          cross does not appear at all -- one control answering one question. */}
      <Panel
        className="lb-context"
        onBack={data.menu ? back : undefined}
        onClose={data.canClose !== false ? close : undefined}
        backLabel={locale.ui.back || 'Back'}
        closeLabel={locale.ui.close || 'Close'}
      >
        <Head title={data.title} />

        <div className="lb-context-list">
          {optionEntries(data.options).map(({ id, opt }) => {
            const disabled = opt.disabled === true;
            const readOnly = (opt as { readOnly?: boolean }).readOnly === true;

            return (
              <button
                type="button"
                key={`context-${id}`}
                className={`lb-item${disabled ? ' is-disabled' : ''}`}
                disabled={disabled || readOnly}
                onClick={() => {
                  play('select');
                  if (opt.menu) return void fetchNui('openContext', { id: opt.menu });
                  fetchNui('clickContext', typeof id === 'number' ? id : isNaN(Number(id)) ? id : Number(id));
                }}
              >
                <ItemIcon icon={opt.icon} image={opt.image} />

                <span style={{ minWidth: 0 }}>
                  <span className="lb-item-title">{opt.title ?? id}</span>
                  {opt.description && <span className="lb-item-desc">{opt.description}</span>}
                  {typeof opt.progress === 'number' && <Bar ratio={opt.progress / 100} bright />}
                  <MetaRows metadata={opt.metadata} />
                </span>

                {opt.arrow || opt.menu ? <span className="lb-item-arrow" /> : <span />}
              </button>
            );
          })}
        </div>
      </Panel>
    </Layer>
  );
};

export default ContextMenu;
