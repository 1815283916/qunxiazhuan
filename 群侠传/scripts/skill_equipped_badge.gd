extends Control
## A vector badge stays crisp at different window sizes.
func _draw() -> void:
	draw_circle(Vector2(16, 16), 15, Color("163e24"))
	draw_arc(Vector2(16, 16), 14, 0, TAU, 32, Color("72e38a"), 2, true)
	draw_polyline(PackedVector2Array([Vector2(8, 16), Vector2(14, 22), Vector2(24, 10)]), Color("c5ffd1"), 3, true)
