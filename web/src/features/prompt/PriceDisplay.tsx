import React from 'react';
import { Price, PricePart } from './types';

const STRINGS = { devise: '$', free: 'Free' };

/** Whole numbers stay whole; anything else shows two decimals. */
const formatPrice = (value: number) => (value % 1 === 0 ? String(value) : value.toFixed(2));

/** The part before the decimal point -- or the word for nothing, when it costs nothing. */
const priceRounded = (value?: number) => (!value ? STRINGS.free : Math.trunc(value));

/** The part after it, as bare digits -- the stylesheet draws the rule above them. */
const centimes = (value?: number) => {
  if (value === undefined || value === 0) return '';
  return (value % 1).toFixed(2).slice(2);
};

const devise = (value: number) => (value === 0 ? '' : STRINGS.devise);

const hasImage = (part: PricePart) => Boolean(part.image && part.image.length > 0);

/** An item shows its name unless it has both a picture and a tooltip to carry the name. */
const displayLabel = (part: PricePart) => !part.tooltip || !hasImage(part);

/**
 * ⚠️ Only a real nui:// or http:// address is used. A bare filename would resolve against this
 *    page and 404 into a broken-image glyph, so anything without a scheme falls back to the
 *    generic item icon -- a wrong picture beats a missing one in a price the player is reading.
 */
const getImage = (url?: string) => (url && url.includes('://') ? url : './assets/images/icons/item.png');

const quantityStyle = (part: PricePart) => (hasImage(part) ? part.quantityStyle : undefined);

/** Items first, then gold, then money -- so a mixed price always reads in the same order. */
const sortItems = (parts: PricePart[]) =>
  [...parts].sort((a, b) => {
    if (a.item && !b.item) return -1;
    if (b.item && !a.item) return 1;
    if (a.gold && !b.gold) return -1;
    if (b.gold && !a.gold) return 1;
    if (a.money && !b.money) return -1;
    if (b.money && !a.money) return 1;
    return 0;
  });

const Money: React.FC<{ value: number }> = ({ value }) => (
  <span className="dollar">
    <span className="devise">{devise(value)}</span>
    <span className="round">{priceRounded(value)}</span>
    <span className="centime">{centimes(value)}</span>
  </span>
);

const Gold: React.FC<{ value: number }> = ({ value }) => (
  <span className="gold">
    <span className="icon">
      <img src="./assets/images/gold.png" alt="" />
    </span>
    {formatPrice(value)}
  </span>
);

const PriceDisplay: React.FC<{ price: Price; right?: boolean }> = ({ price, right }) => {
  if (price === undefined || price === false) return null;

  const className = `priceDisplay${right ? ' priceRight' : ''}`;

  /* ── a list of parts: items, gold and money added together ───────────── */
  if (Array.isArray(price)) {
    if (price.length === 1 && price[0].money === 0) {
      return (
        <div className={className}>
          <span>{priceRounded(0)}</span>
        </div>
      );
    }

    return (
      <div className={className}>
        {sortItems(price).map((part, index) => (
          <React.Fragment key={index}>
            <div className="price-item">
              {part.gold ? (
                <Gold value={part.gold} />
              ) : part.money && part.money > 0 ? (
                <Money value={part.money} />
              ) : part.item ? (
                <span className={`item${displayLabel(part) ? ' with-label' : ''}`}>
                  {quantityStyle(part) === 'circle' ? (
                    <span
                      className="circle-quantity"
                      dangerouslySetInnerHTML={{ __html: String(part.quantity || 1) }}
                    />
                  ) : (
                    <span className="quantity">{part.quantity || 1} x </span>
                  )}
                  <div className="icon">
                    {hasImage(part) && <img src={getImage(part.image)} alt="" />}
                    {displayLabel(part) && (
                      <span className="label" dangerouslySetInnerHTML={{ __html: part.label ?? '' }} />
                    )}
                  </div>
                </span>
              ) : null}
            </div>
            {index < price.length - 1 && <span className="plus">+</span>}
          </React.Fragment>
        ))}
      </div>
    );
  }

  /* ── a single price: a bare number, or one object with money and/or gold ── */
  const single = typeof price === 'number' ? undefined : price;
  const money = typeof price === 'number' ? price : 'money' in price ? price.money : undefined;

  return (
    <div className={className}>
      <div className="monetary">
        {single?.gold ? <Gold value={single.gold} /> : null}
        {money !== undefined && money !== null ? <Money value={money} /> : null}
      </div>
    </div>
  );
};

export default PriceDisplay;
