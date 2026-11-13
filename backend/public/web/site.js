/**
 * SenMiydin public web: story slider and mobile menu.
 * No external dependencies. Auto-advance can be paused and respects reduced motion.
 */
(() => {
  'use strict';

  function initSlider(root) {
    const slides = [...root.querySelectorAll('.hs-slide')];
    const dots = [...root.querySelectorAll('.hs-dot')];
    const pause = root.querySelector('[data-pause]');
    if (slides.length < 2) return;

    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    let index = 0;
    let timer = null;
    let userPaused = reduced;
    let hovering = false;

    function show(next) {
      index = (next + slides.length) % slides.length;
      slides.forEach((slide, i) => {
        const active = i === index;
        slide.classList.toggle('is-active', active);
        slide.setAttribute('aria-hidden', active ? 'false' : 'true');
        const img = slide.querySelector('img[loading="lazy"]');
        if (img && active) img.loading = 'eager';
      });
      dots.forEach((dot, i) => {
        dot.classList.toggle('is-active', i === index);
        if (i === index) dot.setAttribute('aria-current', 'true');
        else dot.removeAttribute('aria-current');
      });
    }

    function stop() {
      if (timer) { clearInterval(timer); timer = null; }
    }

    function start() {
      stop();
      if (userPaused || hovering || document.hidden) return;
      timer = setInterval(() => show(index + 1), 5200);
    }

    function setPaused(value) {
      userPaused = value;
      if (pause) {
        pause.setAttribute('aria-pressed', String(value));
        pause.setAttribute('aria-label', value ? 'Otomatik geçişi başlat' : 'Otomatik geçişi duraklat');
      }
      start();
    }

    dots.forEach((dot) => dot.addEventListener('click', () => {
      show(Number(dot.dataset.index));
      start();
    }));
    if (pause) pause.addEventListener('click', () => setPaused(!userPaused));

    root.addEventListener('mouseenter', () => { hovering = true; stop(); });
    root.addEventListener('mouseleave', () => { hovering = false; start(); });
    root.addEventListener('focusin', () => { hovering = true; stop(); });
    root.addEventListener('focusout', () => { hovering = false; start(); });
    document.addEventListener('visibilitychange', start);

    // Touch swipe
    let startX = null;
    root.addEventListener('touchstart', (e) => { startX = e.touches[0].clientX; }, { passive: true });
    root.addEventListener('touchend', (e) => {
      if (startX === null) return;
      const delta = e.changedTouches[0].clientX - startX;
      startX = null;
      if (Math.abs(delta) > 40) { show(index + (delta < 0 ? 1 : -1)); start(); }
    }, { passive: true });

    root.addEventListener('keydown', (e) => {
      if (e.key === 'ArrowRight') { show(index + 1); start(); }
      if (e.key === 'ArrowLeft') { show(index - 1); start(); }
    });

    if (reduced && pause) setPaused(true);
    else start();
  }

  function initMenu() {
    const inner = document.querySelector('.header-inner');
    const toggle = inner && inner.querySelector('.nav-toggle');
    if (!toggle) return;

    function set(open) {
      inner.classList.toggle('nav-open', open);
      toggle.setAttribute('aria-expanded', String(open));
      toggle.setAttribute('aria-label', open ? 'Menüyü kapat' : 'Menüyü aç');
    }

    toggle.addEventListener('click', () => set(!inner.classList.contains('nav-open')));
    inner.querySelectorAll('nav a').forEach((link) => link.addEventListener('click', () => set(false)));
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && inner.classList.contains('nav-open')) { set(false); toggle.focus(); }
    });
    // Tap outside the open menu closes it.
    document.addEventListener('click', (e) => {
      if (inner.classList.contains('nav-open') && !inner.contains(e.target)) set(false);
    });
    window.matchMedia('(min-width: 901px)').addEventListener('change', (e) => { if (e.matches) set(false); });
  }

  function initHeaderScroll() {
    const header = document.querySelector('.site-header');
    if (!header) return;
    const onScroll = () => header.classList.toggle('is-scrolled', window.scrollY > 16);
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
  }

  function init() {
    document.querySelectorAll('[data-slider]').forEach(initSlider);
    initMenu();
    initHeaderScroll();
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
