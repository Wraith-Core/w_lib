/* The store frame on a panel that scrolls.
   store-theme.css draws the frame (.wst-frame / .wc-frame) as position:absolute; inset:0 inside its panel.
   When the PANEL itself is the scroll box, that box is only as tall as the visible part and scrolls away
   with the content: scrolled down, the border stopped half way and the bottom edge was gone.
   This keeps every such frame over the visible part: on each scroll it is moved down by scrollTop.
   One passive listener for the whole page (scroll does not bubble: it is caught on the way down).
   * And a panel that scrolls gets .wst-scrolls (store-theme.css: up and down only). Its texture
     (.wst-panel::before) reaches 6px past each side, and in a box that scrolls those 6px were a sideways
     scroll - the thin bar under the panel. Checked when the page's elements change, once a frame.
   Load it once per page:  <script src="https://cfx-nui-w_lib/nui/assets/store-frame.js"></script>
   (store-theme-bridge.js carries the same lines for the bundles it skins.) */
(() => {
  'use strict';
  if (window.__wstFrameFollow) return;
  window.__wstFrameFollow = true;
  const FRAME = '.wst-frame,.wc-frame,.ws-frame';
  document.addEventListener('scroll', (event) => {
    const panel = event.target;
    if (!(panel instanceof Element)) return;
    for (const node of panel.children) {
      if (node.matches(FRAME)) node.style.transform = panel.scrollTop ? `translateY(${panel.scrollTop}px)` : '';
    }
  }, { capture: true, passive: true });

  const mark = () => {
    for (const panel of document.querySelectorAll('.wst-panel')) {
      const y = getComputedStyle(panel).overflowY;
      panel.classList.toggle('wst-scrolls', y === 'auto' || y === 'scroll');
    }
  };
  let queued = false;
  const schedule = () => { if (!queued) { queued = true; requestAnimationFrame(() => { queued = false; mark(); }); } };
  const start = () => { mark(); new MutationObserver(schedule).observe(document.body, { childList: true, subtree: true }); };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, { once: true }); else start();
})();
