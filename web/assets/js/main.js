/* Open Lock website — progressive enhancement. Core behaviour is vanilla JS so
 * the site works even if jQuery or the data files fail to load. jQuery (when
 * present) is used only to animate the mobile menu. No tracking, no analytics. */
(function () {
  "use strict";

  document.addEventListener("DOMContentLoaded", function () {
    setYear();
    initNav();
    initData();
  });

  function setYear() {
    var y = String(new Date().getFullYear());
    document.querySelectorAll("[data-year]").forEach(function (el) {
      el.textContent = y;
    });
  }

  function initNav() {
    var toggle = document.querySelector("[data-nav-toggle]");
    var menu = document.getElementById("mobile-menu");
    if (!toggle || !menu) return;

    function open() {
      toggle.setAttribute("aria-expanded", "true");
      if (window.jQuery) {
        window.jQuery(menu).stop(true, true).slideDown(150);
      } else {
        menu.hidden = false;
      }
    }
    function close() {
      toggle.setAttribute("aria-expanded", "false");
      if (window.jQuery) {
        window.jQuery(menu).stop(true, true).slideUp(150, function () {
          menu.hidden = true;
        });
      } else {
        menu.hidden = true;
      }
    }
    toggle.addEventListener("click", function () {
      if (toggle.getAttribute("aria-expanded") === "true") close();
      else open();
    });
    menu.addEventListener("click", function (e) {
      if (e.target.closest("a")) close();
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && toggle.getAttribute("aria-expanded") === "true") {
        close();
        toggle.focus();
      }
    });
  }

  function getJSON(url) {
    return fetch(url, { cache: "no-cache" }).then(function (r) {
      if (!r.ok) throw new Error(url + " " + r.status);
      return r.json();
    });
  }

  function fmtBytes(n) {
    if (n === undefined || n === null) return "";
    var u = ["B", "KB", "MB", "GB"], i = 0;
    while (n >= 1024 && i < u.length - 1) { n /= 1024; i++; }
    return n.toFixed(i ? 1 : 0) + " " + u[i];
  }
  function fmtDate(s) {
    if (!s) return "";
    try {
      return new Date(s).toLocaleDateString(undefined, {
        year: "numeric", month: "long", day: "numeric",
      });
    } catch (e) { return s; }
  }
  function esc(s) {
    return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  function initData() {
    var cfg = null, releases = [];
    getJSON("./data/config.json")
      .then(function (c) { cfg = c; applyPlayStore(c); })
      .catch(function () {})
      .then(function () { return getJSON("./data/version.json").catch(function () { return null; }); })
      .then(function (v) { renderVersion(v, cfg); })
      .then(function () { return getJSON("./data/releases.json").catch(function () { return []; }); })
      .then(function (r) { releases = Array.isArray(r) ? r : []; renderDownloads(releases, cfg); })
      .then(function () { return getJSON("./data/changelog.json").catch(function () { return []; }); })
      .then(function (c) { renderChangelog(Array.isArray(c) ? c : []); })
      .catch(function () {});
  }

  function applyPlayStore(cfg) {
    var slots = document.querySelectorAll("[data-playstore]");
    slots.forEach(function (el) {
      if (cfg && cfg.playStoreUrl) {
        el.setAttribute("href", cfg.playStoreUrl);
        el.removeAttribute("aria-disabled");
      } else {
        el.setAttribute("aria-disabled", "true");
        el.setAttribute("role", "link");
        el.removeAttribute("href");
      }
    });
  }

  function renderVersion(v, cfg) {
    var releasesUrl = (cfg && cfg.githubReleasesUrl) || "https://github.com/itisuniqueofficial-gh/open-lock/releases";
    var hasRelease = v && v.hasRelease && v.version;

    document.querySelectorAll("[data-version]").forEach(function (el) {
      el.textContent = hasRelease ? v.version : "unreleased";
    });

    var box = document.getElementById("latest-release");
    if (box) {
      if (!hasRelease) {
        box.innerHTML =
          '<p class="prose-lead">No stable release has been published yet.</p>' +
          '<p class="mt-4"><a class="btn btn-ghost" href="' + esc(releasesUrl) + '">' +
          '<i class="fa-brands fa-github" aria-hidden="true"></i> View releases on GitHub</a></p>';
      } else {
        box.innerHTML =
          '<p class="eyebrow">Latest stable release</p>' +
          '<h3 class="mt-1 text-2xl font-extrabold">Open Lock ' + esc(v.version) + "</h3>" +
          '<p class="mt-1 font-mono text-sm text-muted">Released ' + esc(fmtDate(v.date)) + "</p>" +
          '<div class="mt-4 flex flex-wrap gap-3">' +
          '<a class="btn btn-blue" data-download-apk href="' + esc(v.url) + '"><i class="fa-solid fa-download" aria-hidden="true"></i> Download APK</a>' +
          '<a class="btn btn-ghost" href="' + esc(v.url) + '"><i class="fa-solid fa-tag" aria-hidden="true"></i> View release</a>' +
          '<a class="btn btn-ghost" href="changelog.html"><i class="fa-solid fa-list" aria-hidden="true"></i> Changelog</a>' +
          "</div>";
        // Point the download button at the universal APK once assets load.
      }
    }
  }

  function renderDownloads(releases, cfg) {
    var latest = releases.filter(function (r) { return !r.prerelease; })[0] || releases[0];

    // Wire any "download APK" buttons to the universal APK asset if present.
    if (latest) {
      var universal = (latest.assets || []).filter(function (a) {
        return /universal\.apk$/i.test(a.name);
      })[0];
      if (universal) {
        document.querySelectorAll("[data-download-apk]").forEach(function (el) {
          el.setAttribute("href", universal.url);
        });
      }
    }

    var list = document.getElementById("asset-list");
    if (!list) return;
    if (!latest || !(latest.assets || []).length) {
      var url = (cfg && cfg.githubReleasesUrl) || "https://github.com/itisuniqueofficial-gh/open-lock/releases";
      list.innerHTML = '<p class="prose-lead">No downloadable assets yet. ' +
        '<a class="link" href="' + esc(url) + '">Browse all releases on GitHub</a>.</p>';
      return;
    }
    var rows = latest.assets.map(function (a) {
      var icon = /\.aab$/i.test(a.name) ? "fa-box-archive" : "fa-mobile-screen-button";
      return '<li class="kv">' +
        '<span class="min-w-0 break-all font-mono text-sm"><i class="fa-solid ' + icon + ' mr-2 text-ol-blue" aria-hidden="true"></i>' + esc(a.name) + "</span>" +
        '<span class="flex shrink-0 items-center gap-3">' +
        '<span class="font-mono text-xs text-muted">' + esc(fmtBytes(a.size)) + "</span>" +
        '<a class="link" href="' + esc(a.url) + '">Download</a></span></li>";
    }).join("");
    list.innerHTML = '<p class="mb-2 font-mono text-sm text-muted">Open Lock ' + esc(latest.version) + " · " + esc(fmtDate(latest.date)) + "</p><ul>" + rows + "</ul>";
  }

  function renderChangelog(entries) {
    var box = document.getElementById("changelog-list");
    if (!box) return;
    if (!entries.length) {
      box.innerHTML = '<p class="prose-lead">No releases published yet. ' +
        '<a class="link" href="https://github.com/itisuniqueofficial-gh/open-lock/releases">View releases on GitHub</a>.</p>';
      return;
    }
    box.innerHTML = entries.map(function (e) {
      var cats = e.categories || {};
      var order = ["Added", "Changed", "Fixed", "Security", "Build / CI"];
      var sections = order.filter(function (k) { return (cats[k] || []).length; }).map(function (k) {
        var lis = cats[k].map(function (t) { return "<li>" + esc(t) + "</li>"; }).join("");
        return '<div class="mt-3"><p class="tag">' + esc(k) + '</p><ul class="mt-2 list-disc pl-5 text-sm leading-relaxed">' + lis + "</ul></div>";
      }).join("");
      if (!sections && (e.items || []).length) {
        sections = '<ul class="mt-3 list-disc pl-5 text-sm leading-relaxed">' +
          e.items.map(function (t) { return "<li>" + esc(t) + "</li>"; }).join("") + "</ul>";
      }
      return '<article class="card mb-6">' +
        '<header class="flex flex-wrap items-baseline justify-between gap-2 border-b-2 border-ink pb-2">' +
        '<h2 class="text-xl font-extrabold">Open Lock ' + esc(e.version) + "</h2>" +
        '<span class="font-mono text-sm text-muted">' + esc(fmtDate(e.date)) + "</span></header>" +
        sections +
        '<p class="mt-4"><a class="link" href="' + esc(e.url) + '">View release on GitHub</a></p>' +
        "</article>";
    }).join("");
  }
})();
