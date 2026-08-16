# The Captain's Deck — Creation Guide

**How Grandpa Ralph's game was found, finished, and how to keep making it better.**

This guide walks through the whole journey step by step: what you had, the decisions that were made, how each part of the game was built, how it was tested, exactly how to put it on Grandpa Ralph's Android phone, and a roadmap for improving it. It's written so you can pick up any piece of it yourself — or hand any step to an AI assistant and know what to ask for.

---

## Part 1 — Where the project stood

You had three things scattered around:

1. **The Godot project** (`The-Captain-s-Deck-For-Grandpa-Ralph` on your GitHub, plus a copy in Downloads). This held your *vision*: a Navy-themed casino for Grandpa Ralph with Solitaire, Blackjack, Slots, and Craps, "Grandpa Coins," a collectible fleet of WWII ships, and a card-counting coach. But only **Blackjack and the main menu were actually coded** — Solitaire existed only in the README.
2. **A React Native starter** (`grandpad-card-suite-starter` in Downloads) — mostly an empty skeleton.
3. **Great design documents inside the Godot code** — the basic strategy tables, the Hi-Lo counting system, the "quietly help him when he's losing" difficulty system, ship encyclopedia data, and the coaching voice ("Victory is yours, Captain!").

**None of your design work was wasted.** All of it was carried into the finished game.

## Part 2 — The big decision: why a web app instead of an APK

The goal: *runs on an older Android phone, no adware, easy to install, easy for Grandpa to open.*

| Option | Verdict |
|---|---|
| Finish the Godot project → export APK | Needs Android SDK + Java JDK + 1 GB of export templates + signing keys. Fragile, and Godot 4 can struggle on older phones. Good **future** path — kept on the roadmap. |
| Finish the React Native starter → APK | Same heavy toolchain problem, plus cloud build services. |
| **One self-contained HTML folder** | **Chosen.** Runs in the Chrome browser every Android phone already has. Works offline. No app store, no ads, no permissions, no tracking. `index.html` plus `captains-logic.js` and a few tiny card-back pictures. |

A web page in the phone's browser is the most reliable "app" an older phone can run. Copy the whole `the-captains-deck` folder onto the phone and tap `index.html`.

## Part 3 — The design pillars (your rules, kept)

Everything in the build answers to these five rules from your original README:

1. **Big and readable.** Large type, high contrast, cards drawn as crisp text (no blurry images), an "easy-to-see suits" mode that colors diamonds blue and clubs green, and a card-size setting up to Huge.
2. **Forgiving input.** No precise drag-and-drop needed. Tap a card, then tap where it goes. Tapping a card that can go "up" to the foundations just sends it there. Wrong moves get a gentle shake, never a punishment.
3. **Never crush him.** Unlimited undo, unlimited re-deals, free hints, and the hidden **Dynamic Difficulty** system: after 3 straight losses, the decks quietly warm up (up to 60% help after 6 losses — your exact numbers from `Global.gd`). If he ever runs low, the "Navy Relief Fund" restocks his coins. He can always play.
4. **Give him things to look forward to.** Grandpa Coins from every game, a Daily Muster bonus, win streaks, and the Fleet — all 16 of your ships and aircraft with their real histories, unlockable with winnings. USS Arizona sails with him from the start, exactly as you designed.
5. **Make it feel loved.** The nautical coaching voice, the dedication on the lobby screen, the victory cascade when he wins Solitaire. He should feel this was made *for him*, because it was.

## Part 4 — How the game was built, step by step

Each step below matches a labeled section banner in `index.html` (search the file for the `====` banners).

### Step 1 — One screen, many rooms
The file is a single page holding seven "screens" (lobby, solitaire, blackjack, slots, war, fleet, settings) as hidden panels. A tiny `showScreen()` function shows one and hides the rest — that's the whole navigation system. The phone's back button returns to the lobby instead of closing the game (a small `history` trick old Chrome understands).

### Step 2 — The look
All styling is plain CSS at the top of the file: navy blues, brass gold, casino-felt green, Georgia serif for titles. Two rules keep it working on older phones: **flexbox only** (no modern grid layout), and **transform-based animation only** (the one kind of animation old phones draw smoothly). Buttons are minimum 48 pixels tall — easy targets for big thumbs.

### Step 3 — The save system
One JavaScript object `S` holds everything: coins, settings, stats, streaks, the fleet, and even the half-finished solitaire deal. It's saved to the phone's `localStorage` (a tiny permanent storage every browser has) a moment after anything changes. Close the app mid-game, reopen it a week later — the same deal is waiting. *Lesson learned during testing: any new field must also be added to `defaultSave()`, or the loader will silently drop it.*

### Step 4 — Sounds with no sound files
Every click, card flip, coin ding, and victory fanfare is **synthesized** with the browser's WebAudio — little sine and triangle wave notes (the win fanfare is just C-E-G-C). Zero downloads, and a Sounds toggle in Settings turns it all off.

