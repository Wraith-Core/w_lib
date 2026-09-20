import React, { useCallback, useState } from 'react';
import { useNuiType } from '../../hooks/useNuiType';
import Lockpick from './Lockpick';
import Qte from './Qte';
import './minigame.css';
import { MinigameName, MinigameShowData } from './shared';

interface Active {
  game: MinigameName;
  config: Record<string, unknown>;
}

/**
 * The minigame gate, ported from the Minigame source's Bridge + Pinia stores.
 *
 * ★ Three stores became one piece of state. Upstream kept `minigames` (which game is up) and a
 *   `lockpick` and a `qte` store (each one's config) separately, then had to remember to reset
 *   all three together on hide -- a rule enforced by hand in the bridge. Here the config lives
 *   with the game it belongs to, so closing is one assignment and cannot half-happen.
 *
 * ⚠️ The key is the game name, so re-showing the same game with a fresh config remounts it
 *    rather than feeding new numbers to a round already in flight.
 */
const Minigame: React.FC = () => {
  const [active, setActive] = useState<Active | null>(null);

  useNuiType<MinigameShowData>('w_minigame:show', (data) => {
    if (data?.game === 'lockpick' || data?.game === 'qte') {
      setActive({ game: data.game, config: data.config ?? {} });
    }
  });

  useNuiType<void>('w_minigame:hide', () => setActive(null));

  const onDone = useCallback(() => setActive(null), []);

  if (!active) return null;

  return active.game === 'lockpick' ? (
    <Lockpick key="lockpick" config={active.config} onDone={onDone} />
  ) : (
    <Qte key="qte" config={active.config} onDone={onDone} />
  );
};

export default Minigame;
