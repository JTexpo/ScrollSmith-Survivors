class_name EnemyBrain
extends RefCounted
## What an enemy does each physics step besides being knocked back. `step` returns the velocity (pixels per
## second) it wants this step, and may also act (fire, light a fuse, heal). One brain belongs to one enemy,
## chosen from its archetype's `EnemyBehaviorData.kind`, so nothing branches on an enemy's name.


func step(_enemy: Enemy, _delta: float) -> Vector2:
	return Vector2.ZERO


static func for_data(data: EnemyData) -> EnemyBrain:
	if data == null or data.behavior == null:
		return BrainChase.new()
	match data.behavior.kind:
		EnemyBehaviorData.Kind.KEEP_DISTANCE:
			return BrainKeepDistance.new()
		EnemyBehaviorData.Kind.EXPLODE:
			return BrainExplode.new()
		EnemyBehaviorData.Kind.SUPPORT:
			return BrainSupport.new()
	return BrainChase.new()
