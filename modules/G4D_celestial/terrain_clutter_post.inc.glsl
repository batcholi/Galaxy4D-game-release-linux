#extension GL_EXT_buffer_reference2 : require

layout(local_size_x = CLUTTER_COMPUTE_SIZE_X) in;

void main() {
	uint index = gl_GlobalInvocationID.x;
	uint clutterSeed = InitRandomSeed(uint(clutterData), index);
	if (RandomFloat(clutterSeed) > 0.01) return;

	double barycentricVertical = double(RandomFloat(clutterSeed));
	double barycentricHorizontal = double(RandomFloat(clutterSeed));
	
	// Size
	vec3 rockSize = vec3(float(clamp(chunk.triangleSize, 0.05, 0.2))) * (0.5f + RandomFloat(clutterSeed) * 0.5) * vec3(
		RandomFloat(clutterSeed),
		RandomFloat(clutterSeed),
		RandomFloat(clutterSeed)
	);
	float minDim = max(0.025f, length(rockSize) * 0.25f);
	if (rockSize.x < minDim) rockSize.x += minDim;
	if (rockSize.y < minDim) rockSize.y += minDim;
	if (rockSize.z < minDim) rockSize.z += minDim;
	if (rockSize.y > rockSize.x) {
		float tmp = rockSize.y;
		rockSize.y = rockSize.x;
		rockSize.x = tmp;
	}
	if (rockSize.y > rockSize.z) {
		float tmp = rockSize.y;
		rockSize.y = rockSize.z;
		rockSize.z = tmp;
	}
	
	// Position
	dvec3 pos = normalize(topLeftPos + (topRightPos - topLeftPos) * barycentricHorizontal + (bottomLeftPos - topLeftPos) * barycentricVertical);
	double altitude = GetHeightMap(pos) + double(rockSize.y)*0.4;
	dvec3 posOnPlanet = pos * altitude;
	vec3 rockPos = vec4(chunk.inverseTransform * dvec4(posOnPlanet, 1)).xyz;
	
	AabbData rock = aabbData[index];
	rock.aabb[0] = rockPos.x - rockSize.x;
	rock.aabb[1] = rockPos.y - rockSize.y;
	rock.aabb[2] = rockPos.z - rockSize.z;
	rock.aabb[3] = rockPos.x + rockSize.x;
	rock.aabb[4] = rockPos.y + rockSize.y;
	rock.aabb[5] = rockPos.z + rockSize.z;
	rock.data = uint64_t(clutterSeed);
}
