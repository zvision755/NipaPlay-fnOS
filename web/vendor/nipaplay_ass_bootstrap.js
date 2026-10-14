import JASSUB from './jassub/jassub.js';

let renderer;

function assFontFamilies(subContent) {
  const families = new Set();
  let styleFields = [];
  let inStyleSection = false;
  for (const line of subContent.split(/\r?\n/)) {
    if (line.startsWith('[')) {
      inStyleSection = /^\[V4(?:\+)? Styles\]$/i.test(line.trim());
      styleFields = [];
      continue;
    }
    if (!inStyleSection) continue;
    if (/^Format:/i.test(line)) {
      styleFields = line.slice(line.indexOf(':') + 1).split(',').map((field) => field.trim().toLowerCase());
      continue;
    }
    if (!/^Style:/i.test(line) || styleFields.length === 0) continue;
    const fontIndex = styleFields.indexOf('fontname');
    const styleValues = line.slice(line.indexOf(':') + 1).split(',');
    if (fontIndex >= 0 && styleValues[fontIndex]?.trim()) families.add(styleValues[fontIndex].trim());
  }
  return families;
}

window.nipaPlayAssAttach = async (video, subContent) => {
  if (renderer) {
    await renderer.destroy();
    renderer = undefined;
  }
  const fontUrl = new URL('../assets/assets/subfont.ttf', import.meta.url).href;
  const availableFonts = Object.fromEntries(
    [...assFontFamilies(subContent)].map((family) => [family, fontUrl]),
  );
  renderer = new JASSUB({
    video,
    subContent,
    workerUrl: new URL('./jassub/worker.js', import.meta.url).href,
    wasmUrl: new URL('./jassub/jassub-worker.wasm', import.meta.url).href,
    modernWasmUrl: new URL('./jassub/jassub-worker-modern.wasm', import.meta.url).href,
    fonts: [fontUrl],
    availableFonts,
    defaultFont: 'Droid Sans Fallback',
    queryFonts: false,
    prescaleHeightLimit: 1080,
  });
  await renderer.ready;
};
window.nipaPlayAssDetach = async () => {
  if (!renderer) return;
  const current = renderer;
  renderer = undefined;
  await current.destroy();
};
