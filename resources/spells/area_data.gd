class_name AreaData
extends Resource
## One Area type's scene and default numbers. A spell points at one of these and scales
## its range and size (SpellData.range_scale / size_scale).

enum AreaType { LINE, CONE, AREA, MISSILE, WAVE }

@export var type: AreaType = AreaType.MISSILE
@export var scene: PackedScene
## Line length, Cone reach, Wave and Missile travel distance, and how far from the player
## an Area can land.
@export var default_range: float = 100.0
## Line width (px), Cone angle (degrees), Area radius (px), Wave width (px), Missile scale factor.
@export var default_size: float = 1.0
## Seconds an instant shape (Line, Cone) exists, or an Area zone lasts.
@export var duration: float = 0.0
## Seconds between hits on one enemy inside an Area zone.
@export var tick_interval: float = 0.0
## Wave: extra width per second, as a fraction of its starting width.
@export var widen_rate: float = 0.0
## True if the spell lands where the player points (the reticle and targeting read this).
@export var needs_ground_target: bool = false
## Missile: radius (px) of the small burst where it ends (its first enemy hit, or the end of its range). 0 means none.
@export var burst_radius: float = 0.0
## Missile: the burst's damage as a share of the spell's damage (0 to 1).
@export var burst_damage_share: float = 0.0
## What an Area crafted from this scroll starts with, before Base multipliers and range.
@export var base_stats: AreaStats
