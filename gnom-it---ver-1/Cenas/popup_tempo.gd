
extends Label

func aparecer(texto_popup: String = "") -> void:
	text = texto_popup

	# APARÊNCIA
	modulate = Color.ORANGE
	add_theme_font_size_override("font_size", 20)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 4)

	# CENTRALIZAR TEXTO
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# CENTRALIZAR NO MARKER2D
	reset_size()
	position = -size / 2.0

	# COMEÇA VISÍVEL
	modulate.a = 1.0

	# ANIMAÇÃO
	var tween = create_tween()

	# PISCA DUAS VEZES
	tween.tween_property(self, "modulate:a", 0.2, 0.1)
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	tween.tween_property(self, "modulate:a", 0.2, 0.1)
	tween.tween_property(self, "modulate:a", 1.0, 0.1)

	# FICA PARADO POR 2 SEGUNDOS
	tween.tween_interval(0.5)

	# DESAPARECE GRADUALMENTE
	tween.tween_property(self, "modulate:a", 0.0, 0.6)

	# REMOVE
	tween.tween_callback(queue_free)
