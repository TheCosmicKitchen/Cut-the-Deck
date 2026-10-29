// Seeded RNG (mulberry32). The seed lives in plain state ({ seed: int }) so
// runs replay exactly and the same sequence can be reproduced in GDScript.

export function rand(s) {
  let t = (s.seed = (s.seed + 0x6d2b79f5) | 0);
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}

export function randInt(s, n) {
  return Math.floor(rand(s) * n);
}

export function pick(s, arr) {
  return arr.length ? arr[randInt(s, arr.length)] : undefined;
}

export function shuffle(s, arr) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = randInt(s, i + 1);
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}
