shader_type spatial;
render_mode cull_disabled;


// ==================================================
// CORES DA GRAMA ALTA
// ==================================================

uniform vec3 bottom_color : source_color = vec3(
	0.05,
	0.25,
	0.03
);

uniform vec3 top_color : source_color = vec3(
	0.30,
	0.80,
	0.15
);


// ==================================================
// VARIAÇÕES DA GRAMA ALTA
// ==================================================

uniform vec3 color_variation_1 : source_color = vec3(
	0.10,
	0.50,
	0.05
);

uniform sampler2D noise_variation_1;
uniform float Noise1Scale = 20.0;


uniform vec3 color_variation_2 : source_color = vec3(
	0.40,
	0.70,
	0.10
);

uniform sampler2D noise_variation_2;
uniform float Noise2Scale = 20.0;


// ==================================================
// APARÊNCIA DA GRAMA CORTADA
// ==================================================

uniform vec3 cut_bottom_color : source_color = vec3(
	0.12,
	0.22,
	0.03
);

uniform vec3 cut_top_color : source_color = vec3(
	0.45,
	0.60,
	0.08
);

uniform vec3 cut_variation_color : source_color = vec3(
	0.25,
	0.35,
	0.04
);

// Noise exclusivo da grama cortada.
uniform sampler2D cut_noise;

// Tamanho do padrão do noise.
uniform float cut_noise_scale = 8.0;

// Intensidade da variação de cor.
uniform float cut_noise_strength : hint_range(
	0.0,
	1.0
) = 0.45;


// ==================================================
// VENTO
// ==================================================

uniform float windSpeed = 0.005;
uniform float windDis = 0.2;
uniform float noiseStrength = 0.5;
uniform float displaceStrength = 3.0;

uniform sampler2D wind_noise;

uniform float windNoiseScale = 20.0;

uniform vec2 windNoisePanSpeed = vec2(
	0.03,
	0.03
);

uniform float noiseFloor = 0.3;
uniform float wind_noise_scale_strength = 0.2;


// ==================================================
// SOMBRA DO VENTO
// ==================================================

uniform vec3 wind_shadow_color : source_color = vec3(
	0.0,
	0.2,
	0.0
);

uniform float wind_shadow_strength = 0.4;

uniform float wind_shadow_displacement_threshold = 0.15;
uniform float wind_shadow_smoothing = 0.3;


// ==================================================
// VARIAÇÃO DA ALTURA
// ==================================================

uniform float combined_noise_min_scale = 0.5;
uniform float combined_noise_max_scale = 1.5;

uniform bool invert_combined_noise = false;


// ==================================================
// MÁSCARA DO CORTE
// ==================================================

// Branco significa grama alta.
// Preto significa grama cortada.
uniform sampler2D mascara : filter_nearest, repeat_disable;

// Seu terreno possui 20 × 20.
uniform float tamanho_terreno = 20.0;

// Centro do terreno nos eixos X e Z.
// Deixe em (0, 0) se o terreno ocupar
// de -10 até +10.
uniform vec2 centro_terreno = vec2(
	0.0,
	0.0
);

// Altura final da grama cortada.
// 0.05 significa 5% da altura original.
uniform float altura_cortada : hint_range(
	0.0,
	1.0
) = 0.05;


// ==================================================
// OPÇÕES DE DEBUG
// ==================================================

uniform bool debug_show_wind_noise = false;
uniform bool debug_show_combined_noise = false;
uniform bool debug_show_cut_mask = false;


// ==================================================
// INFORMAÇÕES ENVIADAS AO FRAGMENT
// ==================================================

varying vec3 worldPos;

varying float wind_displacement_strength;
varying float combinedNoiseDebug;
varying float cutMaskDebug;


// ==================================================
// VERTEX
// ==================================================

