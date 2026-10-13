shader_type spatial;
render_mode unshaded, depth_draw_never, shadows_disabled;

// Draws the 1 m grid on a flat square, brightest at `centre` and gone at `radius`.
uniform vec3 centre = vec3(0.0);
uniform float radius : hint_range(1.0, 20.0) = 7.0;
uniform float line_width = 0.03;
uniform vec4 line_colour : source_color = vec4(1.0, 0.97, 0.85, 1.0);

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 to_line = abs(fract(world.xz + 0.5) - 0.5);
	float on_line = 1.0 - smoothstep(0.0, line_width, min(to_line.x, to_line.y));
	float near = 1.0 - smoothstep(radius * 0.4, radius, distance(world.xz, centre.xz));
	ALBEDO = line_colour.rgb;
	ALPHA = on_line * near * 0.7;
}
