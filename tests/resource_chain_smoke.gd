extends SceneTree

## Focused headless coverage for the exploration resource chain. This test does
## not depend on the world renderer, so it remains useful while map/UI work is
## iterated independently.
func _init() -> void:
	var game := GameManager.new()
	game.start_exploration()
	var resources := game.resources
	resources.amounts["food"] = 0
	resources.amounts["wood"] = 0
	resources.amounts["stone"] = 0
	resources.tools["axe"] = false
	resources.tools["pickaxe"] = false

	# Fishing and salvage never create stone; direct source validation also
	# rejects an accidental non-pebble stone reward.
	var fishing := FishingSpot.new()
	fishing.setup(game)
	assert(not fishing.reward.has("stone"))
	assert(fishing.interact().get("started", false))
	fishing.tick_interaction(3.1)
	assert(resources.get_amount("stone") == 0)
	var ruin := RuinSpot.new()
	ruin.setup(game)
	assert(not ruin.reward.has("stone"))
	assert(resources.add_from_source("stone", 1, "river_fishing") == 0)
	assert(resources.get_amount("stone") == 0)

	# Grassland pebbles are direct pickups and remain available without tools.
	var pebble := PebbleSpot.new()
	pebble.setup(game)
	assert(pebble.interact().get("started", false))
	pebble.tick_interaction(0.9)
	assert(resources.get_amount("stone") == 1)

	# Large stone piles are a separate source and stay locked until the player
	# crafts the dedicated pickaxe.
	var rock_pile := RockPileSpot.new()
	rock_pile.setup(game)
	assert(not rock_pile.can_interact())
	assert(rock_pile.prompt_text().contains("石镐"))
	var locked_pile := rock_pile.interact()
	assert(not locked_pile.get("ok", false))
	assert(locked_pile.get("locked", false))
	assert(locked_pile.get("failed", false))

	# Fallen branches and berry bushes provide wood before an axe exists.
	var branch := BranchSpot.new()
	branch.setup(game)
	assert(branch.interact().get("started", false))
	branch.tick_interaction(1.0)
	assert(resources.get_amount("wood") == 1)
	var forage := ForageSpot.new()
	forage.failure_chance = 0.0
	forage.setup(game)
	assert(forage.interact().get("started", false))
	forage.tick_interaction(2.1)
	assert(resources.get_amount("wood") == 2)

	# Trees are visibly present but locked until the stone axe is crafted.
	var tree := TreeSpot.new()
	tree.failure_chance = 0.0
	tree.setup(game)
	assert(not tree.can_interact())
	assert(tree.prompt_text().contains("石斧"))
	var locked := tree.interact()
	assert(not locked.get("ok", false))
	assert(locked.get("locked", false))
	assert(locked.get("failed", false))
	assert(str(locked.get("reason", "")).contains("石斧"))

	# Crafting is atomic and reports the missing materials clearly.
	resources.set_workbench_available(false)
	var locked_craft := resources.craft_axe()
	assert(not locked_craft.get("ok", false) and locked_craft.get("locked", false))
	resources.set_workbench_available(true)
	var failed_craft := resources.craft_axe()
	assert(not failed_craft.get("ok", false))
	assert(str(failed_craft.get("reason", "")).contains("石料"))
	resources.amounts["stone"] = 3
	resources.amounts["wood"] = 4
	var crafted := resources.craft_axe()
	assert(crafted.get("ok", false))
	assert(resources.has_axe())
	assert(resources.get_amount("stone") == 1)
	assert(resources.get_amount("wood") == 1)
	var duplicate := resources.craft_axe()
	assert(not duplicate.get("ok", false))
	assert(duplicate.get("already_owned", false))

	assert(tree.can_interact())
	assert(tree.interact().get("started", false))
	tree.tick_interaction(3.3)
	assert(resources.get_amount("wood") == 5)

	# The pickaxe has its own recipe and unlocks mining without changing the
	# existing tree/axe chain.
	resources.amounts["stone"] = 3
	resources.amounts["wood"] = 2
	var crafted_pickaxe := resources.craft_pickaxe()
	assert(crafted_pickaxe.get("ok", false))
	assert(resources.has_pickaxe())
	assert(resources.get_amount("stone") == 0)
	assert(resources.get_amount("wood") == 0)
	assert(rock_pile.can_interact())
	assert(rock_pile.interact().get("started", false))
	rock_pile.tick_interaction(3.1)
	assert(resources.get_amount("stone") == 3)

	# New tool state survives save/load, while a version-2 resource payload gets
	# a clean default (no axe) without losing its original amounts.
	var saved := resources.to_dict()
	var restored := ResourceManager.new()
	restored.from_dict(saved)
	assert(restored.has_axe())
	assert(restored.has_pickaxe())
	var legacy := ResourceManager.new()
	legacy.from_dict({"amounts":{"food":2, "wood":1, "medicine":0, "fuel":0, "scrap":0}})
	assert(not legacy.has_axe())
	assert(legacy.get_amount("stone") == 4)

	# Verify the concrete world registers each new point family without relying
	# on HUD code or a rendered frame.
	var integration_world := ExplorationWorld.new()
	root.add_child(integration_world)
	integration_world.setup(game)
	var pebble_count := 0
	var branch_count := 0
	var tree_count := 0
	var rock_pile_count := 0
	var world_tree: TreeSpot = null
	var world_rock_pile: RockPileSpot = null
	for point in integration_world.interactions:
		if point is PebbleSpot:
			pebble_count += 1
		if point is BranchSpot:
			branch_count += 1
		if point is TreeSpot:
			tree_count += 1
			if world_tree == null: world_tree = point
		if point is RockPileSpot:
			rock_pile_count += 1
			if world_rock_pile == null: world_rock_pile = point
	assert(pebble_count >= 3)
	assert(branch_count >= 3)
	assert(tree_count >= 4)
	assert(rock_pile_count >= 6)
	assert(world_tree != null)
	assert(world_rock_pile != null)
	resources.pickaxe = false
	assert(world_rock_pile.interact().get("locked", false))
	resources.pickaxe = true
	assert(world_rock_pile.interact().get("started", false))
	world_rock_pile.tick_interaction(world_rock_pile.interaction_time + 0.1)
	resources.axe = false
	assert(world_tree.interact().get("locked", false))
	resources.axe = true
	assert(world_tree.interact().get("started", false))
	world_tree.tick_interaction(world_tree.interaction_time + 0.1)
	integration_world.free()

	print("RESOURCE_CHAIN_SMOKE_OK stone=%d wood=%d axe=%s pickaxe=%s" % [resources.get_amount("stone"), resources.get_amount("wood"), resources.has_axe(), resources.has_pickaxe()])
	for point in [fishing, ruin, pebble, rock_pile, branch, forage, tree]:
		if is_instance_valid(point): point.free()
	quit()
