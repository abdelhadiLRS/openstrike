extends StaticBody3D

@export var max_health := 100
var health := max_health

func take_damage(amount: int) -> void:
    health = maxi(0, health - amount)
    if health == 0:
        visible = false
        process_mode = Node.PROCESS_MODE_DISABLED

func reset_target() -> void:
    health = max_health
    visible = true
    process_mode = Node.PROCESS_MODE_INHERIT
