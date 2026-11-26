extends Control
## Pantalla de inicio: título, los tres tanques, Muffy saludando y los botones.

const Estilo := preload("res://scripts/estilo.gd")
const Gato := preload("res://scripts/gato_animado.gd")
const Globo := preload("res://scripts/globo.gd")
const ControlSonido := preload("res://scripts/control_sonido.gd")

const ESCENA_COMBATE := "res://scenes/eleccion.tscn"  # primero se elige batallón
const ESCENA_TUTORIAL := "res://scenes/tutorial.tscn"

var _muffy: Gato


func _ready() -> void:
	theme = Estilo.tema()
	var fondo := ColorRect.new()
	fondo.color = Estilo.TAPETE
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 22)
	centro.add_child(columna)

	columna.add_child(Estilo.titulo(tr("MEOWTILLERY"), 64))
	var sub := Label.new()
	sub.text = tr("Táctica por turnos con cartas y gatos tanquistas")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(sub)

	var tanques := HBoxContainer.new()
	tanques.alignment = BoxContainer.ALIGNMENT_CENTER
	tanques.add_theme_constant_override("separation", 24)
	for nombre in ["centurion", "is2"]:
		tanques.add_child(Estilo.imagen("res://assets/%s.png" % nombre, 3))
	columna.add_child(tanques)

	# Muffy con su globo de diálogo, junto a los botones.
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 28)
	columna.add_child(fila)

	var lado_muffy := VBoxContainer.new()
	lado_muffy.add_theme_constant_override("separation", 8)
	fila.add_child(lado_muffy)
	var globo := Globo.new(tr("¡Hola! Soy Muffy.\n¿Te enseño a jugar?"), 17, "abajo")
	globo.cola_pos = 0.45
	globo.custom_minimum_size = Vector2(250, 0)
	lado_muffy.add_child(globo)
	_muffy = Gato.new(5)
	_muffy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lado_muffy.add_child(_muffy)
	# Muffy saluda con un maullido al abrir el menú.
	get_tree().create_timer(0.6).timeout.connect(func():
		if is_inside_tree():
			Sonido.tocar("maullido")
			_muffy.animar("talk", 0.6))

	var botones := VBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", 10)
	fila.add_child(botones)
	_boton(botones, tr("Batalla suelta"), func(): get_tree().change_scene_to_file(ESCENA_COMBATE))
	_boton(botones, tr("Campaña"), func(): get_tree().change_scene_to_file("res://scenes/campana.tscn"))
	_boton(botones, tr("Cómo se juega"), func(): get_tree().change_scene_to_file(ESCENA_TUTORIAL))
	_boton(botones, tr("Fichas técnicas"), func(): get_tree().change_scene_to_file("res://scenes/fichas.tscn"))
	_boton(botones, tr("Trofeos (%d/%d)") % [Trofeos.cuantos(), Trofeos.lista().size()],
		func(): get_tree().change_scene_to_file("res://scenes/vitrina.tscn"))
	if not OS.has_feature("web"):  # en el navegador no hay ventana que cerrar
		_boton(botones, tr("Salir"), func(): get_tree().quit())
	botones.add_child(ControlSonido.new())

	# Idioma: arriba a la derecha, bien a la vista (dice el idioma al que cambia).
	var idioma := Button.new()
	idioma.text = "English" if Idioma.actual() == "es" else "Español"
	idioma.tooltip_text = "Play in English" if Idioma.actual() == "es" else "Jugar en español"
	idioma.custom_minimum_size = Vector2(130, 40)
	idioma.add_theme_font_size_override("font_size", 18)
	idioma.pressed.connect(Idioma.alternar)
	var esquina := MarginContainer.new()
	esquina.set_anchors_preset(Control.PRESET_FULL_RECT)
	esquina.mouse_filter = Control.MOUSE_FILTER_IGNORE  # que no tape los botones del menú
	for lado in ["left", "right", "top", "bottom"]:
		esquina.add_theme_constant_override("margin_" + lado, 16)
	add_child(esquina)
	var fila_idioma := HBoxContainer.new()
	fila_idioma.alignment = BoxContainer.ALIGNMENT_END
	fila_idioma.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	fila_idioma.mouse_filter = Control.MOUSE_FILTER_IGNORE
	esquina.add_child(fila_idioma)
	fila_idioma.add_child(idioma)


func _boton(padre: Control, texto: String, accion: Callable) -> void:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(260, 50)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(accion)
	b.mouse_entered.connect(func(): _muffy.animar("happy", 0.8))
	padre.add_child(b)
