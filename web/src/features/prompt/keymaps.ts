/**
 * Keys the game draws as a picture rather than as letters -- ported as-is from the Prompt
 * source, including the aliases (`return` for enter, `prior`/`next` for the page keys, `back`
 * for backspace), which are the raw Windows key names w.rawKeys reports.
 */
export interface Keymap {
  text?: string;
  image?: string;
}

const KEY = (name: string) => `./assets/images/keys/${name}.png`;

export const keymaps: Record<string, Keymap> = {
  lcontrol: { text: 'CTRL' },
  space: { image: KEY('SPACE') },
  enter: { image: KEY('ENTER') },
  return: { image: KEY('ENTER') },
  pageup: { image: KEY('PAGE_UP') },
  prior: { image: KEY('PAGE_UP') },
  pagedown: { image: KEY('PAGE_DOWN') },
  next: { image: KEY('PAGE_DOWN') },
  home: { image: KEY('HOME') },
  backspace: { image: KEY('BACKSPACE') },
  back: { image: KEY('BACKSPACE') },
  left: { image: KEY('ARROW_LEFT') },
  up: { image: KEY('ARROW_TOP') },
  right: { image: KEY('ARROW_RIGHT') },
  down: { image: KEY('ARROW_BOTTOM') },
};
