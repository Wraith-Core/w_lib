import React, { useEffect, useRef, useState } from 'react';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import Icon from '../../wc/Icon';
import './voice.css';

/**
 * ============================================================================
 * Voice interaction -- the interface only.
 *
 * ★ WHAT THIS IS: the three things a speak-to-play system has to put on screen -- what you may
 *   say, that it is listening, and what it heard. The recognition itself is not here and should
 *   not be: matching speech is the script's job, drawing the conversation is the library's.
 *
 * ★ Three pieces, deliberately independent. A script can use the bubbles without subtitles, or
 *   subtitles without bubbles, and nothing here assumes the other two are present.
 *
 *     voiceHint      a balloon above an NPC listing what it will answer to
 *     voicePanel     the same commands as a panel on screen, grouped by layer
 *     voiceListening the microphone state, with a live spectrum
 *     voiceSubtitle  one line of what was heard, coloured by whether it landed
 *
 * ★ The bubbles and the panel are BOTH provided because they answer different questions. A
 *   balloon says "this person will answer to these"; the panel says "here is everything you may
 *   say right now", which is what a player who has just walked into a shop actually needs. A
 *   layer system that swaps the whole command set on entering a building has nowhere else to
 *   show what just changed.
 *
 * ⚠️ The bubbles are positioned from coordinates LUA has already projected -- exactly as
 *    drawText3D in wnotify does. No world maths happens in this frame, and it must not: the
 *    projection needs the camera, and the camera lives in the game.
 * ============================================================================
 */

/** White while listening, green when the words matched, red when they did not. */
type Heard = 'listening' | 'matched' | 'unknown';

interface Subtitle {
  text?: string;
  state?: Heard;
  /** Who is speaking -- shown small above the line, for an NPC's reply. */
  speaker?: string;
}

interface Listening {
  active?: boolean;
  /** 0-100. A single loudness reading -- the simple case. */
  level?: number;
  /**
   * A spectrum: one value per band, 0-100.
   *
   * ★ Takes precedence over `level`. A script with an analyser node can hand its bins straight
   *   over and get a real waveform; one without can send a single number and still get a meter.
   *   Neither has to know what the other does.
   */
  levels?: number[];
  label?: string;
}

/** What the player may say right now -- the 2D half of the hints overlay. */
interface CommandPanel {
  title?: string;
  /** Where it sits when it is NOT anchored to anyone. */
  position?: string;
  groups?: Array<{ label?: string; commands: string[] }>;

  /**
   * Projected screen coordinates, when this list belongs to a particular person.
   *
   * ★ The commands are THEIRS. A teller answers to "deposit {amount}" and the barkeep does not,
   *   so the list reads properly only when it sits beside the person it applies to -- pinned to
   *   a screen corner it becomes a legend the player has to connect to whoever they are facing.
   *   Lua projects the head bone and sends the result, exactly as the balloons do.
   */
  x?: number;
  y?: number;
}

interface Hint {
  id: string;
  /** Fractions of the viewport, already projected by Lua. */
  x: number;
  y: number;
  title?: string;
  icon?: string;
  /** The phrases this NPC answers to. */
  commands?: string[];
  /**
   * What this NPC is saying RIGHT NOW.
   *
   * ★ A reply belongs over the head of whoever said it, not in a caption at the bottom of the
   *   screen with their name in front of it. When this is set the bubble shows the line and
   *   holds the prompts back -- an NPC that is talking is not simultaneously offering a menu.
   */
  says?: string;
}

/* ── the microphone ───────────────────────────────────────────────────────── */

/**
 * ★ Seven bars driven off one level, each with its own threshold, so the meter fills from the
 *   middle outwards the way a real one does rather than sweeping left to right.
 */
const BARS = [0.28, 0.52, 0.74, 0.9, 0.74, 0.52, 0.28];

const Meter: React.FC<{ level?: number; levels?: number[] }> = ({ level, levels }) => {
  // A real spectrum when the script sends one; the shaped seven-bar meter when it does not.
  const bands = levels?.length
    ? levels.map((v) => Math.min(1, Math.max(0, v / 100)))
    : BARS.map((peak) => ((level ?? 0) / 100 >= 1 - peak ? peak : peak * 0.28));

  return (
    <span className="wv-meter" aria-hidden="true">
      {bands.map((height, i) => (
        <span
          key={i}
          className={`wv-bar${height > 0.34 ? ' is-lit' : ''}`}
          style={{ height: `${Math.max(8, height * 100)}%` }}
        />
      ))}
    </span>
  );
};

/** Only letters and dashes reach the class name -- position comes from Lua. */
const posClass = (position?: string) => (position || 'bottom-left').replace(/[^a-z-]/g, '');

/**
 * ★ SLOT COLOURS ARE KEYED TO THE VARIABLE'S NAME, not to its position in the phrase.
 *
 *   `{item}` is the same green in "buy {item}" and in "do you have {item}", which is the whole
 *   point: across a column of twenty phrases the player learns the colours once. Colouring by
 *   position would make the same variable a different colour on every line and teach nothing.
 *
 * ⚠️ Six, and chosen to stay apart at a glance over a bright sky. Adding a seventh that sits
 *    between two of these would cost more than the extra name is worth.
 */
const SLOT_COLOURS = ['#7bc47f', '#d8b34a', '#c96b6b', '#a98bd1', '#6fb3c4', '#c98f5e'];

const slotColour = (name: string) => {
  let hash = 0;
  for (let i = 0; i < name.length; i += 1) hash = (hash * 31 + name.charCodeAt(i)) >>> 0;
  return SLOT_COLOURS[hash % SLOT_COLOURS.length];
};

