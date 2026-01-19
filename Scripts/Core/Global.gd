extends Node
## Global.gd - The Hub: Manages coins, settings, inventory, and save/load system
## Autoloaded as "Global" - accessible from any script via Global.coins, etc.

# =============================================================================
# SIGNALS
# =============================================================================
signal coins_changed(new_amount: int)
signal item_unlocked(item_type: String, item_id: String)
signal settings_changed(setting_name: String, new_value: Variant)
signal streak_updated(game: String, new_streak: int)

# =============================================================================
# THE "GRANDPA COIN" ECONOMY
# =============================================================================
var coins: int = 100:  # Starting coins for a new player
	set(value):
		coins = max(0, value)  # Never go negative
		coins_changed.emit(coins)
		_queue_save()

# Win streak tracking (visible to player - he loves beating his own streaks)
var win_streaks: Dictionary = {
	"solitaire": 0,
	"blackjack": 0,
	"slots": 0,
	"craps": 0
}

# Hidden stats for Dynamic Difficulty Adjustment (DDA)
# If he loses 3+ hands in a row, we subtly help him out
var _hidden_loss_streaks: Dictionary = {
	"solitaire": 0,
	"blackjack": 0,
	"slots": 0,
	"craps": 0
}

# =============================================================================
# UNLOCKABLES INVENTORY
# =============================================================================
# Card backs he's unlocked (Navy nose art / pinup style)
var unlocked_card_backs: Array[String] = ["classic_navy"]  # Starts with default
var active_card_back: String = "classic_navy"

# Table felts/backgrounds
var unlocked_table_felts: Array[String] = ["green_felt"]
var active_table_felt: String = "green_felt"

# Ships in his Fleet (the encyclopedia collection)
var unlocked_ships: Array[String] = []

# Special unlocks
var unlocked_specials: Array[String] = []

# Daily challenge tracking
var daily_challenges_completed: Dictionary = {}  # { "2024-01-15": true, ... }
var current_daily_seed: int = 0

# =============================================================================
# SETTINGS (Grandpa-Friendly UX)
# =============================================================================
var settings: Dictionary = {
	# Visual settings
	"four_color_deck": false,       # Clubs=Green, Diamonds=Blue for visibility
	"card_scale": 1.0,              # 0.8 to 1.5 - larger cards for visibility
	"high_contrast": false,         # Extra contrast mode
	"animation_speed": 1.0,         # 0.5 (slow) to 2.0 (fast)

	# Solitaire settings
	"solitaire_draw_count": 1,      # Draw 1 or Draw 3
	"solitaire_hints_enabled": true,
	"solitaire_undo_enabled": true, # Easy mode has undo

	# Blackjack settings
	"blackjack_coach_mode": true,   # Show card counting helper
	"blackjack_hint_style": "classic",  # "classic", "aggressive", or "off"
	"blackjack_show_count": true,   # Show running count in corner

	# Audio settings
	"master_volume": 0.8,
	"music_volume": 0.6,
	"sfx_volume": 1.0,
	"voice_enabled": true,          # Helper character voice lines

	# Accessibility
	"touch_mode": false,            # Larger hit areas for tablet
	"confirm_bets": true,           # Require confirmation on big bets
}

# =============================================================================
# STATISTICS (for achievements/bragging rights)
# =============================================================================
var stats: Dictionary = {
	"total_games_played": 0,
	"total_coins_earned": 0,
	"total_coins_spent": 0,
	"solitaire_games_won": 0,
	"solitaire_games_played": 0,
	"solitaire_best_time": 0,        # Seconds (0 = no record)
	"solitaire_cards_moved": 0,
	"blackjack_games_won": 0,
	"blackjack_games_played": 0,
	"blackjack_blackjacks": 0,       # Natural 21s
	"blackjack_biggest_win": 0,
	"slots_games_played": 0,
	"slots_jackpots": 0,
	"slots_biggest_win": 0,
	"craps_games_played": 0,
	"craps_points_made": 0,
	"longest_session_minutes": 0,
}

# =============================================================================
# SAVE/LOAD SYSTEM
# =============================================================================
const SAVE_PATH = "user://save_game.json"
var _save_queued: bool = false

func _ready() -> void:
	_load_game()
	_update_daily_seed()

func _update_daily_seed() -> void:
	# Generate a daily seed for the daily challenge (guaranteed winnable)
	var date = Time.get_date_dict_from_system()
	current_daily_seed = hash("%d-%02d-%02d" % [date.year, date.month, date.day])

func _queue_save() -> void:
	# Debounce saves - don't save on every coin change
	if not _save_queued:
		_save_queued = true
		await get_tree().create_timer(1.0).timeout
		_save_game()
		_save_queued = false

