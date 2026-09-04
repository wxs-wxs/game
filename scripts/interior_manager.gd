class_name InteriorManager
extends Node

var interior

func enter(world) :
	if is_instance_valid(interior): interior.queue_free()
	interior = preload("res://scripts/house_interior.gd").new(); interior.name = "HouseInterior"; add_child(interior); interior.setup(world, ExplorationWorld.INTERIOR_OFFSET); return interior

func exit() -> void:
	if is_instance_valid(interior): interior.queue_free()
	interior = null
