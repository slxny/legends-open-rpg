extends Node
class_name CombatAudioComponent

## Phase 1B.4: combat-specific audio selector (plan §3 corr. 11).
##
## AudioManager (2,888 lines) keeps responsibility for playback, pooling,
## buses, pitch jitter, last-N variation guard. This component selects
## WHICH audio group plays for a given CombatFeedbackProfile + target
## tags, and calls into AudioManager.
##
## Plan rule: do NOT grow AudioManager with combat selection logic.
##
## Owner code calls one of:
##   play_swing(profile)
##   play_impact(profile, target_tags)
##   play_kill(profile)
##
## Where target_tags is an optional StringName ("body" / "armor" /
## "magical") to choose the appropriate sub-layer. Default falls through
## to profile.audio_impact.

@export var pitch_jitter: float = 0.05  # ±5% by default


func play_swing(profile: Resource) -> void:
	if profile == null:
		return
	var id: StringName = StringName(profile.get("audio_swing"))
	if id != &"":
		_play(id, 0.0)


func play_impact(profile: Resource, target_tag: StringName = &"") -> void:
	if profile == null:
		return
	var id: StringName = _select_impact(profile, target_tag)
	if id != &"":
		var db: float = -2.0 if String(id) == "hit_impact" else 0.0
		_play(id, db)


func play_kill(profile: Resource) -> void:
	if profile == null:
		return
	var id: StringName = StringName(profile.get("audio_kill"))
	if id != &"":
		_play(id, 0.0)


func _select_impact(profile: Resource, target_tag: StringName) -> StringName:
	match target_tag:
		&"body":
			var b: StringName = StringName(profile.get("audio_body"))
			if b != &"":
				return b
		&"armor":
			var a: StringName = StringName(profile.get("audio_armor"))
			if a != &"":
				return a
		&"magical":
			var m: StringName = StringName(profile.get("audio_magical"))
			if m != &"":
				return m
	return StringName(profile.get("audio_impact"))


func _play(id: StringName, db: float) -> void:
	# Try AudioManager.play_sfx(name, db) — the project's existing API.
	if AudioManager == null:
		return
	if AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx(String(id), db)