func _save_game() -> void:
	var save_data: Dictionary = {
		"coins": coins,
		"win_streaks": win_streaks,
		"unlocked_card_backs": unlocked_card_backs,
		"active_card_back": active_card_back,
		"unlocked_table_felts": unlocked_table_felts,
		"active_table_felt": active_table_felt,
		"unlocked_ships": unlocked_ships,
		"unlocked_specials": unlocked_specials,
		"daily_challenges_completed": daily_challenges_completed,
		"settings": settings,
		"stats": stats,
		"save_version": 1,
		"last_played": Time.get_datetime_string_from_system()
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		print("[Global] Game saved successfully")

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[Global] No save file found, using defaults")
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_warning("[Global] Could not open save file")
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_warning("[Global] Failed to parse save file: " + json.get_error_message())
		return

	var data: Dictionary = json.data

	# Load each field with type safety
	coins = data.get("coins", 100)
	win_streaks = data.get("win_streaks", win_streaks)
	unlocked_card_backs = Array(data.get("unlocked_card_backs", unlocked_card_backs), TYPE_STRING, "", null)
	active_card_back = data.get("active_card_back", active_card_back)
	unlocked_table_felts = Array(data.get("unlocked_table_felts", unlocked_table_felts), TYPE_STRING, "", null)
	active_table_felt = data.get("active_table_felt", active_table_felt)
	unlocked_ships = Array(data.get("unlocked_ships", unlocked_ships), TYPE_STRING, "", null)
	unlocked_specials = Array(data.get("unlocked_specials", unlocked_specials), TYPE_STRING, "", null)
	daily_challenges_completed = data.get("daily_challenges_completed", daily_challenges_completed)

	# Merge settings (preserving new settings that weren't in save)
	var saved_settings = data.get("settings", {})
	for key in saved_settings:
		if settings.has(key):
			settings[key] = saved_settings[key]

	# Merge stats
	var saved_stats = data.get("stats", {})
	for key in saved_stats:
		if stats.has(key):
			stats[key] = saved_stats[key]

	print("[Global] Game loaded successfully - Coins: %d" % coins)

# =============================================================================
# ECONOMY FUNCTIONS
# =============================================================================
func add_coins(amount: int, source: String = "") -> void:
	coins += amount
	stats.total_coins_earned += amount
	if source:
		print("[Global] +%d coins from %s (Total: %d)" % [amount, source, coins])

func spend_coins(amount: int, item: String = "") -> bool:
	if coins >= amount:
		coins -= amount
		stats.total_coins_spent += amount
		if item:
			print("[Global] -%d coins for %s (Remaining: %d)" % [amount, item, coins])
		return true
	return false

func can_afford(amount: int) -> bool:
	return coins >= amount

# =============================================================================
# UNLOCK FUNCTIONS
# =============================================================================
func unlock_card_back(card_back_id: String) -> void:
	if card_back_id not in unlocked_card_backs:
		unlocked_card_backs.append(card_back_id)
		item_unlocked.emit("card_back", card_back_id)
		_queue_save()

func unlock_table_felt(felt_id: String) -> void:
	if felt_id not in unlocked_table_felts:
		unlocked_table_felts.append(felt_id)
		item_unlocked.emit("table_felt", felt_id)
		_queue_save()

func unlock_ship(ship_id: String) -> void:
	if ship_id not in unlocked_ships:
		unlocked_ships.append(ship_id)
		item_unlocked.emit("ship", ship_id)
		_queue_save()

func is_unlocked(item_type: String, item_id: String) -> bool:
	match item_type:
		"card_back": return item_id in unlocked_card_backs
		"table_felt": return item_id in unlocked_table_felts
		"ship": return item_id in unlocked_ships
		"special": return item_id in unlocked_specials
	return false

# =============================================================================
# STREAK & DDA (Dynamic Difficulty Adjustment)
# =============================================================================
func record_win(game: String) -> void:
	win_streaks[game] = win_streaks.get(game, 0) + 1
	_hidden_loss_streaks[game] = 0
	streak_updated.emit(game, win_streaks[game])
	_queue_save()

func record_loss(game: String) -> void:
	win_streaks[game] = 0
	_hidden_loss_streaks[game] = _hidden_loss_streaks.get(game, 0) + 1
	streak_updated.emit(game, 0)
	_queue_save()

func should_help_player(game: String) -> bool:
	# If he's lost 3+ in a row, give him a little luck
	return _hidden_loss_streaks.get(game, 0) >= 3

func get_help_intensity(game: String) -> float:
	# Returns 0.0 to 1.0 based on how much we should help
	var losses = _hidden_loss_streaks.get(game, 0)
	if losses < 3:
		return 0.0
	return clamp((losses - 2) * 0.15, 0.0, 0.6)  # Max 60% help after 6 losses

# =============================================================================
# DAILY CHALLENGE
# =============================================================================
func is_daily_completed() -> bool:
	var today = _get_today_string()
	return daily_challenges_completed.get(today, false)

func complete_daily_challenge() -> void:
	var today = _get_today_string()
	daily_challenges_completed[today] = true
	add_coins(100, "Daily Challenge")  # Bonus for daily
	_queue_save()

func _get_today_string() -> String:
	var date = Time.get_date_dict_from_system()
	return "%d-%02d-%02d" % [date.year, date.month, date.day]

func get_daily_streak() -> int:
	# Count consecutive days of completed challenges
	var streak = 0
	var date = Time.get_date_dict_from_system()
	var unix = Time.get_unix_time_from_datetime_dict(date)

	while true:
		var check_date = Time.get_date_dict_from_unix_time(unix)
		var date_str = "%d-%02d-%02d" % [check_date.year, check_date.month, check_date.day]
		if daily_challenges_completed.get(date_str, false):
			streak += 1
			unix -= 86400  # Go back one day
		else:
			break

	return streak

# =============================================================================
# SETTINGS HELPERS
# =============================================================================
func set_setting(key: String, value: Variant) -> void:
	if settings.has(key):
		settings[key] = value
		settings_changed.emit(key, value)
		_queue_save()

func get_setting(key: String, default: Variant = null) -> Variant:
	return settings.get(key, default)
