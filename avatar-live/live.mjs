// 台本を VOICEVOX で読み上げ、音声の大きさに合わせてアバターの口を動かす。
// 使い方: node live.mjs   （stream.sh から起動される）
import { chromium } from 'playwright';
import { readFileSync, writeFileSync } from 'node:fs';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const dir = path.dirname(fileURLToPath(import.meta.url));
const VOICEVOX = process.env.VOICEVOX_URL ?? 'http://127.0.0.1:50021';
const SPEAKER = process.env.VOICEVOX_SPEAKER ?? '8';   // 8 = 春日部つむぎ
const SINK = process.env.PULSE_SINK ?? 'live_sink';
const lines = JSON.parse(readFileSync(path.join(dir, 'script.json'), 'utf8'));

async function synth(text) {
  const q = await (await fetch(`${VOICEVOX}/audio_query?speaker=${SPEAKER}&text=${encodeURIComponent(text)}`, { method: 'POST' })).json();
  const res = await fetch(`${VOICEVOX}/synthesis?speaker=${SPEAKER}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(q),
  });
  return Buffer.from(await res.arrayBuffer());
}

// 16bit PCM wav から 50ms ごとの音量(0..1)を作る
function envelope(wav) {
  const rate = wav.readUInt32LE(24), ch = wav.readUInt16LE(22);
  const pcm = new Int16Array(wav.buffer.slice(wav.byteOffset + 44, wav.byteOffset + wav.length - ((wav.length - 44) % 2)));
  const win = Math.floor(rate * ch * 0.05), env = [];
  for (let i = 0; i < pcm.length; i += win) {
    let s = 0, n = 0;
    for (let j = i; j < Math.min(i + win, pcm.length); j++) { s += pcm[j] ** 2; n++; }
    env.push(Math.min(1, Math.sqrt(s / n) / 6000));
  }
  return env;
}

const browser = await chromium.launch({ headless: false, args: ['--no-sandbox', '--start-fullscreen', '--kiosk'] });
const page = await browser.newPage({ viewport: { width: 720, height: 1280 } }); // 縦型
await page.goto('file://' + path.join(dir, 'avatar.html'));

for (;;) {
  for (const text of lines) {
    const wav = await synth(text);
    const file = '/tmp/live_line.wav';
    writeFileSync(file, wav);
    const env = envelope(wav);
    await page.evaluate(t => setCaption(t), text);
    const player = spawn('paplay', ['--device', SINK, file], { stdio: 'ignore' });
    const done = new Promise(r => player.on('close', r));
    for (const v of env) { await page.evaluate(v => setMouth(v), v); await new Promise(r => setTimeout(r, 50)); }
    await done;
    await page.evaluate(() => setMouth(0));
    await new Promise(r => setTimeout(r, 1500));
  }
}
