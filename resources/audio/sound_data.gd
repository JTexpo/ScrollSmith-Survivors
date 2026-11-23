class_name SoundData
extends Resource
## How one sound behaves: its id (the file `assets/audio/<id>.wav`), loudness, how many may play at once, the least time between
## two starts, how important it is when the voices are full, and how much its pitch wobbles so repeats do not sound identical.

enum Priority { LOW, NORMAL, HIGH }

@export var id: StringName = &""
@export var volume_db: float = 0.0
@export var max_voices: int = 4
@export var min_gap_msec: int = 0
@export var priority: Priority = Priority.NORMAL
## Random pitch spread in semitones, plus or minus.
@export var wobble: float = 0.0
## False for interface sounds, which still play while the game is paused.
@export var pausable: bool = true
## True for the music loops, which the board plays on the music bus and never from its voice pool.
@export var music: bool = false
