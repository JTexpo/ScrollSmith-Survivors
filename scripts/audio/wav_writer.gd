class_name WavWriter
extends RefCounted
## Writes samples as a 16 bit mono PCM WAV file. With `loop` it adds a `smpl` chunk holding one forward loop over the whole
## sample, which Godot's WAV importer reads as the stream's loop.

const SMPL_CHUNK_SIZE := 60


static func encode(samples: PackedFloat32Array, rate: int, loop: bool = false) -> PackedByteArray:
	var data_size := samples.size() * 2
	var out := PackedByteArray()
	out.append_array("RIFF".to_ascii_buffer())
	_u32(out, 36 + data_size + (8 + SMPL_CHUNK_SIZE if loop else 0))
	out.append_array("WAVE".to_ascii_buffer())
	out.append_array("fmt ".to_ascii_buffer())
	_u32(out, 16)
	_u16(out, 1)
	_u16(out, 1)
	_u32(out, rate)
	_u32(out, rate * 2)
	_u16(out, 2)
	_u16(out, 16)
	out.append_array("data".to_ascii_buffer())
	_u32(out, data_size)
	for sample in samples:
		var value := clampi(roundi(sample * 32767.0), -32768, 32767)
		_u16(out, value & 0xFFFF)
	if loop:
		out.append_array("smpl".to_ascii_buffer())
		_u32(out, SMPL_CHUNK_SIZE)
		_u32(out, 0)
		_u32(out, 0)
		_u32(out, roundi(1.0e9 / float(rate)))
		_u32(out, 60)
		_u32(out, 0)
		_u32(out, 0)
		_u32(out, 0)
		_u32(out, 1)
		_u32(out, 0)
		_u32(out, 0)
		_u32(out, 0)
		_u32(out, 0)
		_u32(out, maxi(samples.size() - 1, 0))
		_u32(out, 0)
		_u32(out, 0)
	return out


static func _u16(out: PackedByteArray, value: int) -> void:
	out.append(value & 0xFF)
	out.append((value >> 8) & 0xFF)


static func _u32(out: PackedByteArray, value: int) -> void:
	out.append(value & 0xFF)
	out.append((value >> 8) & 0xFF)
	out.append((value >> 16) & 0xFF)
	out.append((value >> 24) & 0xFF)
