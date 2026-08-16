#!/usr/bin/env node
/* Load the SHIPPED captains-logic.js (same file index.html loads) and
   drive Klondike, Blackjack, Slots/War, and the card-back render helper.
   No re-implementation of the rules under test. */
"use strict";

var fs = require("fs");
var path = require("path");
var vm = require("vm");

var ROOT = path.resolve(__dirname, "..");
var LOGIC = path.join(ROOT, "captains-logic.js");
var INDEX = path.join(ROOT, "index.html");

var failed = 0;
var passed = 0;

function assert(cond, msg) {
  if (cond) {
    passed++;
    console.log("  PASS  " + msg);
  } else {
    failed++;
    console.log("  FAIL  " + msg);
  }
}

function section(title) {
  console.log("\n== " + title + " ==");
}

function loadShippedLogic() {
  var code = fs.readFileSync(LOGIC, "utf8");
  var sandbox = { console: console };
  sandbox.global = sandbox;
  sandbox.window = sandbox;
  vm.createContext(sandbox);
  vm.runInContext(code, sandbox, { filename: "captains-logic.js" });
  if (!sandbox.CaptainsDeck) {
    throw new Error("captains-logic.js did not assign CaptainsDeck");
  }
  return sandbox.CaptainsDeck;
}

var CD = loadShippedLogic();
var html = fs.readFileSync(INDEX, "utf8");

