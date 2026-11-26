shader_type canvas_item;
// Turns a sprite into a mid grey with no hue (the icon of an achievement not earned yet), keeping its shape and transparency.
void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float grey = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(grey * 0.5 + 0.28), color.a);
}
