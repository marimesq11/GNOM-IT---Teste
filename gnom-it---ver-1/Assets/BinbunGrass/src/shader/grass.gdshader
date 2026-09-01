shader_type spatial;
render_mode blend_mix, depth_prepass_alpha;

uniform bool billboard = false;

uniform sampler2D shape_texture;
uniform sampler2D shape_atlas;
uniform bool use_atlas = false;

group_uniforms Colors;
uniform sampler2D noise_texture;
uniform sampler2D color_gradient;
uniform float random_variation : hint_range(0.0, 1.0, 0.001) = 0.002;

group_uniforms Wind;
uniform sampler2D wind_texture;
uniform vec2 wind_velocity;

group_uniforms Transparency;
uniform float alpha_cut_start : hint_range(0.0, 1.0, 0.05) = 0.1;
uniform float alpha_cut_end : hint_range(0.0, 1.0, 0.05) = 0.9;
uniform int alpha_mode : hint_enum("Smooth", "Dithered", "Cut") = 0;


// =============================================
// MÁSCARA DO CORTADOR
// =============================================

// Essa textura vai receber a ImageTexture criada
// pelo nosso código GDScript.
//
// Branco = grama existe
// Preto  = grama foi cortada
uniform sampler2D mascara;


// Guarda a posição da grama no mundo.
// O shader original já usava essa variável.
varying vec3 world_pos;


// Guarda a posição correspondente dentro da máscara.
//
// A máscara trabalha com coordenadas de 0 até 1.
varying vec2 mascara_uv;


varying flat int id;


#include "util/dither.gdshaderinc"



vec2 atlas_uv(vec2 uv, int index, int size){
	int tile_count = size * size;
	int i = index % tile_count;
	float x = float(i % size);
	float y = float(i / size);
	vec2 tile_size = 1.0 / vec2(float(size));
	return uv * tile_size + (vec2(x, y) * tile_size);
}



float randomf(int index, int seed){
	float value = sin(float(index + seed)) * 0.5 + 0.5;
	return value;
}



float wind_noise(){
	float value = texture(
		wind_texture,
		(world_pos.xz * 0.03) -
		(vec2(TIME * 0.01) * wind_velocity)
	).r;

	return value;
}



vec3 wind(vec2 uv){
	float wind_noise = wind_noise();

	float wind_affect = pow(
		1.0 - uv.y,
		2.0
	);

	vec3 value = vec3(
		wind_noise * wind_velocity.x,
		0.0,
		wind_noise * wind_velocity.y
	) * 0.25;

	value *= wind_affect;

	return value;
}



void vertex() {

	// =============================================
	// POSIÇÃO DA GRAMA NO MUNDO
	// =============================================

	// Pega a posição deste vértice da grama
	// no mundo 3D.
	world_pos = (
		MODEL_MATRIX *
		vec4(VERTEX, 1.0)
	).xyz;


	// =============================================
	// CONVERTER MUNDO -> MÁSCARA
	// =============================================

	// Nosso terreno tem 20 unidades:
	//
	// -10 -------- 0 -------- +10
	//
	// Precisamos transformar isso em:
	//
	// 0 -------- 0.5 -------- 1
	//
	// porque texture() trabalha com valores
	// entre 0 e 1.

	mascara_uv.x = (
		world_pos.x + 10.0
	) / 20.0;

	mascara_uv.y = (
		world_pos.z + 10.0
	) / 20.0;


	// ID da instância da grama.
	id = INSTANCE_ID;


	// =============================================
	// CÓDIGO ORIGINAL DO BILLBOARD / VENTO
	// =============================================

	if(billboard){

		mat4 billboard_matrix = mat4(
			MAIN_CAM_INV_VIEW_MATRIX[0],
			MAIN_CAM_INV_VIEW_MATRIX[1],
			MAIN_CAM_INV_VIEW_MATRIX[2],
			MODEL_MATRIX[3]
		);

		MODELVIEW_MATRIX =
			VIEW_MATRIX *
			billboard_matrix;


		VERTEX += (
			VIEW_MATRIX *
			vec4(wind(UV), 0.0)
		).xyz;

	} else {

		VERTEX += wind(UV);
	}


	NORMAL = vec3(
		0.0,
		1.0,
		0.0
	);
}



void fragment() {

	// =============================================
	// LER A MÁSCARA
	// =============================================

	// Procura na máscara o valor correspondente
	// à posição dessa grama no terreno.
	//
	// Branco = 1
	// Preto  = 0
	float mask = texture(
		mascara,
		mascara_uv
	).r;


	// Se o cortador já passou aqui,
	// não desenha essa parte da grama.
	if(mask < 0.5){
		discard;
	}


	// =============================================
	// CÓDIGO ORIGINAL DA GRAMA
	// =============================================

	float shape_value =
		texture(
			shape_texture,
			UV
		).r;


	if(use_atlas){

		vec2 atlas_uv =
			atlas_uv(
				UV,
				id,
				2
			);

		shape_value =
			texture(
				shape_atlas,
				atlas_uv
			).r;
	}


	float noise_value =
		texture(
			noise_texture,
			world_pos.xz * 0.1
		).r;


	if(
		randomf(id, 1)
		<
		random_variation
	){
		noise_value += 0.4;
	}


	vec4 color =
		texture(
			color_gradient,
			vec2(
				noise_value,
				0.0
			)
		);


	ALBEDO = color.rgb;


	float alpha = shape_value;


	if(alpha_mode == 0){

		ALPHA = alpha;

	} else {

		alpha = clamp(
			(
				shape_value -
				alpha_cut_start
			)
			/
			(
				alpha_cut_end -
				alpha_cut_start
			),
			0.0,
			1.0
		);


		if(alpha_mode == 1){

			alpha = step(
				bayer4(
					FRAGCOORD.xy
				) + 0.01,
				alpha
			);
		}


		if(alpha < 0.1){
			discard;
		}
	}
}



void light(){

	float ndotl =
		dot(
			LIGHT,
			NORMAL
		)
		*
		ATTENUATION;


	DIFFUSE_LIGHT += ndotl;
}