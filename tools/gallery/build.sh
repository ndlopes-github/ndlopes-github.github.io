#!/usr/bin/env bash
# Build the simulation gallery from clips.tsv:
#   1. fetch each source (Arquivo.pt capture of the 2011 site, YouTube, or a local file),
#   2. encode it into media/gallery/<id>.mp4 plus a poster <id>.jpg,
#   3. regenerate the HTML between <!-- gallery:begin --> and <!-- gallery:end --> in index.html.
#
# Usage:  tools/gallery/build.sh          encode clips not yet in media/gallery, rewrite the HTML
#         FORCE=1 tools/gallery/build.sh  re-encode everything (after changing a crop, say)
# Sources are cached in ${GALLERY_CACHE:-$HOME/.cache/mywebpage-gallery}.
# bak: sources are read from the local backup of the 2011 site, ${GALLERY_BACKUP} (default below).
# Needs curl, ffmpeg/ffprobe, awk, and yt-dlp for yt: sources.
#
# clips.tsv columns (tab-separated, header line first):
#   id  group  src  crop  maxframes  dark  title  meta
#   src       arq:<path under ~ndl/ on the 2011 site> | bak:<same path, in the local backup> | yt:<video id> | file:<path, ~ allowed>
#   crop      ffmpeg crop w:h:x:y in source pixels (w, h even), applied before scaling; further
#             filters may follow after a comma, e.g. "w:h:x:y,transpose=1" to turn a clip clockwise
#   maxframes keep only the first N source frames (0 = all); used for truncated captures
#   dark      1 = black plate behind the clip (for videos with a black background)
#   title, meta  inserted into the HTML verbatim: do not use <, > or &.
#   poster    optional 9th column: where to take the poster, as a fraction of the clip (default 0.6).
#             It needs a non-empty meta: read collapses consecutive tabs, so an empty meta would shift it.
set -euo pipefail
export LC_ALL=C

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
out="$root/media/gallery"
cache="${GALLERY_CACHE:-$HOME/.cache/mywebpage-gallery}"
backup="${GALLERY_BACKUP:-/media/nuno/Warehouse/TOSHIBA/BackUP/mywebpages/public_html}"
mkdir -p "$out" "$cache"

maxdur=30    # s: longer clips are sped up to this length...
mindur=8     # s: ...and shorter ones slowed down to this length...
maxspeed=4   # ...but either way by at most 4x
width=480    # px: tiles display at ~270 px, so 480 covers ~1.8x screens
crf=30

fetch() {  # src -> path of a local copy
  local src=$1 f
  case $src in
    arq:*)  f="$cache/arq_$(printf '%s' "${src#arq:}" | tr '/' '_')"
            [ -s "$f" ] || curl -sfL -m 900 -o "$f" "https://arquivo.pt/wayback/2011id_/http://ptmat.fc.ul.pt/~ndl/${src#arq:}" ;;
    bak:*)  f="$backup/${src#bak:}"
            [ -s "$f" ] || { echo "not in the backup (is it mounted?): $f" >&2; return 1; } ;;
    yt:*)   f="$cache/yt_${src#yt:}.mp4"
            [ -s "$f" ] || yt-dlp -q --no-warnings -f 'bv*[height<=720][ext=mp4]/b[height<=720]' -o "$f" "https://www.youtube.com/watch?v=${src#yt:}" ;;
    file:*) f="${src#file:}"; f="${f/#\~/$HOME}" ;;
    *)      echo "unknown source: $src" >&2; return 1 ;;
  esac
  printf '%s\n' "$f"
}

