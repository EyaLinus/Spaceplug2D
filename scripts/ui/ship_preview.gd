extends Control
## Shipyard preview: the player ship with every bought upgrade module, drawn large (integer scale keeps the pixels).

const Art = preload("res://scripts/core/art.gd")

var levels: Dictionary = {}
var zoom := 3


func _init(upgrade_levels: Dictionary = {}) -> void:
	levels = upgrade_levels.duplicate()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(48, 48) * zoom
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	draw_set_transform(size / 2.0, 0.0, Vector2(zoom, zoom))
	Art.draw_ship(self, levels)
