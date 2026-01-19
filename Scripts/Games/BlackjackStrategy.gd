extends RefCounted
class_name BlackjackStrategy
## BlackjackStrategy.gd - The "Card Counter's Academy"
## Contains the complete Basic Strategy Matrix and coaching logic

# =============================================================================
# ENUMS
# =============================================================================
enum Action { HIT, STAND, DOUBLE, SPLIT, SURRENDER }
enum Style { CLASSIC, AGGRESSIVE, CONSERVATIVE }

# =============================================================================
# BASIC STRATEGY MATRIX
# =============================================================================
# Key: "PlayerTotal-DealerUpcard" or "SoftTotal-DealerUpcard" or "Pair-DealerUpcard"
# Value: Action

# Hard totals (no ace, or ace counted as 1)
# Format: hard_strategy[player_total][dealer_upcard (2-11, where 11=Ace)]
static var hard_strategy: Dictionary = {
	# Player total 5-8: Always Hit
	5: { 2: Action.HIT, 3: Action.HIT, 4: Action.HIT, 5: Action.HIT, 6: Action.HIT, 7: Action.HIT, 8: Action.HIT, 9: Action.HIT, 10: Action.HIT, 11: Action.HIT },
	6: { 2: Action.HIT, 3: Action.HIT, 4: Action.HIT, 5: Action.HIT, 6: Action.HIT, 7: Action.HIT, 8: Action.HIT, 9: Action.HIT, 10: Action.HIT, 11: Action.HIT },
	7: { 2: Action.HIT, 3: Action.HIT, 4: Action.HIT, 5: Action.HIT, 6: Action.HIT, 7: Action.HIT, 8: Action.HIT, 9: Action.HIT, 10: Action.HIT, 11: Action.HIT },
	8: { 2: Action.HIT, 3: Action.HIT, 4: Action.HIT, 5: Action.HIT, 6: Action.HIT, 7: Action.HIT, 8: Action.HIT, 9: Action.HIT, 10: Action.HIT, 11: Action.HIT },

	# Player total 9: Double 3-6, else Hit
	9: { 2: Action.HIT, 3: Action.DOUBLE, 4: Action.DOUBLE, 5: Action.DOUBLE, 6: Action.DOUBLE, 7: Action.HIT, 8: Action.HIT, 9: Action.HIT, 10: Action.HIT, 11: Action.HIT },

	# Player total 10: Double 2-9, Hit 10-A
	10: { 2: Action.DOUBLE, 3: Action.DOUBLE, 4: Action.DOUBLE, 5: Action.DOUBLE, 6: Action.DOUBLE, 7: Action.DOUBLE, 8: Action.DOUBLE, 9: Action.DOUBLE, 10: Action.HIT, 11: Action.HIT },

	# Player total 11: Double 2-10, Hit A
	11: { 2: Action.DOUBLE, 3: Action.DOUBLE, 4: Action.DOUBLE, 5: Action.DOUBLE, 6: Action.DOUBLE, 7: Action.DOUBLE, 8: Action.DOUBLE, 9: Action.DOUBLE, 10: Action.DOUBLE, 11: Action.HIT },

	# Player total 12: Stand 4-6, else Hit
	12: { 2: Action.HIT, 3: Action.HIT, 4: Action.STAND, 5: Action.STAND, 6: Action.STAND, 7: Action.HIT, 8: Action.HIT, 9: Action.HIT, 10: Action.HIT, 11: Action.HIT },

	# Player total 13: Stand 2-6, else Hit
	13: { 2: Action.STAND, 3: Action.STAND, 4: Action.STAND, 5: Action.STAND, 6: Action.STAND, 7: Action.HIT, 8: Action.HIT, 9: Action.HIT, 10: Action.HIT, 11: Action.HIT },

	# Player total 14: Stand 2-6, else Hit
	14: { 2: Action.STAND, 3: Action.STAND, 4: Action.STAND, 5: Action.STAND, 6: Action.STAND, 7: Action.HIT, 8: Action.HIT, 9: Action.HIT, 10: Action.HIT, 11: Action.HIT },

	# Player total 15: Stand 2-6, else Hit (Surrender vs 10 if allowed)
	15: { 2: Action.STAND, 3: Action.STAND, 4: Action.STAND, 5: Action.STAND, 6: Action.STAND, 7: Action.HIT, 8: Action.HIT, 9: Action.HIT, 10: Action.SURRENDER, 11: Action.HIT },

	# Player total 16: Stand 2-6, else Hit (Surrender vs 9-A if allowed)
	16: { 2: Action.STAND, 3: Action.STAND, 4: Action.STAND, 5: Action.STAND, 6: Action.STAND, 7: Action.HIT, 8: Action.HIT, 9: Action.SURRENDER, 10: Action.SURRENDER, 11: Action.SURRENDER },

	# Player total 17+: Always Stand
	17: { 2: Action.STAND, 3: Action.STAND, 4: Action.STAND, 5: Action.STAND, 6: Action.STAND, 7: Action.STAND, 8: Action.STAND, 9: Action.STAND, 10: Action.STAND, 11: Action.STAND },
	18: { 2: Action.STAND, 3: Action.STAND, 4: Action.STAND, 5: Action.STAND, 6: Action.STAND, 7: Action.STAND, 8: Action.STAND, 9: Action.STAND, 10: Action.STAND, 11: Action.STAND },
	19: { 2: Action.STAND, 3: Action.STAND, 4: Action.STAND, 5: Action.STAND, 6: Action.STAND, 7: Action.STAND, 8: Action.STAND, 9: Action.STAND, 10: Action.STAND, 11: Action.STAND },
	20: { 2: Action.STAND, 3: Action.STAND, 4: Action.STAND, 5: Action.STAND, 6: Action.STAND, 7: Action.STAND, 8: Action.STAND, 9: Action.STAND, 10: Action.STAND, 11: Action.STAND },
	21: { 2: Action.STAND, 3: Action.STAND, 4: Action.STAND, 5: Action.STAND, 6: Action.STAND, 7: Action.STAND, 8: Action.STAND, 9: Action.STAND, 10: Action.STAND, 11: Action.STAND },
}

