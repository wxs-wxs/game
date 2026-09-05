const fs = require('fs');
const path = require('path');

const SAMPLE_RATE = 44100;
const OUT_DIR = path.resolve(__dirname, '..', 'artifacts', 'audio_preview');
fs.mkdirSync(OUT_DIR, { recursive: true });

function clamp(value, min = -1, max = 1) {
  return Math.max(min, Math.min(max, value));
}

function seededRandom(seed) {
  let state = seed >>> 0;
  return () => {
    state = (1664525 * state + 1013904223) >>> 0;
    return (state / 0x100000000) * 2 - 1;
  };
}

function envelope(t, duration, attack = 0.005, release = 0.08) {
  if (t < 0 || t >= duration) return 0;
  const attackGain = attack > 0 ? Math.min(1, t / attack) : 1;
  const releaseStart = Math.max(0, duration - release);
  const releaseGain = t > releaseStart ? Math.max(0, (duration - t) / release) : 1;
  return attackGain * releaseGain;
}

function addTone(buffer, start, duration, startFreq, endFreq, amplitude, wave = 'sine', harmonics = 0) {
  const startSample = Math.max(0, Math.floor(start * SAMPLE_RATE));
  const sampleCount = Math.floor(duration * SAMPLE_RATE);
  let phase = 0;
  for (let i = 0; i < sampleCount && startSample + i < buffer.length; i += 1) {
    const t = i / SAMPLE_RATE;
    const ratio = sampleCount <= 1 ? 1 : i / (sampleCount - 1);
    const freq = startFreq * Math.pow(endFreq / startFreq, ratio);
    phase += (Math.PI * 2 * freq) / SAMPLE_RATE;
    const base = wave === 'triangle'
      ? (2 / Math.PI) * Math.asin(Math.sin(phase))
      : wave === 'square' ? Math.sign(Math.sin(phase)) : Math.sin(phase);
    const harmonic = harmonics ? 0.25 * Math.sin(phase * 2.01) : 0;
    buffer[startSample + i] += (base + harmonic) * amplitude * envelope(t, duration);
  }
}

function addNoise(buffer, start, duration, amplitude, seed, lowpass = 0.18) {
  const random = seededRandom(seed);
  const startSample = Math.max(0, Math.floor(start * SAMPLE_RATE));
  const sampleCount = Math.floor(duration * SAMPLE_RATE);
  let filtered = 0;
  for (let i = 0; i < sampleCount && startSample + i < buffer.length; i += 1) {
    const t = i / SAMPLE_RATE;
    const raw = random();
    filtered += (raw - filtered) * lowpass;
    buffer[startSample + i] += filtered * amplitude * envelope(t, duration, 0.001, Math.min(0.08, duration * 0.6));
  }
}

function writeWav(filePath, channels) {
  const channelCount = channels.length;
  const frameCount = channels[0].length;
  const dataSize = frameCount * channelCount * 2;
  const headerSize = 44;
  const output = Buffer.alloc(headerSize + dataSize);
  output.write('RIFF', 0, 'ascii');
  output.writeUInt32LE(36 + dataSize, 4);
  output.write('WAVE', 8, 'ascii');
  output.write('fmt ', 12, 'ascii');
  output.writeUInt32LE(16, 16);
  output.writeUInt16LE(1, 20);
  output.writeUInt16LE(channelCount, 22);
  output.writeUInt32LE(SAMPLE_RATE, 24);
  output.writeUInt32LE(SAMPLE_RATE * channelCount * 2, 28);
  output.writeUInt16LE(channelCount * 2, 32);
  output.writeUInt16LE(16, 34);
  output.write('data', 36, 'ascii');
  output.writeUInt32LE(dataSize, 40);

  let offset = headerSize;
  for (let i = 0; i < frameCount; i += 1) {
    for (let channel = 0; channel < channelCount; channel += 1) {
      const sample = Math.round(clamp(channels[channel][i]) * 32767);
      output.writeInt16LE(sample, offset);
      offset += 2;
    }
  }
  fs.writeFileSync(filePath, output);
}

function normalize(channels, peak = 0.92) {
  let max = 0;
  for (const channel of channels) {
    for (const sample of channel) max = Math.max(max, Math.abs(sample));
  }
  if (max <= 0) return;
  const gain = peak / max;
  for (const channel of channels) {
    for (let i = 0; i < channel.length; i += 1) channel[i] *= gain;
  }
}

function writeMono(name, duration, build) {
  const buffer = new Float32Array(Math.ceil(duration * SAMPLE_RATE));
  build(buffer, duration);
  normalize([buffer]);
  writeWav(path.join(OUT_DIR, name), [buffer]);
}

