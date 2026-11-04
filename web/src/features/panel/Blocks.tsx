import React from 'react';
import Icon from '../../wc/Icon';
import DateFields from '../../components/DateFields';
import PaletteField from '../../components/PaletteField';
import WSelect from '../../components/WSelect';
import HexColourField from '../../components/HexColourField';
import { READING_TONES, toPalette } from '../../utils/palette';
import { Bar, Glyph } from '../../wc/Panel';

/**
 * ============================================================================
 * Blocks -- the panel's composition layer.
 *
 * ★ WHY: a fixed list-and-detail covers a shop and a bench and nothing else. An admin panel is
 *   stat tiles over a log table; a marketplace is a grid of listings beside a sell form; a
 *   cinema is a handful of switches; a kingdom is a ledger. Those are not five layouts, they
 *   are five ARRANGEMENTS of the same dozen pieces -- so the script names the pieces and their
 *   order, and the library draws them.
 *
 * ★ Every block below renders on classes wc-base.css already carries. .wc-card, .wc-manage-row,
 *   .wc-meta-tile, .wc-category-group, .wc-ing, .lb-input -- all of it came across with the
 *   crafting design. Nothing here invents a look.
 *
 * ⚠️ Blocks are DATA. They carry no callbacks -- an action is an id, a field change is an id and
 *   a value, and both come back over the NUI callbacks. That is the same boundary every other
 *   part of this library lives behind, and the reason a panel can be described from Lua at all.
 * ============================================================================
 */

export interface Field {
  id: string;
  label?: string;
  /**
   * ★ colour, time and date are here because two of the five panels needed them and neither
   *   could be faked: w_kingsdom picks a crest colour from a swatch, wraith_cinema schedules a
   *   showing at a time. A text field for either asks the player to type a hex code or '19:30'
   *   correctly, which is a worse control, not a simpler one.
   */
  /**
   * 'hexcolor': a colour that is the script's DATA (a name plate, a crest), shown elsewhere in full colour --
   * a hex box with a ▲ inside it that opens a colour wheel (components/HexColourField). Reports '#rrggbb' or
   * '#rrggbbaa'. 'color' stays the theme's eight paper tones.
   */
  type?: 'text' | 'number' | 'select' | 'checkbox' | 'textarea' | 'color' | 'hexcolor' | 'time' | 'date';
  /** hexcolor: the wheel's words ({ brightness, opacity, wheel }) in the reader's language */
  labels?: { brightness?: string; opacity?: string; wheel?: string; move?: string };
  value?: string | number | boolean;
  placeholder?: string;
  min?: number;
  max?: number;
  step?: number;
  /** a select's choices; `image` is drawn small before the label (a blip, an icon) */
  options?: Array<{ value: string; label: string; image?: string }>;
  /** a select: a search box over its list (on by itself past 12 choices); `placeholder` is the search box's */
  searchable?: boolean;
  /** a select: open as a menu of tiles in this many columns (picture, name below) with a search bar */
  grid?: number;
  disabled?: boolean;
}

export interface BlockAction {
  id: string;
  label: string;
  icon?: string;
  disabled?: boolean;
  /** Red, for the ones that take something away. */
  danger?: boolean;
}

export interface Block {
  type:
    | 'section'
    | 'stats'
    | 'bars'
    | 'rows'
    | 'table'
    | 'cards'
    | 'text'
    | 'form'
    | 'actions'
    | 'requirements'
    | 'chips'
    | 'hero'
    | 'image';
  /** A ruled heading above the block. */
  title?: string;
  /**
   * The heading becomes a button with an arrow that folds the block away (needs a title). `collapsed`: how it
   * starts the first time; after that the reader's choice is kept while the panel is open, across redraws.
   */
  collapsible?: boolean;
  collapsed?: boolean;
  /** Shown at the far end of that heading -- a count, a total. */
  note?: string;
  /** How much of the row this block takes when blocks sit side by side. Defaults to all of it. */
  span?: number;

