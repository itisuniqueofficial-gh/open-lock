#!/usr/bin/env node
/**
 * Static-site validation. Fails (non-zero exit) on missing pages/assets, old
 * branding, localhost URLs, or broken internal links. Run in CI before deploy.
 */
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const errors = [];

const PAGES = [
  "index.html",
  "features.html",
  "download.html",
  "changelog.html",
  "faq.html",
  "support.html",
  "privacy.html",
  "security.html",
  "about.html",
  "404.html",
];

const REQUIRED = [
  "CNAME",
  "robots.txt",
  "sitemap.xml",
  "assets/css/tailwind.css",
  "assets/icons/icon.png",
  "assets/icons/favicon.ico",
  "data/config.json",
  "data/version.json",
  "data/releases.json",
  "data/changelog.json",
];

const BANNED = [
  { re: /MalicKAbdullah/, msg: "old maintainer reference" },
  { re: /dev\.abdullah\.openlock/, msg: "old package id" },
  { re: /localhost|127\.0\.0\.1/, msg: "localhost URL" },
];

function exists(rel) {
  return fs.existsSync(path.join(ROOT, rel));
}

for (const p of PAGES) if (!exists(p)) errors.push(`missing page: ${p}`);
for (const r of REQUIRED) if (!exists(r)) errors.push(`missing required file: ${r}`);

// CNAME content
if (exists("CNAME")) {
  const cname = fs.readFileSync(path.join(ROOT, "CNAME"), "utf8").trim();
  if (cname !== "openlock.itisuniqueofficial.com")
    errors.push(`CNAME must be exactly openlock.itisuniqueofficial.com (got "${cname}")`);
}

// Scan HTML pages for banned strings + broken internal links.
for (const p of PAGES) {
  if (!exists(p)) continue;
  const html = fs.readFileSync(path.join(ROOT, p), "utf8");
  for (const b of BANNED)
    if (b.re.test(html)) errors.push(`${p}: ${b.msg} found`);

  const linkRe = /href="([^"#?:]+\.html)(?:[#?][^"]*)?"/g;
  let m;
  while ((m = linkRe.exec(html))) {
    const target = m[1].replace(/^\.\//, "");
    if (!exists(target)) errors.push(`${p}: broken internal link -> ${m[1]}`);
  }
}

if (errors.length) {
  console.error("Validation FAILED:");
  for (const e of errors) console.error(" - " + e);
  process.exit(1);
}
console.log(`Validation passed: ${PAGES.length} pages, ${REQUIRED.length} required files, no old branding, no broken internal links.`);
