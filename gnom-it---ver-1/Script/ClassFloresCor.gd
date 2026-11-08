@tool
class_name CorFlor
extends Node3D

@export_group("Cor da Flor")
@export var cor_flor: Color = Color.WHITE:
	set(valor):
		cor_flor = valor
		if is_inside_tree():
			aplicar_cor()

func _ready() -> void:
	aplicar_cor()

func aplicar_cor() -> void:
	var grupo_mesh = get_node_or_null("MeshFlor")
	if grupo_mesh == null:
		return

	for mesh in grupo_mesh.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue

		for i in range(mesh.mesh.get_surface_count()):
			var material = mesh.mesh.surface_get_material(i)

			if material is StandardMaterial3D:
				var novo_material = material.duplicate() as StandardMaterial3D
				novo_material.albedo_color = cor_flor
				mesh.set_surface_override_material(i, novo_material)

func obter_cor() -> Color:
	return cor_flor
