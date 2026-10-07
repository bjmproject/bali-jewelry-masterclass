/* Shared header parent controls: hover previews and click/tap toggles. */
(() => {
  const header = document.querySelector('body > header');
  if (!header) return;
  const desktop = window.matchMedia('(min-width: 851px)');
  const groups = [...header.querySelectorAll('.nav-group')].filter(group =>
    group.querySelector(':scope > button.nav-dropdown-toggle') && group.querySelector(':scope > .nav-dropdown'));
  const setState = (group, state) => {
    group.dataset.dropdownState = state;
    group.querySelector(':scope > button').setAttribute('aria-expanded', String(state !== 'closed'));
  };
  const closeAll = except => groups.forEach(group => { if (group !== except) setState(group, 'closed'); });
  groups.forEach(group => {
    const trigger = group.querySelector(':scope > button');
    setState(group, 'closed');
    trigger.addEventListener('click', () => {
      const state = group.dataset.dropdownState === 'open' ? 'closed' : 'open';
      closeAll(group);
      setState(group, state);
    });
    group.addEventListener('mouseenter', () => {
      if (desktop.matches && group.dataset.dropdownState !== 'open') setState(group, 'hover');
    });
    group.addEventListener('mouseleave', () => {
      if (group.dataset.dropdownState === 'hover') setState(group, 'closed');
    });
    group.addEventListener('focusin', () => {
      if (desktop.matches && group.dataset.dropdownState === 'closed') setState(group, 'hover');
    });
    group.addEventListener('focusout', event => {
      if (!group.contains(event.relatedTarget)) setState(group, 'closed');
    });
    group.addEventListener('keydown', event => {
      if (event.key === 'Escape') {
        event.preventDefault();
        trigger.focus();
        setState(group, 'closed');
      }
    });
  });
  document.addEventListener('click', event => {
    if (!groups.some(group => group.contains(event.target))) closeAll();
  });
  desktop.addEventListener('change', () => closeAll());
})();
