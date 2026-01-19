extends Node2D
class_name Card
## Card.gd - The Core Card Class
## Holds Suit, Rank, and Visual State with all the "juice" animations

# =============================================================================
# ENUMS
# =============================================================================
enum Suit { HEARTS, DIAMONDS, CLUBS, SPADES }
enum Rank { ACE = 1, TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, NINE, TEN, JACK, QUEEN, KING }
enum VisualState { FACE_UP, FACE_DOWN }

# =============================================================================
# SIGNALS
# =============================================================================
signal card_clicked(card: Card)
signal card_drag_started(card: Card)
signal card_drag_ended(card: Card, target_position: Vector2)
signal card_hovered(card: Card)
signal card_unhovered(card: Card)
signal flip_completed(card: Card)

# =============================================================================
# PROPERTIES
# =============================================================================
@export var suit: Suit = Suit.HEARTS
@export var rank: Rank = Rank.ACE
@export var visual_state: VisualState = VisualState.FACE_DOWN:
	set(value):
		var old_state = visual_state
		visual_state = value
		if old_state != value:
			_animate_flip()

# Card appearance
var card_back_texture: Texture2D
var card_face_texture: Texture2D

# Interaction state
var is_dragging: bool = false
var is_hovered: bool = false
var is_selectable: bool = true
var drag_offset: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO
var original_z_index: int = 0

# Animation tweens
var _scale_tween: Tween
var _position_tween: Tween
var _rotation_tween: Tween
var _flip_tween: Tween

# The hitbox is 1.5x larger than visible card for grandpa-friendly input tolerance
const HITBOX_MULTIPLIER: float = 1.5
const CARD_WIDTH: float = 140.0
const CARD_HEIGHT: float = 190.0

# =============================================================================
# NODES (will be created in _ready)
# =============================================================================
var sprite: Sprite2D
var hitbox: Area2D
var collision_shape: CollisionShape2D
var glow_effect: CanvasItem  # For hint highlighting

# =============================================================================
# INITIALIZATION
# =============================================================================
func _ready() -> void:
	_setup_visuals()
	_setup_hitbox()
	_connect_signals()

func _setup_visuals() -> void:
	# Create the main sprite
	sprite = Sprite2D.new()
	sprite.name = "CardSprite"
	add_child(sprite)
	_update_texture()

func _setup_hitbox() -> void:
	# Create oversized hitbox for easier clicking
	hitbox = Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.input_pickable = true
	add_child(hitbox)

	collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(CARD_WIDTH * HITBOX_MULTIPLIER, CARD_HEIGHT * HITBOX_MULTIPLIER)
	collision_shape.shape = shape
	hitbox.add_child(collision_shape)

func _connect_signals() -> void:
	hitbox.mouse_entered.connect(_on_mouse_entered)
	hitbox.mouse_exited.connect(_on_mouse_exited)
	hitbox.input_event.connect(_on_input_event)

# =============================================================================
# CARD DATA
# =============================================================================
func setup(p_suit: Suit, p_rank: Rank, face_up: bool = false) -> void:
	suit = p_suit
	rank = p_rank
	visual_state = VisualState.FACE_UP if face_up else VisualState.FACE_DOWN
	_update_texture()

func get_suit_name() -> String:
	return Suit.keys()[suit]

func get_rank_name() -> String:
	return Rank.keys()[rank]

func get_display_name() -> String:
	return "%s of %s" % [get_rank_name().capitalize(), get_suit_name().capitalize()]

func get_short_name() -> String:
	var rank_str: String
	match rank:
		Rank.ACE: rank_str = "A"
		Rank.JACK: rank_str = "J"
		Rank.QUEEN: rank_str = "Q"
		Rank.KING: rank_str = "K"
		_: rank_str = str(rank)

	var suit_str: String
	match suit:
		Suit.HEARTS: suit_str = "H"
		Suit.DIAMONDS: suit_str = "D"
		Suit.CLUBS: suit_str = "C"
		Suit.SPADES: suit_str = "S"

	return rank_str + suit_str

func is_red() -> bool:
	return suit == Suit.HEARTS or suit == Suit.DIAMONDS

