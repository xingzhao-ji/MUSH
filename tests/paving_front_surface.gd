extends "res://tests/paving_surface.gd"
## Same native preservation contract for all 3078 front-batch corners.
func _selected_path() -> String: return "BatchedStaticWorld/Static_-9223371981288634209_0_0"
func _selected_index() -> int: return 1
func _original_property() -> String: return "paving_front_surface_original"
func _report_property() -> String: return "paving_front_surface_report"
func _triplanar() -> bool: return true
func _close_camera() -> Vector3: return Vector3(1.4,1.65,10.8)
func _close_target() -> Vector3: return Vector3(-.45,.18,7.8)
