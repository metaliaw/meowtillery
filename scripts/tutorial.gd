extends Control
## Tutorial: Muffy y la teniente Michi explican el juego en unas pocas páginas,
## con imágenes del propio juego. Cada página dice quién habla ("habla"; Muffy por defecto).

const Estilo := preload("res://scripts/estilo.gd")
const Gato := preload("res://scripts/gato_animado.gd")

const ESCENA_COMBATE := "res://scenes/eleccion.tscn"  # primero se elige batallón
const ESCENA_MENU := "res://scenes/menu.tscn"
const HOJA_MICHI := "res://assets/gatos/michi.png"
const NOMBRES := {"muffy": "Muffy, instructora", "michi": "Teniente Michi"}
## Cuánto rato mueve la boca quien habla al cambiar de página.
const SEGUNDOS_HABLANDO := 1.6

const PAGINAS := [
	{
		"texto": "¡Hola! Soy Muffy y hoy soy tu instructora. Las tripulaciones son gatos y los tanques son de verdad. Primero eliges batallón: británicos, que no pelean sin té, o soviéticos, que atacan todos juntos.",
		"imagenes": ["res://assets/centurion.png", "res://assets/churchill.png", "res://assets/is2.png", "res://assets/t34_85.png"],
		"escala": 2,
	},
	{
		"texto": "Cada gato tiene una manía. Earl Grey recupera moral si se queda quieto tomando té; Boris tiene un cañón enorme pero recarga lento. Mira la ficha de cada tanque para conocer la suya, y el mazo trae cartas propias de tu batallón.",
		"gatos": ["res://assets/gatos/earl_grey.png", "res://assets/gatos/marmalade.png", "res://assets/gatos/boris.png", "res://assets/gatos/pelmeni.png"],
		"anim": "happy",
	},
	{
		"texto": "El campo de batalla es una mesa de cartas. El llano cuesta 1 de movimiento. El bosque y las ruinas cuestan 2, pero te cubren: +1 y +2 de blindaje. Las cartas boca abajo son rocas: por ahí no se pasa.",
		"imagenes": ["res://assets/terreno/llano_0.png", "res://assets/terreno/bosque_0.png",
			"res://assets/terreno/ruinas_0.png", "res://assets/terreno/roca_0.png"],
		"escala": 2,
	},
	{
		"texto": "Haz clic en uno de tus tanques para elegirlo. Las casillas azules muestran hasta dónde llega. Haz clic en una para moverte; puedes repartir el movimiento en varios pasos.",
	},
	{
		"texto": "¡Ojo con la flecha amarilla! Cada tanque mira hacia donde dio su último paso. El frente es lo más blindado; el flanco y la trasera, mucho menos. Rodea a los enemigos y dales por el costado.",
		"anim": "alert",
	},
	{
		"texto": "Y ella es la teniente Michi, que explica las cartas. A veces aparece en batalla de inspección sorpresa y da órdenes: obedécela. Y un consejo: no intentes hacerle cariño.",
		"anim": "alert",
	},
	{
		"habla": "michi",
		"texto": "Escucha bien, recluta, que no lo voy a repetir. Atacas con las cartas de tu mano: 3 de energía por turno, y cada carta dice cuánto cuesta y hasta dónde llega. Elige el blanco con clic en un enemigo y pasa el mouse sobre una carta para ver el daño. ¿Entendido? Bien.",
	},
	{
		"habla": "michi",
		"texto": "El enemigo avisa lo que va a hacer. No es amabilidad, es pura torpeza. Elígelo y verás en rojo hasta dónde pega. Ponte Humo o usa Girar casco para darle tu frente. Y no me hagas pasar vergüenza.",
		"anim": "angry",
	},
	{
		"habla": "michi",
		"texto": "La moral. Si te pegan fuerte, la tripulación se asusta; con 0 entra en pánico y no dispara. Una Arenga o una Hora del té la levantan. Yo no necesito té: yo nací con la moral alta.",
		"anim": "angry",
	},
	{
		"texto": "Cuando no te quede nada por hacer, pulsa Terminar turno. ¡Derrota a todos los enemigos para ganar! ¿Lista la tripulación?",
		"anim": "happy",
	},
]