func is_black() -> bool:
	return suit == Suit.CLUBS or suit == Suit.SPADES

func get_blackjack_value() -> int:
	## Returns card value for Blackjack (Ace = 11, Face = 10)
	if rank == Rank.ACE:
		return 11
	elif rank >= Rank.TEN:
		return 10
	else:
		return rank

func get_blackjack_values() -> Array[int]:
	## Returns possible values for Blackjack (Ace can be 1 or 11)
	if rank == Rank.ACE:
		return [1, 11]
	return [get_blackjack_value()]

# =============================================================================
# VISUAL UPDATES
# =============================================================================
func _update_texture() -> void:
	if not sprite:
		return

	# For now, we'll use placeholder colors
	# In production, load actual card textures
	if visual_state == VisualState.FACE_DOWN:
		sprite.modulate = Color(0.2, 0.3, 0.5)  # Navy blue back
	else:
		if is_red():
			sprite.modulate = Color.WHITE
		else:
			sprite.modulate = Color.WHITE

	# TODO: Load actual textures based on Global.active_card_back
	# var back_path = "res://Assets/Sprites/Cards/Backs/%s.png" % Global.active_card_back
	# var face_path = "res://Assets/Sprites/Cards/Faces/%s.png" % get_short_name()

func _get_suit_color() -> Color:
	## Returns the suit color (supports 4-color deck option)
	if Global.get_setting("four_color_deck", false):
		match suit:
			Suit.HEARTS: return Color.RED
			Suit.DIAMONDS: return Color.BLUE
			Suit.CLUBS: return Color.GREEN
			Suit.SPADES: return Color.BLACK
	else:
		if is_red():
			return Color.RED
		else:
			return Color.BLACK
	return Color.BLACK

# =============================================================================
# INTERACTION HANDLING
# =============================================================================
func _on_mouse_entered() -> void:
	if not is_selectable:
		return
	is_hovered = true
	card_hovered.emit(self)
	_animate_hover_start()

func _on_mouse_exited() -> void:
	is_hovered = false
	card_unhovered.emit(self)
	if not is_dragging:
		_animate_hover_end()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not is_selectable:
		return

	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_start_drag(mouse_event.global_position)
			else:
				_end_drag(mouse_event.global_position)

func _start_drag(mouse_pos: Vector2) -> void:
	is_dragging = true
	drag_offset = global_position - mouse_pos
	original_position = global_position
	original_z_index = z_index
	z_index = 1000  # Bring to front while dragging

	card_clicked.emit(self)
	card_drag_started.emit(self)
	_animate_pickup()

func _end_drag(mouse_pos: Vector2) -> void:
	if not is_dragging:
		return

	is_dragging = false
	z_index = original_z_index
	card_drag_ended.emit(self, mouse_pos + drag_offset)
	_animate_drop()

func _process(_delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position() + drag_offset

# =============================================================================
# ANIMATIONS - THE "JUICE"
# =============================================================================
func _animate_pickup() -> void:
	## Squash and stretch - scale to 1.1x when picked up
	_kill_scale_tween()
	_scale_tween = create_tween()
	_scale_tween.set_ease(Tween.EASE_OUT)
	_scale_tween.set_trans(Tween.TRANS_BACK)
	_scale_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)

func _animate_drop() -> void:
	## Squash and stretch - scale to 0.9x then back to 1.0x
	_kill_scale_tween()
	_scale_tween = create_tween()
	_scale_tween.set_ease(Tween.EASE_OUT)
	_scale_tween.set_trans(Tween.TRANS_ELASTIC)
	_scale_tween.tween_property(self, "scale", Vector2(0.95, 1.05), 0.05)
	_scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)

func _animate_hover_start() -> void:
	## Slight raise effect when hovering
	_kill_scale_tween()
	_scale_tween = create_tween()
	_scale_tween.set_ease(Tween.EASE_OUT)
	_scale_tween.set_trans(Tween.TRANS_QUAD)
	_scale_tween.tween_property(self, "scale", Vector2(1.03, 1.03), 0.1)

