extends Control
## MainMenu.gd - The Casino Lobby
## Big buttons for game selection, coin display, and access to shop/collection

# =============================================================================
# NODES
# =============================================================================
@onready var coin_label: Label = $VBoxContainer/TopBar/CoinDisplay/CoinLabel
@onready var streak_label: Label = $VBoxContainer/TopBar/StreakDisplay/StreakLabel
@onready var daily_button: Button = $VBoxContainer/TopBar/DailyButton
@onready var game_buttons: VBoxContainer = $VBoxContainer/GameButtons
@onready var bottom_buttons: HBoxContainer = $VBoxContainer/BottomBar

# Game scene paths
const SCENES = {
	"blackjack": "res://Scenes/Games/Blackjack/Blackjack.tscn",
	"solitaire": "res://Scenes/Games/Solitaire/Solitaire.tscn",
	"slots": "res://Scenes/Games/Slots/Slots.tscn",
	"craps": "res://Scenes/Games/Craps/Craps.tscn",
	"shop": "res://Scenes/Shop.tscn",
	"collection": "res://Scenes/Collection.tscn",
	"settings": "res://Scenes/Settings.tscn"
}

# =============================================================================
# LIFECYCLE
# =============================================================================
func _ready() -> void:
	_connect_signals()
	_update_displays()
	_check_daily_challenge()
	_play_intro_animation()

func _connect_signals() -> void:
	Global.coins_changed.connect(_on_coins_changed)
	Global.streak_updated.connect(_on_streak_updated)

# =============================================================================
# DISPLAY UPDATES
# =============================================================================
func _update_displays() -> void:
	_update_coin_display()
	_update_streak_display()

func _update_coin_display() -> void:
	if coin_label:
		coin_label.text = "%d" % Global.coins

func _update_streak_display() -> void:
	if streak_label:
		var best_streak = 0
		for game in Global.win_streaks:
			best_streak = max(best_streak, Global.win_streaks[game])
		streak_label.text = "Best Streak: %d" % best_streak

func _check_daily_challenge() -> void:
	if daily_button:
		if Global.is_daily_completed():
			daily_button.text = "DAILY COMPLETE!"
			daily_button.disabled = true
			daily_button.modulate = Color(0.7, 0.7, 0.7)
		else:
			daily_button.text = "DAILY CHALLENGE"
			daily_button.disabled = false
			# Pulse animation to draw attention
			var tween = create_tween()
			tween.set_loops()
			tween.tween_property(daily_button, "modulate", Color(1.2, 1.2, 0.8), 0.5)
			tween.tween_property(daily_button, "modulate", Color.WHITE, 0.5)

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================
func _on_coins_changed(new_amount: int) -> void:
	_update_coin_display()
	# Coin change animation
	if coin_label:
		var tween = create_tween()
		tween.tween_property(coin_label, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(coin_label, "scale", Vector2(1.0, 1.0), 0.1)

func _on_streak_updated(_game: String, _new_streak: int) -> void:
	_update_streak_display()

# =============================================================================
# BUTTON HANDLERS
# =============================================================================
func _on_blackjack_pressed() -> void:
	_go_to_game("blackjack")

func _on_solitaire_pressed() -> void:
	_go_to_game("solitaire")

func _on_slots_pressed() -> void:
	_go_to_game("slots")

func _on_craps_pressed() -> void:
	_go_to_game("craps")

func _on_daily_pressed() -> void:
	# Start the daily challenge (guaranteed winnable Solitaire)
	# TODO: Pass the daily seed to Solitaire
	_go_to_game("solitaire")

func _on_shop_pressed() -> void:
	_go_to_scene("shop")

func _on_collection_pressed() -> void:
	_go_to_scene("collection")

func _on_settings_pressed() -> void:
	_go_to_scene("settings")

func _on_quit_pressed() -> void:
	# Save and quit
	Global._save_game()
	get_tree().quit()

# =============================================================================
# NAVIGATION
# =============================================================================
func _go_to_game(game_name: String) -> void:
	var path = SCENES.get(game_name)
	if path and ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		push_warning("Scene not found: %s" % path)
		_show_coming_soon(game_name)

func _go_to_scene(scene_name: String) -> void:
	var path = SCENES.get(scene_name)
	if path and ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		push_warning("Scene not found: %s" % path)
		_show_coming_soon(scene_name)

func _show_coming_soon(feature: String) -> void:
	# Show a friendly "coming soon" message
	# TODO: Implement popup dialog
	print("[MainMenu] %s coming soon!" % feature.capitalize())

# =============================================================================
# ANIMATIONS
# =============================================================================
func _play_intro_animation() -> void:
	# Stagger-fade in the menu buttons
	for i in range(game_buttons.get_child_count()):
		var button = game_buttons.get_child(i)
		button.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(button, "modulate:a", 1.0, 0.3).set_delay(i * 0.1)