# Soft totals (ace counted as 11)
# Format: soft_strategy[soft_total][dealer_upcard]
static var soft_strategy: Dictionary = {
	# Soft 13 (A,2): Double 5-6, else Hit
	13: { 2: Action.HIT, 3: Action.HIT, 4: Action.HIT, 5: Action.DOUBLE, 6: Action.DOUBLE, 7: Action.HIT, 8: Action.HIT, 9: Action.HIT, 10: Action.HIT, 11: Action.HIT },

	# Soft 14 (A,3): Double 5-6, else Hit
	14: { 2: Action.HIT, 3: Action.HIT, 4: Action.HIT, 5: Action.DOUBLE, 6: Action.DOUBLE, 7: Action.HIT, 8: Action.HIT, 9: Action.HIT, 10: Action.HIT, 11: Action.HIT },

	# Soft 15 (A,4): Double 4-6, else Hit
	15: { 2: Action.HIT, 3: Action.HIT, 4: Action.DOUBLE, 5: Action.DOUBLE, 6: Action.DOUBLE, 7: Action.HIT, 8: Action.HIT, 9: Action.HIT, 10: Action.HIT, 11: Action.HIT },

	# Soft 16 (A,5): Double 4-6, else Hit
	16: { 2: Action.HIT, 3: Action.HIT, 4: Action.DOUBLE, 5: Action.DOUBLE, 6: Action.DOUBLE, 7: Action.HIT, 8: Action.HIT, 9: Action.HIT, 10: Action.HIT, 11: Action.HIT },

	# Soft 17 (A,6): Double 3-6, else Hit
	17: { 2: Action.HIT, 3: Action.DOUBLE, 4: Action.DOUBLE, 5: Action.DOUBLE, 6: Action.DOUBLE, 7: Action.HIT, 8: Action.HIT, 9: Action.HIT, 10: Action.HIT, 11: Action.HIT },

	# Soft 18 (A,7): Stand 2,7,8; Double 3-6; Hit 9-A
	18: { 2: Action.STAND, 3: Action.DOUBLE, 4: Action.DOUBLE, 5: Action.DOUBLE, 6: Action.DOUBLE, 7: Action.STAND, 8: Action.STAND, 9: Action.HIT, 10: Action.HIT, 11: Action.HIT },

	# Soft 19 (A,8): Always Stand
	19: { 2: Action.STAND, 3: Action.STAND, 4: Action.STAND, 5: Action.STAND, 6: Action.STAND, 7: Action.STAND, 8: Action.STAND, 9: Action.STAND, 10: Action.STAND, 11: Action.STAND },

	# Soft 20 (A,9): Always Stand
	20: { 2: Action.STAND, 3: Action.STAND, 4: Action.STAND, 5: Action.STAND, 6: Action.STAND, 7: Action.STAND, 8: Action.STAND, 9: Action.STAND, 10: Action.STAND, 11: Action.STAND },

	# Soft 21: Blackjack! Stand
	21: { 2: Action.STAND, 3: Action.STAND, 4: Action.STAND, 5: Action.STAND, 6: Action.STAND, 7: Action.STAND, 8: Action.STAND, 9: Action.STAND, 10: Action.STAND, 11: Action.STAND },
}