func _animate_hover_end() -> void:
	## Return to normal size
	_kill_scale_tween()
	_scale_tween = create_tween()
	_scale_tween.set_ease(Tween.EASE_OUT)
	_scale_tween.set_trans(Tween.TRANS_QUAD)
	_scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

func _animate_flip() -> void:
	## Flip animation - scale X to 0, change texture, scale X back to 1
	_kill_flip_tween()
	_flip_tween = create_tween()
	_flip_tween.set_ease(Tween.EASE_IN_OUT)
	_flip_tween.set_trans(Tween.TRANS_QUAD)

	# First half of flip
	_flip_tween.tween_property(self, "scale:x", 0.0, 0.1)
	_flip_tween.tween_callback(_update_texture)
	# Second half of flip
	_flip_tween.tween_property(self, "scale:x", 1.0, 0.1)
	_flip_tween.tween_callback(func(): flip_completed.emit(self))

func animate_to_position(target: Vector2, duration: float = 0.3, on_complete: Callable = Callable()) -> void:
	## Magnetic snap - smoothly move to target position
	_kill_position_tween()
	_position_tween = create_tween()
	_position_tween.set_ease(Tween.EASE_OUT)
	_position_tween.set_trans(Tween.TRANS_QUAD)
	_position_tween.tween_property(self, "global_position", target, duration)
	if on_complete.is_valid():
		_position_tween.tween_callback(on_complete)

func animate_return_to_original(duration: float = 0.2) -> void:
	## Gentle slide back to original position (for invalid moves)
	animate_to_position(original_position, duration)
	# TODO: Play soft "whoops" sound

func animate_deal(target: Vector2, delay: float = 0.0, duration: float = 0.3) -> void:
	## Deal animation with delay for staggered dealing
	await get_tree().create_timer(delay).timeout
	animate_to_position(target, duration)

func animate_victory_bounce() -> void:
	## Victory cascade animation (like Windows Solitaire)
	var random_velocity = Vector2(randf_range(-400, 400), randf_range(-600, -200))
	var gravity = 800.0
	var bounce_dampening = 0.7

	_kill_position_tween()
	var elapsed = 0.0
	var velocity = random_velocity

	while global_position.y < get_viewport_rect().size.y + 200:
		elapsed += get_process_delta_time()
		velocity.y += gravity * get_process_delta_time()
		global_position += velocity * get_process_delta_time()

		# Bounce off bottom
		if global_position.y > get_viewport_rect().size.y - 50:
			global_position.y = get_viewport_rect().size.y - 50
			velocity.y *= -bounce_dampening

		await get_tree().process_frame

	queue_free()

func highlight_hint(enabled: bool) -> void:
	## Pulse glow effect for hint system
	if enabled:
		var glow_tween = create_tween()
		glow_tween.set_loops()
		glow_tween.tween_property(sprite, "modulate", Color(1.3, 1.3, 1.0), 0.5)
		glow_tween.tween_property(sprite, "modulate", Color.WHITE, 0.5)
	else:
		sprite.modulate = Color.WHITE

# =============================================================================
# TWEEN MANAGEMENT
# =============================================================================
func _kill_scale_tween() -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()

func _kill_position_tween() -> void:
	if _position_tween and _position_tween.is_valid():
		_position_tween.kill()

func _kill_rotation_tween() -> void:
	if _rotation_tween and _rotation_tween.is_valid():
		_rotation_tween.kill()

func _kill_flip_tween() -> void:
	if _flip_tween and _flip_tween.is_valid():
		_flip_tween.kill()

func kill_all_tweens() -> void:
	_kill_scale_tween()
	_kill_position_tween()
	_kill_rotation_tween()
	_kill_flip_tween()

# =============================================================================
# SERIALIZATION
# =============================================================================
func to_dict() -> Dictionary:
	return {
		"suit": suit,
		"rank": rank,
		"face_up": visual_state == VisualState.FACE_UP
	}

static func from_dict(data: Dictionary) -> Card:
	var card = Card.new()
	card.setup(data.suit, data.rank, data.get("face_up", false))
	return card
