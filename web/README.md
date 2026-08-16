# The Captain's Deck

A Navy-themed card room built for Grandpa Ralph. No ads, no internet needed, runs on any Android phone's browser (including older ones). Open `index.html` from disk or copy the whole folder onto the phone.

**Games:** Klondike Solitaire (tap-to-move, undo, hints, auto-finish) · Blackjack 21 with the Card-Counting Coach · Anchor Slots · War at Sea
**Extras:** Grandpa Coins, Daily Muster bonus, the collectible Fleet (16 real WWII ships), quiet help after losing streaks, progress saved on the phone. Settings lets him pick a Navy-anchor card back or a tasteful vintage sailor-sweetheart pinup.

## Files

- `index.html` — the card room (lobby, games, settings).
- `captains-logic.js` — the shared rules (Klondike, Blackjack, payouts, card backs). Must sit next to `index.html`.
- `cardbacks/` — small cropped pinup portraits for face-down cards. The Navy anchor works without these pictures.
- `tests/run-tests.js` — `npm test` / `node tests/run-tests.js` drives the shipped logic.
- `CREATION-GUIDE.md` — how it was built, how to put it on the phone, and the improvement roadmap.

## Try it on the PC

Double-click `index.html` (opens in your browser), or serve it:

```bash
npx http-server "C:/Users/lloyd/Projects/the-captains-deck" -p 8123
```

## Put it on the phone

See **Part 6** of the Creation Guide — short version: copy `index.html` to the phone's Downloads, tap it, choose Chrome, then ⋮ → *Add to Home screen*.

Originally designed in Godot (github.com/TheRealLloydFrazier/The-Captain-s-Deck-For-Grandpa-Ralph); this web edition carries that design forward so it can sail today.
