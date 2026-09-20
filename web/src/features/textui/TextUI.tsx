import React, { useState } from 'react';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { TextUiProps } from '../../typings';
import Frame from '../../wc/Frame';
import Icon from '../../wc/Icon';

/** Only a-z and dashes reach the class name -- the position comes from Lua and lands in markup. */
const posClass = (position?: string) => (position || 'right-center').replace(/[^a-z-]/g, '');

const TextUI: React.FC = () => {
  const [data, setData] = useState<TextUiProps | null>(null);

  useNuiEvent('textUiHide', () => setData(null));
  useNuiEvent<TextUiProps>('textUi', (payload) => setData(payload));

  if (!data) return null;

  const icon = typeof data.icon === 'string' ? data.icon : Array.isArray(data.icon) ? data.icon[1] : undefined;

  return (
    <div className="lb-layer" data-layer="textui">
      <div className={`lb-textui lb-pos-${posClass(data.position)}`}>
        <Frame px={9} opacity={0.45} />

        {icon && (
          <span className="lb-textui-icon">
            <Icon icon={icon} />
          </span>
        )}

        <span dangerouslySetInnerHTML={{ __html: String(data.text ?? '').replace(/\n/g, '<br>') }} />
      </div>
    </div>
  );
};

export default TextUI;
