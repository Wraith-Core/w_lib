import React from 'react';
import Frame from './Frame';
import Glyph from './Glyph';
import { play } from './sound';

/**
 * The panel furniture the live build draws, as React.
 *
 * ★ These emit exactly the markup lib-ui.css was written for -- `lb-head`, `lb-title`,
 *   `wc-close`, `lb-back-arrow`. The stylesheet is not adapted to the components; the
 *   components are written to the stylesheet, which is what makes the result the old interface
 *   rather than a lookalike.
 */

/**
 * The RDR header strip: the title, always centred.
 *
 * ⚠️ The two empty cells are kept on purpose. The header is a three-column grid and the title
 *    sits in the middle one; removing them would let it drift off centre now that both the
 *    close and the back control live on the tab outside the panel.
 */
export const Head: React.FC<{ title?: string }> = ({ title }) => (
  <header className="lb-head">
    <span className="lb-head-start" />
    <h1 className="lb-title">{title}</h1>
    <span className="lb-head-end" />
  </header>
);

/** A filled bar, masked with the game's own weapon-stats art. */
export const Bar: React.FC<{ ratio: number; bright?: boolean }> = ({ ratio, bright }) => (
  <span className="wc-bar">
    <span className="wc-bar-mask">
      <span
        className={`wc-bar-fill${bright ? ' is-bright' : ''}`}
        style={{ width: `${Math.max(0, Math.min(1, ratio || 0)) * 100}%` }}
      />
    </span>
  </span>
);

/**
 * The plate every interface sits on: gradient, shadow, and the 8-piece frame.
 *
 * ★ The close button is a TAB on the outside edge, not a control in the header. That is where
 *   RDR puts it -- flush against the panel, hanging off its top-left corner -- and it buys back
 *   the header cell the title was competing with.
 */
export const Panel: React.FC<{
  className?: string;
  onClose?: () => void;
  onBack?: () => void;
  closeLabel?: string;
  backLabel?: string;
  children: React.ReactNode;
}> = ({ className, onClose, onBack, closeLabel = 'Close', backLabel = 'Back', children }) => {
  /* ★ One control, not two. When the menu has a parent the tab IS the way back and wears a
     back arrow; only a root menu shows the cross. A panel that offered a cross above it and a
     separate arrow inside the header asked the player to read two controls to answer one
     question -- and the cross, on a submenu, threw away the trail rather than stepping up it.

     Escape still closes outright from any depth, so nothing is unreachable. */
  const action = onBack ?? onClose;

  return (
    <section className={`lb-panel${className ? ` ${className}` : ''}`}>
      <Frame px={11} opacity={0.5} />

      {action && (
        <button
          type="button"
          className={`lb-close-tab${onBack ? ' is-back' : ''}`}
          aria-label={onBack ? backLabel : closeLabel}
          onClick={action}
        >
          {onBack ? <span className="lb-back-arrow" aria-hidden="true" /> : <Glyph tex="cross" />}
        </button>
      )}

      {children}
    </section>
  );
};

/** A layer, so the panels stack in the order the old build gave them. */
export const Layer: React.FC<{ name: string; children: React.ReactNode }> = ({ name, children }) => (
  <div className="lb-layer" data-layer={name}>
    {children}
  </div>
);

export { Frame, Glyph, play };
