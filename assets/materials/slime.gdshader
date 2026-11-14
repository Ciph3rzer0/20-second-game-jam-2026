shader_type spatial;

uniform vec4 slime_color : source_color =
    vec4(0.15, 0.85, 0.35, 1.0);

//uniform float frequency = 0.1;
uniform float squish = 0.0;
uniform float motion = 0.5;
uniform float magnitude = .03;
uniform vec2 lean = vec2(0.0);
uniform float lean_base_y = 0.0;
uniform float lean_height = 1.0;

void vertex() {
    vec3 p = VERTEX;

    // Compress vertically when squishing.
    float sy = clamp(1.0 - squish, 0.6, 1.5);

    // Expand horizontally to approximately preserve volume.
    float sx = inversesqrt(sy);

    p.x *= sx;
    p.z *= sx;
	
    // Keep the bottom of the sphere anchored.
    //p.y = -1.0 + (p.y + 1.0) * sy;

    // Continuous surface wobble.
    float wave = sin(
        TIME * 5.0
        + p.x * 5.0
        + p.z * 6.0
        + p.y * 5.0
    );

    // Reduce deformation near the bottom.
    float mask = smoothstep(-0.2, 0.3, p.y);
	
	// compress height
	//p.y *= 1. - clamp(squish, 0.5, 1.0);
	


    p += normalize(VERTEX)
        * mask
		* wave
        * motion
        * magnitude;

    // Anchor the lean at the base and bend more strongly toward the top.
    float height_fraction = clamp(
        (VERTEX.y - lean_base_y) / max(lean_height, 0.001),
        0.0,
        1.0
    );
    p.xz += lean * height_fraction * height_fraction;

    // Adjust the surface normal for the horizontal stretch and lean.
    vec3 bent_normal = NORMAL;
    bent_normal.xz /= sx;
    vec2 lean_slope = lean * 2.0 * height_fraction / max(lean_height, 0.001);
    bent_normal.y -= dot(bent_normal.xz, lean_slope);
    NORMAL = normalize(bent_normal);

    VERTEX = p;
}

void fragment() {
    ALBEDO = slime_color.rgb;
    ROUGHNESS = 0.05;
    SPECULAR = 0.4;
    METALLIC = 0.0;
	ALPHA = 0.8;
}