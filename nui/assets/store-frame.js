/* The store frame on a panel that scrolls.
   store-theme.css draws the frame (.wst-frame / .wc-frame) as position:absolute; inset:0 inside its panel.
   When the PANEL itself is the scroll box, that box is only as tall as the visible part and scrolls away
   with the content: scrolled down, the border stopped half way and the bottom edge was gone.
   This keeps every such frame over the visible part: on each scroll it is moved down by scrollTop.
   One passive listener for the whole page (scroll does not bubble: it is caught on the way down).
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
})();
