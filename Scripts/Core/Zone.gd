extends Node2D
class_name Zone
## Zone.gd - Represents a pile of cards (Deck, Hand, Discard, Tableau, Foundation)
## Handles card placement validation and visual stacking

# =============================================================================
# ENUMS
# =============================================================================
enum ZoneType {
	DECK,           # Draw pile
	DISCARD,        # Waste pile
	HAND,           # Player's hand (Blackjack)
	DEALER_HAND,    # Dealer's hand (Blackjack)
	TABLEAU,        # Solitaire columns
	FOUNDATION,     # Solitaire foundation piles
	BETTING,        # Betting zone (chips)
	GENERIC         # Generic pile
}

enum StackDirection {
	NONE,           # Cards stack directly on top
	DOWN,           # Cards fan downward (Solitaire tableau)
	RIGHT,          # Cards fan right (hand display)
	LEFT            # Cards fan left
}

# =============================================================================
# SIGNALS
# =============================================================================
signal card_added(card: Card)
signal card_removed(card: Card)
signal cards_changed()
signal zone_clicked()

# =============================================================================
# PROPERTIES
# =============================================================================
@export var zone_type: ZoneType = ZoneType.GENERIC
@export var stack_direction: StackDirection = StackDirection.NONE
@export var card_offset: float = 30.0  # Pixels between stacked cards
@export var face_down_offset: float = 15.0  # Smaller offset for face-down cards
@export var max_cards: int = -1  # -1 = unlimited
@export var accepts_cards: bool = true
@export var auto_flip_top: bool = false  # Auto-flip top card when revealed

# Visual properties
@export var zone_width: float = 140.0
@export var zone_height: float = 190.0
@export var highlight_color: Color = Color(1.0, 1.0, 0.5, 0.3)

# The cards in this zone (bottom to top)
var cards: Array[Card] = []

# For Solitaire foundations - which suit this pile accepts
var foundation_suit: Card.Suit = Card.Suit.HEARTS

# For Solitaire tableau - the column index
var tableau_index: int = 0

# Validation function override (set by game logic)
var custom_can_accept: Callable = Callable()

# Visual nodes
var background: ColorRect
var hitbox: Area2D

# =============================================================================
# INITIALIZATION
# =============================================================================
func _ready() -> void:
	_setup_visuals()
	_setup_hitbox()

func _setup_visuals() -> void:
	# Create a subtle background for the zone
	background = ColorRect.new()
	background.size = Vector2(zone_width, zone_height)
	background.position = Vector2(-zone_width / 2, -zone_height / 2)
	background.color = Color(0.1, 0.1, 0.1, 0.3)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)

func _setup_hitbox() -> void:
	hitbox = Area2D.new()
	hitbox.name = "ZoneHitbox"
	add_child(hitbox)

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(zone_width, zone_height)
	collision.shape = shape
	hitbox.add_child(collision)

	hitbox.input_event.connect(_on_input_event)
	hitbox.mouse_entered.connect(_on_mouse_entered)
	hitbox.mouse_exited.connect(_on_mouse_exited)

# =============================================================================
# CARD MANAGEMENT
# =============================================================================
func add_card(card: Card, animate: bool = true) -> void:
	if max_cards >= 0 and cards.size() >= max_cards:
		push_warning("Zone %s is full" % name)
		return

	cards.append(card)
	card.reparent(self)
	_update_card_positions(animate)
	card_added.emit(card)
	cards_changed.emit()

func add_cards(new_cards: Array[Card], animate: bool = true) -> void:
	for card in new_cards:
		if max_cards >= 0 and cards.size() >= max_cards:
			break
		cards.append(card)
		card.reparent(self)

	_update_card_positions(animate)
	cards_changed.emit()

func remove_card(card: Card) -> Card:
	var index = cards.find(card)
	if index >= 0:
		cards.remove_at(index)
		card_removed.emit(card)
		cards_changed.emit()

		# Auto-flip new top card if enabled
		if auto_flip_top and not is_empty():
			var top = get_top_card()
			if top.visual_state == Card.VisualState.FACE_DOWN:
				top.visual_state = Card.VisualState.FACE_UP

		return card
	return null

func remove_top_card() -> Card:
	if is_empty():
		return null
	return remove_card(cards[-1])