  // stats / bars / rows
  items?: Array<{
    label: string;
    value?: string | number;
    sub?: string;
    icon?: string;
    image?: string;
    progress?: number;
    id?: string | number;
    disabled?: boolean;
    danger?: boolean;
    actions?: BlockAction[];
    /**
     * A number the reader edits ON the row, beside the thing it belongs to.
     *
     * ★ WHY IT IS HERE AND NOT A FIELD IN A FORM BELOW. A quantity belongs to one item, and a
     *   form under the list has to name that item again to say which quantity is which -- so
     *   the reader reads a name, finds the same name again further down, and types there. With
     *   five ingredients that is five round trips of the eye for five numbers. On the row there
     *   is nothing to match up: the picture, the name and the number are one line.
     *
     * ⚠️ It reports through onField, the same channel a form field uses, so the script that
     *    described the row already knows how to receive it.
     */
    input?: { id: string; value?: number; min?: number; max?: number; step?: number };
    /**
     * A status light: any CSS colour, or one of ok / warn / bad.
     *
     * ★ wraith_cinema shows one per screen (playing, idle, unreachable) and an admin list shows
     *   one per player. It is a dot rather than a word because a column of forty of them is read
     *   by colour, not by reading.
     */
    dot?: string;
  }>;

  // table
  columns?: Array<{ key: string; label: string; align?: 'start' | 'end' }>;
  rows?: Array<Record<string, string | number>>;

  // text / hero / image
  value?: string;
  /**
   * hero: the emblem beside the name -- a crest, a screen, a maker's mark.
   * image: a picture shown whole, as wide as its block (a preview a script drew: a name plate, a card) --
   *        any url, nui:// or a data: url (an SVG the script builds). value is its alt text.
   */
  image?: string;
  /** image: the tallest it is drawn, in px (default 120). */
  height?: number;
  /** image: drawn at `height` even when the picture is smaller (scaled up), the width to fit */
  fill?: boolean;
  icon?: string;
  /** hero: a colour behind the emblem, for a crest or a house colour (drawn as its nearest palette tone). */
  color?: string;
  subtitle?: string;

  // form
  fields?: Field[];

  // actions
  actions?: BlockAction[];
}

interface Ctx {
  onAction: (id: string, itemId?: string | number) => void;
  onField: (id: string, value: string | number | boolean) => void;
  onPick?: (id: string | number) => void;
  selected?: string | number | null;
}

/* ── the ruled heading every block may carry ──────────────────────────────── */

const Heading: React.FC<{ title?: string; note?: string; fold?: { open: boolean; toggle: () => void } }> = ({ title, note, fold }) =>
  title ? (
    fold ? (
      /* a foldable block: the whole heading is the button, the arrow says which way it goes */
      <button type="button" className="wc-section-title wl-panel-fold" aria-expanded={fold.open} onClick={fold.toggle}>
        <span className={`wl-panel-fold-arrow${fold.open ? ' is-open' : ''}`} aria-hidden="true" />
        <span>{title}</span>
        <span className="wc-hr-thin" />
        {note && <span className="wc-section-count">{note}</span>}
      </button>
    ) : (
      <div className="wc-section-title">
        <span>{title}</span>
        <span className="wc-hr-thin" />
        {note && <span className="wc-section-count">{note}</span>}
      </div>
    )
  ) : null;

/* ★ Which foldable blocks the reader closed, by title. Kept here, outside the panel's own state: the script
     redraws the panel on every change (a nav, a save) and a fold must not spring open each time. */
const folded = new Map<string, boolean>();

const ActionButtons: React.FC<{ actions?: BlockAction[]; itemId?: string | number; ctx: Ctx }> = ({
  actions,
  itemId,
  ctx,
}) =>
  actions?.length ? (
    <>
      {actions.map((action) => (
        <button
          type="button"
          key={action.id}
          className={`wc-manage-btn${action.danger ? ' is-remove' : ''}`}
          disabled={action.disabled}
          onClick={() => ctx.onAction(action.id, itemId)}
        >
          {action.icon && <Icon icon={action.icon} />}
          {action.label}
        </button>
      ))}
    </>
  ) : null;

/* ── the blocks themselves ────────────────────────────────────────────────── */

const Stats: React.FC<{ block: Block }> = ({ block }) => (
  <div className="wc-meta wl-panel-meta">
    {block.items?.map((item, i) => (
      <div className="wc-meta-tile" key={`${item.label}-${i}`}>
        {item.icon && <Icon icon={item.icon} />}
        <span className="wc-meta-value" dir="ltr">
          {item.value}
        </span>
        <span className="wc-meta-label">{item.label}</span>
      </div>
    ))}
  </div>
);

