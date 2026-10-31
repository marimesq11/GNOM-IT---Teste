
shader_type spatial;

// TEXTURAS
uniform sampler2D textura_grama : source_color;
uniform sampler2D textura_baixo : source_color;
uniform sampler2D mascara : filter_nearest, repeat_disable;

// CONFIGURAÇÕES DO TERRENO
uniform vec2 tamanho_terreno = vec2(23.0, 23.0);
uniform vec2 centro_terreno = vec2(0.0, 0.0);

// POSIÇÃO NO MUNDO
varying vec3 posicao_mundo;


// ==========================================
// VERTEX
// ==========================================

void vertex() {
    // Obtém a posição real do vértice no mundo 3D
    posicao_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


// ==========================================
// FRAGMENT
// ==========================================

void fragment() {

    // Lê as texturas originais
    vec3 grama = texture(textura_grama, UV).rgb;
    vec3 baixo = texture(textura_baixo, UV).rgb;

    // Converte a posição mundial para a máscara
    vec2 mask_uv = (
        posicao_mundo.xz
        - centro_terreno
        + tamanho_terreno * 0.5
    ) / tamanho_terreno;

    // Lê a máscara
    float mask = texture(mascara, mask_uv).r;

    // Branco = grama
    // Preto = chão cortado
    ALBEDO = mix(baixo, grama, mask);
}
