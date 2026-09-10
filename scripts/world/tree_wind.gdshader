shader_type spatial;
render_mode cull_disabled, diffuse_burley;
// Gentle wind sway for the low-poly trees. Trunk stays put, canopy leans with a
// slow gust plus a faster flutter, amount scaled by height above the pivot.

uniform vec3 albedo : source_color = vec3(0.24, 0.34, 0.15);
uniform float roughness = 1.0;
uniform vec3 backlight : source_color = vec3(0.10, 0.16, 0.06);
uniform float sway = 0.06;
uniform float stiffness = 2.2;      // higher = only the top moves
uniform float wind_speed = 0.9;
uniform sampler2D noise_tex : hint_default_black;

void vertex() {
	vec3 wpos = (MODEL_MATRIX * vec4(0.0)).xyz;
	float t = TIME * wind_speed;
	float bend = pow(clamp(VERTEX.y / 4.0, 0.0, 1.0), stiffness);
	float gust = sin(t + wpos.x * 0.15 + wpos.z * 0.1);
	float flutter = 0.28 * sin(t * 3.3 + VERTEX.x * 2.0 + VERTEX.z * 2.0);
	VERTEX.x += (gust + flutter) * sway * bend;
	VERTEX.z += (cos(t * 0.8 + wpos.z * 0.12) + flutter) * sway * 0.7 * bend;
}

void fragment() {
	ALBEDO = albedo * COLOR.rgb;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	SPECULAR = 0.15;
	BACKLIGHT = backlight;
}
