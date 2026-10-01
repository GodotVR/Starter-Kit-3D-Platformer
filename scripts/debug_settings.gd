extends Node

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_increase_max_fps"):
		Engine.max_fps = max(0, Engine.max_fps + 5)
		print("Updated engine max fps to ", Engine.max_fps)
	
	if event.is_action_pressed("debug_decrease_max_fps"):
		Engine.max_fps = max (0, Engine.max_fps - 5)
		print("Updated engine max fps to ", Engine.max_fps)
