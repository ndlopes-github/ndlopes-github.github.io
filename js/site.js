// Site behaviour. Everything degrades gracefully: without JavaScript the abstracts and BibTeX
// are shown inline, the filters are hidden, and videos keep native controls.
(() => {
  // ---- publications: Abstract / BibTeX panels and the Copy button
  document.addEventListener("click", (e) => {
    const tog = e.target.closest(".tog");
    if (tog) {
      const panel = document.getElementById(tog.getAttribute("aria-controls"));
      const open = tog.getAttribute("aria-expanded") !== "true";
      tog.setAttribute("aria-expanded", String(open));
      panel.classList.toggle("open", open);
      return;
    }
    const copy = e.target.closest(".copy");
    if (copy) {
      const code = copy.parentElement.querySelector("code");
      const done = (msg) => { copy.textContent = msg; setTimeout(() => { copy.textContent = "Copy"; }, 1500); };
      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(code.textContent).then(() => done("Copied"), () => done("Select and copy"));
      } else {  // file:// or old browsers: select the text so Ctrl+C works
        const r = document.createRange(); r.selectNodeContents(code);
        const s = getSelection(); s.removeAllRanges(); s.addRange(r);
        done("Selected");
      }
    }
  });

  // ---- topic filters: <div class="filters" data-scope="#id"> with .chip[data-topic];
  //      items carry data-topics="a b"; a .pubgroup/.group with no visible item is hidden
  for (const bar of document.querySelectorAll(".filters")) {
    const scope = document.querySelector(bar.dataset.scope);
    if (!scope) continue;
    const chips = bar.querySelectorAll(".chip");
    bar.addEventListener("click", (e) => {
      const chip = e.target.closest(".chip");
      if (!chip) return;
      const t = chip.dataset.topic;
      for (const c of chips) {
        const on = c === chip;
        c.classList.toggle("on", on);
        c.setAttribute("aria-pressed", String(on));
      }
      for (const it of scope.querySelectorAll("[data-topics]")) {
        it.hidden = !(t === "all" || it.dataset.topics.split(" ").includes(t));
        if (it.hidden) for (const v of it.querySelectorAll("video")) v.pause();
      }
      for (const g of scope.querySelectorAll(".pubgroup, .group")) {
        g.hidden = !g.querySelector("[data-topics]:not([hidden])");
      }
    });
  }

  if (!("IntersectionObserver" in window)) return;

  // ---- research-card animations (video.anim): muted loops that play only while on screen, so
  //      nothing downloads before a clip is visible (preload="none"). Reduced-motion visitors get
  //      the poster and native controls. A clip the visitor paused stays paused.
  const anims = document.querySelectorAll("video.anim");
  if (anims.length && !window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    const io = new IntersectionObserver((entries) => {
      for (const { target: v, isIntersecting } of entries) {
        if (isIntersecting) {
          if (!v.dataset.userPaused) v.play().catch(() => {});
        } else if (!v.paused) {
          v.dataset.autoPause = "1";
          v.pause();
        }
      }
    }, { threshold: 0.35 });
    for (const v of anims) {
      v.addEventListener("pause", () => {
        if (v.dataset.autoPause) delete v.dataset.autoPause;
        else v.dataset.userPaused = "1";
      });
      v.addEventListener("play", () => { delete v.dataset.userPaused; });
      io.observe(v);
    }
  }

  // ---- gallery clips (video.clip): click-to-play tiles (Enter/Space too); one plays at a time,
  //      and a playing clip pauses when it scrolls out of view.
  const clips = document.querySelectorAll("video.clip");
  if (clips.length) {
    document.documentElement.classList.add("js-clips");
    const away = new IntersectionObserver((entries) => {
      for (const { target: v, isIntersecting } of entries) if (!isIntersecting && !v.paused) v.pause();
    }, { threshold: 0 });
    for (const v of clips) {
      const plate = v.parentElement;
      const tile = v.closest(".tile");
      const name = (v.getAttribute("aria-label") || "").replace(/^Animation: /, "");
      v.controls = false;
      plate.tabIndex = 0;
      plate.setAttribute("role", "button");
      plate.setAttribute("aria-label", "Play: " + name);
      const toggle = () => (v.paused ? v.play().catch(() => {}) : v.pause());
      plate.addEventListener("click", toggle);
      plate.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === " ") { e.preventDefault(); toggle(); }
      });
      v.addEventListener("play", () => {
        for (const o of clips) if (o !== v && !o.paused) o.pause();
        tile.classList.add("playing");
        plate.setAttribute("aria-label", "Pause: " + name);
      });
      v.addEventListener("pause", () => {
        tile.classList.remove("playing");
        plate.setAttribute("aria-label", "Play: " + name);
      });
      away.observe(v);
    }
  }
})();
