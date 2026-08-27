/** Formate des secondes en `HH:MM:SS,mmm` (timing SRT). */
export function toSrtTime(seconds) {
  const clamped = Math.max(0, seconds);
  const ms = Math.round((clamped % 1) * 1000);
  const total = Math.floor(clamped);
  const h = String(Math.floor(total / 3600)).padStart(2, '0');
  const m = String(Math.floor((total % 3600) / 60)).padStart(2, '0');
  const s = String(total % 60).padStart(2, '0');
  return `${h}:${m}:${s},${String(ms).padStart(3, '0')}`;
}

/** `1.5` -> `"1.500"` : ffmpeg veut un point decimal, jamais de notation exponentielle. */
export function ffSeconds(seconds) {
  return Math.max(0, seconds).toFixed(3);
}