const Bars: React.FC<{ block: Block }> = ({ block }) => (
  <div className="wl-panel-stats">
    {block.items?.map((item, i) => (
      <div className="wl-panel-row" key={`${item.label}-${i}`}>
        <span className="wl-panel-row-label">{item.label}</span>
        <Bar ratio={(item.progress ?? 0) / 100} bright />
      </div>
    ))}
  </div>
);

/** A list of things, each with a picture, two lines and its own buttons. */
const Rows: React.FC<{ block: Block; ctx: Ctx }> = ({ block, ctx }) => (
  <div className="wc-manage-list wc-scroll">
    {block.items?.map((item, i) => (
      <div className="wc-manage-row" key={item.id ?? `${item.label}-${i}`}>
        <span className="wc-slot">
          <Icon icon={item.image ?? item.icon} fallback="menu_bar" />
        </span>

        <span className="wc-manage-row-main">
          <span className="wc-manage-row-name">
            {item.dot && <span className="wl-panel-dot" data-state={item.dot} />}
            {item.label}
          </span>
          {item.sub && <span className="wc-manage-row-sub">{item.sub}</span>}
        </span>

        <span className="wl-panel-row-end">
          {item.input && <RowInput input={item.input} ctx={ctx} />}

          {item.value != null && (
            <span className={`wc-meta-value${item.danger ? ' is-danger' : ''}`} dir="ltr">
              {item.value}
            </span>
          )}
          <ActionButtons actions={item.actions} itemId={item.id} ctx={ctx} />
        </span>
      </div>
    ))}
  </div>
);

/**
 * A real table -- logs, transactions, bids.
 *
 * ⚠️ Built on .wc-manage-row's grid rather than a <table>, so the columns line up with every
 *    other list in the panel. A real <table> would bring its own spacing and sit half a
 *    millimetre off everything around it, which is the sort of thing nobody can name but
 *    everybody sees.
 */
const Table: React.FC<{ block: Block }> = ({ block }) => {
  const cols = block.columns ?? [];
  const template = cols.map(() => 'minmax(0, 1fr)').join(' ');

  return (
    <div className="wl-panel-table wc-scroll">
      <div className="wl-panel-thead" style={{ gridTemplateColumns: template }}>
        {cols.map((col) => (
          <span key={col.key} style={{ textAlign: col.align ?? 'start' }}>
            {col.label}
          </span>
        ))}
      </div>

      {block.rows?.map((row, i) => (
        <div className="wl-panel-trow" key={i} style={{ gridTemplateColumns: template }}>
          {cols.map((col) => (
            <span key={col.key} style={{ textAlign: col.align ?? 'start' }} dir={col.align === 'end' ? 'ltr' : undefined}>
              {row[col.key]}
            </span>
          ))}
        </div>
      ))}
    </div>
  );
};

/** A grid of pickable cards -- listings, screens, kingdoms, inventory. */
const Cards: React.FC<{ block: Block; ctx: Ctx }> = ({ block, ctx }) => (
  <div className="wl-panel-cards">
    {block.items?.map((item, i) => (
      <button
        type="button"
        key={item.id ?? `${item.label}-${i}`}
        className={`wc-card${item.id != null && item.id === ctx.selected ? ' is-active' : ''}`}
        disabled={item.disabled}
        onClick={() => item.id != null && ctx.onPick?.(item.id)}
      >
        <span className="wc-slot">
          <Icon icon={item.image ?? item.icon} fallback="menu_bar" />
        </span>

        <span style={{ minWidth: 0 }}>
          <span className="wc-card-name">
            {item.dot && <span className="wl-panel-dot" data-state={item.dot} />}
            {item.label}
          </span>
          {(item.sub || item.value != null) && (
            <span className="wc-card-sub">
              {item.sub}
              {item.value != null && <b dir="ltr">{item.value}</b>}
            </span>
          )}
        </span>

        {item.danger && <span className="wc-card-flag" />}
      </button>
    ))}
  </div>
);

/* ── A list row's number box that can actually be typed into ──────────────────
 *
 * ! The same fault as the form fields below, in the other place a number is typed: the
 *   rows of a list block (the daily limits, the cooldowns, the bulk screens) carried a
 *   controlled <input value={item.input.value}> whose onChange only reported to the script.
 *   React put the prop back after every keystroke and the box never changed. The form
 *   fields were fixed first; this is the second path, and there is no third - every input
 *   in this UI was audited after the second was found.
 */
