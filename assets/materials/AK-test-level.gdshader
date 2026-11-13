shader_type spatial;

void vertex() {
    vec3 p = VERTEX;

    
    float wave = sin(
        TIME
        + p.x * 5.0
        + p.z * 4.0
        + p.y * 3.0
    );

    p += normalize(VERTEX)
         * wave
         * 0.04;

    VERTEX = p;}

void fragment() {
	// Called for every pixel the material is visible on.
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
