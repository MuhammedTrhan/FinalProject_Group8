shader_type canvas_item;
// Pixelated, wobbly ripples that travel left and right of the centre (not a
// full circle). Draw it on a square ColorRect centred on the noise source.
// unshaded: stays visible when the house is dark.
render_mode unshaded;

uniform vec4 wave_color : source_color = vec4(0.95, 0.95, 0.85, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0; // 0 = invisible
uniform int ring_count : hint_range(1, 6) = 3;
uniform float speed = 0.45;                           // ripples per second
uniform float ring_width = 0.04;                      // half thickness, 0..1 = centre to edge
uniform float inner_radius : hint_range(0.0, 1.0) = 0.5; // where ripples start (outside the furniture)
uniform float half_angle = 0.7;                       // radians; spread of each side's arc
uniform float wobble_amount = 0.03;
uniform float wobble_freq = 9.0;
uniform float pixel_grid = 48.0;                      // cells across the rect; lower = chunkier
uniform float phase = 0.0;                            // per-instance offset so sources don't pulse in sync


void fragment() {
	// Snap to a coarse grid so the arcs match the pixel art.
	vec2 uv = (floor(UV * pixel_grid) + 0.5) / pixel_grid - 0.5;
	float len = length(uv);
	float dist = len * 2.0; // 0 at centre, 1 at the middle of an edge

	// Keep only the wedges around +X and -X.
	float side = abs(uv.x) / max(len, 0.0001);
	float c = cos(half_angle);
	float arc = smoothstep(c, c + 0.1, side);

	// Mirrored angle so left and right wobble identically.
	float angle = atan(uv.y, abs(uv.x));

	float alpha = 0.0;
	for (int i = 0; i < ring_count; i++) {
		float p = fract(TIME * speed + phase + float(i) / float(ring_count));
		float r = mix(inner_radius, 1.0, p);
		// Steady at the source, shakier as it spreads.
		float wobble = sin(angle * wobble_freq + TIME * 14.0 + float(i) * 2.0) * wobble_amount * p;
		float ring = step(abs(dist + wobble - r), ring_width);
		alpha = max(alpha, ring * (1.0 - p));
	}

	// Three alpha steps instead of a smooth fade, to stay pixel-art.
	alpha = round(alpha * arc * 3.0) / 3.0;
	COLOR = vec4(wave_color.rgb, wave_color.a * alpha * intensity);
}