func remove_cards_from(card: Card) -> Array[Card]:
	## Remove this card and all cards on top of it (for Solitaire moves)
	var index = cards.find(card)
	if index < 0:
		return []

	var removed: Array[Card] = []
	while cards.size() > index:
		removed.append(cards.pop_back())

	removed.reverse()  # Keep original order

	# Auto-flip new top card
	if auto_flip_top and not is_empty():
		var top = get_top_card()
		if top.visual_state == Card.VisualState.FACE_DOWN:
			top.visual_state = Card.VisualState.FACE_UP

	cards_changed.emit()
	return removed

func clear() -> Array[Card]:
	var removed = cards.duplicate()
	cards.clear()
	cards_changed.emit()
	return removed

# =============================================================================
# CARD ACCESS
# =============================================================================
func get_top_card() -> Card:
	if is_empty():
		return null
	return cards[-1]

func get_bottom_card() -> Card:
	if is_empty():
		return null
	return cards[0]

func get_card_at(index: int) -> Card:
	if index < 0 or index >= cards.size():
		return null
	return cards[index]

func get_face_up_cards() -> Array[Card]:
	var result: Array[Card] = []
	for card in cards:
		if card.visual_state == Card.VisualState.FACE_UP:
			result.append(card)
	return result

func is_empty() -> bool:
	return cards.size() == 0

func card_count() -> int:
	return cards.size()

func has_card(card: Card) -> bool:
	return card in cards

func get_card_index(card: Card) -> int:
	return cards.find(card)

# =============================================================================
# VALIDATION - "can_accept_card()"
# =============================================================================
func can_accept_card(card: Card) -> bool:
	## Check if this zone can accept the given card
	if not accepts_cards:
		return false

	if max_cards >= 0 and cards.size() >= max_cards:
		return false

	# Use custom validation if provided
	if custom_can_accept.is_valid():
		return custom_can_accept.call(self, card)

	# Default validation based on zone type
	match zone_type:
		ZoneType.FOUNDATION:
			return _validate_foundation(card)
		ZoneType.TABLEAU:
			return _validate_tableau(card)
		ZoneType.HAND, ZoneType.DEALER_HAND:
			return true  # Hands accept any card
		ZoneType.DISCARD:
			return true  # Discard accepts any card
		_:
			return true

func can_accept_stack(card_stack: Array[Card]) -> bool:
	## Check if this zone can accept a stack of cards (Solitaire)
	if card_stack.is_empty():
		return false

	# First card must be acceptable
	if not can_accept_card(card_stack[0]):
		return false

	# Verify the stack itself is valid (alternating colors, descending)
	for i in range(1, card_stack.size()):
		var prev = card_stack[i - 1]
		var curr = card_stack[i]
		if not _is_valid_tableau_sequence(prev, curr):
			return false

	return true

func _validate_foundation(card: Card) -> bool:
	## Foundation: Aces first, then ascending same suit
	if is_empty():
		return card.rank == Card.Rank.ACE
	else:
		var top = get_top_card()
		return (card.suit == top.suit and
				card.rank == top.rank + 1)

func _validate_tableau(card: Card) -> bool:
	## Tableau: Kings on empty, then descending alternating colors
	if is_empty():
		return card.rank == Card.Rank.KING
	else:
		var top = get_top_card()
		return _is_valid_tableau_sequence(top, card)

func _is_valid_tableau_sequence(top: Card, card: Card) -> bool:
	## Check if card can go on top (red on black, descending)
	return (card.is_red() != top.is_red() and
			card.rank == top.rank - 1)

# =============================================================================
# VISUAL POSITIONING
# =============================================================================
func _update_card_positions(animate: bool = true) -> void:
	for i in range(cards.size()):
		var card = cards[i]
		var target_pos = _calculate_card_position(i, card)
		card.z_index = i

		if animate:
			card.animate_to_position(target_pos, 0.2)
		else:
			card.position = target_pos

func _calculate_card_position(index: int, card: Card) -> Vector2:
	var offset = card_offset
	if card.visual_state == Card.VisualState.FACE_DOWN:
		offset = face_down_offset

	match stack_direction:
		StackDirection.NONE:
			return Vector2.ZERO
		StackDirection.DOWN:
			return Vector2(0, index * offset)
		StackDirection.RIGHT:
			return Vector2(index * offset, 0)
		StackDirection.LEFT:
			return Vector2(-index * offset, 0)

	return Vector2.ZERO

