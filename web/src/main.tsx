import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import './index.css';
import './wc/wc-base.css';
import './wc/wc.css';
import './wc/lib-ui.css';
import { bootstrapWcAssets } from './wc/bootstrap';
import { initButtonSfx, preloadSfx } from './wc/sound';
import App from './App';
import { fas } from '@fortawesome/free-solid-svg-icons';
import { far } from '@fortawesome/free-regular-svg-icons';
import { fab } from '@fortawesome/free-brands-svg-icons';
import { library } from '@fortawesome/fontawesome-svg-core';
import { isEnvBrowser } from './utils/misc';
import LocaleProvider from './providers/LocaleProvider';
import ConfigProvider from './providers/ConfigProvider';
import ErrorBoundary from './providers/errorBoundary';

library.add(fas, far, fab);

/* ⚠️ Before React renders. The textures are CSS variables on documentElement, and a component
   that paints before they exist draws an empty frame and never repaints it. */
bootstrapWcAssets();
preloadSfx();
initButtonSfx();



const root = document.getElementById('root');

createRoot(root!).render(
  <StrictMode>
    <LocaleProvider>
      <ConfigProvider>
        <ErrorBoundary>
          <App />
        </ErrorBoundary>
      </ConfigProvider>
    </LocaleProvider>
  </StrictMode>
);
