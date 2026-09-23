#!/usr/bin/env node
/**
 * Build-time data generation. Fetches the repository's GitHub Releases and
 * writes data/version.json, data/releases.json and data/changelog.json so the
 * static site can render the latest release, download links and changelog
 * without any client-side API tokens. Runs in GitHub Actions (uses GITHUB_TOKEN
 * when available to avoid rate limits) and degrades gracefully offline.
 */
const fs = require("fs");
const path = require("path");

const DATA_DIR = __dirname.replace(/scripts$/, "data");
const config = JSON.parse(
  fs.readFileSync(path.join(DATA_DIR, "config.json"), "utf8"),
);

const REPO = config.githubRepo;
const API = `https://api.github.com/repos/${REPO}/releases?per_page=20`;

function write(name, obj) {
  fs.writeFileSync(
    path.join(DATA_DIR, name),
    JSON.stringify(obj, null, 2) + "\n",
  );
  console.log(`wrote data/${name}`);
}

function categorize(lines) {
  const cats = {
    Added: [],
    Changed: [],
    Fixed: [],
    Security: [],
    "Build / CI": [],
  };
  for (const raw of lines) {
    const l = raw.toLowerCase();
    if (/(secur|keystore|flag_secure|sign|verifier|encrypt)/.test(l))
      cats.Security.push(raw);
    else if (/(^|\s)(fix|bug|correct|resolve)/.test(l)) cats.Fixed.push(raw);
    else if (/(ci|workflow|release|dependabot|build|action|pipeline)/.test(l))
      cats["Build / CI"].push(raw);
    else if (/(add|implement|integrate|generate|introduce|new)/.test(l))
      cats.Added.push(raw);
    else cats.Changed.push(raw);
  }
  return cats;
}

function parseBody(body) {
  if (!body) return [];
  const items = [];
  for (const line of body.split(/\r?\n/)) {
    const m = line.match(/^\s*[-*]\s+(.*\S)\s*$/);
    if (!m) continue;
    // Skip the install-instructions block bullets.
    if (/`Open-Lock-|\.aab`|\.apk`/.test(m[1])) continue;
    items.push(m[1].replace(/\s*\([0-9a-f]{7,}\)\s*$/, "").trim());
  }
  return items;
}

async function main() {
  const headers = { "User-Agent": "open-lock-website-build", Accept: "application/vnd.github+json" };
  if (process.env.GITHUB_TOKEN) headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;

  let releases = [];
  try {
    const res = await fetch(API, { headers });
    if (!res.ok) throw new Error(`GitHub API ${res.status}`);
    releases = await res.json();
  } catch (err) {
    console.warn(`[build-data] release fetch failed (${err.message}); writing empty fallback.`);
    write("version.json", { hasRelease: false, generatedAt: new Date().toISOString() });
    write("releases.json", []);
    write("changelog.json", []);
    return;
  }

  const published = releases
    .filter((r) => !r.draft)
    .map((r) => ({
      version: r.tag_name,
      name: r.name || r.tag_name,
      date: r.published_at || r.created_at,
      url: r.html_url,
      prerelease: !!r.prerelease,
      body: r.body || "",
      assets: (r.assets || []).map((a) => ({
        name: a.name,
        size: a.size,
        url: a.browser_download_url,
      })),
    }));

  const stable = published.filter((r) => !r.prerelease);
  const latest = stable[0] || published[0] || null;

  write("version.json", {
    hasRelease: !!latest,
    version: latest ? latest.version : null,
    name: latest ? latest.name : null,
    date: latest ? latest.date : null,
    url: latest ? latest.url : config.githubReleasesUrl,
    generatedAt: new Date().toISOString(),
  });

  write(
    "releases.json",
    published.map((r) => ({
      version: r.version,
      name: r.name,
      date: r.date,
      url: r.url,
      prerelease: r.prerelease,
      assets: r.assets,
    })),
  );

  write(
    "changelog.json",
    published.map((r) => {
      const items = parseBody(r.body);
      return {
        version: r.version,
        name: r.name,
        date: r.date,
        url: r.url,
        items,
        categories: categorize(items),
      };
    }),
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
