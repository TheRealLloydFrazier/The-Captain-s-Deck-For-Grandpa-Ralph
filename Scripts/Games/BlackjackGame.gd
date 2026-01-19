extends Node2D
## BlackjackGame.gd - The Blackjack game controller
## Implements the Card Counter's Academy with coaching and strategy hints

# =============================================================================
# ENUMS
# =============================================================================
enum GameState { BETTING, DEALING, PLAYER_TURN, DEALER_TURN, PAYOUT, GAME_OVER }

# =============================================================================
# SIGNALS
# =============================================================================
signal game_state_changed(new_state: GameState)
signal hand_result(player_won: bool, is_blackjack: bool, amount: int)

# =============================================================================
# CONSTANTS
# =============================================================================
const MIN_BET: int = 10
const MAX_BET: int = 500
const DEALER_STAND_VALUE: int = 17
const DECK_COUNT: int = 6  # Standard shoe

# =============================================================================
# PROPERTIES
# =============================================================================
var state: GameState = GameState.BETTING:
	set(value):
		state = value
		game_state_changed.emit(state)
		_on_state_changed()

var current_bet: int = MIN_BET
var player_zone: Zone
var dealer_zone: Zone
var deck_zone: Zone
var dealer: Dealer

# Coaching
var coach_enabled: bool = true
var hint_style: BlackjackStrategy.Style = BlackjackStrategy.Style.CLASSIC

# Insurance tracking
var insurance_offered: bool = false
var insurance_taken: bool = false
var insurance_bet: int = 0

# Split/Double tracking
var can_split: bool = false
var can_double: bool = true
var has_doubled: bool = false

# =============================================================================
# NODES (assigned in _ready or from scene)
# =============================================================================
@onready var hit_button: Button = $UI/ActionButtons/HitButton
@onready var stand_button: Button = $UI/ActionButtons/StandButton
@onready var double_button: Button = $UI/ActionButtons/DoubleButton
@onready var split_button: Button = $UI/ActionButtons/SplitButton
@onready var hint_button: Button = $UI/ActionButtons/HintButton
@onready var bet_label: Label = $UI/BetDisplay/BetLabel
@onready var count_label: Label = $UI/CountDisplay/CountLabel
@onready var coach_label: Label = $UI/CoachPanel/CoachMessage
@onready var player_value_label: Label = $UI/PlayerValueLabel
@onready var dealer_value_label: Label = $UI/DealerValueLabel

# =============================================================================
# LIFECYCLE
# =============================================================================
func _ready() -> void:
	_initialize_game()
	_connect_signals()
	_load_settings()

func _initialize_game() -> void:
	# Create the dealer (card handler)
	dealer = Dealer.new()
	add_child(dealer)
	dealer.setup_dynamic_difficulty("blackjack")

	# Create zones
	_create_zones()

	# Create and shuffle deck
	_new_shoe()

func _create_zones() -> void:
	# Player hand zone
	player_zone = Zone.new()
	player_zone.zone_type = Zone.ZoneType.HAND
	player_zone.stack_direction = Zone.StackDirection.RIGHT
	player_zone.card_offset = 40.0
	player_zone.position = Vector2(960, 700)  # Bottom center
	add_child(player_zone)

	# Dealer hand zone
	dealer_zone = Zone.new()
	dealer_zone.zone_type = Zone.ZoneType.DEALER_HAND
	dealer_zone.stack_direction = Zone.StackDirection.RIGHT
	dealer_zone.card_offset = 40.0
	dealer_zone.position = Vector2(960, 300)  # Top center
	add_child(dealer_zone)

	# Deck/shoe zone (off-screen right)
	deck_zone = Zone.new()
	deck_zone.zone_type = Zone.ZoneType.DECK
	deck_zone.position = Vector2(1700, 500)
	add_child(deck_zone)

func _connect_signals() -> void:
	if hit_button:
		hit_button.pressed.connect(_on_hit)
	if stand_button:
		stand_button.pressed.connect(_on_stand)
	if double_button:
		double_button.pressed.connect(_on_double)
	if split_button:
		split_button.pressed.connect(_on_split)
	if hint_button:
		hint_button.pressed.connect(_on_hint)

	player_zone.cards_changed.connect(_update_player_value)
	dealer_zone.cards_changed.connect(_update_dealer_value)

