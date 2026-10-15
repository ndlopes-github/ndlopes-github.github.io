# MyWebPage — personal research website

Successor to the 2011 org-mode page (archived: https://arquivo.pt/wayback/20110707033620/http://cmaf.ptmat.fc.ul.pt/~ndl/).

## Shape

- Static, single page in a "modern academic" style (system sans-serif, topic-coloured venue badges). **No external requests and no tracking.** The page is served as-is; the generators under `tools/` only rewrite marked blocks of `index.html`.
- `js/site.js` opens and closes the Abstract/BibTeX panels (with Copy), runs the topic filters (publications and gallery), and plays the clips. Everything degrades without JavaScript: the panels show inline, the filters hide, and videos keep native controls. An inline `<script>` in `<head>` adds the `js` class that the CSS keys on.
- `index.html` — all content. `css/style.css` — all styling (colour tokens on `:root`, topic colours `--t-*`, dark mode via `prefers-color-scheme`, print styles). `media/` — research-card animations and posters; `media/gallery/` — the gallery. `tools/` — generators and media provenance (`tools/README.md`). `favicon.svg`. `.nojekyll` so GitHub Pages serves files as-is.
- Hosting target (not yet deployed): GitHub Pages user site `ndlopes-github.github.io`. The canonical URL, Open Graph tags and JSON-LD in `<head>` assume this URL. Update them if the hosting changes.

## Sources of truth for content

1. `~/WorkRepos/CV/NunoLopesCV_English.tex` (and the PT version `NunoLopesCV.tex`).
2. ORCID public API: `curl -s -H 'Accept: application/json' https://pub.orcid.org/v3.0/0000-0001-9577-0347/works | jq ...`
3. Crossref (`https://api.crossref.org/works/<doi>`) for titles, author order, volume/issue/pages; DataCite for Zenodo DOIs.

When the sources disagree, the publisher record wins (Crossref, or the PDF itself). Examples: the ICCE 2022 author list, and the COSE 2026 author order and DOI, which ORCID lacks.

## Conventions

- Naming: the title is **Assistant Professor** (never "Adjunct Professor"), and ISEL belongs to the **Polytechnic University of Lisbon** (no longer "Polytechnic of Lisbon").
- **Publications are generated.** Edit `tools/pubs/pubs.toml`, then run `julia tools/pubs/build.jl`. It rewrites the blocks between `<!-- pubs:begin -->`/`<!-- pubs:end -->` and `<!-- review:begin -->`/`<!-- review:end -->` and builds the BibTeX from the TOML fields. Never hand-edit those blocks. Entries are newest first within each section and keep stable ids (`p-` journal, `c-` chapter, `b-` book, `k-` proceedings, `r-` report, `t-` thesis, `s-` under review; `w-` for the hand-written software-in-development entry). Papers under review sit in **Work in progress** (`#wip`); on acceptance, change `section` and add the year, DOI and bib fields. Abstracts come only from verifiable sources (Crossref, the published PDF, or the authors' final LaTeX), noted in a comment per entry; never paraphrase or invent one.
- Topics, used by the filters and badge colours: `waves`, `coastal`, `flows`, `industry`, `other`.
- No typeset equations on the research cards: they were tried and removed (user decision, Oct 2026), as they did not add information there.
- Always render the self-name as `<span class="me">N.&nbsp;D.&nbsp;Lopes</span>`. Use `&nbsp;` between initials. Use en dashes in page ranges.
- Paper titles go in the publisher's original language and wording. Supervision titles follow the English CV.
- The **News** list (in About) holds 3–4 dated items. Prune it whenever adding something, since a stale news box was the 2011 page's failure mode.
- Prose uses American spelling, matching the CV. Quoted titles keep their own spelling.
- No CV link: the full record is on ORCID (user decision, Oct 2026). The `ndlopes-github/CV` repository is private; never link to it.
- Link only **public** repositories. Do not publish personal data: no phone number, date of birth or student grades (the CV has all three).
- Gallery captions carry no years; the exact date is not relevant (user decision, Oct 2026). The gallery intro gives the periods: Navier–Stokes and Tagus convection–diffusion 2003–2007, Boussinesq-type waves up to 2012. YouTube upload years (2016) are not computation years.
- Race animations come only from the public BoostRace (`tools/boostrace/`, notebook `origin/main:JLRace.ipynb`), never from the private BoostRace2 or its `legacy/` track (user decision, Oct 2026).
- Do not add talk slides or other old PDFs (theses, reports) from the 2011 site or its backup (user decision, Oct 2026).
- Gallery: `tools/gallery/clips.tsv` holds one row per clip (source, crop, caption). `tools/gallery/build.sh` encodes new rows into `media/gallery/` and rewrites the HTML between `<!-- gallery:begin -->` and `<!-- gallery:end -->`. Never hand-edit that block. Keep each group a multiple of 3 so the desktop grid has no orphan tiles.
- Animations: self-hosted, muted H.264 MP4 with a JPG poster, markup `<video class="anim" muted loop playsinline controls preload="none" poster=…>`. Keep native `controls` so visitors can pause (WCAG 2.2.2). Crop away solver labels and colour-bar panels, and keep each clip under ~2 MB. Record the source and the ffmpeg settings in `tools/README.md`.
- Local backup of the 2011 site (machine with the Warehouse drive): `/media/nuno/Warehouse/TOSHIBA/BackUP/mywebpages/public_html`. It holds all ~250 films at full length (Arquivo.pt truncated at 10 MB), the org/latex2html pages that describe them, talk slides (2006–2012) and both theses. `build.sh` reads it through `bak:` sources.
- OpenFOAM (MathMould project) on the same drive: `/media/nuno/Warehouse/nuno_folder_backup_23_02_2024/OpenFoam_v2006/` (cases and ParaView GIFs); the 3D runs are in `/media/nuno/Warehouse/SharedMathMould` (121 GB). The GitHub repositories `mathMould_Case1/2` are private: do not link them. The 2022 ISEL seminar folder `/media/nuno/Warehouse/TALK_DF_2_5_2022/` also has pre-paper BoostRace videos (`UrbanRaces/race1.mp4`, `race_hist.mp4`).
- More material: about 60 simulations on YouTube (channel `UCFvEkGMsP_IoCOwNkKcReyA`, 2016) and about 40 MP4s from the 2011 site preserved on Arquivo.pt (`https://arquivo.pt/wayback/2011id_/http://ptmat.fc.ul.pt/~ndl/<path>`; index at `list_m.html`). `~/scripts/yt-dlp` (2026.06) gets HTTP 403 on most YouTube videos; it needs updating before more downloads.

## Previewing

Open `index.html` directly in a browser. For headless screenshots, snap Firefox can only read and write under `$HOME`, so use a profile in `~/snap/firefox/common/`:

```
firefox --headless --no-remote --profile ~/snap/firefox/common/<prof> --window-size=1280,14000 --screenshot ~/snap/firefox/common/<out>.png file:///home/nuno/WorkRepos/ndlopes-github.github.io/index.html
```

For dark mode, put `user_pref("ui.systemUsesDarkTheme", 1);` in the profile's `user.js`. ImageMagick refuses images taller than 16000 px.

## Link-check notes (Oct 2026)

- When checked with curl, Wiley, AIP, Zenodo, ResearchGate and LinkedIn return 403/302/999. That is bot-blocking; the DOIs were checked through Crossref and DataCite instead.
- `cienciavitae.pt` was unreachable from this machine, so its URL is unverified. The URL used is the one on the GitHub profile README.
- DOLFWAVE's Bitbucket workspace returns 404. Launchpad (`launchpad.net/dolfwave`) is still up.