func get_drop_position() -> Vector2:
	## Get the position where the next card should be placed
	if is_empty():
		return global_position

	var top_card = get_top_card()
	return top_card.global_position + _get_offset_vector()

func _get_offset_vector() -> Vector2:
	match stack_direction:
		StackDirection.DOWN:
			return Vector2(0, card_offset)
		StackDirection.RIGHT:
			return Vector2(card_offset, 0)
		StackDirection.LEFT:
			return Vector2(-card_offset, 0)
	return Vector2.ZERO

# =============================================================================
# INTERACTION
# =============================================================================
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			zone_clicked.emit()

func _on_mouse_entered() -> void:
	if accepts_cards:
		background.color = highlight_color

func _on_mouse_exited() -> void:
	background.color = Color(0.1, 0.1, 0.1, 0.3)

func highlight(enabled: bool) -> void:
	if enabled:
		background.color = highlight_color
	else:
		background.color = Color(0.1, 0.1, 0.1, 0.3)

# =============================================================================
# BLACKJACK HELPERS
# =============================================================================
func get_hand_value() -> int:
	## Calculate Blackjack hand value (handles soft aces)
	var total = 0
	var aces = 0

	for card in cards:
		if card.visual_state == Card.VisualState.FACE_DOWN:
			continue  # Don't count face-down cards

		if card.rank == Card.Rank.ACE:
			aces += 1
			total += 11
		else:
			total += card.get_blackjack_value()

	# Convert aces from 11 to 1 as needed
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1

	return total

func get_visible_hand_value() -> int:
	## Calculate value of only face-up cards
	var total = 0
	var aces = 0

	for card in cards:
		if card.visual_state == Card.VisualState.FACE_DOWN:
			continue

		if card.rank == Card.Rank.ACE:
			aces += 1
			total += 11
		else:
			total += card.get_blackjack_value()

	while total > 21 and aces > 0:
		total -= 10
		aces -= 1

	return total

func is_soft_hand() -> bool:
	## Check if hand contains an ace counted as 11
	var total = 0
	var aces = 0

	for card in cards:
		if card.visual_state == Card.VisualState.FACE_DOWN:
			continue

		if card.rank == Card.Rank.ACE:
			aces += 1
			total += 11
		else:
			total += card.get_blackjack_value()

	# If we haven't busted and still have aces as 11
	return total <= 21 and aces > 0

func is_blackjack() -> bool:
	## Natural 21 with first two cards
	return cards.size() == 2 and get_hand_value() == 21

func is_bust() -> bool:
	return get_hand_value() > 21

func is_pair() -> bool:
	## Check if hand is a splittable pair
	if cards.size() != 2:
		return false
	return cards[0].rank == cards[1].rank

# =============================================================================
# SOLITAIRE HELPERS
# =============================================================================
func is_complete_foundation() -> bool:
	## Check if foundation has all 13 cards (Ace through King)
	return zone_type == ZoneType.FOUNDATION and cards.size() == 13

func get_movable_cards() -> Array[Card]:
	## Get all face-up cards that can be moved (for Solitaire)
	var movable: Array[Card] = []
	var in_sequence = false

	for i in range(cards.size() - 1, -1, -1):
		var card = cards[i]
		if card.visual_state == Card.VisualState.FACE_DOWN:
			break
		movable.insert(0, card)

	return movable

# =============================================================================
# SERIALIZATION
# =============================================================================
func to_dict() -> Dictionary:
	var card_data: Array = []
	for card in cards:
		card_data.append(card.to_dict())

	return {
		"zone_type": zone_type,
		"cards": card_data,
		"foundation_suit": foundation_suit,
		"tableau_index": tableau_index
	}

func from_dict(data: Dictionary, card_scene: PackedScene) -> void:
	zone_type = data.get("zone_type", ZoneType.GENERIC)
	foundation_suit = data.get("foundation_suit", Card.Suit.HEARTS)
	tableau_index = data.get("tableau_index", 0)

	clear()
	for card_data in data.get("cards", []):
		var card = Card.from_dict(card_data)
		add_card(card, false)
