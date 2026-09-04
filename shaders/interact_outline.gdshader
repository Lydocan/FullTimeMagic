shader_type canvas_item;
// 交互高亮描边：active=1 时沿精灵不透明边缘描一圈金色光边，并微微提亮本体。
// 呼吸节奏由 TIME 驱动，脚本只切换 active（0/1，可用透明度渐变过渡）。

uniform float active : hint_range(0.0, 1.0) = 0.0;
uniform vec4 outline_color : source_color = vec4(1.0, 0.83, 0.4, 1.0);
uniform float thickness : hint_range(0.0, 4.0) = 1.2;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 ps = TEXTURE_PIXEL_SIZE * thickness;
	float na = 0.0;
	na = max(na, texture(TEXTURE, UV + vec2(ps.x, 0.0)).a);
	na = max(na, texture(TEXTURE, UV - vec2(ps.x, 0.0)).a);
	na = max(na, texture(TEXTURE, UV + vec2(0.0, ps.y)).a);
	na = max(na, texture(TEXTURE, UV - vec2(0.0, ps.y)).a);
	na = max(na, texture(TEXTURE, UV + ps).a);
	na = max(na, texture(TEXTURE, UV - ps).a);
	na = max(na, texture(TEXTURE, UV + vec2(ps.x, -ps.y)).a);
	na = max(na, texture(TEXTURE, UV + vec2(-ps.x, ps.y)).a);
	float pulse = active * (0.72 + 0.28 * sin(TIME * 5.0));
	vec4 base = tex * COLOR;
	// 边缘：本体透明而邻域不透明的像素描金；本体内部轻微提亮
	float edge = na * (1.0 - tex.a) * pulse;
	vec3 lit = base.rgb + outline_color.rgb * 0.22 * pulse * tex.a;
	COLOR = vec4(mix(lit, outline_color.rgb, clamp(edge * 1.6, 0.0, 1.0)),
			max(base.a, clamp(edge, 0.0, 1.0) * outline_color.a));
}
