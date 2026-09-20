// Will return whether the current environment is in a regular browser
// and not CEF / NUI (RedM CEF does not have invokeNative; it defines GetParentResourceName)
export const isEnvBrowser = (): boolean =>
  !Boolean((window as any).GetParentResourceName || (window as any).invokeNative);

// Basic no operation function
export const noop = () => {};
