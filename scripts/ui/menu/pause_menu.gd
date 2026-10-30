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
	title("Paused")
	box.add_child(UI.button("Resume", func(): resume_pressed.emit()))
	box.add_child(UI.button("Save game", func(): save_pressed.emit()))
	box.add_child(UI.button("Load game", func(): load_pressed.emit()))
	box.add_child(UI.button("Settings", func(): settings_pressed.emit()))
	box.add_child(UI.button("Save & main menu", func(): main_menu_pressed.emit()))
	box.add_child(UI.button("Save & quit to desktop", func(): quit_pressed.emit()))
	back.connect(func(): resume_pressed.emit())
