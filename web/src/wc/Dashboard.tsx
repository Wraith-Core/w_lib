import React from 'react';
import Frame from './Frame';
import Glyph from './Glyph';
import Icon from './Icon';

/**
 * ============================================================================
 * The dashboard shell -- w_crafting's own layout, as reusable parts.
 *
 * ★ THE POINT: a script should not have to build a frame. Every interface on this server is the
 *   same shape -- a titled panel, a list down one side, the selected thing down the other, and a
 *   row of actions along the bottom -- and w_crafting already draws it well. These components
 *   are that layout with the crafting taken out of it.
 *
 * ★ Written to the stylesheet, not the other way round. Every class below (wc-viewport, wc-shell,
 *   wc-header, wc-body, wc-browser, wc-vr, wc-detail, wc-actions) is ALREADY in wc-base.css --
 *   it came across with the rest of the crafting design. Nothing here adds a rule; it emits the
 *   markup those rules were written for, which is why the result is the same interface rather
 *   than something that resembles it.
 *
 * ⚠️ Layout only. It holds no state, knows nothing about NUI, and takes no opinion on what goes
 *    inside it -- features/panel drives it from Lua, and a hand-written React feature can use
 *    the same parts directly.
 * ============================================================================
 */

/** The plate everything sits on: the atmosphere wash, the 8-piece frame, and the column. */
export const Dashboard: React.FC<{
  /** Tints the shell -- wc-theme-* are declared in wc-base.css. */
  theme?: string;
  className?: string;
  children: React.ReactNode;
}> = ({ theme, className, children }) => (
  <div className="wc-viewport">
    <section className={`wc-shell${theme ? ` wc-theme-${theme}` : ''}${className ? ` ${className}` : ''}`}>
      <span className="wc-atmo" aria-hidden="true" />
      <Frame px={13} opacity={0.5} />
      {children}
    </section>
  </div>
);

/**
 * The header strip: a badge, the title and its subtitle, anything the caller wants on the far
 * side, and the way out.
 *
 * ★ `aside` is a slot rather than a fixed control. Crafting puts a level badge and an XP bar
 *   there; a shop would put the player's money, a stable the horse's name. Baking in any one of
 *   those would make every other script fight it.
 */
export const DashboardHeader: React.FC<{
  title?: string;
  subtitle?: string;
  /** A texture name, a blip, or an image url -- Icon decides how to draw it. */
  icon?: string;
  /** A picture in place of the badge glyph, for a resource with its own mark. */
  logo?: string;
  aside?: React.ReactNode;
  onClose?: () => void;
  closeLabel?: string;
}> = ({ title, subtitle, icon, logo, aside, onClose, closeLabel = 'Close' }) => (
  <>
    <header className="wc-header">
      {(icon || logo) && (
        <div className="wc-station-badge">
          {logo ? (
            /* ⚠️ A logo that fails to load is hidden rather than left as a broken-image glyph --
               the badge keeps its plate and simply shows nothing, which is tidier than a torn
               picture in the corner of every panel. */
            <img
              className="wc-logo"
              src={logo}
              alt=""
              onError={(e) => {
                e.currentTarget.style.display = 'none';
              }}
            />
          ) : (
            <Icon icon={icon} />
          )}
        </div>
      )}

      <div className="wc-titles">
        {title && <h1 className="wc-title">{title}</h1>}
        {subtitle && <span className="wc-subtitle">{subtitle}</span>}
      </div>

      {aside && <div className="wc-level-block">{aside}</div>}

      {onClose && (
        <button
          type="button"
          className="wc-close"
          onClick={onClose}
          aria-label={closeLabel}
          /* ⚠️ margin-inline-start:auto lives on .wc-level-block, so without an aside the close
             button has nothing pushing it to the end of the row. */
          style={aside ? undefined : { marginInlineStart: 'auto' }}
        >
          <Glyph tex="cross" />
        </button>
      )}
    </header>

    <div className="wc-hr" />
  </>
);

/** The two columns, with the game's own ruled divider between them. */
export const DashboardBody: React.FC<{
  browser: React.ReactNode;
  children: React.ReactNode;
  /** The side column as wide as its widest row instead of the fixed share (a panel's navFit). */
  fit?: boolean;
}> = ({ browser, children, fit }) => (
  <div className="wc-body">
    <div className={`wc-browser${fit ? ' is-fit' : ''}`}>{browser}</div>
    <div className="wc-vr" />
    <div className="wc-detail">{children}</div>
  </div>
);

/** The action row, with the keyboard hints pushed to the far end. */
export const DashboardActions: React.FC<{
  hints?: Array<{ key: string; label: string }>;
  children?: React.ReactNode;
}> = ({ hints, children }) => (
  <>
    <div className="wc-hr-thin" />

    <div className="wc-actions">
      {children}

      {hints && hints.length > 0 && (
        <div className="wc-hints">
          {hints.map((hint, i) => (
            <span key={`${hint.key}-${i}`}>
              {/* ★ dir="ltr" on the key: 'Esc', '↑↓' and 'Enter' are the labels printed on the
                  player's keyboard, and a keyboard does not flip with the interface. */}
              <span className="wc-key" dir="ltr">
                {hint.key}
              </span>
              {hint.label}
            </span>
          ))}
        </div>
      )}
    </div>
  </>
);

/** The search field above a browser list. */
export const DashboardSearch: React.FC<{
  value: string;
  placeholder?: string;
  onChange: (value: string) => void;
}> = ({ value, placeholder, onChange }) => (
  <div className="wc-search">
    <Glyph tex="menu_bar" />
    <input value={value} placeholder={placeholder} onChange={(e) => onChange(e.target.value)} />
  </div>
);

export { Frame, Glyph, Icon };
