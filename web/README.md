# Open Lock — Website

The official website for **Open Lock**, served at
<https://openlock.itisuniqueofficial.com>. Static, no backend, no tracking.

## Architecture

- **Static HTML** (one file per page) + **Tailwind CSS** compiled to a single
  minified stylesheet. Brutalist, high-contrast, mobile-first, accessible.
- **Vanilla JS** (`assets/js/main.js`) for the mobile nav and for rendering the
  latest release / downloads / changelog from local JSON. **jQuery** (CDN) is a
  progressive enhancement only (menu animation) — the site works without it.
- **Font Awesome** (CDN) for UI icons — no emoji.
- **Build-time data**: `scripts/build-data.js` fetches GitHub Releases and writes
  `data/version.json`, `data/releases.json`, `data/changelog.json`. No API tokens
  are shipped to the browser; the fetch happens during the build (in CI it uses
  the workflow `GITHUB_TOKEN`). If the fetch fails, the site degrades gracefully
  to "view releases on GitHub".

## Directory layout

```
web/
├── *.html                # index, features, download, changelog, faq,
│                         # support, privacy, security, about, 404
├── CNAME                 # openlock.itisuniqueofficial.com
├── robots.txt, sitemap.xml, site.webmanifest
├── package.json, tailwind.config.js, postcss.config.js
├── src/css/input.css     # Tailwind source + brutalist components
├── assets/
│   ├── css/tailwind.css  # built (gitignored)
│   ├── js/main.js
│   ├── icons/            # favicon, touch icon, generated from /icons/icon.png
│   └── images/og-image.png
├── data/                 # config.json + generated version/releases/changelog
└── scripts/              # build-data.js, validate.js
```

## Develop

```sh
cd web
npm install
npm run dev      # Tailwind watch
# open index.html in a browser (data files are prebuilt or run: npm run build:data)
```

## Build

```sh
cd web
npm run build    # build:data (GitHub Releases) + build:css (minified Tailwind)
npm run check    # validate pages, assets, branding, internal links
```

## Configuration

Central config is `data/config.json` (app name, package, URLs, license). The
Google Play link is `playStoreUrl: null` → the UI shows "Coming soon". When a
Play Store listing exists, set the URL there — no HTML edits needed.

## Deployment (GitHub Pages)

Deployed by [`.github/workflows/web.yml`](../.github/workflows/web.yml) using the
official Pages actions (`upload-pages-artifact` → `deploy-pages`). Pushes to
`main` touching `web/**` build, validate, and deploy; pull requests build and
validate only.

The launcher-icon master lives at repository root `icons/icon.png`; the web
icons/favicon/OG image are derived from it.

### Custom domain

`web/CNAME` contains `openlock.itisuniqueofficial.com`. In addition, the domain
must be set in **Settings → Pages → Custom domain**, and the DNS provider needs a
`CNAME` record from `openlock` → `<owner>.github.io`. Enable **Enforce HTTPS**
once GitHub provisions the certificate.

> GitHub Pages for a **private** repository requires a plan that supports it, or
> the repository must be **public**. On a free plan a private repo cannot serve
> Pages.

## License

Website content and code: MIT (same as the project). App icon © It Is Unique
Official.
