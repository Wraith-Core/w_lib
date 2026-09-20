import { MutableRefObject, useEffect, useRef } from 'react';
import { noop } from '../utils/misc';

/**
 * The same hook as useNuiEvent, keyed on `type` instead of `action`.
 *
 * ★ Why a second hook rather than one that accepts either: the two are separate contracts that
 *   happen to share a window. ox_lib's modules send `{ action, data }`; the prompt module sends
 *   `{ type, data }` and has done since before it was merged in here. Both now arrive at this
 *   one frame, and they do not collide because they are keyed on different fields.
 *
 * ⚠️ So do not "tidy" this into useNuiEvent by making it read `action ?? type`. A message
 *    carrying both -- and Lua is free to send one -- would then fire two unrelated handlers.
 */
export const useNuiType = <T = any>(type: string, handler: (data: T) => void) => {
  const savedHandler: MutableRefObject<(data: T) => void> = useRef(noop);

  useEffect(() => {
    savedHandler.current = handler;
  }, [handler]);

  useEffect(() => {
    const listener = (event: MessageEvent<{ type?: string; data: T }>) => {
      if (event.data?.type === type) savedHandler.current(event.data.data);
    };

    window.addEventListener('message', listener);
    return () => window.removeEventListener('message', listener);
  }, [type]);
};
