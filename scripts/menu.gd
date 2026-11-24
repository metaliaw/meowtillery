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

	columna.add_child(Estilo.titulo("MEOWTILLERY", 64))
	var sub := Label.new()
	sub.text = "Táctica por turnos con cartas y gatos tanquistas"
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
	var globo := Globo.new("¡Hola! Soy Muffy.\n¿Te enseño a jugar?", 17, "abajo")
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
	botones.add_theme_constant_override("separation", 14)
	fila.add_child(botones)
	_boton(botones, "Iniciar juego", func(): get_tree().change_scene_to_file(ESCENA_COMBATE))
	_boton(botones, "Cómo se juega", func(): get_tree().change_scene_to_file(ESCENA_TUTORIAL))
	if not OS.has_feature("web"):  # en el navegador no hay ventana que cerrar
		_boton(botones, "Salir", func(): get_tree().quit())
	botones.add_child(ControlSonido.new())


func _boton(padre: Control, texto: String, accion: Callable) -> void:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(260, 58)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(accion)
	b.mouse_entered.connect(func(): _muffy.animar("happy", 0.8))
	padre.add_child(b)
