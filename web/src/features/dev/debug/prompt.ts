import { debugType } from '../../../utils/debugType';

/**
 * In the game the press comes from Lua: the module watches the raw keys and sends keyDown /
 * keyUp, and the UI only draws. In the browser nothing sends them, so the keys would render and
 * never light up.
 *
 * ★ So the drawer wires the real keyboard to those two messages while a demo group is up --
 *   which exercises the actual path (message in, fill animates, keyCompleted out) rather than a
 *   shortcut that would prove nothing about the wiring.
 */
let bridge: ((event: KeyboardEvent) => void) | null = null;
let bridgeUp: ((event: KeyboardEvent) => void) | null = null;

const detachBridge = () => {
  if (bridge) window.removeEventListener('keydown', bridge);
  if (bridgeUp) window.removeEventListener('keyup', bridgeUp);
  bridge = null;
  bridgeUp = null;
};

const attachBridge = (keys: string[]) => {
  detachBridge();

  const wanted = new Set(keys.map((k) => k.toLowerCase()));

  bridge = (event: KeyboardEvent) => {
    const key = event.key.toLowerCase();
    if (!wanted.has(key) || event.repeat) return;
    event.preventDefault();
    debugType([{ type: 'keyDown', data: { key } }]);
  };

  bridgeUp = (event: KeyboardEvent) => {
    const key = event.key.toLowerCase();
    if (!wanted.has(key)) return;
    event.preventDefault();
    debugType([{ type: 'keyUp', data: { key } }]);
  };

  window.addEventListener('keydown', bridge);
  window.addEventListener('keyup', bridgeUp);
};

/** A two-page group: a tap, a hold, a separator, a disabled row, and a priced row. */
export const debugPrompt = () => {
  const keys = ['e', 'g', 'f', 'h', 'space'];

  debugType([
    {
      type: 'setGroup',
      data: {
        title: 'Wraith Prompt',
        position: 'bottom-right',
        nextPageKey: 'h',
        currentPage: 1,
        prompts: [
          [
            { visible: true, label: 'Talk', keyboardKeys: ['e'], holdTime: false },
            { visible: true, label: 'Hold to pick up', keyboardKeys: ['g'], holdTime: 1200 },
            { type: 'separator', visible: true },
            { visible: true, label: 'Locked', keyboardKeys: ['f'], disabled: true },
            { visible: true, label: 'Buy', keyboardKeys: ['space'], price: { money: 12.5 } },
          ],
          [
            { visible: true, label: 'Second page', keyboardKeys: ['e'] },
            { visible: true, label: 'Costs items', keyboardKeys: ['g'], price: [{ item: 'weed_raw', label: 'Weed', quantity: 3 }, { gold: 2 }] },
          ],
        ],
      },
    },
  ]);

  attachBridge(keys);
};

export const debugPromptHide = () => {
  detachBridge();
  debugType([{ type: 'setGroup', data: { title: false, position: 'bottom-right', prompts: [] } }]);
};
