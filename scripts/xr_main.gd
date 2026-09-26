extends Node3D

const USE_XR_ORIGIN_WORLD_SCALE = true

@onready var xr_origin_3d: XROrigin3D = $XROrigin3D
@onready var left_controller_mesh: MeshInstance3D = $XROrigin3D/LeftXRController3D/LeftControllerMesh
@onready var right_controller_mesh: MeshInstance3D = $XROrigin3D/RightXRController3D/RightControllerMesh

@onready var game_world: Node3D = $GameWorld
@onready var volume_portal: MeshInstance3D = $VolumePortal


func _ready() -> void:
	var xr_interface = XRServer.find_interface('OpenXR')
	if xr_interface == null or not xr_interface.is_initialized():
		printerr("Unable to access xr interface...")
		return
	
	var spatial_container_ext = OpenXRSpatialContainerExtension
	if spatial_container_ext:
		spatial_container_ext.spatial_container_bounds_changed.connect(_on_spatial_container_bounds_changed)
		
		var bounds_mode = spatial_container_ext.get_spatial_container_state().get_bounds_mode()
		var volume_bounds = spatial_container_ext.get_spatial_container_bounds()
		_update_scale(bounds_mode, volume_bounds)
	else:
		printerr("Unable to access spatial container extension.")

func _on_spatial_container_bounds_changed(_spatial_container_rid: RID, _infinite_bounds: bool, bounds_mode: OpenXRSpatialContainerState.BoundsMode, updated_bounds: Vector3):
	print("Spatial container bounds changed...")
	_update_scale(bounds_mode, updated_bounds)

func _update_scale(bounds_mode: OpenXRSpatialContainerState.BoundsMode, spatial_container_bounds: Vector3):
	var updated_scale = _get_spatial_container_scale(bounds_mode, spatial_container_bounds)
	if USE_XR_ORIGIN_WORLD_SCALE:
		_update_xr_origin_world_scale(updated_scale)
	else:
		_update_game_world_scale(updated_scale)

func _get_spatial_container_scale(bounds_mode: OpenXRSpatialContainerState.BoundsMode, spatial_container_bounds: Vector3) -> Vector3:
	if bounds_mode == OpenXRSpatialContainerState.BOUNDS_MODE_IMMERSIVE:
		return Vector3.ONE

	var volume_portal_mesh = volume_portal.mesh as BoxMesh
	var ratio_vector = spatial_container_bounds / volume_portal_mesh.size
	var min_ratio = ratio_vector[ratio_vector.min_axis_index()]
	var game_world_scale = Vector3(min_ratio, min_ratio, min_ratio)
	return game_world_scale

func _update_xr_origin_world_scale(new_scale: Vector3) -> void:
	var inverse_scale = new_scale.inverse()
	xr_origin_3d.world_scale = inverse_scale.x
	left_controller_mesh.scale = inverse_scale
	right_controller_mesh.scale = inverse_scale

func _update_game_world_scale(new_scale: Vector3) -> void:
	volume_portal.scale = new_scale
	game_world.scale = new_scale
