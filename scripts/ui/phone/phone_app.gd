extends RefCounted
## Base class for a Com-Phone app. Subclass it, set id/title/icon in _init, build the app's first screen in
## home(), then list the script in registry.gd. Deeper screens are pushed with phone.push(title, builder), where
## builder is a Callable(g) -> Control; the phone rebuilds the visible screen after every game event, so apps never
## cache numbers.

const UI = preload("res://scripts/ui/ui_theme.gd")

var id := ""
var title := ""
var icon := ""  ## icon key for Art.icon_for (assets/gfx/icons/<icon>.png); "" = coloured tile with the initial
var tint := UI.ACCENT  ## tile colour on the home screen


## First screen of the app. `phone` is the phone overlay (push/back/open_app).
func home(_g, _phone) -> Control:
	return Control.new()


## Number shown on the app's home tile (unread messages, new contacts …); 0 = no badge.
func badge(_g) -> int:
	return 0
