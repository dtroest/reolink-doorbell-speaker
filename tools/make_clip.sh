#!/usr/bin/env bash
# Cut a doorbell clip from a longer audio file: trim, fade in/out, match loudness.
#
#   ./make_clip.sh input.mp3 START END output.mp3 [TARGET_MEAN_DB]
#   ./make_clip.sh song.mp3 12.4 26.0 doorbell_default.mp3
#
# Tips that made a real difference:
#   - Start and end in a quiet gap in the music. A cut mid-note sounds broken on a
#     small speaker.
#   - Keep it under ~15 s. The doorbell mutes its own microphone while playing, so a
#     long clip means you can't hear the visitor.
#   - All clips at the same mean loudness (default -22 dB) so holiday sounds aren't
#     suddenly louder than the normal one.
#   - The doorbell plays 8 kHz mono (phone quality). Bass disappears, so pick clips
#     where the melody sits in the mid range.
set -euo pipefail

in=$1; start=$2; end=$3; out=$4; target=${5:--22}
dur=$(echo "$end - $start" | bc -l)
fade_out_start=$(echo "$dur - 0.6" | bc -l)

tmp=$(mktemp --suffix=.wav)
trap 'rm -f "$tmp"' EXIT

ffmpeg -hide_banner -loglevel error -y -ss "$start" -t "$dur" -i "$in" \
  -af "afade=t=in:d=0.03,afade=t=out:st=${fade_out_start}:d=0.6" "$tmp"

mean=$(ffmpeg -hide_banner -i "$tmp" -af volumedetect -f null - 2>&1 \
  | sed -n 's/.*mean_volume: \(-\?[0-9.]*\) dB.*/\1/p')
gain=$(echo "$target - ($mean)" | bc -l)

ffmpeg -hide_banner -loglevel error -y -i "$tmp" -af "volume=${gain}dB" \
  -codec:a libmp3lame -q:a 2 "$out"

echo "$out: ${dur}s, mean ${mean} dB -> ${target} dB (gain ${gain} dB)"
