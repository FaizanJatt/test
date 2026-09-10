shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, diffuse_burley, specular_disabled;
// Cross-quad billboard tree: alpha-cut photo texture, canopy wind sway, a
// rounded fake normal so it catches light like a volume, per-instance tint.

uniform sampler2D tex : source_color, filter_linear_mipmap, hint_default_white;
uniform float alpha_cut = 0.4;
uniform float sway = 0.09;
uniform float wind_speed = 0.8;
uniform vec3 tint_lo : source_color = vec3(0.66, 0.72, 0.58);
uniform vec3 tint_hi : source_color = vec3(0.94, 0.96, 0.86);
uniform float tree_height = 18.0;
uniform float base_darken = 0.72;   // ambient-occlusion feel toward the trunk

varying vec3 v_tint;
varying float v_ao;

void vertex() {
	// per-instance colour (MultiMesh instance colour) drives a subtle tint + a
	// deterministic wind phase offset
	v_tint = mix(tint_lo, tint_hi, COLOR.r);
	v_ao = mix(base_darken, 1.0, clamp(VERTEX.y / tree_height, 0.0, 1.0));
	vec3 wpos = MODEL_MATRIX[3].xyz;
	float t = TIME * wind_speed + wpos.x * 0.13 + wpos.z * 0.11 + COLOR.g * 6.2831;
	float bend = pow(clamp(VERTEX.y / tree_height, 0.0, 1.0), 2.0);
	VERTEX.x += (sin(t) + 0.3 * sin(t * 3.1)) * sway * bend;
	VERTEX.z += (cos(t * 0.8) + 0.3 * sin(t * 2.7)) * sway * 0.8 * bend;
	// rounded normal: blend the flat quad normal toward a sphere around the trunk
	vec3 rn = normalize(vec3(VERTEX.x, VERTEX.y * 0.4 + tree_height * 0.2, VERTEX.z));
	NORMAL = normalize(mix(NORMAL, rn, 0.7));
}

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < alpha_cut) {
		discard;
	}
	ALBEDO = c.rgb * v_tint * v_ao;
	ROUGHNESS = 1.0;
	SPECULAR = 0.05;
	// soft translucency through the canopy
	BACKLIGHT = c.rgb * 0.3;
}
