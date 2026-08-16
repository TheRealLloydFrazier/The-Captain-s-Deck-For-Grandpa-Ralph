# The Captain's Deck

**A Casino RPG for Grandpa Ralph**

## Playable now (web edition — no ads, no internet)

The game Grandpa can actually play today lives in **[`web/`](web/)**. Open [`web/index.html`](web/index.html) in a browser, or copy the whole `web` folder onto his Android phone.

**Games:** Klondike Solitaire (tap-to-move, undo, hints) · Blackjack 21 with the Card-Counting Coach · Anchor Slots · War at Sea  
**Extras:** Grandpa Coins, Daily Muster, the Fleet, Settings card-back picker (Navy anchor or tasteful sailor-sweetheart pinups)

```
web/index.html          lobby + all games
web/captains-logic.js   shared rules (required sibling file)
web/cardbacks/          pinup portraits for face-down cards
web/tests/run-tests.js  node tests/run-tests.js
```

The Godot 4 project below is the original design. Only Blackjack and the main menu were coded there. The web folder is the finished, phone-ready room.

---

A lovingly crafted card game experience with Navy themes, WWII-era aesthetics, and personalized rewards. Built with Godot 4.

## Features

### Games
- **Blackjack** - Full implementation with card counting coach and Basic Strategy hints
- **Solitaire** - Klondike with Draw 1/Draw 3 modes, hints, and undo
- **Slots** - Generous payouts with satisfying visual effects
- **Craps** - Tutorial-driven gameplay with helper character

### The "Grandpa-Friendly" Experience
- **Large, high-contrast cards** with optional 4-color deck mode
- **Oversized hitboxes** (1.5x larger than visible) for easier clicking
- **Forgiving input** - support for both click and drag interactions
- **No punishment for mistakes** - invalid moves gently return cards to position
- **Optional tablet/touch mode** for intuitive gameplay

### Card Counter's Academy (Blackjack)
- Hi-Lo card counting display
- Real-time strategy recommendations
- Three coaching styles: Classic, Aggressive, Conservative
- Friendly coaching messages in nautical theme
- Count-based betting advice

### Rewards & Collection
- **Grandpa Coins** - Earn coins from every game
- **Unlockable Card Backs** - Navy themes, vintage pinup art
- **The Fleet** - Collect Navy ships with historical encyclopedia entries
- **Table Felts** - Customize your gaming surface
- **Daily Challenges** - Guaranteed-winnable Solitaire with calendar tracking

### The "Juice" (Visual Satisfaction)
- Squash & stretch card animations
- Magnetic snap to valid positions
- Victory particle effects
- Pitch-ramping card sounds for rapid moves
- Windows Solitaire-style victory cascade

### Dynamic Difficulty
- Hidden loss streak tracking
- Subtle deck rigging after consecutive losses
- Player always has fun - never crushed by RNG

## Project Structure

```
res://
├── Assets/
│   ├── Audio/          # Sound effects and music
│   ├── Sprites/        # Cards, ships, helpers, UI
│   └── Fonts/          # Large, readable fonts
├── Data/
│   ├── ships_data.json       # Navy ship encyclopedia
│   ├── strategy_tables.json  # Blackjack reference
│   └── sample_save_game.json # Save file structure
├── Scenes/
│   ├── MainMenu.tscn         # Casino lobby
│   └── Games/                # Individual game scenes
└── Scripts/
    ├── Core/
    │   ├── Global.gd    # Autoload: coins, settings, saves
    │   ├── Card.gd      # Card class with animations
    │   ├── Zone.gd      # Pile/hand management
    │   └── Dealer.gd    # Shuffling, dealing, counting
    ├── Games/
    │   ├── BlackjackGame.gd    # Blackjack controller
    │   └── BlackjackStrategy.gd # Strategy coach
    └── UI/
        └── MainMenu.gd  # Lobby controller
```

## Getting Started

1. Open the project in Godot 4.2+
2. Run the MainMenu scene
3. All progress saves automatically to `user://save_game.json`

## Ship Collection Highlights

- **USS Missouri** - Where WWII ended
- **USS Enterprise (CV-6)** - The Big E, most decorated ship
- **USS Arizona** - In honored memory (unlocked by default)
- **PT-109** - JFK's command
- **F4U Corsair** - "Whistling Death"
- And many more...

## Future Roadmap

- Poker tournaments with AI opponents
- Roulette wheel
- "Mob Boss" campaign mode
- Family photo deck customization
- Voice lines for helper characters

## Built With Love

For Grandpa Ralph, from his family. Because the best games are made for the people we love.

---

*"The Captain's Deck" - Where every hand is dealt with care.*