void vertex() {

	// Posição original do vértice no mundo.
	worldPos = (
		MODEL_MATRIX
		* vec4(VERTEX, 1.0)
	).xyz;


	// Posição da origem desta instância.
	vec3 instance_world_origin = (
		MODEL_MATRIX
		* vec4(
			0.0,
			0.0,
			0.0,
			1.0
		)
	).xyz;


	// ==================================================
	// RUÍDOS DE VARIAÇÃO
	// ==================================================

	vec2 uv1 = (
		worldPos.xz
		/ Noise1Scale
	);

	vec2 uv2 = (
		worldPos.xz
		/ Noise2Scale
	);


	float noise1 = texture(
		noise_variation_1,
		uv1
	).r;


	float noise2 = texture(
		noise_variation_2,
		uv2
	).r;


	float combinedNoise = clamp(
		(0.5 + noise1) * noise2,
		0.0,
		1.0
	);


	if (invert_combined_noise) {
		combinedNoise = (
			1.0
			- combinedNoise
		);
	}


	combinedNoiseDebug = combinedNoise;


	// ==================================================
	// RUÍDO DO VENTO
	// ==================================================

	vec2 windNoiseUV = (
		instance_world_origin.xz
		/ windNoiseScale
		+ windNoisePanSpeed * TIME
	);


	float windNoiseVal = texture(
		wind_noise,
		windNoiseUV
	).r;


	float windVerticalOffset = mix(
		-wind_noise_scale_strength,
		wind_noise_scale_strength,
		windNoiseVal
	);


	// ==================================================
	// ALTURA ORIGINAL DA GRAMA
	// ==================================================

	float verticalScaleNoise = mix(
		combined_noise_min_scale,
		combined_noise_max_scale,
		1.0 - combinedNoise
	);


	float finalVerticalScale = (
		verticalScaleNoise
		+ windVerticalOffset
	);


	// ==================================================
	// LEITURA DA MÁSCARA DO CORTADOR
	// ==================================================

	// Converte a posição mundial para uma
	// coordenada entre 0 e 1.
	vec2 mask_uv = (
		worldPos.xz
		- centro_terreno
		+ vec2(tamanho_terreno * 0.5)
	) / tamanho_terreno;


	// Impede a leitura fora da textura.
	mask_uv = clamp(
		mask_uv,
		vec2(0.0),
		vec2(1.0)
	);


	// Branco retorna 1.
	// Preto retorna 0.
	float mask_value = texture(
		mascara,
		mask_uv
	).r;


	// Envia o valor da máscara para o fragment.
	cutMaskDebug = mask_value;


	// Máscara preta:
	// usa altura_cortada.
	//
	// Máscara branca:
	// usa altura normal.
	float corte_scale = mix(
		altura_cortada,
		1.0,
		mask_value
	);


	// Aplica o corte permanente.
	finalVerticalScale *= corte_scale;


	// Aplica a altura final.
	VERTEX.y *= finalVerticalScale;


	// ==================================================
	// BALANÇO DO VENTO
	// ==================================================

	float shapedNoise = 0.0;


	float noiseVal = texture(
		wind_noise,
		windNoiseUV
	).r;


	float bias = (
		noiseVal
		- 0.5
	);


	if (bias < 0.0) {

		shapedNoise = mix(
			0.0,
			noiseFloor - 0.5,
			-bias * 2.0
		);

	} else {

		shapedNoise = (
			bias
			* bias
			* 2.0
		);
	}


	float instanceWindSpeed = max(
		0.0,
		windSpeed
		* (
			1.0
			- shapedNoise * noiseStrength
		)
	);


	// Grama cortada recebe menos vento.
	float windResponse = corte_scale;


	float instanceWindDis = (
		windDis
		* (
			1.0
			+ shapedNoise * displaceStrength
		)
		* windResponse
	);


	wind_displacement_strength = instanceWindDis;


	float sineValue = sin(
		TIME
		* instanceWindSpeed
	);


	float heightFactor = clamp(
		UV.y,
		0.0,
		1.0
	);


	vec2 windDir = normalize(
		windNoisePanSpeed
	);


	if (
		length(windNoisePanSpeed)
		< 0.001
	) {
		windDir = vec2(
			1.0,
			0.0
		);
	}


	vec2 sway = (
		windDir
		* sineValue
		* instanceWindDis
		* (1.0 - heightFactor)
	);


	VERTEX.x += sway.x;
	VERTEX.z += sway.y;
}


