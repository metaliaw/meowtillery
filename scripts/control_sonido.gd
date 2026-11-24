extends HBoxContainer
## Control de sonido: botón para silenciar y barra de volumen. Usa el autoload Sonido,
## que guarda el ajuste; si hay más de un control abierto, todos quedan sincronizados.

const Estilo := preload("res://scripts/estilo.gd")

var _silencio: Button
var _barra: HSlider


func _init(color_texto: Color = Estilo.PAPEL) -> void:
	add_theme_constant_override("separation", 10)
	var etiqueta := Label.new()
	etiqueta.text = "Sonido"
	etiqueta.add_theme_color_override("font_color", color_texto)
	add_child(etiqueta)
	_barra = HSlider.new()
	_barra.min_value = 0
	_barra.max_value = 100
	_barra.step = 5
	_barra.custom_minimum_size = Vector2(160, 24)
	_barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_barra.value_changed.connect(func(v: float): Sonido.poner_volumen(v / 100.0))
	# Al soltar la barra suena un clic, para oír cómo quedó el volumen.
	_barra.drag_ended.connect(func(_cambio: bool): Sonido.tocar("clic"))
	add_child(_barra)
	_silencio = Button.new()
	_silencio.toggle_mode = true
	_silencio.custom_minimum_size = Vector2(110, 34)
	_silencio.toggled.connect(func(activo: bool): Sonido.poner_silencio(activo))
	add_child(_silencio)


func _ready() -> void:
	Sonido.ajustes_cambiados.connect(_sincronizar)
	_sincronizar()


func _sincronizar() -> void:
	_barra.set_value_no_signal(Sonido.volumen * 100.0)
	_silencio.set_pressed_no_signal(Sonido.silencio)
	_silencio.text = "Sin sonido" if Sonido.silencio else "Silenciar"
	_barra.editable = not Sonido.silencio
