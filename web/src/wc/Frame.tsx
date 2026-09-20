import React, { CSSProperties } from 'react';

const PIECES = ['t', 'b', 'l', 'r', 'tl', 'tr', 'bl', 'br'] as const;

/**
 * The game's own crafting-highlight border: eight pieces of texture art hugging the edges of
 * the nearest positioned ancestor.
 *
 * ★ Eight pieces, not a CSS border. RDR's frame is drawn art with worn corners and a repeating
 *   run along each edge, so the corners are fixed-size sprites and the four sides tile between
 *   them. A `border: 1px solid` gets the geometry right and the game wrong.
 *
 * ⚠️ Decoration only: it never takes pointer events, and it is symmetric so RTL needs no mirror.
 *   The parent must be positioned, or the frame will find the wrong box to hug.
 */
export default function Frame({
  color,
  px,
  opacity,
}: {
  color?: string;
  px?: number;
  opacity?: number;
}) {
  const style = {
    ...(color ? { '--fr-c': color } : null),
    ...(px ? { '--fr-px': `${px}px` } : null),
    ...(opacity !== undefined ? { '--fr-o': opacity } : null),
  } as CSSProperties;

  return (
    <span className="wc-frame" style={style} aria-hidden="true">
      {PIECES.map((p) => (
        <span key={p} className={`wc-fr-${p}`} />
      ))}
    </span>
  );
}
