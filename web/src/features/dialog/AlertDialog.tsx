import React, { useEffect, useState } from 'react';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { fetchNui } from '../../utils/fetchNui';
import { AlertProps } from '../../typings';
import { play } from '../../wc/sound';
import { cls, Txt, useKit } from '../../kit/ui';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import MarkdownComponents from '../../config/MarkdownComponents';

/** lg/xl widen the note, xs/sm narrow it; anything else keeps the default. */
const sizeClass = (size?: string) => (size === 'lg' || size === 'xl' ? 'is-wide' : size === 'xs' || size === 'sm' ? 'is-sm' : undefined);

/**
 * The alert, on the board kit (4.4.0): the kit's paper note -- light paper, ink lettering, a torn edge, and the
 * answers as words. ONE frame: the inner double frame of the old dialog is gone.
 *
 * ★ The answer the keys and the mouse would take is underlined in red (the kit's .wf-choice.is-here): confirm by
 *   default (Enter), the other one while the mouse is on it. The contract is unchanged: sendAlert /
 *   closeAlertDialog in, closeAlert 'confirm' | 'cancel' out, Enter confirms, Escape cancels.
 */
const AlertDialog: React.FC = () => {
  const { rtl, t } = useKit();
  const [data, setData] = useState<AlertProps | null>(null);
  const [here, setHere] = useState<'confirm' | 'cancel'>('confirm');

  const answer = (value: 'confirm' | 'cancel') => {
    // ★ Confirming is a selection, cancelling is a close -- the two cues the bench uses.
    play(value === 'confirm' ? 'select' : 'close');
    setData(null);
    fetchNui('closeAlert', value);
  };

  useNuiEvent('closeAlertDialog', () => setData(null));

  useNuiEvent<AlertProps>('sendAlert', (payload) => {
    setData(payload);
    setHere('confirm');
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

  const cancelLabel = data.labels?.cancel || (data.cancel ? t('cancel') : null);
  const confirmLabel = data.labels?.confirm || t('confirm');

  return (
    <div className={cls('wf-note', 'is-alone', 'wk-alert', rtl && 'is-rtl')} role="alertdialog" aria-modal="true">
      <div className={cls('wf-note-plate', sizeClass(data.size))}>
        {data.header && <div className="wf-note-q"><Txt s={data.header} /></div>}

        {/* ★ Markdown is the alert's documented contract. react-markdown escapes HTML by default (the reason this
            is not dangerouslySetInnerHTML); remark-gfm adds tables and strikethrough. */}
        <div className="wk-md" dir="auto">
          <ReactMarkdown components={MarkdownComponents} remarkPlugins={[remarkGfm]}>
            {String(data.content ?? '')}
          </ReactMarkdown>
        </div>

        {/* ★ Confirm is FIRST in the DOM: the inline start, the right in Arabic. */}
        <div className="wf-note-row" onMouseLeave={() => setHere('confirm')}>
          <button
            type="button"
            className={cls('wf-choice', here === 'confirm' && 'is-here')}
            onMouseEnter={() => setHere('confirm')}
            onClick={() => answer('confirm')}
          >
            <Txt s={confirmLabel} />
          </button>

          {cancelLabel && (
            <button
              type="button"
              className={cls('wf-choice', here === 'cancel' && 'is-here')}
              onMouseEnter={() => setHere('cancel')}
              onClick={() => answer('cancel')}
            >
              <Txt s={cancelLabel} />
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

export default AlertDialog;
