// a data: picture too (a script that read a file itself, w_tribes' blip: one the page may tint)
export const isIconUrl = (icon: string) => icon.startsWith('data:image/') || icon.includes('://') || icon.includes('.png') || icon.includes('.webp');
