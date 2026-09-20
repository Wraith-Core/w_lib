import { isEnvBrowser } from './misc';
import { localiseDemo } from './demoStrings';

interface DebugTypeEvent<T = any> {
  type: string;
  data?: T;
}

/**
 * The `type`-keyed twin of debugData.
 *
 * ⚠️ debugData dispatches `{ action, data }`, which is ox_lib's contract. The prompt and the
 *    minigames are on `{ type, data }` -- see hooks/useNuiType -- so they never hear anything
 *    debugData sends. Testing them in the browser needs this second emitter, not a change to
 *    the first: widening debugData to emit both keys would fire two unrelated features per call.
 */
export const debugType = <P>(events: DebugTypeEvent<P>[], timer = 0): void => {
  if (process.env.NODE_ENV === 'development' && isEnvBrowser()) {
    for (const event of events) {
      setTimeout(() => {
        window.dispatchEvent(
          new MessageEvent('message', {
            data: { type: event.type, data: localiseDemo(event.data) },
          })
        );
      }, timer);
    }
  }
};
