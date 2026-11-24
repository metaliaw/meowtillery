extends Node
## Autoload "Partida": qué batallón eligió la jugadora y contra quién pelea.
## La función estática también la usan las pruebas, sin autoload.

const Datos := preload("res://scripts/datos.gd")

var jugador := "britanico"
var rival := "sovietico"


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
static func iniciar_combate(combate, id_jugador: String, id_rival: String, semilla: int = -1) -> void:
	var b := batallones()
	var mazo: Array = Datos.leer("res://data/mazo_inicial.json")
	mazo = mazo + b[id_jugador]["cartas"]
	combate.iniciar(
		Datos.leer("res://data/mapa.json"),
		b[id_jugador]["unidades"],
		b[id_rival]["unidades"],
		Datos.leer("res://data/cartas.json"),
		mazo,
		semilla)