func _load_settings() -> void:
	coach_enabled = Global.get_setting("blackjack_coach_mode", true)
	var style_name = Global.get_setting("blackjack_hint_style", "classic")
	match style_name:
		"aggressive": hint_style = BlackjackStrategy.Style.AGGRESSIVE
		"conservative": hint_style = BlackjackStrategy.Style.CONSERVATIVE
		_: hint_style = BlackjackStrategy.Style.CLASSIC

# =============================================================================
# GAME FLOW
# =============================================================================
func _new_shoe() -> void:
	# Create fresh shoe with multiple decks
	var cards: Array[Card]
	if dealer.help_player:
		cards = dealer.create_rigged_deck(DECK_COUNT, dealer.help_intensity)
	else:
		cards = dealer.create_deck(DECK_COUNT)

	cards = dealer.shuffle_deck(cards)

	# Add cards to deck zone
	for card in cards:
		deck_zone.add_card(card, false)

func start_new_round() -> void:
	# Clear hands
	_clear_hands()

	# Reset tracking
	insurance_offered = false
	insurance_taken = false
	insurance_bet = 0
	can_double = true
	has_doubled = false

	# Check if shoe needs reshuffling (past 75% dealt)
	if deck_zone.card_count() < (DECK_COUNT * 52 * 0.25):
		_new_shoe()
		dealer.reset_count()
		_update_count_display()

	state = GameState.BETTING

func _on_state_changed() -> void:
	match state:
		GameState.BETTING:
			_enable_betting_ui()
		GameState.DEALING:
			_disable_all_buttons()
			_deal_initial_hands()
		GameState.PLAYER_TURN:
			_enable_player_actions()
			_update_coach_hint()
		GameState.DEALER_TURN:
			_disable_all_buttons()
			_play_dealer_turn()
		GameState.PAYOUT:
			_calculate_payout()
		GameState.GAME_OVER:
			_show_result_ui()

# =============================================================================
# BETTING PHASE
# =============================================================================
func _enable_betting_ui() -> void:
	# Show bet controls, hide action buttons
	_disable_all_buttons()
	# TODO: Show bet slider/buttons

func place_bet(amount: int) -> void:
	if state != GameState.BETTING:
		return

	if not Global.can_afford(amount):
		_show_message("Not enough coins, Captain!")
		return

	current_bet = clamp(amount, MIN_BET, min(MAX_BET, Global.coins))
	Global.spend_coins(current_bet, "Blackjack bet")
	_update_bet_display()
	state = GameState.DEALING

func _update_bet_display() -> void:
	if bet_label:
		bet_label.text = "Bet: %d" % current_bet

# =============================================================================
# DEALING PHASE
# =============================================================================
func _deal_initial_hands() -> void:
	await dealer.deal_blackjack_initial(deck_zone, player_zone, dealer_zone)

	# Check for blackjacks
	if player_zone.is_blackjack():
		if dealer_zone.get_card_at(0).rank == Card.Rank.ACE:
			# Could be push, wait for dealer
			_offer_insurance()
		else:
			# Player blackjack!
			state = GameState.PAYOUT
			return

	# Check if dealer shows Ace
	if dealer_zone.get_card_at(0).rank == Card.Rank.ACE:
		_offer_insurance()
		return

	# Check for pair (can split)
	can_split = player_zone.is_pair() and Global.can_afford(current_bet)

	state = GameState.PLAYER_TURN

func _offer_insurance() -> void:
	if not insurance_offered:
		insurance_offered = true
		# TODO: Show insurance dialog
		# For now, skip insurance (it's usually a bad bet anyway)
		_on_insurance_declined()

func _on_insurance_accepted() -> void:
	insurance_bet = current_bet / 2
	if Global.spend_coins(insurance_bet, "Insurance"):
		insurance_taken = true
	state = GameState.PLAYER_TURN

func _on_insurance_declined() -> void:
	state = GameState.PLAYER_TURN