### Step 5 — Cards without pictures (and optional pinup backs)
Each card is a small HTML box: rank and suit in the corner, one big suit symbol at the bottom. Text stays razor-sharp at any size, which beats images for older eyes on older screens. Face-down cards default to the navy back with the gold anchor. Settings also offers a few compressed vintage sailor-sweetheart portraits (classic pinup, clothed / swimsuit — never explicit). Those pictures live as small JPEGs in `cardbacks/` and are painted by `CaptainsDeck.applyFaceDownBack` in `captains-logic.js`.

### Step 6 — Solitaire (the heart of it)
Built in this order, and worth understanding as a pattern for any card game:

1. **State first.** The whole game is just lists of cards: 1 stock, 1 waste, 4 foundations, 7 tableau piles. Every card is `{rank, suit, faceUp}`.
2. **Deal.** Pile 1 gets 1 card, pile 2 gets 2… only the top card face-up. The remaining 24 go to the stock.
3. **Rules as small functions.** "Can this card go there?" is one function (`solValidDest`): foundations take same-suit going up from Ace; tableau takes alternating colors going down; empty columns take Kings. Write the rules once, and moving, hints, and auto-finish all reuse them.
4. **Tap-to-move.** First tap selects a card (and everything stacked on it); valid landing spots glow green; second tap drops it. Tapping the same card again sends it to the foundation if it fits. This is far kinder to shaky hands than drag-and-drop.
5. **Undo as snapshots.** Before every move, the whole layout is photographed into a list (up to 300 deep). Undo just restores the last photo. Simple and unbreakable.
6. **Hints that teach.** The hint button looks for moves in priority order — foundation moves first, then moves that uncover hidden cards, then waste cards, then "draw from the stock, Captain" — flashes the card, and says the move out loud in plain words.
7. **The finish.** When the stock is empty and every card is face-up, a big **FINISH THE GAME** button appears and flies the rest home. Then: the classic falling-card cascade, the victory fanfare, +200 coins (more on a streak), +100 the first win each day.

### Step 7 — Blackjack: the Card Counter's Academy
Ported line-for-line from your Godot scripts: the full basic-strategy matrix (hard totals, soft totals — stored as compact rule strings), the Hi-Lo running count (2–6 = +1, 10–Ace = −1), true count, count-based deviation plays ("Count is high — stand on 16 vs 10!"), bet advice, and your coach messages word for word. The coach highlights the recommended button with a golden pulse. Six-deck shoe, reshuffles at 25%, dealer stands on 17, blackjack pays 3:2. Split is not in yet — it was a TODO in your Godot code too; it's on the roadmap.

### Step 8 — Anchor Slots and War at Sea
Slots: three reels, weighted symbols, generous paytable (a single anchor gives the bet back — about 87% return before help). The outcome is decided the instant he spins; the spinning reels are showmanship. War at Sea is the simplest game in the room — one button, high card wins, ties trigger a dramatic WAR at no extra cost. Perfect for low-energy days.

### Step 9 — The quiet helper (Dynamic Difficulty)
Your `create_rigged_deck` algorithm, ported: when a game's hidden loss streak hits 3, high cards drift toward the draw positions (blackjack), the slot machine starts "warming up" (18%+ forced-win chance), War favors his flip, and Solitaire re-shuffles until at least two Aces sit near the surface. He never sees it. He just starts winning again.

### Step 10 — The Fleet
All 16 ships from your `ships_data.json`, each drawn as a small silhouette (battleship, carrier, destroyer, submarine, PT boat, aircraft) tinted by rarity color. Locked ships show their coin price; tapping an owned ship opens its encyclopedia card — specs plus the "fun fact" you wrote. USS Arizona is free and pre-unlocked, "in honor of those who gave all."

## Part 5 — How it was tested

All of this was verified in a phone-sized browser (375px wide) before delivery:

- Deal integrity — 28 tableau + 24 stock = 52, every game, every time
- Move rules — red-on-black yes, red-on-red no, Kings to empty columns, Aces up
- Draw, recycle the stock, undo, hints, draw-3 fanning
- A full solitaire win through the real pipeline: cascade, +300 coins, streak, stats, modal
- A full blackjack hand: correct coach advice (12 vs Ace → Hit), dealer played by the book, correct 2× payout on a dealer bust
- Slots spin economics and War payout
- Fleet rendering, unlocking, settings toggles, four-color mode
- Daily Muster pays once and refuses seconds
- **Close-and-reopen** — coins and the half-played deal both survive
- No horizontal scrolling and no undersized buttons on any screen; zero console errors

**Your re-test ritual after any change** (2 minutes): open the game on your PC in Chrome → press F12 → Console tab (red lines = problems) → deal solitaire, make 3 moves, undo once, get a hint → play one blackjack hand → one spin, one battle → refresh the page and confirm your coins and deal survived.

## Part 6 — Putting it on Grandpa Ralph's phone

