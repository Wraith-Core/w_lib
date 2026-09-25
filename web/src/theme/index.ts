import { MantineThemeOverride, Tuple } from '@mantine/core';

/**
 * ============================================================================
 * The w_crafting look, expressed as a Mantine theme.
 *
 * ★ RDR2's interface is near-black plates, hairline white rules, square corners and cream
 *   lettering. Mantine's defaults are the opposite of all four -- rounded, blue-accented and
 *   grey-on-grey -- so this file is mostly subtraction: take the radius off, take the colour
 *   out of the accent, and put the game's own faces back on the text.
 *
 * ⚠️ The values are NOT restated here. They live as CSS custom properties in index.css, and
 *    everything below reads them through var(). One palette, one place to change it, and no
 *    chance of the React components drifting away from the plain-CSS ones (the prompt and the
 *    minigames) that use the same tokens directly.
 * ============================================================================
 */

/**
 * The ramp Mantine wants for a colour: ten shades, light to dark -- the theme's paper down to
 * its ink (w_lib/nui/theme/tokens.css), with the two steps between them mixed from the pair.
 * Mantine needs literal colours here (it computes shades from them), so these are the token
 * values written out; everything else below reads the tokens through var().
 */
const wraith: Tuple<string, 10> = [
  '#F6F1E6', // paper-lit
  '#EDE6D6', // paper
  '#B9AF9C', // paper-dim
  '#9B9281', // between paper-dim and paper-faint
  '#7D7466', // paper-faint
  '#5E5344', // note-dim
  '#38322A', // ink-5
  '#27231C', // ink-4
  '#15130F', // ink-2
  '#0B0A08', // ink
];

/**
 * ★ Red is not a ramp. It is the theme's ONE mark (#CB0101): danger, refusal, the destructive
 *   confirm, a progress tick -- never a family of reds, and never text. Mantine still asks for ten
 *   shades wherever it reaches for 'red' (an invalid field's border, a required asterisk), so
 *   every shade is the same mark. The error TEXT Mantine would paint with it is paper here
 *   (InputWrapper below), with the red kept as a square in front of it.
 */
const blood: Tuple<string, 10> = [
  '#CB0101', '#CB0101', '#CB0101', '#CB0101', '#CB0101',
  '#CB0101', '#CB0101', '#CB0101', '#CB0101', '#CB0101',
];

/**
 * Mantine's dark scheme draws its surfaces from `dark` (0 = text, 7 = the body) -- its own
 * blue-grey ramp by default. Here it is the theme's: paper for text, the ink steps for surfaces.
 */
const dark: Tuple<string, 10> = [
  '#EDE6D6', // paper: text
  '#B9AF9C', // paper-dim
  '#9B9281', // between paper-dim and paper-faint
  '#7D7466', // paper-faint: placeholders
  '#38322A', // ink-5: borders
  '#27231C', // ink-4: hover
  '#1D1A15', // ink-3: fields
  '#15130F', // ink-2: body
  '#0B0A08', // ink
  '#0B0A08', // ink
];

/**
 * ★ The owner's rule is ink, paper and one red on every interface, without exception -- so no
 *   hue is left for a stray `color="green"` to reach. Every one of Mantine's named colours
 *   (blue, teal, yellow...) resolves to the paper-to-ink ramp, and red to the mark.
 */
const MONO = ['gray', 'pink', 'grape', 'violet', 'indigo', 'blue', 'cyan', 'teal', 'green', 'lime', 'yellow', 'orange'] as const;
const mono = Object.fromEntries(MONO.map((name) => [name, wraith])) as Record<(typeof MONO)[number], Tuple<string, 10>>;

