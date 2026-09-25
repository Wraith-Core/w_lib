import React from 'react';
import KeyboardKey from './KeyboardKey';
import PriceDisplay from './PriceDisplay';
import { monoHtml } from '../../utils/palette';
import { PromptRow as Row } from './types';

interface Props {
  prompt: Row;
  isLeft: boolean;
  pressedKeys: Record<string, boolean>;
  /** Drives the same pressed state the game's keyDown/keyUp drive. */
  onPress: (keys: string[], down: boolean) => void;
}

const PromptRow: React.FC<Props> = ({ prompt, isLeft, pressedKeys, onPress }) => {
  if (!prompt.visible) return null;

  if (prompt.type === 'separator') {
    return (
      <img
        className={`promptSeparator${isLeft ? ' isLeft' : ''}`}
        src="./assets/images/ilo_title_line.webp"
        alt=""
      />
    );
  }

  const keys = prompt.keyboardKeys ?? [];
  const pressable = !prompt.disabled && keys.length > 0;

  /**
   * ★ The mouse drives the very same pressed state the game's keyDown/keyUp drive -- it does not
   *   post keyCompleted itself. So a hold behaves identically whichever way it is started: the
   *   ring fills, and letting go early unwinds it. One path, one behaviour.
   *
   * ⚠️ And releasing on leaving the row, not only on mouseup: a button released off the element
   *    never sends mouseup to it, and the key would stay held for as long as the prompt lived.
   */
  const press = (down: boolean) => {
    if (!pressable) return;
    onPress(keys, down);
  };

  return (
    <div
      className={`prompt${isLeft ? ' isLeft' : ''}${prompt.disabled ? ' disabled' : ''}${pressable ? ' pressable' : ''}`}
      onMouseDown={() => press(true)}
      onMouseUp={() => press(false)}
      onMouseLeave={() => press(false)}
    >
      {/* ⚠️ The label is HTML on purpose: Lua passes markup through it -- inline item icons in
          w_crafting, coloured words elsewhere -- so escaping it would print the tags. It comes
          from the server's own scripts, never from a player. */}
      <div className="label crock">
        <span dangerouslySetInnerHTML={{ __html: monoHtml(prompt.label ?? '') }} />
      </div>

      <PriceDisplay price={prompt.price} right />

      <div className="keyboardKeys">
        {keys.map((key, index) => (
          <KeyboardKey
            key={`${key}-${index}`}
            kkey={key}
            holdTime={prompt.holdTime}
            disabled={prompt.disabled}
            pressed={Boolean(pressedKeys[key])}
          />
        ))}
      </div>
    </div>
  );
};

export default PromptRow;
