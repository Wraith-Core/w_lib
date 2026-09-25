import React, { useEffect, useState } from 'react';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { fetchNui } from '../../utils/fetchNui';
import { AlertProps } from '../../typings';
import { Glyph, Head, Layer, Panel, play } from '../../wc/Panel';
import { useLocales } from '../../providers/LocaleProvider';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import MarkdownComponents from '../../config/MarkdownComponents';

/** lg/xl widen the plate, xs/sm narrow it; anything else keeps the default. */
const sizeClass = (size?: string) =>
  size === 'lg' || size === 'xl' ? ' is-lg' : size === 'xs' || size === 'sm' ? ' is-sm' : '';

const AlertDialog: React.FC = () => {
  const { locale } = useLocales();
  const [data, setData] = useState<AlertProps | null>(null);

  const answer = (value: 'confirm' | 'cancel') => {
    // ★ Confirming is a selection, cancelling is a close -- the two cues the bench uses.
    play(value === 'confirm' ? 'select' : 'close');
    setData(null);
    fetchNui('closeAlert', value);
  };

  useNuiEvent('closeAlertDialog', () => setData(null));

  useNuiEvent<AlertProps>('sendAlert', (payload) => {
    setData(payload);
    play('open');
  });

  useEffect(() => {
    if (!data) return;

    const onKey = (e: KeyboardEvent) => {
      if (e.code === 'Escape') answer('cancel');
      if (e.code === 'Enter') answer('confirm');
    };

    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [data]);

  if (!data) return null;

  const cancelLabel = data.labels?.cancel || (data.cancel ? locale.ui.cancel : null);
  const confirmLabel = data.labels?.confirm || locale.ui.confirm;

  return (
    <Layer name="dialog">
      <div className="lb-scrim" />

      {/* ★ The alert is the pause menu's paper note (lib-ui.css, "the alert"): light paper, ink
          lettering, a torn edge, the answers as words with the one the Enter key takes underlined
          in red. The wrap carries the drop shadow, because the note's torn mask clips its own. */}
      <div className="lb-note-wrap">
        <Panel className={`lb-dialog is-note${sizeClass(data.size)}`}>
          <Head title={data.header} />

          {/* ★ Markdown, which is the alert's documented contract -- the demo's own body says
              "**Markdown** works here too" and it was printing the asterisks. This was lost in the
              port: the content had been reduced to raw HTML with newlines swapped for <br>, so
              bold, links and lists all came through as literal punctuation.

              ⚠️ react-markdown escapes HTML by default, which is the safer default and the
                 reason this is not dangerouslySetInnerHTML. remark-gfm adds the table and
                 strikethrough syntax the upstream library documents. */}
          <div className="lb-dialog-body">
            <ReactMarkdown components={MarkdownComponents} remarkPlugins={[remarkGfm]}>
              {String(data.content ?? '')}
            </ReactMarkdown>
          </div>

          <div className="wc-hr-thin" />

          {/* ★ Confirm is FIRST in the DOM, which puts it at the inline start: on the right in
              Arabic and on the left in English. Reordering here rather than with CSS `order`
              keeps the focus order the same as the visual order, which is what a keyboard and a
              screen reader both follow. */}
          <div className="lb-actions">
            <button type="button" className="lb-btn" onClick={() => answer('confirm')}>
              <span>
                <Glyph tex="tick" />
                {confirmLabel}
              </span>
            </button>

            {cancelLabel && (
              <button type="button" className="lb-btn-ghost" onClick={() => answer('cancel')}>
                <span>
                  <Glyph tex="cross" />
                  {cancelLabel}
                </span>
              </button>
            )}
          </div>
        </Panel>
      </div>
    </Layer>
  );
};

export default AlertDialog;
