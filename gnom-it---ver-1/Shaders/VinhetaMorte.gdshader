
shader_type canvas_item;

uniform float raio = 1.4;
uniform float suavidade = 0.08;

void fragment() {
    vec2 centro = UV - vec2(0.5);

    // Mantém o círculo proporcional à tela
    centro.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;

    float distancia = length(centro);

    float escuro = smoothstep(
        raio - suavidade,
        raio + suavidade,
        distancia
    );

    COLOR = vec4(0.0, 0.0, 0.0, escuro);
}
