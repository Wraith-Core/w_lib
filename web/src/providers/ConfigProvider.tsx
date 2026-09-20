import { Context, createContext, useContext, useEffect, useState } from 'react';
import { MantineColor } from '@mantine/core';
import { postNui } from '../utils/postNui';

interface Config {
  primaryColor: MantineColor;
  primaryShade: 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9;
}

interface ConfigCtxValue {
  config: Config;
  setConfig: (config: Config) => void;
}

const ConfigCtx = createContext<{ config: Config; setConfig: (config: Config) => void } | null>(null);

const ConfigProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [config, setConfig] = useState<Config>({
    primaryColor: 'wraith',
    primaryShade: 1,
  });

  useEffect(() => {
    /**
     * ⚠️ Guarded, and non-fatal. A resource borrowing this frame through its own ui_page has no
     *    'getConfig' callback, so the reply is empty and postNui hands back null -- assigning
     *    that would wipe the defaults above and leave every accented control unstyled. Keeping
     *    ours is the correct answer to 'the owner has no opinion'.
     */
    postNui<Config>('getConfig').then((data) => {
      if (data) setConfig(data);
    });
  }, []);

  return <ConfigCtx.Provider value={{ config, setConfig }}>{children}</ConfigCtx.Provider>;
};

export default ConfigProvider;

export const useConfig = () => useContext<ConfigCtxValue>(ConfigCtx as Context<ConfigCtxValue>);