const RowInput: React.FC<{ input: NonNullable<NonNullable<Block['items']>[number]['input']>; ctx: Ctx }> = ({ input, ctx }) => {
  const external = input.value;
  const [text, setText] = React.useState<string>(external == null ? '' : String(external));
  React.useEffect(() => { setText(external == null ? '' : String(external)); }, [external]);
  return (
    <input
      type="number"
      className="wl-panel-row-input"
      dir="ltr"
      value={text}
      min={input.min}
      max={input.max}
      step={input.step}
      /* ★ اختيار الكلّ عند التركيز: الكميّة تُستبدل لا تُلحَق بها الأرقام.
         من يضغط حقلاً فيه 8 ليكتب 12 يقصد 12، لا 812. */
      onFocus={(e) => e.currentTarget.select()}
      onChange={(e) => {
        setText(e.target.value);
        ctx.onField(input.id, Number(e.target.value));
      }}
    />
  );
};

/* ── A form field that can actually be typed into ──────────────────────────────
 *
 * ! Every input here used to be a controlled input - value={field.value} - whose onChange
 *   only reported to the script (ctx.onField) and updated no state on this side. React then
 *   put the prop value straight back into the box after every keystroke: a digit was typed
 *   and gone in the same frame, and the panel read as one that would not take an edit. The
 *   script did receive every keystroke and did keep a draft; it just never re-showed the
 *   panel with it, and it should not have to.
 *
 * * So the field keeps its own text while the panel is open, and hands the script what it
 *   always did. When the script re-shows the panel with a different value (a save, a reset,
 *   a nav), the prop changes and the box follows it - that is the only moment the prop wins.
 *
 * * The number field keeps its text as text: "0." and "-" are states a number cannot hold,
 *   and coercing on every keystroke is how a decimal becomes untypeable. The script still
 *   gets a Number, as before.
 */
type FormFieldSpec = NonNullable<Block['fields']>[number];

const FormField: React.FC<{ field: FormFieldSpec; ctx: Ctx }> = ({ field, ctx }) => {
  const external = field.value;
  const [text, setText] = React.useState<string>(String(external ?? ''));
  const [checked, setChecked] = React.useState<boolean>(Boolean(external));

  // the prop is the source of truth only when the script sends a new one
  React.useEffect(() => {
    setText(String(external ?? ''));
    setChecked(Boolean(external));
  }, [external]);

  if (field.type === 'checkbox') {
    return (
      <input
        type="checkbox"
        className="wl-panel-check"
        checked={checked}
        disabled={field.disabled}
        onChange={(e) => {
          setChecked(e.target.checked);
          ctx.onField(field.id, e.target.checked);
        }}
      />
    );
  }

  if (field.type === 'select') {
    return (
      <span className="lb-input">
        {/* the page's own dropdown: a native <select> opens a popup the game paints as noise (components/WSelect) */}
        <WSelect
          value={text}
          options={field.options ?? []}
          disabled={field.disabled}
          ariaLabel={field.label}
          searchable={field.searchable}
          searchPlaceholder={field.placeholder}
          grid={field.grid}
          onChange={(v) => {
            setText(v);
            ctx.onField(field.id, v);
          }}
        />
      </span>
    );
  }

  if (field.type === 'hexcolor') {
    return (
      <span className="lb-input">
        <HexColourField
          value={text}
          placeholder={field.placeholder}
          disabled={field.disabled}
          ariaLabel={field.label}
          labels={field.labels}
          onChange={(v) => {
            setText(v);
            ctx.onField(field.id, v);
          }}
        />
      </span>
    );
  }

  if (field.type === 'textarea') {
    return (
      <span className="lb-input is-area">
        <textarea
          value={text}
          placeholder={field.placeholder}
          disabled={field.disabled}
          onChange={(e) => {
            setText(e.target.value);
            ctx.onField(field.id, e.target.value);
          }}
        />
      </span>
    );
  }

  if (field.type === 'date') {
    // ★ Day, month by name, year (components/DateFields): the same "YYYY-MM-DD" the native box
    //   reported, or "" until the three parts make a real date.
    return (
      <DateFields
        value={text}
        rtl={document.documentElement.dir === 'rtl'}
        label={field.label}
        disabled={field.disabled}
        onChange={(v) => {
          setText(v);
          ctx.onField(field.id, v);
        }}
      />
    );
  }

  if (field.type === 'color') {
    // ★ The palette's eight tones, not the machine's full-spectrum picker (components/PaletteField).
    //   The script keeps its stored colour until the player picks a tone.
    return (
      <PaletteField
        value={text}
        rtl={document.documentElement.dir === 'rtl'}
        label={field.label}
        disabled={field.disabled}
        onChange={(v) => {
          setText(v);
          ctx.onField(field.id, v);
        }}
      />
    );
  }

  const isNumber = field.type === 'number';
  return (
    <span className="lb-input">
      <input
        type={isNumber ? 'number' : field.type === 'time' ? field.type : 'text'}
        dir={field.type === 'text' || field.type === undefined ? undefined : 'ltr'}
        value={text}
        placeholder={field.placeholder}
        min={field.min}
        max={field.max}
        step={field.step}
        disabled={field.disabled}
        onFocus={isNumber ? (e) => e.currentTarget.select() : undefined}
        onChange={(e) => {
          setText(e.target.value);
          ctx.onField(field.id, isNumber ? Number(e.target.value) : e.target.value);
        }}
      />
    </span>
  );
};