# Pair splitting strategy
# Format: split_strategy[card_rank (2-11 where 11=Ace)][dealer_upcard]
static var split_strategy: Dictionary = {
	# Pair of 2s: Split 2-7, else Hit
	2: { 2: Action.SPLIT, 3: Action.SPLIT, 4: Action.SPLIT, 5: Action.SPLIT, 6: Action.SPLIT, 7: Action.SPLIT, 8: Action.HIT, 9: Action.HIT, 10: Action.HIT, 11: Action.HIT },

	# Pair of 3s: Split 2-7, else Hit
	3: { 2: Action.SPLIT, 3: Action.SPLIT, 4: Action.SPLIT, 5: Action.SPLIT, 6: Action.SPLIT, 7: Action.SPLIT, 8: Action.HIT, 9: Action.HIT, 10: Action.HIT, 11: Action.HIT },

	# Pair of 4s: Split 5-6, else Hit
	4: { 2: Action.HIT, 3: Action.HIT, 4: Action.HIT, 5: Action.SPLIT, 6: Action.SPLIT, 7: Action.HIT, 8: Action.HIT, 9: Action.HIT, 10: Action.HIT, 11: Action.HIT },

	# Pair of 5s: Never Split (treat as 10)
	5: { 2: Action.DOUBLE, 3: Action.DOUBLE, 4: Action.DOUBLE, 5: Action.DOUBLE, 6: Action.DOUBLE, 7: Action.DOUBLE, 8: Action.DOUBLE, 9: Action.DOUBLE, 10: Action.HIT, 11: Action.HIT },

	# Pair of 6s: Split 2-6, else Hit
	6: { 2: Action.SPLIT, 3: Action.SPLIT, 4: Action.SPLIT, 5: Action.SPLIT, 6: Action.SPLIT, 7: Action.HIT, 8: Action.HIT, 9: Action.HIT, 10: Action.HIT, 11: Action.HIT },

	# Pair of 7s: Split 2-7, else Hit
	7: { 2: Action.SPLIT, 3: Action.SPLIT, 4: Action.SPLIT, 5: Action.SPLIT, 6: Action.SPLIT, 7: Action.SPLIT, 8: Action.HIT, 9: Action.HIT, 10: Action.HIT, 11: Action.HIT },

	# Pair of 8s: Always Split
	8: { 2: Action.SPLIT, 3: Action.SPLIT, 4: Action.SPLIT, 5: Action.SPLIT, 6: Action.SPLIT, 7: Action.SPLIT, 8: Action.SPLIT, 9: Action.SPLIT, 10: Action.SPLIT, 11: Action.SPLIT },

	# Pair of 9s: Split 2-9 except 7, Stand vs 7, 10, A
	9: { 2: Action.SPLIT, 3: Action.SPLIT, 4: Action.SPLIT, 5: Action.SPLIT, 6: Action.SPLIT, 7: Action.STAND, 8: Action.SPLIT, 9: Action.SPLIT, 10: Action.STAND, 11: Action.STAND },

	# Pair of 10s: Never Split (Stand)
	10: { 2: Action.STAND, 3: Action.STAND, 4: Action.STAND, 5: Action.STAND, 6: Action.STAND, 7: Action.STAND, 8: Action.STAND, 9: Action.STAND, 10: Action.STAND, 11: Action.STAND },

	# Pair of Aces: Always Split
	11: { 2: Action.SPLIT, 3: Action.SPLIT, 4: Action.SPLIT, 5: Action.SPLIT, 6: Action.SPLIT, 7: Action.SPLIT, 8: Action.SPLIT, 9: Action.SPLIT, 10: Action.SPLIT, 11: Action.SPLIT },
}

# =============================================================================
# AGGRESSIVE VARIATIONS (for the risk-taker)
# =============================================================================
static var aggressive_variations: Dictionary = {
	# More doubles
	"hard_8_vs_5": Action.DOUBLE,
	"hard_8_vs_6": Action.DOUBLE,
	"soft_19_vs_5": Action.DOUBLE,
	"soft_19_vs_6": Action.DOUBLE,
	# More splits
	"pair_4_vs_4": Action.SPLIT,
}

