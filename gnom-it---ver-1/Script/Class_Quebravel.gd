class_name Quebravel
extends Node

static func quebrar(objeto):
	if objeto.is_in_group("quebravel"):
		objeto.queue_free()
