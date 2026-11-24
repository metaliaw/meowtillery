extends Node
## Autoload "Partida": qué batallón eligió la jugadora y contra quién pelea.
## La función estática también la usan las pruebas, sin autoload.

const Datos := preload("res://scripts/datos.gd")

## Oficial al mando de cualquier batallón: la teniente Michi.
const OFICIAL := {
	"id": "michi",
	"nombre": "Teniente Michi",
	"gato": "res://assets/gatos/michi.png",
	"mania": "mandona",
	"mania_texto": "Mandona: cada turno ordena a un tanque que ataque. Si obedece, +1 energía el turno siguiente; si no, ese tanque pierde 1 de moral.",
}

## Michi aparece de inspección sorpresa: con esta probabilidad en cada batalla,
## y segura si lleva BATALLAS_SIN_MICHI_MAX batallas sin venir.
const PROBABILIDAD_MICHI := 1.0 / 3.0
const BATALLAS_SIN_MICHI_MAX := 3

## Niveles de dificultad (ver Combate.dificultad). Calibrados con tools/qa/simular.gd.
const DIFICULTADES := {
	"recluta": {"nombre": "Recluta", "texto": "Para aprender. Actúan 2 enemigos por turno y pegan 2 menos.",
		"acciones_max": 2, "bonus_dano": -2, "ia_lista": false, "salvavidas": true},
	"veterano": {"nombre": "Veterano", "texto": "El enemigo piensa: remata, flanquea, se cubre y pega 2 más. Un tanque sano no cae en un solo turno.",
		"acciones_max": 3, "bonus_dano": 2, "ia_lista": true, "salvavidas": true},
	"as": {"nombre": "As", "texto": "Sin piedad: actúan todos, pegan 2 más y no hay red de seguridad.",
		"acciones_max": 4, "bonus_dano": 2, "ia_lista": true},
}

## Arsenal: cartas de botín guardadas entre batallas (las que capturaste y no usaste).
## Antes de una batalla se eligen hasta LLEVAR_MAX para llevar; usarlas las gasta.
const ARCHIVO_ARSENAL := "user://arsenal.json"
const ARSENAL_MAX := 12
const LLEVAR_MAX := 2

var jugador := "britanico"
var rival := "sovietico"
## Rival elegido en la pantalla de batallón ("" = al azar entre los demás).
var rival_elegido := ""
var dificultad := "recluta"
var batallas_sin_michi := 0
var arsenal: Array = []
var llevar: Array = []  # posiciones del arsenal elegidas para la próxima batalla
var archivo_arsenal := ARCHIVO_ARSENAL  # las pruebas usan otro archivo


func _ready() -> void:
	cargar_arsenal()


## Arma la batalla elegida y decide si esta vez viene Michi. Devuelve si vino.
## Las cartas elegidas del Arsenal salen de él y entran como botín inicial.
func nueva_batalla(combate) -> bool:
	var viene := batallas_sin_michi >= BATALLAS_SIN_MICHI_MAX or randf() < PROBABILIDAD_MICHI
	batallas_sin_michi = 0 if viene else batallas_sin_michi + 1
	iniciar_combate(combate, jugador, rival, -1, viene, dificultad)
	var posiciones := llevar.filter(func(i): return i >= 0 and i < arsenal.size())
	posiciones.sort()
	for i in posiciones:
		combate.botin.append(arsenal[i])
	posiciones.reverse()
	for i in posiciones:
		arsenal.remove_at(i)
	llevar.clear()
	combate.set_meta("arsenal_cerrado", false)
	guardar_arsenal()
	return viene


## Al terminar o abandonar una batalla: el botín sin usar vuelve al Arsenal (y las capturas
## que quedaron sin elegir, con su primera opción). Se puede llamar más de una vez.
func cerrar_batalla(combate) -> void:
	if combate == null or combate.get_meta("arsenal_cerrado", true):
		return
	combate.set_meta("arsenal_cerrado", true)
	for captura in combate.capturas:
		combate.botin.append(captura["opciones"][0])
	combate.capturas.clear()
	arsenal.append_array(combate.botin)
	while arsenal.size() > ARSENAL_MAX:
		arsenal.pop_front()  # se descartan las más antiguas
	guardar_arsenal()


## Marca o desmarca la carta en la posición `i` del Arsenal. Devuelve si quedó elegida.
func alternar_llevar(i: int) -> bool:
	if llevar.has(i):
		llevar.erase(i)
		return false
	if llevar.size() >= LLEVAR_MAX or i < 0 or i >= arsenal.size():
		return false
	llevar.append(i)
	return true


func cargar_arsenal() -> void:
	arsenal = []
	if FileAccess.file_exists(archivo_arsenal):
		var datos = JSON.parse_string(FileAccess.get_file_as_string(archivo_arsenal))
		if datos is Array:
			arsenal = datos.filter(func(x): return x is String)
	llevar = llevar.filter(func(i): return i < arsenal.size())


func guardar_arsenal() -> void:
	var f := FileAccess.open(archivo_arsenal, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(arsenal))


static func batallones() -> Dictionary:
	return Datos.leer("res://data/batallones.json")


## El rival es el elegido o, si es "al azar" (o el mismo batallón), uno de los demás.
func elegir(id_batallon: String) -> void:
	jugador = id_batallon
	var otros: Array = batallones().keys().filter(func(id): return id != id_batallon)
	rival = rival_elegido if otros.has(rival_elegido) else otros[randi() % otros.size()]


## Arma el combate. No hay mazo compartido: cada gato trae sus propias cartas
## ("habilidades" en data/batallones.json). Con `con_michi`, la teniente Michi está al
## mando y da órdenes.
static func iniciar_combate(combate, id_jugador: String, id_rival: String, semilla: int = -1,
		con_michi: bool = false, id_dificultad: String = "") -> void:
	var b := batallones()
	var mazo: Array = []
	combate.oficial = OFICIAL if con_michi else {}
	combate.dificultad = DIFICULTADES.get(id_dificultad, {})
	combate.refuerzo = b[id_jugador].get("refuerzo", {})
	combate.iniciar(
		Datos.leer("res://data/mapa.json"),
		b[id_jugador]["unidades"],
		b[id_rival]["unidades"],
		Datos.leer("res://data/cartas.json"),
		mazo,
		semilla)