function writeStereo(name, duration, build) {
  const left = new Float32Array(Math.ceil(duration * SAMPLE_RATE));
  const right = new Float32Array(left.length);
  build(left, right, duration);
  normalize([left, right]);
  writeWav(path.join(OUT_DIR, name), [left, right]);
}

writeMono('ui_click.wav', 0.14, (buffer) => {
  addTone(buffer, 0, 0.12, 920, 1480, 0.58, 'sine', 1);
  addTone(buffer, 0.012, 0.055, 1800, 1100, 0.16, 'triangle');
});

writeMono('item_pickup.wav', 0.42, (buffer) => {
  addTone(buffer, 0.00, 0.16, 660, 710, 0.28, 'sine', 1);
  addTone(buffer, 0.10, 0.17, 880, 950, 0.28, 'sine', 1);
  addTone(buffer, 0.20, 0.21, 1320, 1420, 0.24, 'sine', 1);
  addTone(buffer, 0.25, 0.11, 1760, 1520, 0.10, 'triangle');
});

writeMono('footstep_dirt.wav', 0.20, (buffer) => {
  addTone(buffer, 0, 0.17, 125, 62, 0.52, 'sine');
  addNoise(buffer, 0, 0.15, 0.34, 0x1492a7, 0.34);
  addNoise(buffer, 0.025, 0.08, 0.15, 0x78c31f, 0.08);
});

writeMono('player_hit.wav', 0.32, (buffer) => {
  addTone(buffer, 0, 0.25, 190, 48, 0.62, 'saw');
  addNoise(buffer, 0, 0.11, 0.66, 0xcafe12, 0.42);
  addTone(buffer, 0.005, 0.045, 720, 240, 0.20, 'square');
});

writeStereo('camp_night_loop.wav', 8.0, (left, right, duration) => {
  const noiseL = seededRandom(0x63f0a1);
  const noiseR = seededRandom(0x8d24b7);
  const count = left.length;
  let filteredL = 0;
  let filteredR = 0;
  for (let i = 0; i < count; i += 1) {
    const t = i / SAMPLE_RATE;
    const wind = 0.48 + 0.20 * Math.sin(Math.PI * 2 * t / duration) + 0.08 * Math.sin(Math.PI * 2 * t / 2.7);
    filteredL += (noiseL() - filteredL) * 0.012;
    filteredR += (noiseR() - filteredR) * 0.012;
    const lowHum = 0.08 * Math.sin(Math.PI * 2 * 78 * t) + 0.035 * Math.sin(Math.PI * 2 * 117 * t + 0.7);
    left[i] = filteredL * wind + lowHum;
    right[i] = filteredR * wind + lowHum * 0.82;
  }
  const chirps = [1.25, 3.85, 6.45];
  for (const start of chirps) {
    for (let n = 0; n < 4; n += 1) {
      addTone(left, start + n * 0.105, 0.045, 2700 + n * 90, 3300 + n * 110, 0.09, 'sine');
      addTone(right, start + n * 0.105 + 0.014, 0.045, 2850 + n * 90, 3450 + n * 110, 0.09, 'sine');
    }
  }
  const crossfadeSamples = Math.floor(0.08 * SAMPLE_RATE);
  for (let i = 0; i < crossfadeSamples; i += 1) {
    const amount = i / crossfadeSamples;
    const tailIndex = count - crossfadeSamples + i;
    left[tailIndex] = left[tailIndex] * (1 - amount) + left[i] * amount;
    right[tailIndex] = right[tailIndex] * (1 - amount) + right[i] * amount;
  }
});

const manifest = {
  generated_by: 'tools/generate_audio_preview.js',
  sample_rate_hz: SAMPLE_RATE,
  format: 'PCM 16-bit WAV',
  files: [
    { file: 'ui_click.wav', use: '菜单或按钮点击', duration_seconds: 0.14 },
    { file: 'item_pickup.wav', use: '拾取资源或道具', duration_seconds: 0.42 },
    { file: 'footstep_dirt.wav', use: '泥土地面脚步', duration_seconds: 0.20 },
    { file: 'player_hit.wav', use: '角色受击', duration_seconds: 0.32 },
    { file: 'camp_night_loop.wav', use: '营地夜晚循环环境音', duration_seconds: 8.0, loop: true },
  ],
};
fs.writeFileSync(path.join(OUT_DIR, 'manifest.json'), JSON.stringify(manifest, null, 2));
console.log(`Generated ${manifest.files.length} WAV previews in ${OUT_DIR}`);