The game lives in: `C:\Users\lloyd\Projects\the-captains-deck\`

Copy the **whole folder** — `index.html`, `captains-logic.js`, and the `cardbacks` pictures. The Navy-anchor back still works if the pictures are missing.

### Way 1 — Copy the folder (simplest; works on any phone; offline forever)
1. Get the folder onto the phone. Any of these works:
   - **USB cable:** plug the phone into the PC, choose "File transfer" on the phone, copy the whole `the-captains-deck` folder into the phone's **Download** folder.
   - **Zip + email:** zip the folder, email it, open the email on the phone, download and unzip.
   - **Google Drive:** upload the folder from the PC, then in the Drive app on the phone download it.
2. On the phone, open the **Files** (or "My Files") app → **Downloads** → open `the-captains-deck` → tap `index.html`. If it asks, choose **Chrome** and tap **Always**.
3. That's it — the game runs, saves his progress, and never needs internet again. Settings has the card-back picker (Navy default or a sailor-sweetheart pinup).
4. To make it one-tap for Grandpa: with the game open in Chrome, tap ⋮ → **Add to Home screen**. A Captain's Deck icon lands on his home screen.

### Way 2 — Free hosting + a real home-screen icon (nicest)
Host the file for free, and the game installs like an app:

- **GitHub Pages** (you already have the repo): add `index.html` to the repo → on github.com open the repo → **Settings → Pages** → Source: *Deploy from a branch* → Branch: `main`, folder `/ (root)` → Save. A few minutes later the game lives at
  `https://thereallloydfrazier.github.io/The-Captain-s-Deck-For-Grandpa-Ralph/`
- **Or Vercel**, which you already use for your other sites — drag the folder into a new project.

Then on Grandpa's phone: open that address in Chrome → ⋮ → **Add to Home screen**. He gets a real icon with the game's name, opening full-screen. One honest note: hosted this way it wants internet when it opens (his progress still lives safely on the phone). For guaranteed-offline, use Way 1 — or add the "service worker" from the roadmap below, which makes the hosted version work offline too.

### Way 3 — A true APK (optional, someday)
Two routes, both heavier: **(a)** finish your Godot project — your PC already has an Android SDK; you'd add JDK 17 and Godot's export templates and follow Godot's "Exporting for Android" guide; or **(b)** wrap this exact web game with **Capacitor** (a tool that puts a web page inside a real installable app). Do this only if Way 1 or 2 ever falls short — they likely won't.

## Part 7 — The improvement roadmap

Ranked easiest → hardest. Each is a clean, self-contained ask.

| # | Improvement | Difficulty | Notes |
|---|---|---|---|
| 1 | Change coin rewards, starting coins, or slot payouts | ★ | All plain numbers near the top of each game's section |
| 2 | More ships in the Fleet | ★ | Copy any entry in the `SHIPS` list and edit the words |
| 3 | A "Stats" page (games played, best time, biggest win) | ★★ | The numbers are already tracked in `S.stats` — they just need a screen |
| 4 | **Family photo card backs** — your "Family Deck" idea | ★★ | Photos can be embedded right into the file as data-URIs |
| 5 | Service worker → hosted version works offline | ★★ | ~20 lines; makes Way 2 perfect |
| 6 | Blackjack split hands | ★★★ | The strategy table already knows when to split — the game needs a second hand zone |
| 7 | Guaranteed-winnable daily Solitaire deal | ★★★ | Deal a solved game backwards, then shuffle it forward a fixed number of legal moves |
| 8 | Craps with the tutorial helper (your original roadmap) | ★★★★ | Biggest game; the coach panel pattern from Blackjack is the template |
| 9 | Voice lines for the coach | ★★★ | The browser's built-in speech voice (`speechSynthesis`) costs nothing |
| 10 | True APK via Godot or Capacitor | ★★★★ | Only if a store-style install is ever truly needed |

**How to ask an AI for any of these** (the vibe-coder workflow that keeps the game safe):

1. Make a copy of `index.html` first (e.g. `index-backup-2026-08-10.html`).
2. Ask for **one change at a time**, naming the section banner: *"In the ANCHOR SLOTS section of this file, add a fourth reel. Don't change anything else."*
3. Run the 2-minute re-test ritual from Part 5.
4. Only replace the phone's copy after it passes.

## Part 8 — Troubleshooting

- **Blank page?** Something broke the code. On the PC, F12 → Console shows the line. Restore your backup copy.
- **Cards too small?** Settings → Card size → Large or Huge. (The four-color deck helps more than size, for telling suits apart.)
- **Progress vanished?** Progress lives in the browser's storage. Clearing Chrome's "browsing data" erases it — uncheck "Cookies and site data" when clearing, or just know the Relief Fund will float him again.
- **No sound?** Phones only allow sound after the first tap — tap any button once. Also check Settings → Sounds, and the phone's media volume.
- **He keeps losing?** He won't for long — that's the quiet helper's job. To make the whole game gentler permanently, raise the help numbers in the `shouldHelp`/`helpIntensity` functions.

---

*Built with love for Grandpa Ralph — finished August 10, 2026. Every hand dealt with care.*
