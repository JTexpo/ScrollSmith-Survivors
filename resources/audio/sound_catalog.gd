class_name SoundCatalog
extends Resource
## Every sound the game can play, with how each behaves. Adding a sound is a recipe, its built WAV and one entry here.

const DEFAULT_PATH := "res://resources/audio/sound_catalog.tres"

@export var sounds: Array[SoundData] = []


func find(id: StringName) -> SoundData:
	for data in sounds:
		if data.id == id:
			return data
	return null


static func default_catalog() -> SoundCatalog:
	return load(DEFAULT_PATH) as SoundCatalog
