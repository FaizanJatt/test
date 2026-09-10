shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, diffuse_burley, specular_disabled;

uniform sampler2D blade_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform vec3 tip_color : source_color = vec3(0.55, 0.66, 0.28);
uniform vec3 root_color : source_color = vec3(0.16, 0.28, 0.12);
uniform float wind_strength = 0.12;
uniform float wind_speed = 1.6;
uniform float sway_height = 1.0;

varying float v_h;

void vertex() {
	v_h = clamp(VERTEX.y / max(sway_height, 0.001), 0.0, 1.0);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world.x * 0.35 + world.z * 0.35 + TIME * wind_speed;
	float gust = sin(phase) + 0.4 * sin(phase * 2.3);
	VERTEX.x += gust * wind_strength * v_h * v_h;
	VERTEX.z += cos(phase * 0.8) * wind_strength * 0.5 * v_h * v_h;
}

void fragment() {
	vec4 t = texture(blade_tex, UV);
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.35;
	ALBEDO = mix(root_color, tip_color, v_h) * (0.7 + 0.3 * t.r);
	ROUGHNESS = 0.9;
}