section("Shipped page is an ad-free file:// card room");
assert(/<!DOCTYPE html>/i.test(html), "index.html is a plain HTML page");
assert(/data-go="solitaire"/.test(html) && /Klondike/.test(html), "lobby names Klondike Solitaire");
assert(/data-go="blackjack"/.test(html), "lobby names Blackjack 21");
assert(/data-go="slots"/.test(html) && /data-go="war"/.test(html), "lobby names Anchor Slots and War at Sea");
assert(!/type\s*=\s*["']module["']/.test(html), "no ES-module script tags");
assert(!/importmap/i.test(html), "no import map");
assert(!/\bimport\s+[\w*{]/.test(html), "no bare ES-module import statements");
assert(/<script src="captains-logic.js"><\/script>/.test(html), "page loads shipped captains-logic.js as a classic script");
assert(!/googletagmanager|google-analytics|doubleclick|adsense|adsbygoogle|facebook\.net|hotjar|mixpanel|segment\.com/i.test(html),
  "no ad or analytics scripts");
assert(!/require\(|module\.exports|process\.env/.test(html), "page is not a Node-only entry");
assert(/CaptainsDeck\.applyFaceDownBack/.test(html), "UI paints face-down cards through the shipped helper");
assert(/CaptainsDeck\.klondikeCanPlace/.test(html), "UI uses shipped Klondike placement rules");
assert(/CaptainsDeck\.bjSettle/.test(html), "UI uses shipped blackjack payout");
assert(/CaptainsDeck\.slotsPayout/.test(html), "UI uses shipped slots payout");
assert(/CaptainsDeck\.warCompare/.test(html), "UI uses shipped War winner");

section("Klondike deal — 52 unique cards, 28 tableau + 24 stock");
var ordered = CD.makeDeck();
assert(ordered.length === 52, "makeDeck deals 52 cards");
var dealt = CD.dealKlondike(ordered);
var counts = CD.countKlondike(dealt);
assert(counts.tableau === 28, "tableau holds 28 cards (got " + counts.tableau + ")");
assert(counts.stock === 24, "stock holds 24 cards (got " + counts.stock + ")");
assert(counts.waste === 0 && counts.foundations === 0, "waste and foundations start empty");
assert(counts.total === 52, "deal accounts for every card");
var keys = CD.uniqueCardKeys(dealt);
var uniq = {};
var dup = false;
for (var k = 0; k < keys.length; k++) {
  if (uniq[keys[k]]) dup = true;
  uniq[keys[k]] = true;
}
assert(keys.length === 52 && !dup, "every rank/suit appears once");
assert(dealt.tab.length === 7 && dealt.found.length === 4, "7 tableau columns and 4 foundations");
for (var col = 0; col < 7; col++) {
  assert(dealt.tab[col].length === col + 1, "column " + (col + 1) + " has " + (col + 1) + " cards");
  assert(dealt.tab[col][col].up === true, "top card of column " + (col + 1) + " is face-up");
  if (col > 0) assert(dealt.tab[col][0].up === false, "buried card in column " + (col + 1) + " is face-down");
}

var reversed = CD.makeDeck().reverse();
var dealt2 = CD.dealKlondike(reversed);
var counts2 = CD.countKlondike(dealt2);
assert(counts2.tableau === 28 && counts2.stock === 24 && counts2.total === 52,
  "a differently ordered deck still deals 28 + 24");

section("Klondike placement — color, rank, Kings-only, Ace foundations");
var red6 = [{ r: 6, s: 1, up: true }];
var blk6 = [{ r: 6, s: 0, up: true }];
var red7 = [{ r: 7, s: 2, up: true }];
var blk7 = [{ r: 7, s: 3, up: true }];
var king = [{ r: 13, s: 0, up: true }];
var queen = [{ r: 12, s: 1, up: true }];
var aceS = [{ r: 1, s: 0, up: true }];
var twoS = [{ r: 2, s: 0, up: true }];
var twoH = [{ r: 2, s: 1, up: true }];
var threeS = [{ r: 3, s: 0, up: true }];

assert(CD.klondikeCanPlace(red6, red7, "tableau") === false, "same color (red on red) is rejected");
assert(CD.klondikeCanPlace(blk6, red7, "tableau") === true, "black 6 on red 7 is legal");
assert(CD.klondikeCanPlace(red6, blk7, "tableau") === true, "red 6 on black 7 is legal");
assert(CD.klondikeCanPlace(red6, blk6, "tableau") === false, "same rank is rejected");
assert(CD.klondikeCanPlace(king, [], "tableau") === true, "King may land on an empty column");
assert(CD.klondikeCanPlace(queen, [], "tableau") === false, "Queen may not land on an empty column");
assert(CD.klondikeCanPlace(aceS, [], "tableau") === false, "Ace may not land on an empty column");
assert(CD.klondikeCanPlace(aceS, [], "foundation") === true, "Ace may start a foundation");
assert(CD.klondikeCanPlace(twoS, [], "foundation") === false, "non-Ace may not start a foundation");
assert(CD.klondikeCanPlace(twoS, aceS, "foundation") === true, "same-suit 2 on Ace is legal");
assert(CD.klondikeCanPlace(twoH, aceS, "foundation") === false, "off-suit 2 on Ace is rejected");
assert(CD.klondikeCanPlace(threeS, aceS, "foundation") === false, "skipping a rank on the foundation is rejected");
assert(CD.klondikeCanPlace([aceS[0], twoS[0]], [], "foundation") === false, "a run cannot be dropped on a foundation");
assert(CD.klondikeCanPlace(blk6, [{ r: 7, s: 2, up: false }], "tableau") === false,
  "cannot drop onto a face-down tableau card");

section("Klondike Draw 1, Draw 3, recycle, undo");
var d1 = CD.dealKlondike(CD.makeDeck());
var snap1 = CD.klondikeSnapshot(d1);
var r1 = CD.klondikeDraw(d1, 1);
assert(r1.drew === 1 && r1.recycled === false, "Draw 1 turns one card");
assert(d1.waste.length === 1 && d1.stock.length === 23, "Draw 1: waste 1, stock 23");
assert(d1.waste[0].up === true, "drawn waste card is face-up");

CD.klondikeRestore(d1, snap1);
assert(d1.stock.length === 24 && d1.waste.length === 0, "undo restores the pre-draw layout");

var d3 = CD.dealKlondike(CD.makeDeck());
var snap3 = CD.klondikeSnapshot(d3);
var r3 = CD.klondikeDraw(d3, 3);
assert(r3.drew === 3 && d3.waste.length === 3 && d3.stock.length === 21, "Draw 3: waste 3, stock 21");
CD.klondikeRestore(d3, snap3);
assert(d3.stock.length === 24 && d3.waste.length === 0, "undo after Draw 3 restores stock and waste");

var rec = CD.dealKlondike(CD.makeDeck());
CD.klondikeDraw(rec, 3);
CD.klondikeDraw(rec, 3);
while (rec.stock.length) CD.klondikeDraw(rec, 3);
assert(rec.stock.length === 0 && rec.waste.length === 24, "stock can be emptied into the waste");
var recSnap = CD.klondikeSnapshot(rec);
var recycled = CD.klondikeDraw(rec, 1);
assert(recycled.recycled === true && rec.stock.length === 24 && rec.waste.length === 0,
  "empty stock recycles the waste face-down");
CD.klondikeRestore(rec, recSnap);
assert(rec.stock.length === 0 && rec.waste.length === 24, "undo restores the layout from before recycle");

section("Blackjack — soft/hard totals, stand-on-17, 3:2, bust");
function C(r, s) { return { r: r, s: s || 0, up: true }; }

var soft17 = CD.bjHandValue([C(1), C(6)]);
assert(soft17.total === 17 && soft17.soft === true, "Ace + 6 is a soft 17");
var hard17 = CD.bjHandValue([C(1), C(6), C(10)]);
assert(hard17.total === 17 && hard17.soft === false, "Ace + 6 + 10 is a hard 17");
var soft21 = CD.bjHandValue([C(1), C(1), C(9)]);
assert(soft21.total === 21 && soft21.soft === true, "Ace + Ace + 9 is a soft 21");
var hard12 = CD.bjHandValue([C(10), C(2)]);
assert(hard12.total === 12 && hard12.soft === false, "Ten + 2 is a hard 12");
assert(CD.bjIsNatural([C(1), C(12)]) === true, "Ace + Queen is a natural blackjack");
assert(CD.bjIsNatural([C(1), C(6), C(4)]) === false, "21 in three cards is not a natural");

assert(CD.bjDealerShouldHit([C(10), C(6)]) === true, "dealer hits a 16");
assert(CD.bjDealerShouldHit([C(10), C(7)]) === false, "dealer stands on a hard 17");
assert(CD.bjDealerShouldHit([C(1), C(6)]) === false, "dealer stands on a soft 17");
assert(CD.bjDealerShouldHit([C(5), C(5)]) === true, "dealer hits a 10");

var nat = CD.bjSettle([C(1), C(13)], [C(9), C(8)], 100);
assert(nat.outcome === "blackjack" && nat.won === true && nat.winnings === 250,
  "natural blackjack on a 100 bet pays 250 (3:2 plus the stake)");
var bust = CD.bjSettle([C(10), C(8), C(5)], [C(10), C(7)], 40);
assert(bust.outcome === "bust" && bust.won === false && bust.winnings === 0,
  "player bust loses the bet");
var dbust = CD.bjSettle([C(10), C(8)], [C(10), C(6), C(8)], 20);
assert(dbust.outcome === "dealer_bust" && dbust.winnings === 40, "dealer bust pays even money");
var push = CD.bjSettle([C(10), C(9)], [C(9), C(10)], 30);
assert(push.push === true && push.winnings === 30, "tied totals return the stake");
var lose = CD.bjSettle([C(10), C(6)], [C(10), C(8)], 10);
assert(lose.outcome === "lose" && lose.winnings === 0, "lower total loses");

section("Anchor Slots payout + War at Sea winner");
assert(CD.slotsPayout(["7", "7", "7"], 10).win === 500, "three sevens pay ×50");
assert(CD.slotsPayout(["⚓", "⚓", "⚓"], 10).win === 250, "three anchors pay ×25");
assert(CD.slotsPayout(["★", "★", "★"], 10).win === 100, "three stars pay ×10");
assert(CD.slotsPayout(["♥", "♥", "♥"], 10).win === 50, "three hearts pay ×5");
assert(CD.slotsPayout(["⚓", "⚓", "★"], 10).win === 25, "two anchors pay ×2.5");
assert(CD.slotsPayout(["⚓", "7", "★"], 10).win === 10, "one anchor returns the bet");
assert(CD.slotsPayout(["7", "★", "♥"], 10).win === 0, "a miss pays nothing");

assert(CD.warCompare(C(1), C(13)) === "win", "Ace beats King");
assert(CD.warCompare(C(5), C(8)) === "lose", "5 loses to 8");
assert(CD.warCompare(C(9), C(9)) === "war", "tied ranks are war");
assert(CD.warCompare(C(13), C(1)) === "lose", "King loses to Ace");

section("Card-back chooser — shipped render helper");
var navy = CD.getCardBack("navy");
var sweet = CD.getCardBack("sweetheart");
var harbor = CD.getCardBack("harbor");
assert(navy.kind === "navy" && !navy.src, "Navy/anchor default has no pinup image");
assert(sweet.kind === "pinup" && /cardbacks\/sweetheart\.jpg$/.test(sweet.src),
  "sweetheart back points at the cropped pinup file");
assert(harbor.kind === "pinup" && /cardbacks\/harbor\.jpg$/.test(harbor.src),
  "harbor back points at a second cropped pinup file");
assert(CD.normalizeCardBackId("not-a-back") === "navy", "unknown id falls back to navy");
assert(CD.pinupSourceFiles().length >= 2, "at least two provided pinup sources are catalogued");

var elPin = { className: "card", style: {} };
CD.applyFaceDownBack(elPin, "sweetheart");
assert(/\bdown\b/.test(elPin.className) && /\bback-sweetheart\b/.test(elPin.className),
  "selecting a pinup back sets the face-down CSS class");
assert(/\bback-pinup\b/.test(elPin.className), "pinup selection adds the pinup class");
assert(elPin.style.backgroundImage.indexOf("cardbacks/sweetheart.jpg") >= 0,
  "face-down helper sets background-image to the pinup");

var elNavy = { className: "card down back-sweetheart back-pinup", style: { backgroundImage: "url('x')" } };
CD.applyFaceDownBack(elNavy, "navy");
assert(/\bback-navy\b/.test(elNavy.className) && !/back-sweetheart/.test(elNavy.className),
  "switching to Navy replaces the pinup class");
assert(!elNavy.style.backgroundImage, "Navy default clears the pinup background-image");

var sources = CD.pinupSourceFiles();
for (var si = 0; si < CD.CARD_BACKS.length; si++) {
  var b = CD.CARD_BACKS[si];
  if (!b.src) continue;
  var disk = path.join(ROOT, b.src.replace(/\//g, path.sep));
  assert(fs.existsSync(disk), "card-back file exists on disk: " + b.src);
  assert(html.indexOf(b.src) >= 0 || html.indexOf("CARD_BACKS") >= 0,
    "page can reach " + b.src + " through the shipped catalog");
}
assert(html.indexOf("cardbacks/sweetheart.jpg") >= 0 || /CaptainsDeck\.CARD_BACKS/.test(html),
  "settings gallery is driven by the shipped CARD_BACKS list");
assert(sources.indexOf("PinUp-Girls-For-Grandpas-Cardgames-15.jpg") >= 0, "source 15.jpg is referenced");
assert(sources.indexOf("PinUp-Girls-For-Grandpas-Cardgames-16.jpg") >= 0, "source 16.jpg is referenced");

console.log("\n" + passed + " passed, " + failed + " failed");
if (failed) process.exit(1);
