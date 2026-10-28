shader_type canvas_item;

uniform vec4 color_a : source_color = vec4(0.8, 0.2, 0.4, 1.0);
uniform vec4 color_b : source_color = vec4(0.9, 0.8, 0.2, 1.0);
uniform float stripes_per_tile : hint_range(0.25, 16.0) = 2.0;
uniform float speed = 0.5;
uniform float chevron : hint_range(0.0, 2.0) = 0.033;
uniform float stripe_ratio : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	float offset = abs(0.5 - UV.y) * chevron;
	float stripes = step(stripe_ratio, fract((UV.x + offset) * stripes_per_tile - TIME * speed));
	COLOR = mix(color_a, color_b, stripes);
}
