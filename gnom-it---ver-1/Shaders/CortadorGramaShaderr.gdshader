shader_type spatial;


// ==================================================
// TREMOR
// ==================================================

// 0 = parado.
// 1 = tremor completo.
uniform float progress : hint_range(
	0.0,
	1.0
) = 1.0;


// Quantidade de tremores por segundo.
uniform float frequency : hint_range(
	0.0,
	60.0,
	0.1
) = 12.0;


// Distância do tremor em cada eixo.
uniform vec3 max_offset = vec3(
	0.015,
	0.01,
	0.015
);


// ==================================================
// APARÊNCIA DO CORTADOR
// ==================================================

// Coloque aqui a textura original do cortador.
uniform sampler2D albedo_texture : source_color;

// Permite ajustar a cor sem perder a textura.
// Deixe branco para manter a cor original.
uniform vec4 albedo_color : source_color = vec4(
	1.0,
	1.0,
	1.0,
	1.0
);


// Aspereza do material.
uniform float roughness_value : hint_range(
	0.0,
	1.0
) = 0.7;


// Aparência metálica.
uniform float metallic_value : hint_range(
	0.0,
	1.0
) = 0.0;


// ==================================================
// FUNÇÕES DO TREMOR
// ==================================================

float hash(float x) {
	
	return fract(
		sin(x * 127.1)
		* 43758.5453123
	);
}


float smooth_noise(float t) {
	
	float i = floor(t);
	float f = fract(t);

	// Suaviza a mudança entre os valores.
	f = (
		f
		* f
		* (3.0 - 2.0 * f)
	);

	return mix(
		hash(i),
		hash(i + 1.0),
		f
	);
}


vec3 shake3(float t) {
	
	return vec3(
		smooth_noise(t),
		smooth_noise(t + 37.0),
		smooth_noise(t + 91.0)
	) * 2.0 - 1.0;
}


// ==================================================
// MOVIMENTO DOS VÉRTICES
// ==================================================

void vertex() {
	
	VERTEX += (
		progress
		* shake3(TIME * frequency)
		* max_offset
	);
}


// ==================================================
// TEXTURA
// ==================================================

void fragment() {
	
	vec4 textura = texture(
		albedo_texture,
		UV
	);

	ALBEDO = (
		textura.rgb
		* albedo_color.rgb
	);

	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
}