encode() {  # input id crop maxframes posterfraction
  local in=$1 id=$2 crop=$3 maxf=$4 pf=$5 rate n dur speed od
  rate=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$in")
  # Count decodable frames: Arquivo.pt truncated some captures at 10 MB.
  n=$(ffmpeg -nostdin -v quiet -i "$in" -map 0:v:0 -f null - -progress pipe:1 | awk -F= '/^frame=/{f=$2} END{print f+0}')
  if [ "$maxf" -gt 0 ] && [ "$maxf" -lt "$n" ]; then n=$maxf; fi
  dur=$(awk -v n="$n" -v r="$rate" 'BEGIN{split(r, a, "/"); print n * a[2] / a[1]}')
  speed=$(awk -v d="$dur" -v m="$maxdur" -v l="$mindur" -v s="$maxspeed" 'BEGIN{
    x = d / m; if (x < 1) x = 1; if (x > s) x = s
    if (d < l) { x = d / l; if (x < 1 / s) x = 1 / s }
    print x}')
  ffmpeg -nostdin -v error -y -i "$in" -an \
    -vf "trim=end_frame=$n,setpts=PTS-STARTPTS,crop=$crop,setpts=PTS/$speed,fps=24,scale='min($width,iw)':-2:flags=lanczos,format=yuv420p" \
    -c:v libx264 -preset slow -crf "$crf" -movflags +faststart "$out/$id.mp4"
  od=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out/$id.mp4")
  ffmpeg -nostdin -v error -y -ss "$(awk -v d="$od" -v f="$pf" 'BEGIN{print d * f}')" -i "$out/$id.mp4" -frames:v 1 -q:v 4 "$out/$id.jpg"
  printf '  %-22s %5d frames  %5.1f s source  x%-4s -> %6d bytes\n' "$id" "$n" "$dur" "$speed" "$(stat -c %s "$out/$id.mp4")" >&2
}

heading() {
  case $1 in
    waves) echo "Water waves" ;;
    flows) echo "Incompressible Navier–Stokes flows" ;;
    molding) echo "Water-assisted injection molding" ;;
    tagus) echo "Transport in the Tagus estuary" ;;
    races) echo "Urban running races" ;;
    *)     echo "$1" ;;
  esac
}

grep -q '<!-- gallery:begin -->' "$root/index.html" && grep -q '<!-- gallery:end -->' "$root/index.html" \
  || { echo "index.html lacks the gallery markers" >&2; exit 1; }

html=$(mktemp)
trap 'rm -f "$html" "$root/index.html.tmp"' EXIT
group=""
while IFS=$'\t' read -r id grp src crop maxf dark title meta poster <&3; do
  if [ -n "${FORCE:-}" ] || [ ! -s "$out/$id.mp4" ]; then
    encode "$(fetch "$src")" "$id" "$crop" "$maxf" "${poster:-0.6}"
  fi
  if [ "$grp" != "$group" ]; then
    if [ -n "$group" ]; then printf '  </div>\n  </div>\n'; fi
    printf '  <div class="group">\n  <h3 class="eyebrow">%s</h3>\n  <div class="tiles">\n' "$(heading "$grp")"
    group=$grp
  fi
  wh=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$out/$id.mp4")
  w=${wh%x*}; h=${wh#*x}
  plate="plate"; if [ "$dark" = 1 ]; then plate="plate dark"; fi
  link=""; if [[ $src == yt:* ]]; then link="<a href=\"https://www.youtube.com/watch?v=${src#yt:}\">YouTube</a>"; [ -n "$meta" ] && link=" · $link"; fi
  cat <<EOF
    <figure class="tile" data-topics="$grp">
      <div class="$plate"><video class="clip" muted loop playsinline controls preload="none" width="$w" height="$h"
        poster="media/gallery/$id.jpg" aria-label="Animation: $title"><source src="media/gallery/$id.mp4" type="video/mp4"></video></div>
      <figcaption>$title<span class="m">$meta$link</span></figcaption>
    </figure>
EOF
done 3< <(tail -n +2 "$here/clips.tsv") > "$html"
printf "  </div>\n  </div>\n" >> "$html"

awk -v f="$html" '
  /<!-- gallery:begin -->/ { print; while ((getline line < f) > 0) print line; skip = 1; next }
  /<!-- gallery:end -->/   { skip = 0 }
  !skip                    { print }
' "$root/index.html" > "$root/index.html.tmp"
mv "$root/index.html.tmp" "$root/index.html"
rm -f "$html"
echo "gallery: $(tail -n +2 "$here/clips.tsv" | wc -l) clips, $(du -sh "$out" | cut -f1) in media/gallery"
