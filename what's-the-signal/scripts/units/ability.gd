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
