extends TextureRect
## Un gato animado desde su hoja de sprites: cuadros de 32×32, una fila por animación.
## Por defecto es Muffy, la instructora (assets/muchi/muchi-kawaii-sheet.png; el archivo
## conserva el nombre original del personaje). Los gatos tanquistas y Michi
## (assets/gatos/) usan el mismo formato.

const HOJA := preload("res://assets/muchi/muchi-kawaii-sheet.png")
const CUADRO := 32
const ANIMACIONES := {
	"idle": {"fila": 0, "cuadros": 16, "ms": 130, "bucle": true},
	"talk": {"fila": 1, "cuadros": 6, "ms": 90, "bucle": true},
	"happy": {"fila": 2, "cuadros": 8, "ms": 80, "bucle": false},
	"alert": {"fila": 3, "cuadros": 6, "ms": 100, "bucle": false},
	"angry": {"fila": 4, "cuadros": 6, "ms": 90, "bucle": false},
}

var escala := 5
var hoja: Texture2D = HOJA
var _atlas := AtlasTexture.new()
var _anim := "idle"
var _cuadro := 0
var _tiempo := 0.0
var _volver_a_idle := -1.0


func _init(escala_inicial: int = 5, otra_hoja: Texture2D = null) -> void:
	escala = escala_inicial
	if otra_hoja != null:
		hoja = otra_hoja


func _ready() -> void:
	_atlas.atlas = hoja
	texture = _atlas
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	custom_minimum_size = Vector2(CUADRO, CUADRO) * escala
	animar("idle")


## Cambia de animación. Con `segundos` > 0 vuelve sola a "idle" pasado ese tiempo.
func animar(nombre: String, segundos: float = 0.0) -> void:
	_anim = nombre
	_cuadro = 0
	_tiempo = 0.0
	_volver_a_idle = segundos if segundos > 0.0 else -1.0
	_actualizar()


func _process(delta: float) -> void:
	if _volver_a_idle > 0.0:
		_volver_a_idle -= delta
		if _volver_a_idle <= 0.0:
			animar("idle")
			return
	var a: Dictionary = ANIMACIONES[_anim]
	var paso: float = a["ms"] / 1000.0
	_tiempo += delta
	while _tiempo >= paso:
		_tiempo -= paso
		if _cuadro + 1 < a["cuadros"]:
			_cuadro += 1
		elif a["bucle"]:
			_cuadro = 0
	_actualizar()


func _actualizar() -> void:
	var a: Dictionary = ANIMACIONES[_anim]
	_atlas.region = Rect2(_cuadro * CUADRO, a["fila"] * CUADRO, CUADRO, CUADRO)
