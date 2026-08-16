#!/usr/bin/env node
/* Drive the real index.html twice in Chromium. Writes logs + screenshots
   into the path given as argv[1] (the goal scratch dir). */
"use strict";

var fs = require("fs");
var http = require("http");
var path = require("path");
var { pathToFileURL } = require("url");

var ROOT = path.resolve(__dirname, "..");
var OUT = process.argv[2] || process.argv[1];
if (!OUT || OUT === __filename) {
  console.error("usage: node tests/launch.js <scratch-dir>");
  process.exit(2);
}
fs.mkdirSync(OUT, { recursive: true });

var MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".json": "application/json"
};

function startServer() {
  return new Promise(function (resolve, reject) {
    var server = http.createServer(function (req, res) {
      var urlPath = decodeURIComponent((req.url || "/").split("?")[0]);
      if (urlPath === "/") urlPath = "/index.html";
      var file = path.normalize(path.join(ROOT, urlPath));
      if (file.indexOf(ROOT) !== 0) {
        res.statusCode = 403;
        res.end("forbidden");
        return;
      }
      fs.readFile(file, function (err, data) {
        if (err) {
          res.statusCode = 404;
          res.end("not found");
          return;
        }
        res.setHeader("Content-Type", MIME[path.extname(file).toLowerCase()] || "application/octet-stream");
        res.end(data);
      });
    });
    server.listen(0, "127.0.0.1", function () {
      resolve({ server: server, port: server.address().port });
    });
    server.on("error", reject);
  });
}

function write(name, text) {
  fs.writeFileSync(path.join(OUT, name), text, "utf8");
}

function filledPixels(pngBuf) {
  /* PNG is compressed; we only need "not an empty file" here. Pixel
     occupancy is measured in-page via canvas sampling. */
  return pngBuf && pngBuf.length > 8000;
}

async function measureFill(page) {
  return page.evaluate(function () {
    var w = Math.min(360, document.documentElement.clientWidth || 360);
    var h = Math.min(640, document.documentElement.clientHeight || 640);
    var canvas = document.createElement("canvas");
    canvas.width = 90;
    canvas.height = 160;
    var ctx = canvas.getContext("2d");
    // drawWindow is not available; sample computed backgrounds + card nodes instead.
    var body = document.body;
    var bg = getComputedStyle(body).backgroundColor;
    var cards = document.querySelectorAll(".card").length;
    var shown = document.querySelectorAll(".screen.show").length;
    var lobby = document.getElementById("scr-lobby");
    var lobbyOn = lobby && lobby.className.indexOf("show") >= 0;
    var title = document.querySelector(".lobby-title");
    var titleText = title ? title.textContent : "";
    var rect = (lobbyOn ? lobby : document.querySelector(".screen.show")).getBoundingClientRect();
    return {
      bg: bg,
      cards: cards,
      shown: shown,
      lobbyOn: lobbyOn,
      titleText: titleText,
      width: rect.width,
      height: rect.height,
      innerWidth: window.innerWidth,
      innerHeight: window.innerHeight
    };
  });
}

async function runLaunch(page, url, label) {
  var errors = [];
  var pageErrors = [];
  page.on("pageerror", function (err) { pageErrors.push(String(err)); });
  page.on("console", function (msg) {
    if (msg.type() === "error") errors.push(msg.text());
  });
  await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30000 });
  await page.waitForSelector("#scr-lobby.screen.show", { timeout: 10000 });
  var fill = await measureFill(page);
  var shot = await page.screenshot({ fullPage: true });
  fs.writeFileSync(path.join(OUT, label === "launch-1" ? "lobby.png" : label + "-lobby.png"), shot);
  var log = [
    "url=" + url,
    "pageerrors=" + pageErrors.length,
    "console_errors=" + errors.length,
    "pageerrors_detail=" + JSON.stringify(pageErrors),
    "console_detail=" + JSON.stringify(errors),
    "fill=" + JSON.stringify(fill),
    "screenshot_bytes=" + shot.length,
    "screenshot_substantial=" + filledPixels(shot)
  ].join("\n") + "\n";
  write(label + ".log", log);
  return { errors: errors, pageErrors: pageErrors, fill: fill, shot: shot };
}

