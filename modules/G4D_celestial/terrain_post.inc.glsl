#extension GL_EXT_buffer_reference2 : require

layout(local_size_x = COMPUTE_SIZE_X, local_size_y = COMPUTE_SIZE_Y) in;

vec3 GetVertex(in uint index) {
	return vec3(vertices[index*3].vertex, vertices[index*3+1].vertex, vertices[index*3+2].vertex);
}

uint32_t computeSize = gl_NumWorkGroups.x*gl_WorkGroupSize.x;
uint32_t vertexSubdivisionsPerChunk = computeSize - 1;
uint32_t genCol = gl_GlobalInvocationID.x;
uint32_t genRow = gl_GlobalInvocationID.y;
uint32_t currentIndex = computeSize * genRow + genCol;
uint32_t Xindex = currentIndex*3;
uint32_t Yindex = currentIndex*3+1;
uint32_t Zindex = currentIndex*3+2;

vec3 ComputeNormal() {
	vec3 currentVertex = GetVertex(currentIndex);
	dvec3 posNormRight = normalize((chunk.transform * dvec4(currentVertex + vec3(chunk.triangleSize,0,0), 1)).xyz);
	dvec3 posNormBottom = normalize((chunk.transform * dvec4(currentVertex + vec3(0,0,chunk.triangleSize), 1)).xyz);
	vec3 right = vec3((chunk.inverseTransform * dvec4(posNormRight * GetHeightMap(posNormRight), 1)).xyz);
	vec3 bottom = vec3((chunk.inverseTransform * dvec4(posNormBottom * GetHeightMap(posNormBottom), 1)).xyz);
	return cross(normalize(right - currentVertex), normalize(currentVertex - bottom));
}

void main() {
	// Vertex
	dvec3 posNorm = normalize((chunk.transform * dvec4(GetVertex(currentIndex), 1)).xyz);
	double height = GetHeightMap(posNorm);
	dvec3 finalPos = (chunk.inverseTransform * dvec4(posNorm * height, 1)).xyz;
	vertices[Xindex].vertex = float(finalPos.x);
	vertices[Yindex].vertex = float(finalPos.y);
	vertices[Zindex].vertex = float(finalPos.z);
	colors[currentIndex].color = u8vec4(vec4(GetColor(posNorm, height), 1) * 255.0f);
	// Normal
	vec3 normal = ComputeNormal();
	normals[Xindex].normal = normal.x;
	normals[Yindex].normal = normal.y;
	normals[Zindex].normal = normal.z;
	// Skirt
	int32_t skirtIndex = -1;
	if (genCol == 0) {
		skirtIndex = int(genRow);
	} else if (genCol == vertexSubdivisionsPerChunk) {
		skirtIndex = int(vertexSubdivisionsPerChunk*4 - vertexSubdivisionsPerChunk - genRow);
	} else if (genRow == 0) {
		skirtIndex = int(vertexSubdivisionsPerChunk*4 - genCol);
	} else if (genRow == vertexSubdivisionsPerChunk) {
		skirtIndex = int(vertexSubdivisionsPerChunk + genCol);
	}
	if (skirtIndex != -1) {
		vertices[(computeSize*computeSize + skirtIndex) * 3 + 1].vertex = vertices[Yindex].vertex - chunk.skirtOffset;
		// normals[(computeSize*computeSize + skirtIndex) * 3 + 0].normal = 0.0f;
		// normals[(computeSize*computeSize + skirtIndex) * 3 + 1].normal = 1.0f;
		// normals[(computeSize*computeSize + skirtIndex) * 3 + 2].normal = 0.0f;
	}
}
