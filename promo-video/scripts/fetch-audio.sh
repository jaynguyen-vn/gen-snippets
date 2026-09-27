#!/usr/bin/env bash
# Rebuilds public/music and public/sfx from Mixkit. The files are licensed for
# use inside the rendered video, not for redistribution, so they stay out of git.
# Needs curl and ffmpeg.
set -euo pipefail

OUT_DIR="${OUT_DIR:-$(cd "$(dirname "$0")/.." && pwd)/public}"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/fetch-audio.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$OUT_DIR/music" "$OUT_DIR/sfx"

# "Other World" by Lily J (Mixkit Stock Music Free License).
curl -fsSL -o "$OUT_DIR/music/other-world.mp3" "https://assets.mixkit.co/music/723/723.mp3"

# Sound effects (Mixkit Sound Effects Free License): trim to the hit, fade the
# tail, peak-normalise to -3 dBFS. Columns: name, Mixkit id, start, end, fade-out.
while read -r name id start end fade; do
  src="$TMP/$id.mp3"
  [ -f "$src" ] || curl -fsSL -o "$src" "https://assets.mixkit.co/active_storage/sfx/${id}/${id}-preview.mp3"
  cut="$TMP/${name}.wav"
  ffmpeg -v error -y -i "$src" \
    -af "atrim=start=${start}:end=${end},asetpts=PTS-STARTPTS,afade=t=in:d=0.002,areverse,afade=t=in:d=${fade},areverse" \
    -ac 1 -ar 44100 -c:a pcm_s16le "$cut"
  peak=$(ffmpeg -i "$cut" -af volumedetect -f null - 2>&1 | sed -n 's/.*max_volume: \(-\{0,1\}[0-9.]*\) dB.*/\1/p')
  gain=$(awk -v p="$peak" 'BEGIN { printf "%.2f", -3.0 - p }')
  ffmpeg -v error -y -i "$cut" -af "volume=${gain}dB" -c:a pcm_s16le "$OUT_DIR/sfx/${name}.wav"
  echo "sfx/${name}.wav  (Mixkit ${id}, gain ${gain} dB)"
done <<'EOF'
key-1 2533 0.000 0.180 0.03
key-2 2534 0.005 0.200 0.03
key-3 2534 0.215 0.420 0.03
key-4 2534 0.434 0.620 0.03
key-hard 2542 0.100 0.310 0.04
pop-expand 3005 0.005 0.180 0.03
pop-panel 2356 0.025 0.300 0.05
pop-word 2358 0.020 0.480 0.08
whoosh 1490 0.240 0.900 0.12
sparkle 2350 0.030 3.500 0.40
EOF

echo "music/other-world.mp3"
