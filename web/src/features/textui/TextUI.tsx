import React, { useState } from 'react';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { TextUiProps } from '../../typings';
import Icon from '../../wc/Icon';
import { monoHtml } from '../../utils/palette';

/** Only a-z and dashes reach the class name -- the position comes from Lua and lands in markup. */
const posClass = (position?: string) => (position || 'right-center').replace(/[^a-z-]/g, '');

/**
 * ★ "[E] - Open" names a key, so it is drawn as one: the theme's key cap (lib-ui.css .lb-key,
 *   the loading screen's kbd). Only a short run of letters, digits or a key word in square
 *   brackets qualifies, and never one followed by "(" -- that is a markdown link, not a key.
 */
const keyCaps = (html: string) =>
  html.replace(/\[([A-Za-z0-9+\-_ ]{1,12})\](?!\()/g, (_, key: string) => `<kbd class="lb-key">${key.trim()}</kbd>`);

const TextUI: React.FC = () => {
  const [data, setData] = useState<TextUiProps | null>(null);

  useNuiEvent('textUiHide', () => setData(null));
  useNuiEvent<TextUiProps>('textUi', (payload) => setData(payload));

  if (!data) return null;

  const icon = typeof data.icon === 'string' ? data.icon : Array.isArray(data.icon) ? data.icon[1] : undefined;

  return (
    <div className="lb-layer" data-layer="textui">
      <div className={`lb-textui lb-pos-${posClass(data.position)}`}>

        {icon && (
          <span className="lb-textui-icon">
            <Icon icon={icon} />
          </span>
        )}

        <span dangerouslySetInnerHTML={{ __html: monoHtml(keyCaps(String(data.text ?? '')).replace(/\n/g, '<br>')) }} />
      </div>
    </div>
  );
};

export default TextUI;
