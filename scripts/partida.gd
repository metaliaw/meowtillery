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

var jugador := "britanico"
var rival := "sovietico"
var batallas_sin_michi := 0


## Arma la batalla elegida y decide si esta vez viene Michi. Devuelve si vino.
func nueva_batalla(combate) -> bool:
	var viene := batallas_sin_michi >= BATALLAS_SIN_MICHI_MAX or randf() < PROBABILIDAD_MICHI
	batallas_sin_michi = 0 if viene else batallas_sin_michi + 1
	iniciar_combate(combate, jugador, rival, -1, viene)
	return viene


static func batallones() -> Dictionary:
	return Datos.leer("res://data/batallones.json")


## El rival es el otro batallón (por ahora hay dos).
func elegir(id_batallon: String) -> void:
	jugador = id_batallon
	for id in batallones():
		if id != id_batallon:
			rival = id
			return


## Arma el combate: mazo = cartas generales + las del batallón propio.
## Con `con_michi`, la teniente Michi está al mando y da órdenes.
static func iniciar_combate(combate, id_jugador: String, id_rival: String, semilla: int = -1, con_michi: bool = false) -> void:
	var b := batallones()
	var mazo: Array = Datos.leer("res://data/mazo_inicial.json")
	mazo = mazo + b[id_jugador]["cartas"]
	combate.oficial = OFICIAL if con_michi else {}
	combate.iniciar(
		Datos.leer("res://data/mapa.json"),
		b[id_jugador]["unidades"],
		b[id_rival]["unidades"],
		Datos.leer("res://data/cartas.json"),
		mazo,
		semilla)
