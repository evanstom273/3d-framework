extends CharacterBody3D
## Just enough of a player for NPC tests: carries a tool.
class FakeTools extends RefCounted:
	func is_equipped() -> bool:
		return true
var tool_handler := FakeTools.new()
