import React from 'react';
import DateFields from '../../components/DateFields';
import PaletteField from '../../components/PaletteField';
import WSelect from '../../components/WSelect';
import HexColourField from '../../components/HexColourField';
import { READING_TONES, toPalette } from '../../utils/palette';
import { cls, Gauge, GlyphDown, KitIcon, latinDigits, Txt, useKit } from '../../kit/ui';

/**
 * ============================================================================
 * Blocks -- the panel's composition layer, on the board kit (4.4.0).
 *
 * ★ WHY: a fixed list-and-detail covers a shop and a bench and nothing else. An admin panel is
 *   stat tiles over a log table; a marketplace is a grid of listings beside a sell form; a
 *   kingdom is a ledger. Those are ARRANGEMENTS of the same dozen pieces -- the script names
 *   the pieces and their order (a 12-column grid, `span`), the library draws them.
 *
 * ⚠️ Blocks are DATA. They carry no callbacks -- an action is an id, a field change is an id and
 *   a value, and both come back over the NUI callbacks (panelAction, panelField).
 * ============================================================================
 */

export interface Field {
  id: string;
  label?: string;
  /**
   * 'hexcolor': a colour that is the script's DATA (a name plate, a crest) -- a hex box with a wheel
   * (components/HexColourField), reports '#rrggbb' or '#rrggbbaa'. 'color' stays the theme's eight paper tones.
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
  /** For the ones that take something away. */
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
  /** A ruled heading above the block (a hero: a kicker over its name). */
  title?: string;
  /** The heading folds the block away (needs a title); `collapsed` is how it starts the first time. */
  collapsible?: boolean;
  collapsed?: boolean;
  /** Shown at the far end of that heading -- a count, a total. */
  note?: string;
  /** How much of the row this block takes when blocks sit side by side (of 12). Defaults to all of it. */
  span?: number;

  // stats / bars / rows / cards / chips / requirements
  items?: Array<{
    label: string;
    value?: string | number;
    sub?: string;
    icon?: string;
    image?: string;
    progress?: number;
    id?: string | number;
    disabled?: boolean;
    /** a row's value / a bar / a requirement: marked as bad (a red mark, red only where the caller says so) */
    danger?: boolean;
    actions?: BlockAction[];
    /** A number the reader edits ON the row; it reports through onField, like a form field. */
    input?: { id: string; value?: number; min?: number; max?: number; step?: number };
    /** A status light: any CSS colour, or one of ok / warn / bad. */
    dot?: string;
  }>;

  // table
  columns?: Array<{ key: string; label: string; align?: 'start' | 'end' }>;
  rows?: Array<Record<string, string | number>>;

