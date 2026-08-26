// Esse shader é usado em um objeto 3D
shader_type spatial;

//Uniform é uma variavel q eu posso preencher no inspector
//Sampler2D recebe um textura 2D
uniform sampler2D textura_grama;
uniform sampler2D textura_baixo;
uniform sampler2D mascara;


void fragment() {
//Vá na imagem textura_grama e veja qual é a cor nesse ponto.
//Uv sao as coordenadas dentro da textura(Como plano cartesiano)
//Vec4 Valor RGBA
	vec4 grama = texture(textura_grama, UV);
	vec4 baixo = texture(textura_baixo, UV);
//Aq a mascara é preto/branco ent a gente isola so
// o valor do RGBA q meche nisso
	float mask = texture(mascara, UV).r;

//Mix == mix(A, B, quantidade)
// quantidade = 0 -> resultado = A
// quantidade = 1 -> resultado = B
// Portanto:
// mask = 0 (preto)  -> mostra baixo
// mask = 1 (branco) -> mostra grama
	ALBEDO = mix(baixo.rgb, grama.rgb, mask);
}