// ==================================================
// FRAGMENT
// ==================================================

void fragment() {

	float heightFactor = clamp(
		UV.y,
		0.0,
		1.0
	);


	// ==================================================
	// MODOS DE DEBUG
	// ==================================================

	if (debug_show_cut_mask) {

		// Branco = grama alta.
		// Preto = grama cortada.
		ALBEDO = vec3(
			cutMaskDebug
		);

	} else if (debug_show_combined_noise) {

		ALBEDO = vec3(
			combinedNoiseDebug
		);

	} else if (debug_show_wind_noise) {

		vec2 noiseUV = (
			worldPos.xz
			/ windNoiseScale
			+ windNoisePanSpeed * TIME
		);


		float debugNoiseValue = texture(
			wind_noise,
			noiseUV
		).r;


		ALBEDO = vec3(
			debugNoiseValue
		);

	} else {

		// ==================================================
		// COR DA GRAMA ALTA
		// ==================================================

		vec3 baseGradient = mix(
			top_color,
			bottom_color,
			heightFactor
		);


		vec3 altGradient1 = mix(
			color_variation_1,
			bottom_color,
			heightFactor
		);


		float blendVal1 = texture(
			noise_variation_1,
			worldPos.xz / Noise1Scale
		).r;


		vec3 firstBlend = mix(
			baseGradient,
			altGradient1,
			blendVal1
		);


		vec3 altGradient2 = mix(
			color_variation_2,
			bottom_color,
			heightFactor
		);


		float blendVal2 = texture(
			noise_variation_2,
			worldPos.xz / Noise2Scale
		).r;


		vec3 finalBlend = mix(
			firstBlend,
			altGradient2,
			blendVal2
		);


		// Variação leve da luminosidade.
		float noiseFactor = texture(
			wind_noise,
			worldPos.xz / windNoiseScale
		).r;


		finalBlend *= mix(
			0.9,
			1.1,
			noiseFactor
		);


		// ==================================================
		// SOMBRA DO VENTO
		// ==================================================

		float displace_fade = smoothstep(
			wind_shadow_displacement_threshold,
			wind_shadow_displacement_threshold
				+ wind_shadow_smoothing,
			wind_displacement_strength
		);


		float total_overlay_strength = clamp(
			displace_fade
			* wind_shadow_strength,
			0.0,
			1.0
		);


		vec3 tint = mix(
			vec3(1.0),
			wind_shadow_color,
			total_overlay_strength
		);


		finalBlend = mix(
			finalBlend,
			finalBlend * tint,
			total_overlay_strength
		);


		// ==================================================
		// COR E NOISE DA GRAMA CORTADA
		// ==================================================

		// Gradiente exclusivo da grama cortada.
		vec3 cutGradient = mix(
			cut_top_color,
			cut_bottom_color,
			heightFactor
		);


		// Noise exclusivo da grama cortada.
		float cutNoiseValue = texture(
			cut_noise,
			worldPos.xz / cut_noise_scale
		).r;


		// Controla a intensidade do noise.
		float cutNoiseBlend = (
			cutNoiseValue
			* cut_noise_strength
		);


		// Mistura o gradiente com a
		// cor de variação.
		vec3 cutFinalColor = mix(
			cutGradient,
			cut_variation_color,
			cutNoiseBlend
		);


		// Máscara preta:
		// usa a cor da grama cortada.
		//
		// Máscara branca:
		// usa a cor da grama alta.
		finalBlend = mix(
			cutFinalColor,
			finalBlend,
			cutMaskDebug
		);


		ALBEDO = finalBlend;
	}


	// Corrige a iluminação no verso da grama.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}