extends StaticBody

export var prompt_text := "Press E to Sit"
export var pose_key := "chair_sit"

onready var sit_position: Position3D = $SitPosition

func interact(player) -> void:
	if player.has_method("sit_at"):
		# In Godot 3.5, use global_transform.basis instead of global_basis
		var seat_transform = Transform(global_transform.basis, sit_position.global_transform.origin)
		player.sit_at(seat_transform, pose_key)
