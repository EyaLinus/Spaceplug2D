extends "res://scripts/ui/menu/overlay.gd"
## In-game pause menu (Esc). Esc again resumes. main.gd connects the signals.

signal resume_pressed
signal save_pressed
signal load_pressed
signal settings_pressed
signal main_menu_pressed
signal quit_pressed


func _init() -> void:
	super(360)
	_build()
	back.connect(func(): resume_pressed.emit())
	Settings.language_changed.connect(_rebuild)


func _rebuild() -> void:
	clear_box()
	_build()
	if visible:
		focus_first()


func _build() -> void:
	title(Loc.t("pause.title", "Paused"))
	box.add_child(UI.button(Loc.t("pause.resume", "Resume"), func(): resume_pressed.emit()))
	box.add_child(UI.button(Loc.t("pause.save", "Save game"), func(): save_pressed.emit()))
	box.add_child(UI.button(Loc.t("pause.load", "Load game"), func(): load_pressed.emit()))
	box.add_child(UI.button(Loc.t("pause.settings", "Settings"), func(): settings_pressed.emit()))
	box.add_child(UI.button(Loc.t("pause.main_menu", "Save & main menu"), func(): main_menu_pressed.emit()))
	box.add_child(UI.button(Loc.t("pause.quit", "Save & quit to desktop"), func(): quit_pressed.emit()))