  // text / hero / image
  value?: string;
  /** hero: the emblem beside the name. image: a picture shown whole, as wide as its block. */
  image?: string;
  /** image: the tallest it is drawn, in px at 1080p (default 120). */
  height?: number;
  /** image: drawn at `height` even when the picture is smaller (scaled up), the width to fit */
  fill?: boolean;
  icon?: string;
  /** hero: a colour behind the emblem (drawn as its nearest palette tone). */
  color?: string;
  subtitle?: string;
  /** hero (the panel's own detail): a state beside the subtitle, and whether it is a bad one */
  tag?: string;
  tagBad?: boolean;

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

type Item = NonNullable<Block['items']>[number];

/* ── the picture of a thing: a quiet square slot ── */
export const Slot: React.FC<{ image?: string; icon?: string; big?: boolean; crest?: string }> = ({ image, icon, big, crest }) => (
  <span
    className={cls('wk-slot', big && 'is-big', crest && 'is-crest')}
    style={crest ? { ['--wk-crest' as string]: crest } : undefined}
  >
    <KitIcon icon={image ?? icon} />
  </span>
);

/* ── the ruled heading every block may carry ── */
const Heading: React.FC<{ title?: string; note?: string; fold?: { open: boolean; toggle: () => void } }> = ({ title, note, fold }) => {
  if (!title) return null;
  const inner = (
    <>
      {fold && <span className={cls('wk-fold', fold.open && 'is-open')}><GlyphDown /></span>}
      <span className="wk-sec-title"><Txt s={title} /></span>
      {note && <span className="wk-sec-note"><Txt s={note} /></span>}
    </>
  );
  return fold ? (
    <button type="button" className="wf-sec wk-sec is-fold" aria-expanded={fold.open} onClick={fold.toggle}>{inner}</button>
  ) : (
    <div className="wf-sec wk-sec">{inner}</div>
  );
};

/* ★ Which foldable blocks the reader closed, by title. Kept outside the panel's state: the script redraws the
     panel on every change and a fold must not spring open each time. */
const folded = new Map<string, boolean>();

const Buttons: React.FC<{ actions?: BlockAction[]; itemId?: string | number; ctx: Ctx }> = ({ actions, itemId, ctx }) =>
  actions?.length ? (
    <>
      {actions.map((a) => (
        <button
          key={a.id}
          type="button"
          className={cls('wf-btn', a.danger && 'wk-danger')}
          disabled={a.disabled}
          onClick={() => ctx.onAction(a.id, itemId)}
        >
          {a.icon && <span className="wk-btn-ico"><KitIcon icon={a.icon} /></span>}
          <Txt s={a.label} />
        </button>
      ))}
    </>
  ) : null;

const dotState = (d?: string) => (d === 'ok' || d === 'warn' || d === 'bad' ? d : d ? 'custom' : undefined);
const Dot: React.FC<{ dot?: string }> = ({ dot }) => {
  if (!dot) return null;
  const state = dotState(dot);
  return <span className="wk-dot" data-state={state} style={state === 'custom' ? { background: dot } : undefined} />;
};

/* ── the blocks themselves ── */

/** The subject of the panel, stated once at the top -- a kingdom's crest, the screen being run. */
const Hero: React.FC<{ block: Block }> = ({ block }) => {
  const name = block.value ?? block.title;
  const crest = toPalette(block.color, READING_TONES) || undefined;
  return (
    <div className="wk-hero">
      <Slot big image={block.image} icon={block.icon ?? 'menu_icon_rank'} crest={crest} />
      <div className="wk-hero-text">
        {block.value && block.title && <div className="wf-kicker"><Txt s={block.title} /></div>}
        <div className="wf-h"><Txt s={name} /></div>
        {(block.subtitle || block.tag) && (
          <div className="wk-tagline">
            {block.tag && <span className={cls('wk-state', block.tagBad && 'is-bad')}><Txt s={block.tag} /></span>}
            {block.subtitle && <span className="wf-sub"><Txt s={block.subtitle} /></span>}
          </div>
        )}
      </div>
    </div>
  );
};

/** Plain facts as tiles, the value over its label; balanced rows of up to five. */
const Stats: React.FC<{ items: Item[] }> = ({ items }) => {
  const n = items.length;
  const cols = n <= 5 ? Math.max(1, n) : Math.ceil(n / Math.ceil(n / 5));
  return (
    <div className="wk-stats" style={{ gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))` }}>
      {items.map((it, i) => (
        <div className="wk-stat" key={`${it.label}-${i}`}>
          <span className="wk-stat-v">
            {it.icon && <span className="wk-ico"><KitIcon icon={it.icon} /></span>}
            <Txt s={it.value ?? '—'} />
          </span>
          <span className="wf-label"><Txt s={it.label} /></span>
        </div>
      ))}
    </div>
  );
};

const Bars: React.FC<{ items: Item[] }> = ({ items }) => (
  <div className="wk-bars">
    {items.map((it, i) => (
      <div className="wk-barrow" key={`${it.label}-${i}`}>
        <span className="wf-label"><Txt s={it.label} /></span>
        <Gauge value={it.progress} critical={it.danger} />
      </div>
    ))}
  </div>
);

/** What it is made of / costs: picture, name, amount. A shortage is marked under the amount. */
const Requirements: React.FC<{ items: Item[] }> = ({ items }) => (
  <div className="wk-reqs">
    {items.map((it, i) => (
      <div className={cls('wk-req', it.danger && 'is-missing')} key={`${it.label}-${i}`}>
        <Slot image={it.image} icon={it.icon} />
        <span className="wk-req-name"><Txt s={it.label} /></span>
        {it.value != null && <span className="wk-req-amount wf-num">{it.value}</span>}
      </div>
    ))}
  </div>
);

/* ── a number box that can be typed into: it keeps its own text, the script gets every change ──
 * ! Every input here used to be controlled by the script's value only, and React put that value back after each
 *   keystroke. The field keeps its own text while the panel is open; a NEW value from the script wins. */
const RowInput: React.FC<{ input: NonNullable<Item['input']>; ctx: Ctx }> = ({ input, ctx }) => {
  const external = input.value;
  const [text, setText] = React.useState<string>(external == null ? '' : String(external));
  React.useEffect(() => { setText(external == null ? '' : String(external)); }, [external]);
  return (
    <input
      type="number"
      className="wf-input is-num wk-rowinput"
      dir="ltr"
      value={text}
      min={input.min}
      max={input.max}
      step={input.step}
      /* ★ select all on focus: the amount is replaced, not appended to */
      onFocus={(e) => e.currentTarget.select()}
      onChange={(e) => {
        setText(e.target.value);
        ctx.onField(input.id, Number(e.target.value));
      }}
    />
  );
};

const Rows: React.FC<{ items: Item[]; ctx: Ctx }> = ({ items, ctx }) => (
  <div className="wk-lines">
    {items.map((it, i) => (
      <div className={cls('wk-line', it.disabled && 'is-off')} key={it.id ?? `${it.label}-${i}`}>
        <Slot image={it.image} icon={it.icon} />
        <span className="wk-line-main">
          <span className="wk-line-name"><Dot dot={it.dot} /><Txt s={it.label} /></span>
          {it.sub && <span className="wk-line-sub"><Txt s={it.sub} /></span>}
        </span>
        <span className="wk-line-end">
          {it.input && <RowInput input={it.input} ctx={ctx} />}
          {it.value != null && <span className={cls('wk-line-value', it.danger && 'is-bad')}><Txt s={it.value} /></span>}
          <Buttons actions={it.actions} itemId={it.id} ctx={ctx} />
        </span>
      </div>
    ))}
  </div>
);

/** A real table -- logs, transactions, bids -- on a grid so its columns line up with everything around it. */
const Table: React.FC<{ block: Block }> = ({ block }) => {
  const cols = block.columns ?? [];
  const template = cols.map(() => 'minmax(0, 1fr)').join(' ');
  return (
    <div className="wk-table">
      <div className="wk-thead" style={{ gridTemplateColumns: template }}>
        {cols.map((c) => <span key={c.key} style={{ textAlign: c.align ?? 'start' }}><Txt s={c.label} /></span>)}
      </div>
      {(block.rows ?? []).map((row, i) => (
        <div className="wk-trow" key={i} style={{ gridTemplateColumns: template }}>
          {cols.map((c) => (
            <span key={c.key} style={{ textAlign: c.align ?? 'start' }} dir={c.align === 'end' ? 'ltr' : undefined}>
              <Txt s={row[c.key]} />
            </span>
          ))}
        </div>
      ))}
    </div>
  );
};

/** A grid of pickable cards (picked = the red mark under it), or a wrap of chips (picked = the red band). */
const Cards: React.FC<{ items: Item[]; ctx: Ctx; chips?: boolean }> = ({ items, ctx, chips }) => (
  <div className={chips ? 'wk-chips' : 'wk-cards'}>
    {items.map((it, i) => {
      const on = it.id != null && it.id === ctx.selected;
      return chips ? (
        <button
          key={it.id ?? `${it.label}-${i}`}
          type="button"
          className={cls('wf-btn', on && 'is-on')}
          disabled={it.disabled || it.id == null}
          onClick={() => it.id != null && ctx.onPick?.(it.id)}
        >
          <Dot dot={it.dot} />
          {it.icon && <span className="wk-btn-ico"><KitIcon icon={it.icon} /></span>}
          <Txt s={it.label} />
          {it.value != null && <b className="wf-num">{it.value}</b>}
        </button>
      ) : (
        <button
          key={it.id ?? `${it.label}-${i}`}
          type="button"
          className={cls('wk-card', on && 'is-on')}
          disabled={it.disabled}
          onClick={() => it.id != null && ctx.onPick?.(it.id)}
        >
          <Slot image={it.image} icon={it.icon} />
          <span className="wk-line-main">
            <span className="wk-line-name"><Dot dot={it.dot} /><Txt s={it.label} /></span>
            {(it.sub || it.value != null) && (
              <span className="wk-line-sub">
                <Txt s={it.sub} />
                {it.sub && it.value != null ? ' · ' : ''}
                {it.value != null && <b className="wf-num">{it.value}</b>}
              </span>
            )}
          </span>
          {it.danger && <span className="wk-card-flag" />}
        </button>
      );
    })}
  </div>
);

/* ── a form field that can be typed into (it keeps its own text; a new value from the script wins) ── */
const FormField: React.FC<{ field: Field; ctx: Ctx }> = ({ field, ctx }) => {
  const { rtl, t } = useKit();
  const external = field.value;
  const [text, setText] = React.useState<string>(String(external ?? ''));
  const [checked, setChecked] = React.useState<boolean>(Boolean(external));

  React.useEffect(() => {
    setText(String(external ?? ''));
    setChecked(Boolean(external));
  }, [external]);

  const report = (v: string) => { setText(v); ctx.onField(field.id, v); };
  const label = field.label ? <span className="wf-label"><Txt s={field.label} /></span> : null;

  if (field.type === 'checkbox') {
    return (
      <button
        type="button"
        className={cls('wf-switch-row', 'wk-switch', field.disabled && 'is-locked')}
        disabled={field.disabled}
        aria-pressed={checked}
        onClick={() => {
          const next = !checked;
          setChecked(next);
          ctx.onField(field.id, next);
        }}
      >
        <span><Txt s={field.label} /></span>
        <span className="wf-switch" data-on={checked ? 'true' : 'false'}>{checked ? t('on') : t('off')}</span>
      </button>
    );
  }

  let control: React.ReactNode;
  if (field.type === 'select') {
    /* the page's own dropdown: a native <select> opens a popup the game paints as noise (components/WSelect) */
    control = (
      <span className="wk-selectbox">
        <WSelect
          value={text}
          options={(field.options ?? []).map((o) => (o.label != null ? { ...o, label: latinDigits(String(o.label)) } : o))}
          disabled={field.disabled}
          ariaLabel={field.label}
          searchable={field.searchable}
          searchPlaceholder={field.placeholder}
          grid={field.grid}
          onChange={report}
        />
      </span>
    );
  } else if (field.type === 'hexcolor') {
    control = (
      <span className="wk-selectbox wk-hexbox">
        <HexColourField value={text} placeholder={field.placeholder} disabled={field.disabled} ariaLabel={field.label} labels={field.labels} onChange={report} />
      </span>
    );
  } else if (field.type === 'textarea') {
    control = (
      <textarea
        className="wf-input wf-textarea"
        dir="auto"
        value={text}
        placeholder={field.placeholder}
        disabled={field.disabled}
        onChange={(e) => report(e.target.value)}
      />
    );
  } else if (field.type === 'date') {
    // ★ Day, month by name, year (components/DateFields): the same "YYYY-MM-DD" the native box reported.
    control = <DateFields value={text} rtl={rtl} label={field.label} disabled={field.disabled} onChange={report} />;
  } else if (field.type === 'color') {
    // ★ The palette's eight tones, not the machine's full-spectrum picker (components/PaletteField).
    control = <div className="wk-field-host"><PaletteField value={text} rtl={rtl} label={field.label} disabled={field.disabled} onChange={report} /></div>;
  } else {
    const isNumber = field.type === 'number';
    const free = !field.type || field.type === 'text';
    control = (
      <input
        className={cls('wf-input', !free && 'is-num')}
        type={isNumber ? 'number' : field.type === 'time' ? 'time' : 'text'}
        dir={free ? 'auto' : 'ltr'}
        value={text}
        placeholder={field.placeholder}
        min={field.min}
        max={field.max}
        step={field.step}
        disabled={field.disabled}
        spellCheck={false}
        onFocus={isNumber ? (e) => e.currentTarget.select() : undefined}
        onChange={(e) => {
          setText(e.target.value);
          ctx.onField(field.id, isNumber ? Number(e.target.value) : e.target.value);
        }}
      />
    );
  }

  /* ⚠️ A colour row is not a <label>: a click on a label's text is forwarded to the first control inside it,
        which for the swatches would pick the first tone, and for the wheel would open the box. */
  const Row = field.type === 'color' || field.type === 'hexcolor' || field.type === 'date' || field.type === 'select' ? 'div' : 'label';
  return (
    <Row className="wf-field">
      {label}
      {control}
    </Row>
  );
};

/* ★ A form may carry a picture above its fields and its own buttons below them. */
const Form: React.FC<{ block: Block; ctx: Ctx }> = ({ block, ctx }) => {
  const fields = block.fields ?? [];
  const allSwitches = fields.length > 0 && fields.every((f) => f.type === 'checkbox');
  return (
    <>
      {block.image && (
        <div className="wk-image wk-form-image">
          <img src={block.image} alt="" style={{ height: `calc(${Math.max(24, Math.min(400, block.height ?? 90))} * var(--ws-px))`, width: 'auto', maxWidth: '100%' }} />
        </div>
      )}
      <div className={cls('wf-grid', 'wk-form-grid', allSwitches && 'is-switches')}>
        {fields.map((f) => (
          <div key={f.id} className={cls('wk-form-cell', (f.type === 'textarea' || f.type === 'color' || f.type === 'hexcolor') && 'is-wide')}>
            <FormField field={f} ctx={ctx} />
          </div>
        ))}
      </div>
      {block.actions?.length ? <div className="wf-btns wk-form-btns"><Buttons actions={block.actions} ctx={ctx} /></div> : null}
    </>
  );
};

const Body: React.FC<{ block: Block; ctx: Ctx }> = ({ block, ctx }) => {
  const items = block.items ?? [];
  switch (block.type) {
    case 'hero': return <Hero block={block} />;
    case 'text': return block.value ? <p className="wk-text"><Txt s={block.value} /></p> : null;
    case 'stats': return <Stats items={items} />;
    case 'bars': return <Bars items={items} />;
    case 'requirements': return <Requirements items={items} />;
    case 'rows': return <Rows items={items} ctx={ctx} />;
    case 'table': return <Table block={block} />;
    case 'cards': return <Cards items={items} ctx={ctx} />;
    case 'chips': return <Cards items={items} ctx={ctx} chips />;
    case 'form': return <Form block={block} ctx={ctx} />;
    case 'actions': return <div className="wf-btns"><Buttons actions={block.actions} ctx={ctx} /></div>;
    /* ★ A picture shown whole, not an icon in a slot: a script's preview (a name plate, a card face) is wide. */
    case 'image': {
      if (!block.image) return null;
      const h = Math.max(24, Math.min(400, block.height ?? 120));
      return (
        <div className="wk-image">
          <img
            src={block.image}
            alt={block.value ?? ''}
            style={block.fill ? { height: `calc(${h} * var(--ws-px))`, width: 'auto', maxWidth: '100%' } : { maxHeight: `calc(${h} * var(--ws-px))` }}
          />
        </div>
      );
    }
    default: return null;
  }
};

const Blocks: React.FC<{ blocks?: Block[]; ctx: Ctx }> = ({ blocks, ctx }) => {
  const [, redraw] = React.useReducer((n: number) => n + 1, 0);
  if (!blocks?.length) return null;

  return (
    <div className="wk-blocks">
      {blocks.map((block, i) => {
        const foldKey = block.collapsible && block.title ? block.title : null;
        const open = foldKey ? !(folded.get(foldKey) ?? !!block.collapsed) : true;
        const fold = foldKey ? { open, toggle: () => { folded.set(foldKey, open); redraw(); } } : undefined;
        // a hero's heading IS its name, so it draws no ruled heading above itself
        const heading = block.type === 'hero' ? null : <Heading title={block.title} note={block.note} fold={fold} />;
        return (
          <section
            key={i}
            className={cls('wk-block', `is-${block.type}`, (block.span ?? 12) <= 6 && 'is-narrow')}
            style={{ gridColumn: `span ${Math.min(12, Math.max(1, Math.round(block.span ?? 12)))}` }}
          >
            {heading}
            {open && <Body block={block} ctx={ctx} />}
          </section>
        );
      })}
    </div>
  );
};

/** The amount an action asks for (how many, a bid): minus, the value, plus, on the kit's stepper. */
export const AmountField: React.FC<{
  spec: { min?: number; max?: number; step?: number; placeholder?: string };
  label: string;
  value: number;
  onChange: (value: number) => void;
}> = ({ spec, label, value, onChange }) => {
  const step = spec.step ?? 1;
  const clamp = (n: number) =>
    Math.min(spec.max ?? Number.MAX_SAFE_INTEGER, Math.max(spec.min ?? 0, Number.isFinite(n) ? n : spec.min ?? 0));
  return (
    <div className="wk-amount">
      <span className="wf-label"><Txt s={label} /></span>
      <div className="wf-stepper" dir="ltr">
        <button type="button" className="wf-stepper-arrow" aria-label="-" onClick={() => onChange(clamp(value - step))}>
          <span className="wk-pm">−</span>
        </button>
        <input
          className="wk-num-input"
          type="number"
          value={value}
          min={spec.min}
          max={spec.max}
          step={step}
          placeholder={spec.placeholder}
          onFocus={(e) => e.currentTarget.select()}
          onChange={(e) => onChange(clamp(Number(e.target.value)))}
        />
        <button type="button" className="wf-stepper-arrow" aria-label="+" onClick={() => onChange(clamp(value + step))}>
          <span className="wk-pm">+</span>
        </button>
      </div>
    </div>
  );
};

export default Blocks;
