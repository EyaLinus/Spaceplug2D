extends RefCounted
## Com-Phone apps in home-screen order. Adding an app = one script in apps/ plus one line here.

const APPS := [
	preload("res://scripts/ui/phone/apps/contacts_app.gd"),
	preload("res://scripts/ui/phone/apps/deals_app.gd"),
]


static func create_all() -> Array:
	var r: Array = []
	for script in APPS:
		r.append(script.new())
	return r