/* ★ A form may carry a picture above its fields (`image`, drawn at `height` like an image block's `fill`) and its
     own buttons below them (`actions`), so a section and what acts on it fold away together. */
const Form: React.FC<{ block: Block; ctx: Ctx }> = ({ block, ctx }) => (
  <>
    {block.image && (
      <div className="wl-panel-image">
        <img src={block.image} alt="" style={{ height: `calc(${Math.max(24, Math.min(400, block.height ?? 90))} * var(--ws-px))`, width: 'auto', maxWidth: '100%' }} />
      </div>
    )}
    <div className="wl-panel-form">
      {block.fields?.map((field) => {
        // ⚠️ A colour row is not a <label>: a click on a label's text is forwarded to the first
        //    control inside it, which for the swatches would pick the first tone on its own.
        // a <label> would pass a click on the wheel's ▲ to the box: those two are rows, not labels
        const Row = field.type === 'color' || field.type === 'hexcolor' ? 'div' : 'label';
        return (
          <Row className={`wl-panel-field${field.type === 'checkbox' ? ' is-check' : ''}`} key={field.id}>
            {field.label && <span className="wl-panel-row-label">{field.label}</span>}
            <FormField field={field} ctx={ctx} />
          </Row>
        );
      })}
    </div>
    {block.actions?.length ? (
      <div className="wl-panel-buttons is-form">
        <ActionButtons actions={block.actions} ctx={ctx} />
      </div>
    ) : null}
  </>
);

const Requirements: React.FC<{ block: Block }> = ({ block }) => (
  <div className="wc-ingredients wc-scroll">
    {block.items?.map((item, i) => (
      <div className="wc-ing" key={`${item.label}-${i}`}>
        <span className="wc-slot">
          <Icon icon={item.image ?? item.icon} fallback="menu_bar" />
        </span>
        <span className="wc-ing-label">{item.label}</span>
        {item.value != null && (
          <span className={`wc-ing-amount${item.danger ? ' is-danger' : ''}`} dir="ltr">
            {item.value}
          </span>
        )}
      </div>
    ))}
  </div>
);

/**
 * A wrap of small pills -- roles, tags, the genres on a showing.
 *
 * ★ Pickable when an item carries an id, decoration when it does not. The same block does a
 *   read-only tag list and a multiple-choice filter, because those differ by whether anything
 *   listens, not by how they look.
 */
const Chips: React.FC<{ block: Block; ctx: Ctx }> = ({ block, ctx }) => (
  <div className="wl-panel-chips">
    {block.items?.map((item, i) => (
      <button
        type="button"
        key={item.id ?? `${item.label}-${i}`}
        className={`wl-panel-chip${item.id != null && item.id === ctx.selected ? ' is-active' : ''}`}
        disabled={item.disabled || item.id == null}
        onClick={() => item.id != null && ctx.onPick?.(item.id)}
      >
        {item.dot && <span className="wl-panel-dot" data-state={item.dot} />}
        {item.icon && <Icon icon={item.icon} />}
        {item.label}
        {item.value != null && <b dir="ltr">{item.value}</b>}
      </button>
    ))}
  </div>
);

