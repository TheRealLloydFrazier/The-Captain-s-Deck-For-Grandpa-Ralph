extends Node
class_name Dealer
## Dealer.gd - Handles shuffling and moving cards between zones
## Supports standard and rigged decks for Dynamic Difficulty Adjustment

# =============================================================================
# SIGNALS
# =============================================================================
signal deck_shuffled()
signal card_dealt(card: Card, to_zone: Zone)
signal dealing_complete()

# =============================================================================
# PROPERTIES
# =============================================================================
# The deck(s) in use
var decks: Array[Array] = []  # Array of deck arrays for multi-deck games
var deck_count: int = 1

# Card counting (Hi-Lo system for Blackjack)
var running_count: int = 0
var true_count: float = 0.0
var cards_dealt: int = 0

# For Dynamic Difficulty Adjustment
var help_player: bool = false
var help_intensity: float = 0.0

# Audio pitch ramping (for satisfying card sounds)
var pitch_ramp_base: float = 1.0
var pitch_ramp_step: float = 0.05
var current_pitch: float = 1.0

# =============================================================================
# DECK MANAGEMENT
# =============================================================================
func create_deck(num_decks: int = 1) -> Array[Card]:
	## Creates one or more standard 52-card decks
	deck_count = num_decks
	var full_deck: Array[Card] = []

	for _d in range(num_decks):
		for suit in Card.Suit.values():
			for rank in Card.Rank.values():
				var card = Card.new()
				card.setup(suit, rank, false)
				full_deck.append(card)

	reset_count()
	return full_deck

func shuffle_deck(deck: Array) -> Array:
	## Fisher-Yates shuffle
	var shuffled = deck.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var temp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = temp

	deck_shuffled.emit()
	return shuffled

func shuffle_with_seed(deck: Array, seed_value: int) -> Array:
	## Seeded shuffle for reproducible games (Daily Challenge)
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value

	var shuffled = deck.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var temp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = temp

	deck_shuffled.emit()
	return shuffled

func create_rigged_deck(num_decks: int = 1, favor_player: float = 0.0) -> Array[Card]:
	## Creates a deck with subtle rigging to help the player
	## favor_player: 0.0 = fair, 1.0 = heavily favor player
	var deck = create_deck(num_decks)
	deck = shuffle_deck(deck)

	if favor_player <= 0.0:
		return deck

	# Rigging strategy: Move high-value cards (10, J, Q, K, A) toward the top
	# where "top" is where the player draws from
	var high_cards: Array[Card] = []
	var other_cards: Array[Card] = []

	for card in deck:
		if card.rank >= Card.Rank.TEN or card.rank == Card.Rank.ACE:
			high_cards.append(card)
		else:
			other_cards.append(card)

	# Shuffle within each group
	high_cards = shuffle_deck(high_cards)
	other_cards = shuffle_deck(other_cards)

	# Interleave, with more high cards toward the "draw" position
	var rigged: Array[Card] = []
	var high_index = 0
	var other_index = 0
	var favor_chance = favor_player * 0.3  # Max 30% bias

	while high_index < high_cards.size() or other_index < other_cards.size():
		if high_index >= high_cards.size():
			rigged.append(other_cards[other_index])
			other_index += 1
		elif other_index >= other_cards.size():
			rigged.append(high_cards[high_index])
			high_index += 1
		elif randf() < (0.35 + favor_chance):  # Slightly favor high cards
			rigged.append(high_cards[high_index])
			high_index += 1
		else:
			rigged.append(other_cards[other_index])
			other_index += 1

	return rigged

# =============================================================================
# DEALING
# =============================================================================
func deal_card(from_zone: Zone, to_zone: Zone, face_up: bool = true, animate: bool = true) -> Card:
	## Deal a single card from one zone to another
	var card = from_zone.remove_top_card()
	if not card:
		return null

	card.visual_state = Card.VisualState.FACE_UP if face_up else Card.VisualState.FACE_DOWN
	to_zone.add_card(card, animate)

	# Update card counting
	if face_up:
		_count_card(card)

	card_dealt.emit(card, to_zone)
	_increment_pitch()

	return card

func deal_cards(from_zone: Zone, to_zone: Zone, count: int, face_up: bool = true, stagger_delay: float = 0.1) -> Array[Card]:
	## Deal multiple cards with staggered animation
	var dealt: Array[Card] = []

	for i in range(count):
		var card = deal_card(from_zone, to_zone, face_up, true)
		if card:
			dealt.append(card)
			if stagger_delay > 0 and i < count - 1:
				await get_tree().create_timer(stagger_delay).timeout

	return dealt

func move_card(card: Card, from_zone: Zone, to_zone: Zone, animate: bool = true) -> bool:
	## Move a specific card between zones
	if not to_zone.can_accept_card(card):
		if animate:
			card.animate_return_to_original()
		return false

	from_zone.remove_card(card)
	to_zone.add_card(card, animate)
	_increment_pitch()
	return true

func move_card_stack(cards: Array[Card], from_zone: Zone, to_zone: Zone, animate: bool = true) -> bool:
	## Move a stack of cards (Solitaire tableau moves)
	if cards.is_empty():
		return false

	if not to_zone.can_accept_stack(cards):
		if animate:
			for card in cards:
				card.animate_return_to_original()
		return false

	# Remove all cards from source
	for card in cards:
		from_zone.remove_card(card)

	# Add to destination
	to_zone.add_cards(cards, animate)
	_increment_pitch()
	return true

