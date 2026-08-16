/* =============================================================================
   THE CAPTAIN'S DECK — shared game logic
   Plain script (no modules). Loaded by index.html and by tests/run-tests.js.
   Works from file:// and from a static folder serve.
   ============================================================================= */
(function (root) {
  "use strict";

  var SUITS = ["♠", "♥", "♦", "♣"];
  var RANK_TXT = ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"];

  var CARD_BACKS = [
    { id: "navy", name: "Navy Anchor", src: "", kind: "navy", sourceFile: null, position: "" },
    {
      id: "sweetheart",
      name: "Sailor Sweetheart",
      src: "cardbacks/sweetheart.jpg",
      kind: "pinup",
      sourceFile: "PinUp-Girls-For-Grandpas-Cardgames-15.jpg",
      position: "center 16%"
    },
    {
      id: "harbor",
      name: "Harbor Girl",
      src: "cardbacks/harbor.jpg",
      kind: "pinup",
      sourceFile: "PinUp-Girls-For-Grandpas-Cardgames-16.jpg",
      position: "center 14%"
    },
    {
      id: "stars",
      name: "Stars & Anchor",
      src: "cardbacks/stars.jpg",
      kind: "pinup",
      sourceFile: "PinUp-Girls-For-Grandpas-Cardgames-18.jpg",
      position: "center 18%"
    },
    {
      id: "liberty",
      name: "Liberty Dress",
      src: "cardbacks/liberty.jpg",
      kind: "pinup",
      sourceFile: "PinUp-Girls-For-Grandpas-Cardgames-21.jpg",
      position: "center 16%"
    }
  ];

  var BACK_BY_ID = {};
  for (var bi = 0; bi < CARD_BACKS.length; bi++) BACK_BY_ID[CARD_BACKS[bi].id] = CARD_BACKS[bi];

  function isRed(s) { return s === 1 || s === 2; }

  function makeDeck() {
    var d = [];
    for (var s = 0; s < 4; s++)
      for (var r = 1; r <= 13; r++)
        d.push({ r: r, s: s, up: false });
    return d;
  }

  function copyCard(c) {
    return { r: c.r, s: c.s, up: !!c.up };
  }

  /* ---- Card backs -------------------------------------------------------- */
  function normalizeCardBackId(id) {
    if (id && BACK_BY_ID[id]) return id;
    return "navy";
  }

  function getCardBack(id) {
    return BACK_BY_ID[normalizeCardBackId(id)];
  }

  function pinupSourceFiles() {
    var out = [];
    for (var i = 0; i < CARD_BACKS.length; i++) {
      if (CARD_BACKS[i].sourceFile) out.push(CARD_BACKS[i].sourceFile);
    }
    return out;
  }

  /* Paint a face-down card element (real DOM node or a test stand-in).
     The UI and the tests both call this — it is the shipped render helper. */
  function applyFaceDownBack(el, backId) {
    var back = getCardBack(backId);
    var raw = (el.className || "") + "";
    var classes = raw.split(/\s+/).filter(function (c) {
      return c && c.indexOf("back-") !== 0;
    });
    if (classes.indexOf("card") < 0) classes.push("card");
    if (classes.indexOf("down") < 0) classes.push("down");
    classes.push("back-" + back.id);
    if (back.kind === "pinup") classes.push("back-pinup");
    el.className = classes.join(" ");
    if (!el.style) el.style = {};
    if (back.src) {
      el.style.backgroundImage = "url('" + back.src + "')";
      el.style.backgroundSize = "cover";
      el.style.backgroundPosition = back.position || "center 16%";
    } else {
      el.style.backgroundImage = "";
      el.style.backgroundSize = "";
      el.style.backgroundPosition = "";
    }
    if (el.setAttribute) el.setAttribute("data-card-back", back.id);
    else el["data-card-back"] = back.id;
    return el;
  }

  /* ---- Klondike ---------------------------------------------------------- */
  function dealKlondike(deck) {
    var src = deck && deck.length ? deck : makeDeck();
    var state = {
      stock: [],
      waste: [],
      found: [[], [], [], []],
      tab: [[], [], [], [], [], [], []],
      moves: 0,
      secs: 0,
      undo: [],
      sel: null,
      won: false
    };
    var di = 0;
    var i, j, c;
    for (i = 0; i < 7; i++) {
      for (j = 0; j <= i; j++) {
        c = copyCard(src[di++]);
        c.up = (j === i);
        state.tab[i].push(c);
      }
    }
    for (; di < src.length; di++) {
      c = copyCard(src[di]);
      c.up = false;
      state.stock.push(c);
    }
    return state;
  }

  function countKlondike(state) {
    var tab = 0, found = 0, i;
    for (i = 0; i < 7; i++) tab += state.tab[i].length;
    for (i = 0; i < 4; i++) found += state.found[i].length;
    return {
      tableau: tab,
      stock: state.stock.length,
      waste: state.waste.length,
      foundations: found,
      total: tab + state.stock.length + state.waste.length + found
    };
  }

  function uniqueCardKeys(state) {
    var keys = [];
    function walk(p) {
      for (var i = 0; i < p.length; i++) keys.push(p[i].r + "-" + p[i].s);
    }
    var i;
    walk(state.stock);
    walk(state.waste);
    for (i = 0; i < 4; i++) walk(state.found[i]);
    for (i = 0; i < 7; i++) walk(state.tab[i]);
    keys.sort();
    return keys;
  }

  /* destKind: "tableau" | "foundation" (also accepts "t" / "f") */
  function klondikeCanPlace(cards, destPile, destKind) {
    if (!cards || !cards.length) return false;
    var c = cards[0];
    var kind = destKind === "f" ? "foundation" : destKind === "t" ? "tableau" : destKind;
    if (kind === "foundation") {
      if (cards.length !== 1) return false;
      if (!destPile.length) return c.r === 1;
      var top = destPile[destPile.length - 1];
      return top.s === c.s && c.r === top.r + 1;
    }
    if (kind === "tableau") {
      if (!destPile.length) return c.r === 13;
      var tt = destPile[destPile.length - 1];
      return !!tt.up && tt.r === c.r + 1 && isRed(tt.s) !== isRed(c.s);
    }
    return false;
  }

  function packPile(p) {
    var out = [];
    for (var i = 0; i < p.length; i++) out.push([p[i].r, p[i].s, p[i].up ? 1 : 0]);
    return out;
  }

  function unpackPile(a) {
    var out = [];
    for (var i = 0; i < a.length; i++) out.push({ r: a[i][0], s: a[i][1], up: !!a[i][2] });
    return out;
  }

  function klondikeSnapshot(state) {
    return {
      stock: packPile(state.stock),
      waste: packPile(state.waste),
      found: [
        packPile(state.found[0]), packPile(state.found[1]),
        packPile(state.found[2]), packPile(state.found[3])
      ],
      tab: [
        packPile(state.tab[0]), packPile(state.tab[1]), packPile(state.tab[2]),
        packPile(state.tab[3]), packPile(state.tab[4]), packPile(state.tab[5]),
        packPile(state.tab[6])
      ],
      moves: state.moves || 0,
      secs: state.secs || 0
    };
  }

  function klondikeRestore(state, snap) {
    state.stock = unpackPile(snap.stock);
    state.waste = unpackPile(snap.waste);
    state.found = [
      unpackPile(snap.found[0]), unpackPile(snap.found[1]),
      unpackPile(snap.found[2]), unpackPile(snap.found[3])
    ];
    state.tab = [
      unpackPile(snap.tab[0]), unpackPile(snap.tab[1]), unpackPile(snap.tab[2]),
      unpackPile(snap.tab[3]), unpackPile(snap.tab[4]), unpackPile(snap.tab[5]),
      unpackPile(snap.tab[6])
    ];
    state.moves = snap.moves || 0;
    state.secs = snap.secs || 0;
    state.sel = null;
    return state;
  }

  /* Mutates stock/waste the same way the table does.
     Empty stock + waste recycles (unlimited passes). Empty both is a no-op. */
  function klondikeDraw(state, drawCount) {
    drawCount = drawCount || 1;
    if (state.stock.length === 0) {
      if (state.waste.length === 0) return { recycled: false, drew: 0 };
      while (state.waste.length) {
        var c = state.waste.pop();
        c.up = false;
        state.stock.push(c);
      }
      return { recycled: true, drew: 0 };
    }
    var n = Math.min(drawCount, state.stock.length);
    for (var i = 0; i < n; i++) {
      var d = state.stock.pop();
      d.up = true;
      state.waste.push(d);
    }
    return { recycled: false, drew: n };
  }

  /* ---- Blackjack --------------------------------------------------------- */
  function bjHandValue(cards) {
    var total = 0, aces = 0, i, c;
    for (i = 0; i < cards.length; i++) {
      c = cards[i];
      if (c.r === 1) { aces++; total += 11; }
      else total += (c.r > 10 ? 10 : c.r);
    }
    while (total > 21 && aces > 0) { total -= 10; aces--; }
    return { total: total, soft: aces > 0 };
  }

  function bjIsNatural(cards) {
    return cards.length === 2 && bjHandValue(cards).total === 21;
  }

  function bjDealerShouldHit(cards) {
    return bjHandValue(cards).total < 17;
  }

  /* Natural blackjack pays 3:2 (stake returned + 1.5× profit).
     Regular win / dealer bust returns 2× the stake. Bust loses. */
  function bjSettle(playerCards, dealerCards, bet) {
    var pv = bjHandValue(playerCards).total;
    var dv = bjHandValue(dealerCards).total;
    var playerBJ = bjIsNatural(playerCards);
    var dealerBJ = bjIsNatural(dealerCards);
    if (pv > 21) {
      return { outcome: "bust", winnings: 0, won: false, push: false };
    }
    if (playerBJ && !dealerBJ) {
      return {
        outcome: "blackjack",
        winnings: bet + Math.floor(bet * 1.5),
        won: true,
        push: false
      };
    }
    if (playerBJ && dealerBJ) {
      return { outcome: "push", winnings: bet, won: false, push: true };
    }
    if (dealerBJ) {
      return { outcome: "dealer_blackjack", winnings: 0, won: false, push: false };
    }
    if (dv > 21) {
      return { outcome: "dealer_bust", winnings: bet * 2, won: true, push: false };
    }
    if (pv > dv) {
      return { outcome: "win", winnings: bet * 2, won: true, push: false };
    }
    if (pv < dv) {
      return { outcome: "lose", winnings: 0, won: false, push: false };
    }
    return { outcome: "push", winnings: bet, won: false, push: true };
  }

  /* ---- Anchor Slots ------------------------------------------------------ */
  function slotsPayout(symbols, bet) {
    var f = symbols;
    var anchors = 0, i;
    for (i = 0; i < 3; i++) if (f[i] === "⚓") anchors++;
    var three = (f[0] === f[1] && f[1] === f[2]);
    if (three && f[0] === "7") return { win: bet * 50, kind: "jackpot7" };
    if (three && f[0] === "⚓") return { win: bet * 25, kind: "jackpotAnchor" };
    if (three && f[0] === "★") return { win: bet * 10, kind: "stars" };
    if (three) return { win: bet * 5, kind: "three" };
    if (anchors === 2) return { win: Math.round(bet * 2.5), kind: "twoAnchors" };
    if (anchors === 1) return { win: bet, kind: "oneAnchor" };
    return { win: 0, kind: "miss" };
  }

  /* ---- War at Sea -------------------------------------------------------- */
  function warValue(c) { return c.r === 1 ? 14 : c.r; }

  function warCompare(mine, theirs) {
    var mv = warValue(mine), tv = warValue(theirs);
    if (mv > tv) return "win";
    if (mv < tv) return "lose";
    return "war";
  }

  var CD = {
    SUITS: SUITS,
    RANK_TXT: RANK_TXT,
    CARD_BACKS: CARD_BACKS,
    isRed: isRed,
    makeDeck: makeDeck,
    normalizeCardBackId: normalizeCardBackId,
    getCardBack: getCardBack,
    pinupSourceFiles: pinupSourceFiles,
    applyFaceDownBack: applyFaceDownBack,
    dealKlondike: dealKlondike,
    countKlondike: countKlondike,
    uniqueCardKeys: uniqueCardKeys,
    klondikeCanPlace: klondikeCanPlace,
    klondikeSnapshot: klondikeSnapshot,
    klondikeRestore: klondikeRestore,
    klondikeDraw: klondikeDraw,
    packPile: packPile,
    unpackPile: unpackPile,
    bjHandValue: bjHandValue,
    bjIsNatural: bjIsNatural,
    bjDealerShouldHit: bjDealerShouldHit,
    bjSettle: bjSettle,
    slotsPayout: slotsPayout,
    warValue: warValue,
    warCompare: warCompare
  };

  root.CaptainsDeck = CD;
})(typeof window !== "undefined" ? window : typeof global !== "undefined" ? global : this);