# =============================================================================
# COACHING FUNCTIONS
# =============================================================================
static func get_recommendation(player_zone: Zone, dealer_upcard: Card, style: Style = Style.CLASSIC, can_split: bool = true, can_double: bool = true, can_surrender: bool = false) -> Action:
	## Get the recommended action based on Basic Strategy

	var dealer_value = _get_upcard_value(dealer_upcard)
	var player_total = player_zone.get_hand_value()
	var is_soft = player_zone.is_soft_hand()
	var is_pair = player_zone.is_pair()

	var action: Action

	# Check for pairs first (if splitting is allowed)
	if is_pair and can_split and player_zone.card_count() == 2:
		var pair_rank = _get_pair_rank(player_zone)
		if split_strategy.has(pair_rank) and split_strategy[pair_rank].has(dealer_value):
			action = split_strategy[pair_rank][dealer_value]
			if action == Action.SPLIT:
				return action

	# Check soft totals
	if is_soft and soft_strategy.has(player_total) and soft_strategy[player_total].has(dealer_value):
		action = soft_strategy[player_total][dealer_value]
	# Check hard totals
	elif hard_strategy.has(player_total) and hard_strategy[player_total].has(dealer_value):
		action = hard_strategy[player_total][dealer_value]
	else:
		# Default for very low or high totals
		if player_total <= 8:
			action = Action.HIT
		else:
			action = Action.STAND

	# Apply aggressive variations
	if style == Style.AGGRESSIVE:
		action = _apply_aggressive(player_total, dealer_value, is_soft, action)

	# Downgrade actions if not available
	if action == Action.DOUBLE and not can_double:
		action = Action.HIT
	if action == Action.SURRENDER and not can_surrender:
		action = Action.HIT
	if action == Action.SPLIT and not can_split:
		# Re-evaluate as regular hand
		if is_soft:
			action = soft_strategy.get(player_total, {}).get(dealer_value, Action.HIT)
		else:
			action = hard_strategy.get(player_total, {}).get(dealer_value, Action.HIT)

	return action

static func _get_upcard_value(card: Card) -> int:
	## Convert card to strategy table key (2-11 where 11=Ace)
	if card.rank == Card.Rank.ACE:
		return 11
	elif card.rank >= Card.Rank.TEN:
		return 10
	else:
		return card.rank

static func _get_pair_rank(zone: Zone) -> int:
	## Get the rank value for pair splitting lookup
	if zone.card_count() != 2:
		return -1

	var card = zone.get_card_at(0)
	if card.rank == Card.Rank.ACE:
		return 11
	elif card.rank >= Card.Rank.TEN:
		return 10
	else:
		return card.rank

static func _apply_aggressive(player_total: int, dealer_value: int, is_soft: bool, base_action: Action) -> Action:
	## Apply aggressive variations for risk-takers
	var key = ""
	if is_soft:
		key = "soft_%d_vs_%d" % [player_total, dealer_value]
	else:
		key = "hard_%d_vs_%d" % [player_total, dealer_value]

	if aggressive_variations.has(key):
		return aggressive_variations[key]
	return base_action

# =============================================================================
# COACHING MESSAGES
# =============================================================================
static func get_action_name(action: Action) -> String:
	match action:
		Action.HIT: return "Hit"
		Action.STAND: return "Stand"
		Action.DOUBLE: return "Double Down"
		Action.SPLIT: return "Split"
		Action.SURRENDER: return "Surrender"
	return "Unknown"

static func get_coaching_message(action: Action, player_total: int, dealer_value: int, is_soft: bool = false) -> String:
	## Returns a friendly coaching message explaining the recommendation

	var hand_type = "soft" if is_soft else "hard"
	var dealer_str = "Ace" if dealer_value == 11 else str(dealer_value)

	match action:
		Action.HIT:
			if player_total <= 11:
				return "Hit! You can't bust with %d, and you need more to beat the dealer." % player_total
			elif dealer_value >= 7:
				return "Hit! The dealer's %s is strong. You need to improve your %d." % [dealer_str, player_total]
			else:
				return "Hit! Your %d isn't quite enough. Take another card, Captain." % player_total

		Action.STAND:
			if player_total >= 17:
				return "Stand! %d is solid. Let the dealer take the risk." % player_total
			elif dealer_value <= 6:
				return "Stand! The dealer's %s is weak. They might bust!" % dealer_str
			else:
				return "Stand! Your %d should hold. Trust the odds, Captain." % player_total

		Action.DOUBLE:
			if player_total == 11:
				return "Double Down! 11 is the best hand to double. Go big, Captain!"
			elif player_total == 10:
				return "Double Down! 10 against the dealer's %s is a money-maker!" % dealer_str
			elif is_soft:
				return "Double Down! Your %s %d is flexible. Press your advantage!" % [hand_type, player_total]
			else:
				return "Double Down! The odds favor doubling here. Fortune favors the bold!"

		Action.SPLIT:
			if player_total == 16:  # 8-8
				return "Split those 8s! Two hands of 8 beat one hand of 16."
			elif player_total == 22:  # A-A (counted as 12 in zone)
				return "Split those Aces! Two chances at 21, Captain!"
			else:
				return "Split! You'll do better with two hands against the dealer's %s." % dealer_str

		Action.SURRENDER:
			return "Surrender. Live to fight another hand, Captain. Discretion is the better part of valor."

	return "The book says: %s" % get_action_name(action)

