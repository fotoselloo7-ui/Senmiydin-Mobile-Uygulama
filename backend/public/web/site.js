/**
 * SenMiydin Public Web Experience Script
 * Handles automatic hero quote sliding, dot navigation, smooth transitions, and scroll effects.
 */
(() => {
  'use strict';

  const quotes = [
    {
      loc: 'İstanbul · Kadıköy',
      title: 'Bugün vapurda karşılaştığımız kişi...',
      text: '“Sarı montlu, kitap okuyan ve vapurda karşı koltukta oturan sen miydin?”'
    },
    {
      loc: 'İstanbul · İstiklal',
      title: 'Nostaljik tramvay durağındaki o an...',
      text: '“Kırmızı tramvayın yanında göz göze geldiğimiz, sarı montlu ve gülümseyen sen miydin?”'
    },
    {
      loc: 'İstanbul · Moda',
      title: 'Sahil kafesinde tebessüm eden o kişi...',
      text: '“Köşe masada oturup aynı anda kahvemizi yudumladığımız sen miydin?”'
    },
    {
      loc: 'İstanbul · Karaköy',
      title: 'Akşam vapurunda gün batımını izlerken...',
      text: '“Martılara simit atarken göz göze geldiğimiz, sıcak bakışlı sen miydin?”'
    }
  ];

  function initHeroCarousel() {
    const card = document.querySelector('.hero-photo-card');
    const dots = document.querySelectorAll('.carousel-dots .dot');
    if (!card || !dots.length) return;

    const slideInner = card.querySelector('.quote-slide-inner');
    const locEl = card.querySelector('.quote-location');
    const titleEl = card.querySelector('.quote-title');
    const textEl = card.querySelector('.quote-text');

    let idx = 0;
    let timer = null;
    let isTransitioning = false;

    function render(i, immediate = false) {
      if (isTransitioning && !immediate) return;
      const nextIdx = (i + quotes.length) % quotes.length;
      if (nextIdx === idx && !immediate) return;

      const q = quotes[nextIdx];
      idx = nextIdx;

      // Update dots immediately
      dots.forEach((dot, dIdx) => {
        dot.classList.toggle('active', dIdx === idx);
      });

      if (immediate || !slideInner) {
        if (locEl) {
          locEl.innerHTML = `<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg> ${q.loc}`;
        }
        if (titleEl) titleEl.textContent = q.title;
        if (textEl) textEl.textContent = q.text;
        return;
      }

      isTransitioning = true;
      slideInner.classList.add('slide-out');

      setTimeout(() => {
        if (locEl) {
          locEl.innerHTML = `<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="#7C20D4" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg> ${q.loc}`;
        }
        if (titleEl) titleEl.textContent = q.title;
        if (textEl) textEl.textContent = q.text;

        slideInner.classList.remove('slide-out');
        slideInner.classList.add('slide-in');

        // Force browser reflow
        void slideInner.offsetWidth;

        slideInner.classList.remove('slide-in');
        isTransitioning = false;
      }, 220);
    }

    function startAuto() {
      stopAuto();
      timer = setInterval(() => {
        render(idx + 1);
      }, 4500);
    }

    function stopAuto() {
      if (timer) {
        clearInterval(timer);
        timer = null;
      }
    }

    dots.forEach((dot, dIdx) => {
      dot.addEventListener('click', () => {
        render(dIdx);
        startAuto();
      });
    });

    card.addEventListener('mouseenter', stopAuto);
    card.addEventListener('mouseleave', startAuto);

    startAuto();
  }

  function initHeaderScroll() {
    const header = document.querySelector('.site-header');
    if (!header) return;

    function onScroll() {
      if (window.scrollY > 16) {
        header.classList.add('is-scrolled');
      } else {
        header.classList.remove('is-scrolled');
      }
    }

    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
      initHeroCarousel();
      initHeaderScroll();
    });
  } else {
    initHeroCarousel();
    initHeaderScroll();
  }
})();