/**
 * The thing this panel is ABOUT, stated once at the top -- a kingdom's crest, the screen you
 * are controlling, the character being edited.
 *
 * ⚠️ Not the same as the header. The header names the PANEL ('Kingdoms'); this names the
 *    subject inside it ('House Beaumont'), which changes as the player moves around.
 */
const Hero: React.FC<{ block: Block }> = ({ block }) => (
  <div className="wl-panel-hero">
    {/* ★ The house colour on the palette: whatever hue a script stored is drawn as its nearest
        paper tone (utils/palette), so the crest's frame stays visible on the ink. */}
    <span
      className="wc-slot wl-panel-crest"
      style={toPalette(block.color, READING_TONES) ? { ['--wl-crest' as string]: toPalette(block.color, READING_TONES) } : undefined}
    >
      <Icon icon={block.image ?? block.icon} fallback="menu_icon_rank" />
    </span>

    <div style={{ minWidth: 0 }}>
      <h2 className="wc-preview-name">{block.value}</h2>
      {block.subtitle && (
        <div className="wc-preview-tags">
          <span>{block.subtitle}</span>
        </div>
      )}
    </div>
  </div>
);

/* ── the renderer ─────────────────────────────────────────────────────────── */

const BODY: Record<Block['type'], React.FC<{ block: Block; ctx: Ctx }>> = {
  section: () => null,
  stats: ({ block }) => <Stats block={block} />,
  bars: ({ block }) => <Bars block={block} />,
  rows: Rows,
  table: ({ block }) => <Table block={block} />,
  cards: Cards,
  text: ({ block }) => <p className="wl-panel-text">{block.value}</p>,
  form: Form,
  actions: ({ block, ctx }) => (
    <div className="wl-panel-buttons">
      <ActionButtons actions={block.actions} ctx={ctx} />
    </div>
  ),
  requirements: ({ block }) => <Requirements block={block} />,
  chips: Chips,
  hero: ({ block }) => <Hero block={block} />,
  /* ★ A picture shown whole, not an icon in a slot: a slot is a small square and a script's preview (a name
     plate, a card face) is wide. Put it beside a hero with `span` (hero 5, image 7) to show the subject and
     its preview on one line. */
  image: ({ block }) =>
    block.image ? (
      <div className="wl-panel-image">
        {/* fill: drawn AT that height (a small picture scaled up -- an SVG stays sharp), not merely kept under it */}
        <img src={block.image} alt={block.value ?? ''} style={block.fill
          ? { height: `calc(${Math.max(24, Math.min(400, block.height ?? 120))} * var(--ws-px))`, width: 'auto', maxWidth: '100%' }
          : { maxHeight: `calc(${Math.max(24, Math.min(400, block.height ?? 120))} * var(--ws-px))` }} />
      </div>
    ) : null,
};

const Blocks: React.FC<{ blocks?: Block[]; ctx: Ctx }> = ({ blocks, ctx }) => {
  const [, redraw] = React.useReducer((n: number) => n + 1, 0);
  if (!blocks?.length) return null;

  return (
    <div className="wl-panel-blocks wc-scroll">
      {blocks.map((block, i) => {
        const Body = BODY[block.type] ?? (() => null);
        const foldKey = block.collapsible && block.title ? block.title : null;
        const open = foldKey ? !(folded.get(foldKey) ?? !!block.collapsed) : true;
        const fold = foldKey ? { open, toggle: () => { folded.set(foldKey, open); redraw(); } } : undefined;

        return (
          /* ⚠️ span is a grid column count, defaulting to the full width. It is what lets a
             script put two half-width blocks side by side without the library guessing. */
          <section
            className="wl-panel-block"
            key={i}
            style={{ gridColumn: `span ${Math.min(12, Math.max(1, block.span ?? 12))}` }}
          >
            <Heading title={block.title} note={block.note} fold={fold} />
            {open && <Body block={block} ctx={ctx} />}
          </section>
        );
      })}
    </div>
  );
};

export default Blocks;
export { Glyph };
