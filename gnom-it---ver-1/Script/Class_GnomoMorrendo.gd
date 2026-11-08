class_name CorMorteGnomo
extends Node

@export_group("Partícula")
@export var particula: GPUParticles3D

@export_group("Gnomo Vermelho")
@export var vermelho_cor_1: Color = Color.RED
@export var vermelho_cor_2: Color = Color.ORANGE
@export var vermelho_cor_3: Color = Color.YELLOW

@export_group("Gnomo Verde")
@export var verde_cor_1: Color = Color.GREEN
@export var verde_cor_2: Color = Color.YELLOW_GREEN
@export var verde_cor_3: Color = Color.DARK_GREEN

@export_group("Gnomo Azul")
@export var azul_cor_1: Color = Color.BLUE
@export var azul_cor_2: Color = Color.CYAN
@export var azul_cor_3: Color = Color.DARK_BLUE

@export_group("Gnomo Amarelo")
@export var amarelo_cor_1: Color = Color.YELLOW
@export var amarelo_cor_2: Color = Color.ORANGE
@export var amarelo_cor_3: Color = Color.GOLD


func mudar_cor(gnomo: Node3D) -> void:
	if not is_instance_valid(gnomo) or not is_instance_valid(particula):
		return

	var cores: Array[Color] = []

	if gnomo.is_in_group("GnomoVermelho"):
		cores = [vermelho_cor_1, vermelho_cor_2, vermelho_cor_3]
	elif gnomo.is_in_group("GnomoVerde"):
		cores = [verde_cor_1, verde_cor_2, verde_cor_3]
	elif gnomo.is_in_group("GnomoAzul"):
		cores = [azul_cor_1, azul_cor_2, azul_cor_3]
	elif gnomo.is_in_group("GnomoAmarelo"):
		cores = [amarelo_cor_1, amarelo_cor_2, amarelo_cor_3]
	else:
		push_warning("Gnomo sem grupo de cor: " + gnomo.name)
		return

	emitir_particula(gnomo.global_position, cores)


func emitir_particula(posicao: Vector3, cores: Array[Color]) -> void:
	if not is_instance_valid(particula):
		return

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

	# GRADIENTE COM TRÊS CORES
	var gradiente = Gradient.new()
	gradiente.set_color(0, cores[0])
	gradiente.add_point(0.5, cores[1])
	gradiente.set_color(1, cores[2])

	var textura = GradientTexture1D.new()
	textura.gradient = gradiente

	material.color = Color.WHITE
	material.color_ramp = textura

	# MATERIAL VISUAL
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
