extends RefCounted
## Station minigame id (data/content.json stations.*.minigame) -> script. Kept free of autoload references so the
## headless unit tests can load it.

const MINIGAMES := {
	"trim": preload("res://scripts/ui/minigames/trim.gd"),
	"measure": preload("res://scripts/ui/minigames/measure.gd"),
	"pour": preload("res://scripts/ui/minigames/pour.gd"),
	"heat": preload("res://scripts/ui/minigames/heat.gd"),
	"extract": preload("res://scripts/ui/minigames/extract.gd"),
	"equilibrium": preload("res://scripts/ui/minigames/equilibrium.gd"),
	"pack": preload("res://scripts/ui/minigames/pack.gd"),
}