# =============================================================================
# PLAYER TURN
# =============================================================================
func _enable_player_actions() -> void:
	if hit_button:
		hit_button.disabled = false
	if stand_button:
		stand_button.disabled = false
	if double_button:
		double_button.disabled = not (can_double and Global.can_afford(current_bet))
	if split_button:
		split_button.disabled = not can_split
	if hint_button:
		hint_button.disabled = not coach_enabled

func _on_hit() -> void:
	if state != GameState.PLAYER_TURN:
		return

	can_double = false  # Can only double on first two cards
	can_split = false

	dealer.deal_blackjack_hit(deck_zone, player_zone)
	_update_count_display()

	# Check for bust
	if player_zone.is_bust():
		state = GameState.PAYOUT
	else:
		_update_coach_hint()

func _on_stand() -> void:
	if state != GameState.PLAYER_TURN:
		return

	state = GameState.DEALER_TURN

func _on_double() -> void:
	if state != GameState.PLAYER_TURN or not can_double:
		return

	if not Global.spend_coins(current_bet, "Double down"):
		return

	has_doubled = true
	current_bet *= 2
	_update_bet_display()

	# Get exactly one more card, then stand
	dealer.deal_blackjack_hit(deck_zone, player_zone)
	_update_count_display()

	if player_zone.is_bust():
		state = GameState.PAYOUT
	else:
		state = GameState.DEALER_TURN

func _on_split() -> void:
	if state != GameState.PLAYER_TURN or not can_split:
		return

	# TODO: Implement split hands
	# This requires creating a second player zone
	_show_message("Split coming soon, Captain!")

func _on_hint() -> void:
	if state != GameState.PLAYER_TURN or not coach_enabled:
		return

	_show_strategy_hint()

# =============================================================================
# COACHING SYSTEM
# =============================================================================
func _update_coach_hint() -> void:
	if not coach_enabled or not coach_label:
		return

	var dealer_upcard = dealer_zone.get_card_at(0)
	if not dealer_upcard:
		return

	var recommendation = BlackjackStrategy.get_recommendation(
		player_zone,
		dealer_upcard,
		hint_style,
		can_split,
		can_double
	)

	var player_total = player_zone.get_hand_value()
	var dealer_value = dealer_upcard.get_blackjack_value()
	var is_soft = player_zone.is_soft_hand()

	var message = BlackjackStrategy.get_coaching_message(
		recommendation,
		player_total,
		dealer_value,
		is_soft
	)

	coach_label.text = message

func _show_strategy_hint() -> void:
	# Flash the recommended button
	var dealer_upcard = dealer_zone.get_card_at(0)
	if not dealer_upcard:
		return

	var recommendation = BlackjackStrategy.get_recommendation(
		player_zone,
		dealer_upcard,
		hint_style,
		can_split,
		can_double
	)

	var button_to_highlight: Button = null
	match recommendation:
		BlackjackStrategy.Action.HIT:
			button_to_highlight = hit_button
		BlackjackStrategy.Action.STAND:
			button_to_highlight = stand_button
		BlackjackStrategy.Action.DOUBLE:
			button_to_highlight = double_button
		BlackjackStrategy.Action.SPLIT:
			button_to_highlight = split_button

	if button_to_highlight:
		_flash_button(button_to_highlight)

func _flash_button(button: Button) -> void:
	var original_color = button.modulate
	var tween = create_tween()
	tween.tween_property(button, "modulate", Color.YELLOW, 0.2)
	tween.tween_property(button, "modulate", original_color, 0.2)
	tween.tween_property(button, "modulate", Color.YELLOW, 0.2)
	tween.tween_property(button, "modulate", original_color, 0.2)

# =============================================================================
# DEALER TURN
# =============================================================================
func _play_dealer_turn() -> void:
	# Reveal hole card
	dealer.reveal_dealer_hole(dealer_zone)
	_update_count_display()
	_update_dealer_value()

	await get_tree().create_timer(0.5).timeout

	# Dealer hits on soft 17 and below
	while dealer_zone.get_hand_value() < DEALER_STAND_VALUE:
		dealer.deal_blackjack_hit(deck_zone, dealer_zone)
		_update_count_display()
		_update_dealer_value()
		await get_tree().create_timer(0.5).timeout

	state = GameState.PAYOUT

