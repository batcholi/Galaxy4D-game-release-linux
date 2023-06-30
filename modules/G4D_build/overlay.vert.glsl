#include "overlay.inc.glsl"

layout(location = 0) out vec4 out_position;
layout(location = 1) out vec4 out_color;
layout(location = 2) out vec3 out_localPos;

void main() {
	uint index = indexBuffer.indices[gl_VertexIndex];
	vec4 vertex = vec4(
		vertexBuffer.vertices[index * 3 + 0],
		vertexBuffer.vertices[index * 3 + 1],
		vertexBuffer.vertices[index * 3 + 2],
		1
	);
	
	out_localPos = vertex.xyz;
	gl_Position = out_position = xenonRendererData.config.projectionMatrix * modelViewMatrix * vertex;
	
	out_color = color;
	
	if (uint64_t(normalBuffer) == 0) {
		// // Triangles: compute face normals (flat shading) from vertex positions
		// uint triangleIndex = gl_VertexIndex - (gl_VertexIndex % 3);
		// uint index0 = indexBuffer.indices[triangleIndex + 0];
		// uint index1 = indexBuffer.indices[triangleIndex + 1];
		// uint index2 = indexBuffer.indices[triangleIndex + 2];
		// vec3 v0 = vec3(vertexBuffer.vertices[index0*3], vertexBuffer.vertices[index0*3+1], vertexBuffer.vertices[index0*3+2]);
		// vec3 v1 = vec3(vertexBuffer.vertices[index1*3], vertexBuffer.vertices[index1*3+1], vertexBuffer.vertices[index1*3+2]);
		// vec3 v2 = vec3(vertexBuffer.vertices[index2*3], vertexBuffer.vertices[index2*3+1], vertexBuffer.vertices[index2*3+2]);
		// vec3 normal = normalize(cross(v1 - v0, v2 - v0));
	} else {
		// Wireframe: read edge normals from buffer
		uint edgeIndex = gl_VertexIndex / 2;
		vec3 normal = vec3(
			normalBuffer.normals[edgeIndex * 3 + 0],
			normalBuffer.normals[edgeIndex * 3 + 1],
			normalBuffer.normals[edgeIndex * 3 + 2]
		);
		normal = normalize(((mat3(modelViewMatrix))) * normal);
		out_color *= clamp(1.0 + dot(normal, vec3(0,0,1)), 0.25, 1);
	}
}
