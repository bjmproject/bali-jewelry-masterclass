/* Shared footer email-provider chooser. */
(() => {
  const triggers = document.querySelectorAll('footer button[data-email-chooser]');
  if (!triggers.length) return;

  const recipient = 'balijewelrymasterclass@gmail.com';
  const encodedRecipient = encodeURIComponent(recipient);
  const providers = [
    ['Gmail', `https://mail.google.com/mail/?view=cm&fs=1&to=${encodedRecipient}`],
    ['Outlook', `https://outlook.live.com/mail/0/deeplink/compose?to=${encodedRecipient}`],
    ['Yahoo Mail', `https://compose.mail.yahoo.com/?to=${encodedRecipient}`],
    ['Default Email App', `mailto:${recipient}`]
  ];

  const dialog = document.createElement('dialog');
  dialog.id = 'email-provider-chooser';
  dialog.className = 'email-chooser';
  dialog.setAttribute('aria-labelledby', 'email-chooser-title');
  dialog.setAttribute('aria-describedby', 'email-chooser-description');
  dialog.innerHTML = `
    <button type="button" class="email-chooser-close" aria-label="Close email chooser" autofocus>&times;</button>
    <h2 id="email-chooser-title">Send us an email</h2>
    <p id="email-chooser-description">Choose your preferred email service.</p>
    <div class="email-chooser-options"></div>`;
  const options = dialog.querySelector('.email-chooser-options');
  for (const [name, url] of providers) {
    const link = document.createElement('a');
    const icon = document.createElement('img');
    icon.src = {
      'Gmail': 'email-provider-gmail.svg',
      'Outlook': 'email-provider-outlook.svg',
      'Yahoo Mail': 'email-provider-yahoo.svg',
      'Default Email App': 'email-provider-other.svg'
    }[name];
    icon.className = 'email-provider-icon';
    icon.alt = '';
    icon.width = 22;
    icon.height = 22;
    const label = document.createElement('span');
    label.textContent = name;
    link.append(icon, label);
    link.href = url;
    link.target = '_blank';
    link.rel = 'noopener noreferrer';
    options.append(link);
  }
  document.body.append(dialog);

  let opener;
  for (const trigger of triggers) {
    trigger.addEventListener('click', () => {
      opener = trigger;
      dialog.showModal();
    });
  }
  dialog.querySelector('.email-chooser-close').addEventListener('click', () => dialog.close());
  let startedOutside = false;
  const outside = event => {
    const bounds = dialog.getBoundingClientRect();
    return event.target === dialog && (event.clientX < bounds.left || event.clientX > bounds.right ||
      event.clientY < bounds.top || event.clientY > bounds.bottom);
  };
  dialog.addEventListener('pointerdown', event => { startedOutside = outside(event); });
  dialog.addEventListener('click', event => {
    if (startedOutside && outside(event)) dialog.close();
    startedOutside = false;
  });
  // Native modal dialogs handle Escape, focus containment, and inert background content.
  dialog.addEventListener('close', () => opener?.focus());
})();
