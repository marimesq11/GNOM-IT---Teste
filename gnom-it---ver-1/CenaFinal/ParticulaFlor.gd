class_name CorParticulaFlor
extends Node3D

@export_group("Partícula")
@export var particula: GPUParticles3D

@onready var cor_flor: CorFlor = get_parent() as CorFlor


func emitir_particula(posicao: Vector3) -> void:
	if not is_instance_valid(cor_flor) or not is_instance_valid(particula):
		return

	var cor_atual: Color = cor_flor.obter_cor()

	var nova_particula = particula.duplicate() as GPUParticles3D
	if nova_particula == null:
		return

	get_tree().current_scene.add_child(nova_particula)
	nova_particula.global_position = posicao
	nova_particula.visible = true
	nova_particula.one_shot = true
	nova_particula.emitting = false
	nova_particula.local_coords = false

	# MATERIAL DE PROCESSAMENTO
	var material = nova_particula.process_material as ParticleProcessMaterial

	if material == null:
		push_warning("A partícula precisa de um ParticleProcessMaterial!")
		nova_particula.queue_free()
		return

	material = material.duplicate(true) as ParticleProcessMaterial
	nova_particula.process_material = material

	# USA A COR DA FLOR
	var gradiente = Gradient.new()
	gradiente.set_color(0, cor_atual)
	gradiente.set_color(1, cor_atual)

	var textura = GradientTexture1D.new()
	textura.gradient = gradiente

	material.color = Color.WHITE
	material.color_ramp = textura

	# MATERIAL VISUAL DA PARTÍCULA
	if nova_particula.draw_passes > 0:
		var mesh_original = nova_particula.get_draw_pass_mesh(0)

		if mesh_original != null:
			var mesh_copia = mesh_original.duplicate(true) as Mesh

			if mesh_copia != null:
				nova_particula.set_draw_pass_mesh(0, mesh_copia)

				var material_visual = mesh_copia.surface_get_material(0)

				if material_visual == null:
					material_visual = mesh_copia.material

				if material_visual is StandardMaterial3D:
					var novo_material = material_visual.duplicate() as StandardMaterial3D
					novo_material.vertex_color_use_as_albedo = true
					novo_material.albedo_color = Color.WHITE
					mesh_copia.material = novo_material

	# EMITE A PARTÍCULA
	nova_particula.restart()
	nova_particula.emitting = true

	# REMOVE DEPOIS DA ANIMAÇÃO
	var duracao = nova_particula.lifetime / maxf(nova_particula.speed_scale, 0.01)
	await get_tree().create_timer(duracao + 0.5).timeout

	if is_instance_valid(nova_particula):
		nova_particula.queue_free()
