class_name ElementLook
extends Resource
## How one element looks when a spell is cast: the faint tint and bright edge drawn on the exact hit area, the effect sprite
## played over it, the flying object of its Missiles and Waves, and whether its effects rise from the ground (Fire, Land)
## or fall from the sky (Thunder, Sea). Data only: no code branches on an element's name.

@export var element: int = -1
## The faint tint over the hit area (alpha about 0.25) and the bright 1 px edge along its border.
@export var tint: Color = Color(1, 1, 1, 0.25)
@export var edge: Color = Color.WHITE
## The sprite played, once, at each effect spot (`fx_fire_burst`, `fx_land_spike`, `fx_thunder_bolt`, `fx_sea_splash`).
@export var effect_sprite: StringName
## The prefix of the flying object's sprites: `<prefix>_12`, `_16` and `_24`, one per size class.
@export var orb_sprite: StringName
## True when the effect rises from the ground and spreads out from the caster, false when it falls from the sky.
@export var rises: bool = true
