/* Reuses the existing footer email chooser and each page's contact routes. */
(() => {
  const hub = document.querySelector('.communication-hub');
  if (!hub) return;
  const toggle = hub.querySelector('.communication-hub-toggle');
  const panel = hub.querySelector('.communication-hub-panel');
  const setOpen = (open, restoreFocus = false) => {
    panel.hidden = !open;
    toggle.setAttribute('aria-expanded', String(open));
    if (open) panel.querySelector('a, button:not(:disabled)')?.focus({ preventScroll: true });
    else if (restoreFocus) toggle.focus({ preventScroll: true });
  };
  // Keep the floating button clear of visible footer links without moving the footer.
  const footer = document.querySelector('footer');
  let clearanceFrame;
  const updateFooterClearance = () => {
    hub.style.setProperty('--hub-viewport-width', document.documentElement.clientWidth + 'px');
    hub.style.setProperty('--hub-footer-clearance', '0px');
    const rect = toggle.getBoundingClientRect();
    const controls = [...(footer?.querySelectorAll('a, button') || [])]
      .map(element => element.getBoundingClientRect())
      .filter(box => box.width && box.height && box.top < innerHeight && box.bottom > 0);
    let lift = 0;
    for (let pass = 0; pass <= controls.length; pass += 1) {
      const collision = controls.find(box => box.left < rect.right && box.right > rect.left &&
        box.top < rect.bottom - lift && box.bottom > rect.top - lift);
      if (!collision) break;
      lift = rect.bottom - collision.top + 12;
    }
    hub.style.setProperty('--hub-footer-clearance', Math.max(0, lift) + 'px');
  };
  const scheduleClearance = () => {
    cancelAnimationFrame(clearanceFrame);
    clearanceFrame = requestAnimationFrame(updateFooterClearance);
  };
  window.addEventListener('scroll', scheduleClearance, { passive: true });
  window.addEventListener('resize', scheduleClearance);
  window.addEventListener('load', scheduleClearance);
  if (footer && typeof ResizeObserver !== 'undefined') new ResizeObserver(scheduleClearance).observe(footer);
  updateFooterClearance();
  toggle.addEventListener('click', () => setOpen(panel.hidden));
  document.addEventListener('click', event => {
    if (!panel.hidden && !hub.contains(event.target)) setOpen(false);
  });
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && !panel.hidden) {
      event.preventDefault();
      setOpen(false, true);
    }
  });
  const emailTrigger = document.querySelector('footer button[data-email-chooser]');
  const emailDialog = document.querySelector('#email-provider-chooser');
  if (!emailTrigger || !emailDialog) return;
  const emailOption = hub.querySelector('[data-hub-email]');
  const back = document.createElement('button');
  back.type = 'button';
  back.className = 'communication-hub-back';
  back.textContent = hub.querySelector('[data-hub-back-label]').textContent;
  back.hidden = true;
  emailDialog.querySelector('h2').before(back);
  let openingFromHub = false;
  let emailFromHub = false;
  let returnToHub = false;
  let scrollPosition;
  emailTrigger.addEventListener('click', () => {
    emailFromHub = openingFromHub;
    returnToHub = false;
    back.hidden = !emailFromHub;
  });
  emailOption.addEventListener('click', () => {
    scrollPosition = { x: window.scrollX, y: window.scrollY };
    setOpen(false);
    openingFromHub = true;
    emailTrigger.click();
    openingFromHub = false;
  });
  back.addEventListener('click', () => {
    returnToHub = true;
    emailDialog.close();
  });
  emailDialog.addEventListener('close', () => {
    if (!emailFromHub) return;
    emailFromHub = false;
    window.scrollTo(scrollPosition.x, scrollPosition.y);
    updateFooterClearance();
    if (returnToHub) {
      setOpen(true);
      emailOption.focus({ preventScroll: true });
    } else {
      setOpen(false, true);
    }
    returnToHub = false;
    back.hidden = true;
  });
})();
