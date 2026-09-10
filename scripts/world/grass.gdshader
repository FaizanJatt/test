shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled, shadows_disabled;

uniform vec3 tip_color : source_color = vec3(0.46, 0.60, 0.26);
uniform vec3 root_color : source_color = vec3(0.13, 0.24, 0.08);
uniform float wind_strength = 0.045;
uniform float wind_speed = 1.5;
uniform float sway_height = 0.2;

varying float v_h;
varying vec3 v_tint;

void vertex() {
	v_h = clamp(VERTEX.y / max(sway_height, 0.001), 0.0, 1.0);
	v_tint = COLOR.rgb;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world.x * 0.4 + world.z * 0.4 + TIME * wind_speed;
	float gust = sin(phase) + 0.35 * sin(phase * 2.7);
	VERTEX.x += gust * wind_strength * v_h * v_h;
	VERTEX.z += cos(phase * 0.7) * wind_strength * 0.4 * v_h * v_h;
}

void fragment() {
	vec3 col = mix(root_color, tip_color, v_h) * mix(vec3(1.0), v_tint, 0.6);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	// fake a little ambient occlusion at the base so the field reads as dense
	AO = mix(0.55, 1.0, v_h);
	AO_LIGHT_AFFECT = 1.0;
}