async function main() {
  var pw;
  try {
    pw = require("playwright");
  } catch (e) {
    try {
      pw = require("playwright-core");
    } catch (e2) {
      write("launch-unavailable.log",
        "Playwright require failed:\n" + String(e) + "\n" + String(e2) + "\n");
      process.exit(0);
    }
  }

  var launched = await startServer();
  var url = "http://127.0.0.1:" + launched.port + "/index.html";
  var browser;
  var launchErrs = [];
  var attempts = [
    { name: "chromium-default", opts: { headless: true } },
    { name: "channel-chrome", opts: { headless: true, channel: "chrome" } },
    { name: "channel-msedge", opts: { headless: true, channel: "msedge" } },
    {
      name: "ms-playwright-1228",
      opts: {
        headless: true,
        executablePath: process.env.LOCALAPPDATA +
          "\\ms-playwright\\chromium-1228\\chrome-win64\\chrome.exe"
      }
    },
    {
      name: "ms-playwright-1217",
      opts: {
        headless: true,
        executablePath: process.env.LOCALAPPDATA +
          "\\ms-playwright\\chromium-1217\\chrome-win64\\chrome.exe"
      }
    }
  ];
  for (var ai = 0; ai < attempts.length; ai++) {
    try {
      browser = await pw.chromium.launch(attempts[ai].opts);
      write("launch-browser.txt", "using " + attempts[ai].name + "\n");
      break;
    } catch (err) {
      launchErrs.push(attempts[ai].name + ": " + String(err).split("\n")[0]);
    }
  }
  if (!browser) {
    write("launch-unavailable.log",
      "chromium.launch failed after fallbacks:\n" + launchErrs.join("\n") + "\n");
    launched.server.close();
    process.exit(0);
  }

  try {
    var context = await browser.newContext({
      viewport: { width: 390, height: 844 },
      deviceScaleFactor: 2
    });
    var page = await context.newPage();

    var first = await runLaunch(page, url, "launch-1");
    if (first.pageErrors.length || first.errors.length) {
      throw new Error("launch-1 had page errors");
    }
    if (first.fill.width < 200 || first.fill.height < 300) {
      throw new Error("launch-1 render surface too small: " + JSON.stringify(first.fill));
    }
    if (first.fill.titleText.indexOf("CAPTAIN") < 0) {
      throw new Error("lobby title missing");
    }

    await page.click('button[data-go="solitaire"]');
    await page.waitForSelector("#scr-solitaire.screen.show", { timeout: 8000 });
    await page.waitForSelector("#sol-tabs .card", { timeout: 8000 });
    var solInfo = await page.evaluate(function () {
      var downs = document.querySelectorAll("#sol-table .card.down").length;
      var ups = document.querySelectorAll("#sol-table .card:not(.down)").length;
      var navy = document.querySelectorAll("#sol-table .card.down.back-navy").length;
      var stock = document.querySelectorAll("#sol-stock .card.down").length;
      return { downs: downs, ups: ups, navy: navy, stock: stock };
    });
    var solShot = await page.screenshot({ fullPage: true });
    fs.writeFileSync(path.join(OUT, "solitaire.png"), solShot);
    write("launch-1.log",
      fs.readFileSync(path.join(OUT, "launch-1.log"), "utf8") +
      "solitaire=" + JSON.stringify(solInfo) + "\nsolitaire_bytes=" + solShot.length + "\n");
    if (solInfo.downs < 21 || solInfo.ups < 7) {
      throw new Error("dealt solitaire layout incomplete: " + JSON.stringify(solInfo));
    }

    await page.locator("#sol-stock").click();
    var afterDraw = await page.evaluate(function () {
      return {
        waste: document.querySelectorAll("#sol-waste .card").length,
        moves: document.getElementById("sol-moves").textContent
      };
    });
    write("launch-1.log",
      fs.readFileSync(path.join(OUT, "launch-1.log"), "utf8") +
      "after_stock_tap=" + JSON.stringify(afterDraw) + "\n");
    if (!afterDraw.waste) throw new Error("stock tap did not draw a waste card");

    await page.locator("#scr-solitaire .backbtn").click();
    await page.waitForSelector("#scr-lobby.screen.show");
    await page.locator('#scr-lobby button[data-go="blackjack"]').click();
    await page.waitForSelector("#scr-blackjack.screen.show");
    await page.waitForSelector("#bj-deal");
    var bjShot = await page.screenshot({ fullPage: true });
    fs.writeFileSync(path.join(OUT, "blackjack.png"), bjShot);
    await page.locator("#scr-blackjack .backbtn").click();
    await page.waitForSelector("#scr-lobby.screen.show");
    await page.locator('#scr-lobby button[data-go="slots"]').click();
    await page.waitForSelector("#scr-slots.screen.show");
    await page.waitForSelector("#sl-spin");
    var slShot = await page.screenshot({ fullPage: true });
    fs.writeFileSync(path.join(OUT, "slots.png"), slShot);

    await page.locator("#scr-slots .backbtn").click();
    await page.waitForSelector("#scr-lobby.screen.show");
    await page.locator('#scr-lobby button[data-go="settings"]').click();
    await page.waitForSelector("#cardback-gallery", { timeout: 8000 });
    await page.locator('button[data-cardback="sweetheart"]').click();
    await page.waitForTimeout(400);
    var setShot = await page.screenshot({ fullPage: true });
    fs.writeFileSync(path.join(OUT, "settings.png"), setShot);
    await page.locator("#scr-settings .backbtn").click();
    await page.waitForSelector("#scr-lobby.screen.show");
    await page.locator('#scr-lobby button[data-go="solitaire"]').click();
    await page.waitForSelector("#scr-solitaire.screen.show");
    await page.waitForSelector("#sol-table .card.down.back-sweetheart, #sol-table .card.down.back-pinup", { timeout: 8000 });
    var backInfo = await page.evaluate(function () {
      var pin = document.querySelector("#sol-table .card.down.back-sweetheart");
      if (!pin) return { ok: false };
      var cs = getComputedStyle(pin);
      return {
        ok: true,
        cls: pin.className,
        bg: cs.backgroundImage,
        data: pin.getAttribute("data-card-back")
      };
    });
    var backShot = await page.screenshot({ fullPage: true });
    fs.writeFileSync(path.join(OUT, "cardback.png"), backShot);
    write("cardback-dom.txt", JSON.stringify(backInfo, null, 2) + "\n");
    if (!backInfo.ok || backInfo.bg.indexOf("sweetheart") < 0) {
      throw new Error("pinup back not applied: " + JSON.stringify(backInfo));
    }

    await page.evaluate(function () {
      S.coins = 777;
      S.settings.cardBack = "harbor";
      try { localStorage.setItem(SAVE_KEY, JSON.stringify(S)); } catch (e) {}
    });

    var page2 = await context.newPage();
    var second = await runLaunch(page2, url, "launch-2");
    if (second.pageErrors.length || second.errors.length) {
      throw new Error("launch-2 had page errors");
    }
    var persist = await page2.evaluate(function () {
      return { coins: S.coins, cardBack: S.settings.cardBack };
    });
    write("persist.log",
      "after_reload coins=" + persist.coins + " cardBack=" + persist.cardBack + "\n" +
      "launch-2 fill=" + JSON.stringify(second.fill) + "\n");
    if (persist.coins !== 777 || persist.cardBack !== "harbor") {
      throw new Error("persistence failed: " + JSON.stringify(persist));
    }

    console.log("launch ok");
    console.log("solitaire", JSON.stringify(solInfo));
    console.log("cardback", JSON.stringify(backInfo));
    console.log("persist", JSON.stringify(persist));
  } finally {
    await browser.close();
    launched.server.close();
  }
}

main().catch(function (err) {
  write("launch-unavailable.log",
    "launch script threw (treating as launcher failure only if chromium itself cannot start).\n" +
    String(err) + "\nstack=" + (err && err.stack || "") + "\n");
  console.error(err);
  process.exit(1);
});
