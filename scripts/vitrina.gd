extends Control
## Vitrina de trofeos: todos los logros, los ganados en dorado y los que faltan en gris
## (siempre se ve cómo se consiguen, para tener una meta).

const Estilo := preload("res://scripts/estilo.gd")
const ESCENA_MENU := "res://scenes/menu.tscn"
const COLUMNAS := 3


func _ready() -> void:
	theme = Estilo.tema()
	var fondo := ColorRect.new()
	fondo.color = Estilo.TAPETE
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 28)
	add_child(margen)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 14)
	margen.add_child(columna)
	columna.add_child(Estilo.titulo(tr("VITRINA DE TROFEOS"), 40))
	var cuenta := Label.new()
	cuenta.text = tr("Tienes %d de %d trofeos.") % [Trofeos.cuantos(), Trofeos.lista().size()]
	cuenta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cuenta.add_theme_font_size_override("font_size", 20)
	columna.add_child(cuenta)

	var desplazable := ScrollContainer.new()
	desplazable.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columna.add_child(desplazable)
	var grilla := GridContainer.new()
	grilla.columns = COLUMNAS
	grilla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grilla.add_theme_constant_override("h_separation", 12)
	grilla.add_theme_constant_override("v_separation", 12)
	desplazable.add_child(grilla)
	for t in Trofeos.lista():
		grilla.add_child(_tarjeta(t, Trofeos.tiene(t["id"])))

	var volver := Button.new()
	volver.text = tr("Volver")
	volver.custom_minimum_size = Vector2(140, 44)
	volver.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	volver.pressed.connect(func(): get_tree().change_scene_to_file(ESCENA_MENU))
	columna.add_child(volver)


func _tarjeta(t: Dictionary, ganado: bool) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 92)
	if ganado:
		panel.add_theme_stylebox_override("panel", Estilo.caja(Color("fff3c4"), Estilo.TINTA, 3))
	else:
		panel.add_theme_stylebox_override("panel", Estilo.caja(Color("c9ccd6"), Color("6b6b78"), 3))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	panel.add_child(fila)
	var copa := Estilo.imagen("res://assets/trofeo.png", 3)
	if not ganado:
		copa.modulate = Color(0.2, 0.2, 0.25, 0.45)  # silueta
	fila.add_child(copa)
	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_child(textos)
	var nombre := Estilo.texto_en_papel(t["nombre"], 18)
	textos.add_child(nombre)
	var como := Estilo.texto_en_papel(t["texto"], 13)
	como.add_theme_color_override("font_color", Color("4a4858") if ganado else Color("5b5d6b"))
	textos.add_child(como)
	if not ganado:
		nombre.add_theme_color_override("font_color", Color("4a4858"))
	return panel
