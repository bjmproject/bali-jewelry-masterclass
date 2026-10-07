# Footer design

Preserve the footer design approved by the user. Change its appearance, spacing,
content, icons, or alignment only when the user explicitly requests a footer change.

All website pages must use identical footer markup and load `footer-layout.css`
followed by `site-chrome.css`. `gallery.html` is the reference footer. Keep footer
updates consistent across index, gallery, craft, articles, pricing, and policies.
Use shared styles rather than introducing page-specific footer overrides.

# Header design

Preserve both approved header designs. Change headers only when the user explicitly
requests a header change. Keep the homepage header in `index.html` as it is.

All other pages must use identical header markup from `gallery.html` and load
`header-layout.css` before `site-chrome.css`. Keep header updates consistent across
gallery, craft, articles, pricing, and policies, including future interior pages.
Do not apply interior-header changes to the homepage. Avoid changing shared
`site-chrome.css` header rules unless explicitly requested, since they also affect
the homepage.

# Blog hub layout

The user has locked the approved layout of blog.html. Preserve its structure
unless the user explicitly requests a layout change. Adding articles does not
authorize changing the layout.

Keep BLOG and all article entries left-aligned with the shared header/logo
and footer content container: width min(1500px, 90%), centered with auto inline
margins. Keep one vertical editorial list, with each article occupying a full-width
row. Do not switch to a two-column article listing or reserve an empty right-side
image column. Do not add placeholders, cards, or artificial minimum heights.

Add future articles using the existing article-preview and article-preview-content
markup and shared hub styles, in reading order. Preserve the current typography,
colors, subtle top dividers, compact spacing, and single-column mobile behavior.
Do not introduce article-specific positioning or redesign the hub as it grows.
Add photography or alter this structure only when explicitly requested by the user.
Preserve header, footer, navigation, existing article content, and destinations.
