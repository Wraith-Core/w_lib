import { fetchNui } from './fetchNui';

/**
 * fetchNui, but a failure is not fatal.
 *
 * ⚠️ The raw one rejects whenever the callback cannot be reached -- always in a browser, and
 *    in game whenever the resource is mid-restart. Awaited un-caught, that rejection skips
 *    whatever follows: `finish()` would never call onDone, so the minigame would stay on
 *    screen holding NUI focus with no way out but a reconnect. A lost callback must not
 *    become a stuck player.
 */
export const postNui = async <T = unknown>(event: string, data?: unknown): Promise<T | null> => {
  try {
    return await fetchNui<T>(event, data);
  } catch {
    return null;
  }
};
