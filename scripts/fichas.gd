extends Control
## Fichas técnicas: datos reales de cada tanque del juego, con su dibujo y un dato curioso.
## Datos aproximados, para disfrutar; no son un manual técnico (data/fichas.json).

const Estilo := preload("res://scripts/estilo.gd")
const Datos := preload("res://scripts/datos.gd")
const ESCENA_MENU := "res://scenes/menu.tscn"

var _fichas: Array = []
var _imagen: TextureRect
var _titulo: Label
var _datos: Label
var _dato: Label


func _ready() -> void:
	_fichas = Datos.leer("res://data/fichas.json")
	theme = Estilo.tema()
	var fondo := ColorRect.new()
	fondo.color = Estilo.TAPETE
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 32)
	add_child(margen)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 16)
	margen.add_child(columna)
	columna.add_child(Estilo.titulo("FICHAS TÉCNICAS", 40))

	var fila := HBoxContainer.new()
	fila.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fila.add_theme_constant_override("separation", 24)
	columna.add_child(fila)

	# Izquierda: un botón por tanque.
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 3)
	lista.custom_minimum_size = Vector2(240, 0)
	# Con tanques y aviones ya no caben todos: la lista se desplaza con la rueda del mouse.
	var desplazable := ScrollContainer.new()
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	desplazable.custom_minimum_size = Vector2(254, 0)
	fila.add_child(desplazable)
	desplazable.add_child(lista)
	for i in _fichas.size():
		var b := Button.new()
		b.text = _fichas[i]["nombre"]
		b.custom_minimum_size = Vector2(0, 30)
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_mostrar.bind(i))
		lista.add_child(b)

	# Derecha: la ficha.
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(panel)
	var ficha := VBoxContainer.new()
	ficha.add_theme_constant_override("separation", 12)
	panel.add_child(ficha)
	_titulo = Estilo.texto_en_papel("", 30)
	ficha.add_child(_titulo)
	_imagen = TextureRect.new()
	_imagen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_imagen.custom_minimum_size = Vector2(80, 28) * 5
	_imagen.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ficha.add_child(_imagen)
	_datos = Estilo.texto_en_papel("", 18)
	ficha.add_child(_datos)
	_dato = Estilo.texto_en_papel("", 17)
	_dato.add_theme_color_override("font_color", Color("3b6fb0"))
	ficha.add_child(_dato)
	var nota := Estilo.texto_en_papel("Datos aproximados de los tanques y aviones reales. En el juego los números están simplificados.", 12)
	nota.add_theme_color_override("font_color", Color("6b6b78"))
	ficha.add_child(nota)

	var volver := Button.new()
	volver.text = "Volver"
	volver.custom_minimum_size = Vector2(140, 44)
	volver.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	volver.pressed.connect(func(): get_tree().change_scene_to_file(ESCENA_MENU))
	columna.add_child(volver)

	_mostrar(0)


func _mostrar(i: int) -> void:
	var f: Dictionary = _fichas[i]
	Trofeos.ficha_vista(i, _fichas.size())
	_titulo.text = "%s  ·  %s, %s" % [f["nombre"], f["pais"], f["anio"]]
	_imagen.texture = load(f["sprite"])
	if f.get("avion", false):
		_datos.text = "Tripulación: %d\nPeso: %s\nArmamento: %s\nBlindaje: %s\nVelocidad: %s\nEn el juego: %s (Veterano y As)" % [
			int(f["tripulacion"]), f["peso"], f["armamento"], f["blindaje"], f["velocidad"], f["gato"]]
	else:
		_datos.text = "Tripulación: %d\nPeso: %s\nCañón: %s\nBlindaje: %s\nVelocidad: %s\nEn el juego lo maneja: %s" % [
			int(f["tripulacion"]), f["peso"], f["canon"], f["blindaje"], f["velocidad"], f["gato"]]
	_dato.text = "¿Sabías que…? " + f["dato"]