static func get_warning_message(intended_action: Action, recommended_action: Action, player_total: int) -> String:
	## Returns a warning if the player's intended action differs from the recommendation

	if intended_action == recommended_action:
		return ""

	var rec_name = get_action_name(recommended_action)
	var int_name = get_action_name(intended_action)

	if intended_action == Action.HIT and recommended_action == Action.STAND:
		if player_total >= 17:
			return "Are you sure, Captain? Hitting on %d is risky. The book says Stand." % player_total
		else:
			return "The book says Stand here, but it's your call, Captain."

	elif intended_action == Action.STAND and recommended_action == Action.HIT:
		if player_total <= 11:
			return "Standing on %d? You can't bust if you hit. Sure about this?" % player_total
		else:
			return "The book says Hit here. Standing on %d might not be enough." % player_total

	elif intended_action == Action.HIT and recommended_action == Action.DOUBLE:
		return "You could Double Down here for extra winnings. Just hitting is safe, though."

	elif recommended_action == Action.SPLIT:
		return "The book says Split here. Are you sure you want to %s instead?" % int_name.to_lower()

	return "The book recommends %s, but you're the Captain of this ship!" % rec_name

# =============================================================================
# CARD COUNTING ADVICE
# =============================================================================
static func get_count_based_advice(true_count: float, base_action: Action, player_total: int, dealer_value: int) -> Dictionary:
	## Modify recommendations based on card count (advanced play)

	var advice = {
		"action": base_action,
		"modified": false,
		"message": ""
	}

	# Insurance: Only take when count is +3 or higher
	# (This would be called separately when dealer shows Ace)

	# Deviation plays based on count
	if true_count >= 3:
		# High count = more 10s/Aces in deck
		if player_total == 16 and dealer_value == 10:
			advice.action = Action.STAND
			advice.modified = true
			advice.message = "Count is high (+%.1f). Stand on 16 vs 10 - more small cards left!" % true_count

		elif player_total == 15 and dealer_value == 10:
			advice.action = Action.STAND
			advice.modified = true
			advice.message = "Count is high. Standing on 15 is better here."

		elif player_total == 10 and dealer_value == 10:
			advice.action = Action.DOUBLE
			advice.modified = true
			advice.message = "Hot deck! Double that 10 against the dealer's 10!"

	elif true_count <= -2:
		# Low count = more high cards in deck
		if player_total == 12 and dealer_value == 4:
			advice.action = Action.HIT
			advice.modified = true
			advice.message = "Count is cold (%.1f). Hit on 12 vs 4 - deck is rich in 10s." % true_count

		elif player_total == 13 and dealer_value == 2:
			advice.action = Action.HIT
			advice.modified = true
			advice.message = "Count is low. More 10s in the deck - take the chance and hit."

	return advice

# =============================================================================
# BETTING ADVICE
# =============================================================================
static func get_bet_advice(true_count: float, min_bet: int, max_bet: int) -> Dictionary:
	## Get betting advice based on count

	var bet_units = 1  # Default to minimum
	var advice = ""

	if true_count >= 4:
		bet_units = 5
		advice = "Deck is HOT! Maximum bet recommended, Captain!"
	elif true_count >= 3:
		bet_units = 4
		advice = "Very favorable count. Bet big!"
	elif true_count >= 2:
		bet_units = 3
		advice = "Count is good. Raise your bet."
	elif true_count >= 1:
		bet_units = 2
		advice = "Slightly favorable. Consider raising."
	elif true_count <= -2:
		bet_units = 1
		advice = "Cold deck. Minimum bet - protect your bankroll."
	elif true_count <= -1:
		bet_units = 1
		advice = "Count is unfavorable. Stick to minimum."
	else:
		bet_units = 1
		advice = "Neutral count. Standard bet."

	var recommended_bet = clamp(min_bet * bet_units, min_bet, max_bet)

	return {
		"units": bet_units,
		"amount": recommended_bet,
		"advice": advice
	}