# =============================================================================
# PAYOUT
# =============================================================================
func _calculate_payout() -> void:
	var player_value = player_zone.get_hand_value()
	var dealer_value = dealer_zone.get_hand_value()
	var player_blackjack = player_zone.is_blackjack()
	var dealer_blackjack = dealer_zone.is_blackjack()
	var player_bust = player_zone.is_bust()
	var dealer_bust = dealer_zone.is_bust()

	var winnings = 0
	var player_won = false

	# Handle insurance first
	if insurance_taken and dealer_blackjack:
		winnings += insurance_bet * 3  # 2:1 payout + original bet
		Global.add_coins(winnings, "Insurance payout")

	# Main hand
	if player_bust:
		# Player busts, loses bet (already deducted)
		player_won = false
		_show_message("Bust! The sea claims this one, Captain.")
		Global.record_loss("blackjack")
	elif player_blackjack and not dealer_blackjack:
		# Blackjack pays 3:2
		winnings = current_bet + int(current_bet * 1.5)
		Global.add_coins(winnings, "Blackjack!")
		Global.stats.blackjack_blackjacks += 1
		player_won = true
		_show_message("BLACKJACK! 21 on the nose!")
		Global.record_win("blackjack")
	elif dealer_bust:
		# Dealer busts, player wins
		winnings = current_bet * 2
		Global.add_coins(winnings, "Dealer bust")
		player_won = true
		_show_message("Dealer busts! Victory is yours, Captain!")
		Global.record_win("blackjack")
	elif player_blackjack and dealer_blackjack:
		# Push on blackjack
		winnings = current_bet  # Return bet
		Global.add_coins(winnings, "Push")
		_show_message("Push! Both blackjack. Your bet is returned.")
	elif player_value > dealer_value:
		# Player wins
		winnings = current_bet * 2
		Global.add_coins(winnings, "Blackjack win")
		player_won = true
		_show_message("You win! %d beats %d!" % [player_value, dealer_value])
		Global.record_win("blackjack")
	elif player_value < dealer_value:
		# Dealer wins
		player_won = false
		_show_message("Dealer wins with %d. Better luck next hand, Captain." % dealer_value)
		Global.record_loss("blackjack")
	else:
		# Push
		winnings = current_bet  # Return bet
		Global.add_coins(winnings, "Push")
		_show_message("Push! %d ties %d. Your bet is returned." % [player_value, dealer_value])

	# Update stats
	Global.stats.blackjack_games_played += 1
	if player_won:
		Global.stats.blackjack_games_won += 1
		if winnings > Global.stats.blackjack_biggest_win:
			Global.stats.blackjack_biggest_win = winnings

	hand_result.emit(player_won, player_blackjack, winnings)
	state = GameState.GAME_OVER

func _show_result_ui() -> void:
	# Show "Play Again" button
	# TODO: Implement result dialog
	await get_tree().create_timer(2.0).timeout
	start_new_round()

# =============================================================================
# UI HELPERS
# =============================================================================
func _update_player_value() -> void:
	if player_value_label:
		var value = player_zone.get_hand_value()
		var soft = " (soft)" if player_zone.is_soft_hand() else ""
		player_value_label.text = str(value) + soft

func _update_dealer_value() -> void:
	if dealer_value_label:
		var value = dealer_zone.get_visible_hand_value()
		dealer_value_label.text = str(value)

func _update_count_display() -> void:
	if count_label and Global.get_setting("blackjack_show_count", true):
		count_label.text = "Count: %+d (True: %+.1f)" % [dealer.running_count, dealer.true_count]
		count_label.visible = true
	elif count_label:
		count_label.visible = false

func _disable_all_buttons() -> void:
	if hit_button:
		hit_button.disabled = true
	if stand_button:
		stand_button.disabled = true
	if double_button:
		double_button.disabled = true
	if split_button:
		split_button.disabled = true

func _clear_hands() -> void:
	for card in player_zone.clear():
		card.queue_free()
	for card in dealer_zone.clear():
		card.queue_free()

func _show_message(text: String) -> void:
	if coach_label:
		coach_label.text = text
	print("[Blackjack] %s" % text)

# =============================================================================
# NAVIGATION
# =============================================================================
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