var _pagina := 0
var _muffy: Gato
var _michi: Gato
var _quien: Label
var _texto: Label
var _imagenes: HBoxContainer
var _contador: Label
var _anterior: Button
var _siguiente: Button


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
	columna.add_theme_constant_override("separation", 20)
	centro.add_child(columna)
	columna.add_child(Estilo.titulo("CÓMO SE JUEGA", 44))

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 24)
	columna.add_child(fila)
	_muffy = Gato.new(7)
	_muffy.size_flags_vertical = Control.SIZE_SHRINK_END
	fila.add_child(_muffy)

	var derecha := VBoxContainer.new()
	derecha.add_theme_constant_override("separation", 16)
	fila.add_child(derecha)
	_quien = Estilo.titulo("", 24)
	_quien.add_theme_constant_override("outline_size", 8)
	derecha.add_child(_quien)
	var globo := PanelContainer.new()
	globo.custom_minimum_size = Vector2(620, 170)
	_texto = Estilo.texto_en_papel("", 19)
	globo.add_child(_texto)
	derecha.add_child(globo)
	_imagenes = HBoxContainer.new()
	_imagenes.alignment = BoxContainer.ALIGNMENT_CENTER
	_imagenes.add_theme_constant_override("separation", 16)
	_imagenes.custom_minimum_size = Vector2(0, 130)
	derecha.add_child(_imagenes)

	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 12)
	derecha.add_child(botones)
	_boton(botones, "Saltar", func(): get_tree().change_scene_to_file(ESCENA_MENU))
	var espacio := Control.new()
	espacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	botones.add_child(espacio)
	_contador = Label.new()
	botones.add_child(_contador)
	_anterior = _boton(botones, "Anterior", func(): _ir_a(_pagina - 1))
	_siguiente = _boton(botones, "Siguiente", _avanzar)

	# Michi a la derecha, mirando hacia Muffy.
	_michi = Gato.new(7, load(HOJA_MICHI))
	_michi.flip_h = true
	_michi.size_flags_vertical = Control.SIZE_SHRINK_END
	fila.add_child(_michi)

	_ir_a(0)


func _hablante() -> Gato:
	return _michi if PAGINAS[_pagina].get("habla", "muffy") == "michi" else _muffy


func _boton(padre: Control, texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(130, 46)
	b.pressed.connect(accion)
	padre.add_child(b)
	return b


func _avanzar() -> void:
	if _pagina == PAGINAS.size() - 1:
		get_tree().change_scene_to_file(ESCENA_COMBATE)
	else:
		_ir_a(_pagina + 1)


func _ir_a(indice: int) -> void:
	_pagina = clampi(indice, 0, PAGINAS.size() - 1)
	var p: Dictionary = PAGINAS[_pagina]
	_texto.text = p["texto"]
	_quien.text = NOMBRES[p.get("habla", "muffy")]
	for hijo in _imagenes.get_children():
		_imagenes.remove_child(hijo)
		hijo.queue_free()
	for ruta in p.get("imagenes", []):
		_imagenes.add_child(Estilo.imagen(ruta, p.get("escala", 2)))
	for ruta in p.get("gatos", []):
		_imagenes.add_child(Gato.new(4, load(ruta)))
	_contador.text = "%d / %d" % [_pagina + 1, PAGINAS.size()]
	_anterior.disabled = _pagina == 0
	_siguiente.text = "¡A jugar!" if _pagina == PAGINAS.size() - 1 else "Siguiente"
	# Habla un rato y luego hace el gesto de la página (si tiene) o vuelve a reposo.
	var otro := _muffy if _hablante() == _michi else _michi
	otro.animar("idle")
	_hablante().animar("talk", SEGUNDOS_HABLANDO)
	if p.has("anim"):
		get_tree().create_timer(SEGUNDOS_HABLANDO).timeout.connect(_gesto.bind(_pagina, p["anim"]))


func _gesto(pagina: int, anim: String) -> void:
	if pagina == _pagina:  # solo si sigue en la misma página
		_hablante().animar(anim, 1.5)
