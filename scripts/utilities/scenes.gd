class_name Scenes
extends RefCounted
## The paths of the scenes the game moves between (the run scene is the ruins; the forest and maze are small inherited scenes), so no script writes them twice.

const HOME := "res://scenes/home/home.tscn"
const RUN := "res://scenes/main/main.tscn"
const FOREST := "res://scenes/main/main_forest.tscn"
const MAZE := "res://scenes/main/main_maze.tscn"
