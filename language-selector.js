/* Disclosure and equivalent-page routing. Only generated/approved pages are available. */
(() => {
  const selector = document.querySelector('header .language-selector');
  if (!selector) return;
  const toggle = selector.querySelector('.language-toggle');
  const options = selector.querySelector('.language-options');
  const close = () => {
    toggle.setAttribute('aria-expanded', 'false');
    options.hidden = true;
  };
  toggle.addEventListener('click', () => {
    const open = toggle.getAttribute('aria-expanded') !== 'true';
    toggle.setAttribute('aria-expanded', String(open));
    options.hidden = !open;
  });
  selector.addEventListener('keydown', event => {
    if (event.key === 'Escape') {
      close();
      toggle.focus();
    }
  });
  document.addEventListener('click', event => {
    if (!selector.contains(event.target)) close();
  });
  document.addEventListener('focusin', event => {
    if (!selector.contains(event.target)) close();
  });
  window.matchMedia('(max-width: 850px)').addEventListener('change', close);

  fetch('/locales/availability.json', { cache: 'no-store' })
    .then(response => {
      if (!response.ok) throw new Error('Language availability unavailable');
      return response.json();
    })
    .then(manifest => {
      if (manifest.schemaVersion !== 1 || !manifest.languages || !manifest.pages) return;
      const segments = window.location.pathname.split('/').filter(Boolean);
      const currentLanguage = Object.keys(manifest.languages).find(code =>
        manifest.languages[code] && manifest.languages[code] === segments[0]
      ) || 'en';
      if (currentLanguage !== 'en') segments.shift();
      const page = segments.join('/') || 'index.html';
      const equivalents = manifest.pages[page];
      if (!equivalents) return;
      options.querySelectorAll('[data-language]').forEach(existing => {
        const code = existing.dataset.language;
        const current = code === currentLanguage;
        const destination = equivalents[code];
        const element = document.createElement(current ? 'span' : 'button');
        for (const attribute of existing.attributes) element.setAttribute(attribute.name, attribute.value);
        element.replaceChildren(...existing.childNodes);
        element.classList.toggle('is-active', current);
        element.removeAttribute('aria-current');
        element.removeAttribute('disabled');
        element.removeAttribute('type');
        if (current) {
          element.setAttribute('aria-current', 'true');
          const flag = element.querySelector('img');
          if (flag) toggle.querySelector('img').src = flag.src;
          if (currentLanguage !== 'en') {
            for (const name of ['title', 'aria-label']) {
              const label = element.getAttribute(name);
              if (label) element.setAttribute(name, label.replace(/\s*[\u2014\u2013-]\s*coming soon$/i, ''));
            }
            const label = element.getAttribute('title') || code;
            toggle.title = label;
            toggle.setAttribute('aria-label', element.getAttribute('aria-label') || label);
          }
        } else {
          element.type = 'button';
          element.disabled = !destination;
          // Missing equivalents remain unavailable rather than navigating to a wrong page.
          if (destination && destination.startsWith('/') && !destination.startsWith('//')) {
            for (const name of ['title', 'aria-label']) {
              const label = element.getAttribute(name);
              if (label) element.setAttribute(name, label.replace(/\s*[—–-]\s*(coming soon|current language)$/i, ''));
            }
            element.addEventListener('click', () => {
              window.location.assign(destination + window.location.search + window.location.hash);
            });
          } else element.disabled = true;
        }
        existing.replaceWith(element);
      });
    })
    .catch(() => { /* Keep the original safe, disabled selector if the manifest cannot load. */ });
})();
