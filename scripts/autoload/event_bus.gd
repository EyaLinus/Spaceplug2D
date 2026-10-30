extends Node
## Global event bus. Decouples the core simulation, the world and the UI.
## Core events are relayed by GameState as `game_event(kind, payload)`; world/UI events have their own signals.

signal game_event(kind: String, payload: Dictionary)  ## everything the core Game emits (sold, busted, new_day, ...)
signal toast(text: String, good: bool)  ## short on-screen notification
signal dock_requested(location: String)
signal undock_requested
signal scan_progress(ratio: float)  ## 0 = nobody scanning, 1 = busted
signal new_game_started
signal game_loaded