# =============================================================================
# CARD COUNTING (Hi-Lo System)
# =============================================================================
func _count_card(card: Card) -> void:
	## Update running count based on card value
	## Hi-Lo: 2-6 = +1, 7-9 = 0, 10-A = -1
	cards_dealt += 1

	match card.rank:
		Card.Rank.TWO, Card.Rank.THREE, Card.Rank.FOUR, Card.Rank.FIVE, Card.Rank.SIX:
			running_count += 1
		Card.Rank.TEN, Card.Rank.JACK, Card.Rank.QUEEN, Card.Rank.KING, Card.Rank.ACE:
			running_count -= 1
		# 7, 8, 9 are neutral (0)

	# Calculate true count (running count / decks remaining)
	var total_cards = deck_count * 52
	var decks_remaining = max(1.0, (total_cards - cards_dealt) / 52.0)
	true_count = running_count / decks_remaining

func reset_count() -> void:
	running_count = 0
	true_count = 0.0
	cards_dealt = 0

func get_count_advice() -> String:
	## Returns advice based on current count
	if true_count >= 3:
		return "Hot deck! Bet big, Captain!"
	elif true_count >= 1:
		return "Count is favorable. Consider raising your bet."
	elif true_count <= -3:
		return "Cold deck. Play conservatively."
	elif true_count <= -1:
		return "Count is unfavorable. Minimum bets recommended."
	else:
		return "Neutral count. Play standard strategy."

# =============================================================================
# AUDIO PITCH RAMPING
# =============================================================================
func _increment_pitch() -> void:
	## Increase pitch for rapid card movements (musical progression)
	current_pitch = min(current_pitch + pitch_ramp_step, 2.0)

func reset_pitch() -> void:
	current_pitch = pitch_ramp_base

func get_current_pitch() -> float:
	return current_pitch

# Call this when there's a pause in action
func decay_pitch(amount: float = 0.02) -> void:
	current_pitch = max(pitch_ramp_base, current_pitch - amount)

# =============================================================================
# BLACKJACK-SPECIFIC DEALING
# =============================================================================
func deal_blackjack_initial(deck_zone: Zone, player_zone: Zone, dealer_zone: Zone) -> void:
	## Deal initial Blackjack hands: Player, Dealer, Player, Dealer(face down)
	reset_pitch()

	# First round - both face up
	deal_card(deck_zone, player_zone, true, true)
	await get_tree().create_timer(0.2).timeout
	deal_card(deck_zone, dealer_zone, true, true)
	await get_tree().create_timer(0.2).timeout

	# Second round - player up, dealer down (hole card)
	deal_card(deck_zone, player_zone, true, true)
	await get_tree().create_timer(0.2).timeout
	deal_card(deck_zone, dealer_zone, false, true)  # Hole card face down

	dealing_complete.emit()

func deal_blackjack_hit(deck_zone: Zone, hand_zone: Zone) -> Card:
	## Deal a single hit card
	return deal_card(deck_zone, hand_zone, true, true)

func reveal_dealer_hole(dealer_zone: Zone) -> void:
	## Flip the dealer's hole card
	if dealer_zone.card_count() >= 2:
		var hole_card = dealer_zone.get_card_at(1)
		if hole_card and hole_card.visual_state == Card.VisualState.FACE_DOWN:
			hole_card.visual_state = Card.VisualState.FACE_UP
			_count_card(hole_card)

# =============================================================================
# SOLITAIRE-SPECIFIC DEALING
# =============================================================================
func deal_solitaire_tableau(deck_zone: Zone, tableaus: Array[Zone]) -> void:
	## Deal initial Solitaire tableau (7 piles, 1-7 cards each)
	reset_pitch()

	for i in range(7):
		for j in range(i, 7):
			var face_up = (j == i)  # Only top card face up
			deal_card(deck_zone, tableaus[j], face_up, true)
			await get_tree().create_timer(0.05).timeout

	dealing_complete.emit()

func auto_complete_solitaire(tableaus: Array[Zone], foundations: Array[Zone]) -> void:
	## Auto-complete when all cards are face up
	var moved = true

	while moved:
		moved = false

		# Check each tableau
		for tableau in tableaus:
			if tableau.is_empty():
				continue

			var top = tableau.get_top_card()
			if not top:
				continue

			# Try to move to foundations
			for foundation in foundations:
				if foundation.can_accept_card(top):
					move_card(top, tableau, foundation, true)
					await get_tree().create_timer(0.1).timeout
					moved = true
					break

	dealing_complete.emit()

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
func get_random_card_for_help(deck: Array[Card], prefer_high: bool) -> Card:
	## Get a random card, biased toward high or low values
	if deck.is_empty():
		return null

	if not help_player or help_intensity <= 0:
		return deck[randi() % deck.size()]

	# Filter for preferred cards
	var preferred: Array[Card] = []
	var other: Array[Card] = []

	for card in deck:
		var is_high = card.rank >= Card.Rank.TEN or card.rank == Card.Rank.ACE
		if (prefer_high and is_high) or (not prefer_high and not is_high):
			preferred.append(card)
		else:
			other.append(card)

	# Use help_intensity to determine bias
	if randf() < help_intensity and not preferred.is_empty():
		return preferred[randi() % preferred.size()]
	elif not other.is_empty():
		return other[randi() % other.size()]
	else:
		return deck[randi() % deck.size()]

func setup_dynamic_difficulty(game: String) -> void:
	## Configure DDA based on Global settings
	help_player = Global.should_help_player(game)
	help_intensity = Global.get_help_intensity(game)

	if help_player:
		print("[Dealer] DDA active for %s (intensity: %.1f)" % [game, help_intensity])
