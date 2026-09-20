import { isEnvBrowser } from './misc';
import { localiseDemo } from './demoStrings';

interface DebugEvent<T = any> {
  action: string;
  data: T;
}

/**
 * Emulates dispatching an event using SendNuiMessage in the lua scripts.
 * This is used when developing in browser
 *
 * @param events - The event you want to cover
 * @param timer - How long until it should trigger (ms)
 */
export const debugData = <P>(events: DebugEvent<P>[], timer = 1000): void => {
  if (process.env.NODE_ENV === 'development' && isEnvBrowser()) {
    for (const event of events) {
      setTimeout(() => {
        window.dispatchEvent(
          new MessageEvent('message', {
            data: {
              action: event.action,
              // ★ The mocks are written in English and translated on the way out, so the
              //   drawer follows the direction switch without every file carrying two copies.
              data: localiseDemo(event.data),
            },
          })
        );
      }, timer);
    }
  }
};
