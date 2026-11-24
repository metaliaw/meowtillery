extends Node
## Autoload "Sonido": efectos de sonido de todo el juego (ver assets/sonidos/CREDITOS.txt).
##
## Todos los botones suenan solos: al aparecer un Button en el árbol se le conectan
## hover, clic y un "error" si se pulsa estando deshabilitado. Un botón puede cambiar
## su sonido de clic con set_meta("sonido", "nombre").
## Lo del combate entra por cola(): así los disparos de la fase enemiga no suenan todos a la vez.

const CARPETA := "res://assets/sonidos/"
const ARCHIVOS := {
	"hover": "hover.wav", "clic": "clic.wav", "carta": "carta.wav", "mover": "mover.wav",
	"error": "error.wav", "victoria": "victoria.wav", "derrota": "derrota.wav",
	"turno": "turno.wav", "disparo": "disparo.ogg", "explosion": "explosion.ogg",
	# Gatos: Muffy maúlla, Michi gruñe (y ronronea cuando aprueba), un gato asustado maúlla agudo.
	"maullido": "maullido.ogg", "maullido_suave": "maullido_suave.ogg", "ronroneo": "ronroneo.ogg",
	"susto": "susto.ogg", "grunido": "grunido.ogg",
}
## Ajuste de volumen por sonido (dB): el cañón y la explosión son fuertes y el hover se repite mucho.
const VOLUMEN := {"hover": -14.0, "clic": -6.0, "disparo": -8.0, "explosion": -6.0, "turno": -6.0,
	"maullido": -6.0, "maullido_suave": -6.0, "ronroneo": -4.0, "susto": -8.0, "grunido": -5.0}
const REPRODUCTORES := 8
## Separación entre sonidos encolados (segundos).
const PAUSA_COLA := 0.35

var _flujos: Dictionary = {}
var _reproductores: Array[AudioStreamPlayer] = []
var _siguiente := 0
var _cola_libre_en := 0.0


func _ready() -> void:
	for nombre in ARCHIVOS:
		_flujos[nombre] = load(CARPETA + ARCHIVOS[nombre])
	for i in REPRODUCTORES:
		var r := AudioStreamPlayer.new()
		add_child(r)
		_reproductores.append(r)
	get_tree().node_added.connect(_al_agregar_nodo)


func tocar(nombre: String) -> void:
	if not _flujos.has(nombre):
		return
	# Reparte entre varios reproductores para que un sonido no corte al anterior.
	var r := _reproductores[_siguiente]
	_siguiente = (_siguiente + 1) % REPRODUCTORES
	r.stream = _flujos[nombre]
	r.volume_db = VOLUMEN.get(nombre, 0.0)
	r.pitch_scale = randf_range(0.95, 1.05)  # pequeña variación para que no canse
	r.play()


## Toca el sonido después de los que ya están en cola, separados por PAUSA_COLA.
func cola(nombre: String) -> void:
	var ahora := Time.get_ticks_msec() / 1000.0
	var espera := maxf(_cola_libre_en - ahora, 0.0)
	_cola_libre_en = ahora + espera + PAUSA_COLA
	if espera <= 0.0:
		tocar(nombre)
	else:
		get_tree().create_timer(espera).timeout.connect(tocar.bind(nombre))


func _al_agregar_nodo(nodo: Node) -> void:
	if nodo is Button:
		var b: Button = nodo
		b.mouse_entered.connect(func(): if not b.disabled: tocar("hover"))
		b.pressed.connect(func(): tocar(b.get_meta("sonido", "clic")))
		b.gui_input.connect(func(e: InputEvent):
			if b.disabled and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				tocar("error"))