/**
 * Split a phrase on its {variable} slots.
 *
 * ★ This is the script's own syntax, not ours -- `phrases = { "buy {item}" }` is what a voice
 *   action is registered with, so the panel reads the phrase exactly as it was written rather
 *   than asking the script to describe it a second time in some other shape.
 */
const Phrase: React.FC<{ text: string }> = ({ text }) => (
  <span className="wv-phrase">
    {text.split(/(\{[^}]+\})/g).filter(Boolean).map((part, i) => {
      const slot = part.match(/^\{([^}]+)\}$/);

      if (!slot) return <span key={i}>{part}</span>;

      return (
        <span
          key={i}
          className="wv-slot"
          dir="ltr"
          style={{ ['--wv-slot' as string]: slotColour(slot[1]) }}
        >
          {slot[1]}
        </span>
      );
    })}
  </span>
);

const Voice: React.FC = () => {
  const [listening, setListening] = useState<Listening | null>(null);
  const [subtitle, setSubtitle] = useState<Subtitle | null>(null);
  const [hints, setHints] = useState<Record<string, Hint>>({});
  const [panel, setPanel] = useState<CommandPanel | null>(null);

  const timer = useRef<ReturnType<typeof setTimeout>>();

  useNuiEvent<Listening | false>('voiceListening', (data) => setListening(data || null));

  /**
   * ⚠️ The line clears itself. A subtitle that stays until the script remembers to remove it is
   *    a subtitle still on screen three minutes after the conversation ended -- and the one
   *    thing a script writing a voice system will forget is the tidy-up. `hold = false` opts out
   *    for a line that should stay until replaced.
   */
  useNuiEvent<(Subtitle & { duration?: number; hold?: boolean }) | false>('voiceSubtitle', (data) => {
    clearTimeout(timer.current);

    if (!data) return setSubtitle(null);

    setSubtitle(data);
    if (data.hold !== true) timer.current = setTimeout(() => setSubtitle(null), Number(data.duration) || 4000);
  });

  useNuiEvent<CommandPanel | false>('voicePanel', (data) => setPanel(data || null));

  useNuiEvent<Hint>('voiceHint', (data) => {
    if (!data?.id) return;
    setHints((prev) => ({ ...prev, [data.id]: data }));
  });

  useNuiEvent<{ id?: string }>('voiceHintRemove', (data) =>
    setHints((prev) => {
      if (!data?.id) return {};
      if (!(data.id in prev)) return prev;

      const next = { ...prev };
      delete next[data.id];
      return next;
    })
  );

  useEffect(() => () => clearTimeout(timer.current), []);

  const bubbles = Object.values(hints);
  /* Anchored when Lua sent a projected point -- otherwise it falls back to a screen corner. */
  const anchored = typeof panel?.x === 'number' && typeof panel?.y === 'number';
  if (!listening?.active && !subtitle && !bubbles.length && !panel) return null;

  return (
    <div className="wv-root">
      {/* ── what each NPC will answer to ───────────────────────────────── */}
      {bubbles.map((hint) => (
        <div className="wv-bubble" key={hint.id} style={{ left: `${hint.x * 100}%`, top: `${hint.y * 100}%` }}>
          {hint.title && (
            <span className="wv-bubble-name">
              {hint.icon && <Icon icon={hint.icon} />}
              {hint.title}
            </span>
          )}

          {hint.says ? (
            <span className="wv-says">{hint.says}</span>
          ) : hint.commands?.length ? (
            <span className="wv-commands">
              {hint.commands.map((command, i) => (
                <span className="wv-command" key={i}>
                  {command}
                </span>
              ))}
            </span>
          ) : null}

          {/* The tail, drawn as a rotated corner of the plate itself so it takes the same
              gradient and the same hairline instead of being a triangle stuck underneath. */}
          <span className="wv-tail" aria-hidden="true" />
        </div>
      ))}

      {/* ── everything the player may say right now ────────────────────── */}
      {panel?.groups?.length ? (
        <div
          className={`wv-panel${anchored ? ' is-anchored' : ` wv-at-${posClass(panel.position)}`}`}
          style={anchored ? { left: `${panel.x! * 100}%`, top: `${panel.y! * 100}%` } : undefined}
        >
          {/* The badge, lit while the microphone is open -- the panel's own little indicator, so
              the list itself shows whether it is currently listening to you. */}
          <span className={`wv-badge${listening?.active ? ' is-live' : ''}`} aria-hidden="true">
            {listening?.active ? (
              <Meter level={listening.level} levels={listening.levels} />
            ) : (
              <span className="wv-badge-wave" />
            )}
          </span>

          {panel.title && <span className="wv-panel-title">{panel.title}</span>}

          {panel.groups.map((group, gi) => (
            <div className="wv-panel-group" key={group.label ?? gi}>
              {group.label && <span className="wv-panel-group-name">{group.label}</span>}

              {group.commands.map((command, i) => (
                <Phrase key={i} text={command} />
              ))}
            </div>
          ))}
        </div>
      ) : null}

      {/* ── what it heard ──────────────────────────────────────────────── */}
      {/* ⚠️ The microphone is NOT here any more. It used to be a second indicator floating in the
          middle of the screen while the panel already carried one in its badge -- two things
          saying the same thing in two places. The badge stayed because it is attached to the
          commands it is listening for; this was the one that had nothing around it. */}
      {subtitle && (
        <div className="wv-dock">
          {subtitle?.text && (
            <div className={`wv-line is-${subtitle.state ?? 'listening'}`}>
              {subtitle.speaker && <span className="wv-speaker">{subtitle.speaker}</span>}
              <span className="wv-said">{subtitle.text}</span>
              <span className="wv-tail" aria-hidden="true" />
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default Voice;