export const theme: MantineThemeOverride = {
  colorScheme: 'dark',

  colors: { ...mono, dark, red: blood, wraith, blood },
  primaryColor: 'wraith',
  // ★ Shade 1, not the usual 6: on a near-black plate the accent is the *light* end of the
  //   ramp. Picking a mid grey would make every primary control disappear into its own panel.
  primaryShade: 1,

  black: '#0B0A08', // ink
  white: '#EDE6D6', // paper: "white" is always paper in this theme

  fontFamily: 'var(--w-f-label)',
  fontFamilyMonospace: 'var(--w-f-num)',
  headings: {
    fontFamily: 'var(--w-f-title)',
    fontWeight: 400,
  },

  /* RDR draws boxes, not pills. */
  defaultRadius: 0,
  radius: { xs: 0, sm: 0, md: 0, lg: 0, xl: 0 },

  shadows: {
    xs: '0 2px 6px rgba(0, 0, 0, 0.6)',
    sm: '0 6px 18px rgba(0, 0, 0, 0.65)',
    md: '0 14px 34px rgba(0, 0, 0, 0.7)',
    lg: '0 22px 60px -18px rgba(0, 0, 0, 0.85)',
    xl: '0 30px 80px -20px rgba(0, 0, 0, 0.9)',
  },

  components: {
    /* ── surfaces ─────────────────────────────────────────────────────── */

    Paper: {
      styles: {
        root: {
          // ★ The plate, not a flat panel: RDR lights its surfaces from the top edge and lets
          //   them fall to black at the corners. Identical to .wc-plate in wc.css.
          background: 'radial-gradient(140% 130% at 50% 0%, rgba(29, 26, 21, 0.95), rgba(11, 10, 8, 0.96))',
          border: '1px solid var(--wc-line)',
          color: 'var(--wc-text)',
        },
      },
    },

    Modal: {
      styles: {
        modal: {
          background: 'radial-gradient(140% 130% at 50% 0%, rgba(29, 26, 21, 0.95), rgba(11, 10, 8, 0.96))',
          border: '1px solid var(--wc-line)',
          boxShadow: '0 22px 60px -18px rgba(0, 0, 0, 0.85)',
        },
        title: {
          fontFamily: 'var(--w-f-title)',
          fontWeight: 600,
          fontSize: 20,
          color: 'var(--wc-text)',
        },
        // The scrim is nearly opaque: RDR dims the world hard behind its menus.
        overlay: { backgroundColor: 'var(--w-scrim)' },
        close: { color: 'var(--wc-text-dim)', '&:hover': { backgroundColor: 'var(--wc-hover)' } },
      },
    },

    Divider: {
      styles: { root: { borderColor: 'var(--wc-line)' } },
    },

    Tooltip: {
      styles: {
        tooltip: {
          backgroundColor: 'var(--wc-panel-2)',
          border: '1px solid var(--wc-line)',
          color: 'var(--wc-text)',
          fontFamily: 'var(--wc-font-body)',
        },
      },
    },

    /* ── controls ─────────────────────────────────────────────────────── */

    Button: {
      styles: {
        root: {
          border: '1px solid var(--wc-line)',
          backgroundColor: 'var(--wc-panel-2)',
          color: 'var(--wc-text)',
          fontFamily: 'var(--w-f-action)',
          fontWeight: 500,
          letterSpacing: '0.02em',
          transition: 'background-color 120ms ease, border-color 120ms ease',
          '&:hover': {
            backgroundColor: 'var(--wc-plate)',
            borderColor: 'var(--wc-line-strong)',
          },
        },
      },
    },

    ActionIcon: {
      styles: {
        root: {
          color: 'var(--wc-text-dim)',
          '&:hover': { backgroundColor: 'var(--wc-hover)', color: 'var(--wc-text)' },
        },
      },
    },

    /* ── fields ───────────────────────────────────────────────────────── */

    Input: {
      styles: {
        input: {
          backgroundColor: 'var(--wc-panel-3)',
          border: '1px solid var(--wc-line)',
          color: 'var(--wc-text)',
          fontFamily: 'var(--wc-font-body)',
          '&:focus, &:focus-within': { borderColor: 'var(--wc-line-strong)' },
          '&::placeholder': { color: 'var(--wc-text-faint)' },
        },
      },
    },

    InputWrapper: {
      styles: {
        label: {
          color: 'var(--wc-text-dim)',
          fontFamily: 'var(--wc-font-body)',
          marginBottom: 4,
        },
        description: { color: 'var(--wc-text-faint)' },
        // ★ Paper text with the red square in front: red is a mark, never the words themselves.
        error: {
          color: 'var(--wc-text)',
          '&::before': {
            content: '""',
            display: 'inline-block',
            width: 6,
            height: 6,
            marginInlineEnd: '0.45em',
            verticalAlign: '0.12em',
            background: 'var(--wc-red)',
          },
        },
      },
    },

    Select: {
      styles: {
        item: {
          fontFamily: 'var(--wc-font-body)',
          '&[data-selected]': {
            backgroundColor: 'var(--wc-plate)',
            color: 'var(--wc-text)',
            '&:hover': { backgroundColor: 'var(--wc-plate)' },
          },
          '&[data-hovered]': { backgroundColor: 'var(--wc-hover)' },
        },
        dropdown: {
          backgroundColor: 'var(--wc-panel-2)',
          border: '1px solid var(--wc-line)',
        },
      },
    },

    Checkbox: {
      styles: {
        input: {
          backgroundColor: 'var(--wc-panel-3)',
          border: '1px solid var(--wc-line)',
          '&:checked': { backgroundColor: 'var(--wc-text)', borderColor: 'var(--wc-text)' },
        },
        icon: { color: 'var(--wc-bg)' },
        label: { color: 'var(--wc-text)', fontFamily: 'var(--wc-font-body)' },
      },
    },

    Slider: {
      styles: {
        track: { backgroundColor: 'var(--wc-panel-3)' },
        bar: { backgroundColor: 'var(--wc-text)' },
        thumb: { backgroundColor: 'var(--wc-text)', borderColor: 'var(--wc-text)' },
        markFilled: { borderColor: 'var(--wc-text)' },
        label: { backgroundColor: 'var(--wc-plate)', fontFamily: 'var(--wc-font-numeral)' },
      },
    },

    /* ── readouts ─────────────────────────────────────────────────────── */

    Progress: {
      styles: {
        root: { backgroundColor: 'var(--wc-panel-3)' },
        bar: { backgroundColor: 'var(--wc-text)' },
      },
    },

    Text: {
      styles: { root: { fontFamily: 'var(--wc-font-body)' } },
    },

    Title: {
      styles: { root: { fontFamily: 'var(--w-f-title)', fontWeight: 400 } },
    },

    Badge: {
      styles: {
        root: {
          fontFamily: 'var(--wc-font-numeral)',
          fontWeight: 400,
          border: '1px solid var(--wc-line)',
          backgroundColor: 'var(--wc-panel-2)',
          color: 'var(--wc-text)',
        },
      },
    },

    ScrollArea: {
      styles: {
        thumb: { backgroundColor: 'var(--wc-line-strong)' },
      },
    },
  },
};
