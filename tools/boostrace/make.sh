#!/usr/bin/env bash
# Regenerate media/race-boostrace.{mp4,jpg} from the published BoostRace notebook.
# Usage: tools/boostrace/make.sh [JLRace.ipynb] [output dir]
# Needs julia, jq, ffmpeg, ImageMagick. Takes about 3 minutes (simulation ~100 s, rendering ~50 s).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
nb="${1:-$HOME/DrWatsonProjects/BoostRace/JLRace.ipynb}"
out="${2:-$here/../../media}"
work="$(mktemp -d)"
echo "work dir: $work"

# Model = notebook code cells 0..51 (53 is the training run, 55 the race, later cells are plots).
jq -r '.cells | to_entries[] | select(.value.cell_type=="code" and .key <= 51) | (.value.source|join("")) + "\n"' "$nb" > "$work/model.jl"
# Julia >= 1.12 rejects re-assigning a const global; cell 23 re-assigns coursename to the same value.
sed -i 's|^coursename=parameters.coursename|# &|' "$work/model.jl"
cp "$here/sim.jl" "$here/render.jl" "$work/"

julia --project="$here" -e 'using Pkg; Pkg.instantiate()'
julia --project="$here" "$work/sim.jl"
julia --project="$here" "$work/render.jl"

ffmpeg -v error -y -framerate 30 -i "$work/frames/f%04d.png" \
  -vf "tpad=stop_mode=clone:stop_duration=1,format=yuv420p" \
  -c:v libx264 -preset slow -crf 26 -tune animation -movflags +faststart -an "$out/race-boostrace.mp4"
convert "$work/frames/f0090.png" -strip -quality 82 "$out/race-boostrace.jpg"
echo "wrote $out/race-boostrace.mp4 and .jpg"
