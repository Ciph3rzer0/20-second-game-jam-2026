shader_type spatial;

uniform vec4 slime_color : source_color =
    vec4(0.15, 0.85, 0.35, 1.0);

//uniform float frequency = 0.1;
uniform float squish = 0.0;
uniform float motion = 0.5;
uniform float magnitude = .1;

void vertex() {
    vec3 p = VERTEX;

    // Compress vertically when squishing.
    // float clamp(1.0 - squish, 0.6, 1.5);

    // Expand horizontally to approximately preserve volume.
    //float sx = inversesqrt(sy);
//
    //p.x *= sx;
    //p.z *= sx;

     //Keep the bottom of the sphere anchored.
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

    VERTEX = p;
}

void fragment() {
    ALBEDO = slime_color.rgb;
    ROUGHNESS = 0.05;
    SPECULAR = 0.4;
    METALLIC = 0.0;
	ALPHA = 0.8;
}