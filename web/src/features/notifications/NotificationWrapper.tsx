import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { NotificationProps } from '../../typings';
import Icon from '../../wc/Icon';
import { monoHtml } from '../../utils/palette';

/** The texture that stands for each kind when Lua does not name one. */
const TOAST_ICON: Record<string, string> = {
  inform: 'rating_star',
  success: 'tick',
  error: 'cross',
  warning: 'lock',
};

interface Toast extends NotificationProps {
  key: number;
  leaving?: boolean;
}

const posClass = (position?: string) => (position || 'top-right').replace(/[^a-z-]/g, '');

const Notifications: React.FC = () => {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const nextKey = useRef(0);
  const timers = useRef<Array<ReturnType<typeof setTimeout>>>([]);

  const dismiss = useCallback((key: number) => {
    // ★ Marked leaving first, removed after: the exit animation needs the node to still be
    //   there to play on. Removing it outright makes toasts vanish rather than fade.
    setToasts((list) => list.map((t) => (t.key === key ? { ...t, leaving: true } : t)));
    timers.current.push(setTimeout(() => setToasts((list) => list.filter((t) => t.key !== key)), 200));
  }, []);

  useNuiEvent<NotificationProps>('notify', (data) => {
    const key = nextKey.current++;
    setToasts((list) => [...list, { ...data, key }]);
    timers.current.push(setTimeout(() => dismiss(key), Number(data.duration) || 3000));
  });

  useEffect(() => () => timers.current.forEach(clearTimeout), []);

  if (!toasts.length) return null;

  /* Grouped by corner, so several positions can be on screen at once. */
  const groups = toasts.reduce<Record<string, Toast[]>>((acc, toast) => {
    const pos = posClass(toast.position);
    (acc[pos] ||= []).push(toast);
    return acc;
  }, {});

  return (
    <div className="lb-layer" data-layer="notify">
      {Object.entries(groups).map(([pos, list]) => (
        <div key={pos} className={`lb-notifications pos-${pos}`}>
          {list.map((toast) => {
            const icon = typeof toast.icon === 'string' ? toast.icon : Array.isArray(toast.icon) ? toast.icon[1] : undefined;
            const type = toast.type || 'inform';

            return (
              /* ⚠️ No <Frame> and no plate: the toast is text and icon over the world, and its
                    border art was the last thing that still drew a box around them. */
              <div key={toast.key} className={`lb-toast is-${type}${toast.leaving ? ' is-out' : ''}`}>
                <span className="lb-toast-text">
                  {toast.title && <span className="lb-toast-title">{toast.title}</span>}
                  {toast.description && (
                    <span
                      className="lb-toast-desc"
                      dangerouslySetInnerHTML={{ __html: monoHtml(String(toast.description).replace(/\n/g, '<br>')) }}
                    />
                  )}
                </span>

                <span className="lb-toast-icon">
                  <Icon icon={icon} fallback={TOAST_ICON[type] || 'rating_star'} />
                </span>
              </div>
            );
          })}
        </div>
      ))}
    </div>
  );
};

export default Notifications;
