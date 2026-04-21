class_name Ability
extends Resource

enum Kind {
	LIFESTEAL,
	THORNS,
	CRIT_CHANCE,
	FIRST_STRIKE,
	REGEN,
	ARMOR_PIERCE,
	EVASION,
	EXECUTE,
	BERSERK,
	SHIELD,
	LAST_STAND,
}

@export var kind: Kind = Kind.LIFESTEAL
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var value: float = 0.0
@export var icon: Texture2D


static func kind_name(k: int) -> String:
	match k:
		Kind.LIFESTEAL: return "Lifesteal"
		Kind.THORNS: return "Thorns"
		Kind.CRIT_CHANCE: return "Crit"
		Kind.FIRST_STRIKE: return "First Strike"
		Kind.REGEN: return "Regen"
		Kind.ARMOR_PIERCE: return "Armor Pierce"
		Kind.EVASION: return "Evasion"
		Kind.EXECUTE: return "Execute"
		Kind.BERSERK: return "Berserk"
		Kind.SHIELD: return "Shield"
		Kind.LAST_STAND: return "Last Stand"
	return "Ability"


static func format_description(k: int, amount: float) -> String:
	var v: int = int(round(amount))
	match k:
		Kind.LIFESTEAL:
			return "Heal %d%% of damage dealt." % v
		Kind.THORNS:
			return "Reflect %d%% of damage taken." % v
		Kind.CRIT_CHANCE:
			if v >= 100:
				@warning_ignore("integer_division")
				var tier: int = v / 100 + 1
				var remainder: int = v % 100
				if remainder > 0:
					return "Always %dx, %d%% chance for %dx." % [tier, remainder, tier + 1]
				return "Always %dx damage." % tier
			return "%d%% chance for 2x damage." % v
		Kind.FIRST_STRIKE:
			return "Strike first in ties."
		Kind.REGEN:
			return "Heal %d HP per attack." % v
		Kind.ARMOR_PIERCE:
			return "Ignore %d enemy DEF." % v
		Kind.EVASION:
			return "%d%% chance to dodge." % v
		Kind.EXECUTE:
			return "+%d%% damage vs targets below 25%% HP." % v
		Kind.BERSERK:
			return "+%d%% damage while below 30%% HP." % v
		Kind.SHIELD:
			return "Absorb %d damage total." % v
		Kind.LAST_STAND:
			return "Survive one lethal blow with 1 HP."
	return ""
