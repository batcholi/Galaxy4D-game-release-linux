const vec4[3] vertices = {
	vec4( 0.0, +0.5, 0, 1),
	vec4(+0.5, -0.5, 0, 1),
	vec4(-0.5, -0.5, 0, 1)
};

void main() {
	gl_Position = vertices[gl_VertexIndex];
}
