#include "ShaderConstants.fxh"

struct VS_Input {
	float3 position : POSITION;
#ifdef USE_SKINNING
	uint boneId : BONEID_0;
#endif
	float4 normal : NORMAL;
	float2 texCoords : TEXCOORD_0;
#ifdef COLOR_BASED
	float4 color : COLOR;
#endif
#ifdef INSTANCEDSTEREO
	uint instanceID : SV_InstanceID;
#endif
};


struct PS_Input {
	float4 position : SV_Position;

	float4 light : LIGHT;
	float4 fogColor : FOG_COLOR;

	bool lonel_slime : lonel_slime;

#ifdef GLINT
	// there is some alignment issue on the Windows Phone 1320 that causes the position
	// to get corrupted if this is two floats and last in the struct memory wise
	float4 layerUV : GLINT_UVS;
#endif

#ifdef COLOR_BASED
	float4 color : COLOR;
#endif

#ifdef USE_OVERLAY
	float4 overlayColor : OVERLAY_COLOR;
#endif

#ifdef TINTED_ALPHA_TEST
	// With MSAA Enabled, making this field a float results in a DX11 internal compiler error
	// We assume it is trying to pack the single float with the centroid-interpolated UV coordinates, which it can't do
	float4 alphaTestMultiplier : ALPHA_MULTIPLIER;
#endif

	float2 uv : TEXCOORD_0_FB_MSAA;


#ifdef GEOMETRY_INSTANCEDSTEREO
	uint instanceID : SV_InstanceID;
#endif
#ifdef VERTEXSHADER_INSTANCEDSTEREO
	uint renTarget_id : SV_RenderTargetArrayIndex;
#endif
};

static const float AMBIENT = 0.45;

static const float XFAC = -0.1;
static const float ZFAC = 0.1;


float4 TransformRGBA8_SNORM(const float4 RGBA8_SNORM) {
#ifdef R8G8B8A8_SNORM_UNSUPPORTED
	return RGBA8_SNORM * float(2.0).xxxx - float(1.0).xxxx;
#else
	return RGBA8_SNORM;
#endif
}


float lightIntensity(const float4x4 worldMat, const float4 position, const float3 normal) {
#ifdef FANCY
	float3 N = normalize(mul(worldMat, normal)).xyz;

	N.y *= TILE_LIGHT_COLOR.a;

	//take care of double sided polygons on materials without culling
#ifdef FLIP_BACKFACES
	float3 viewDir = normalize((mul(worldMat, position)).xyz);
	if (dot(N, viewDir) > 0.0) {
		N *= -1.0;
	}
#endif

	float yLight = (1.0 + N.y) * 0.5;
	return yLight * (1.0 - AMBIENT) + N.x*N.x * XFAC + N.z*N.z * ZFAC + AMBIENT;
#else
	return 1.0;
#endif
}

#ifdef GLINT
float2 calculateLayerUV(float2 origUV, float offset, float rotation) {
	float2 uv = origUV;
	uv -= 0.5;
	float rsin = sin(rotation);
	float rcos = cos(rotation);
	uv = mul(uv, float2x2(rcos, -rsin, rsin, rcos));
	uv.x += offset;
	uv += 0.5;

	return uv * GLINT_UV_SCALE;
}
#endif

#ifdef LONEL_SLIME_CHUNK
bool slime_chunk(uint x , uint z)
{
uint s = (x*0x1f1f1f1f)^z;
uint m =0x6c078965 * (s ^ s >> 30) +1;
s = s & 0x80000000 | m & 0x7fffffff;
for (int i = 2; i < 398; i++)
 m=0x6c078965*(m ^ m >> 30)+i;
m ^= (s >> 1) ^ ((-((uint)(s & 1))) & 0x9908b0df);
m ^=m>>11;
m ^=m<<07 & 0x9d2c5680;
m ^=m<<15 & 0xefc60000;
m ^=m>>18;
return ((m%10));
}
#endif

ROOT_SIGNATURE
void main(in VS_Input VSInput, out PS_Input PSInput) {
	float4 entitySpacePosition = float4(VSInput.position, 1);
	float3 entitySpaceNormal = TransformRGBA8_SNORM(VSInput.normal);
#ifdef USE_SKINNING
	entitySpacePosition = mul(BONES[VSInput.boneId], entitySpacePosition);
	entitySpaceNormal = mul(BONES[VSInput.boneId], entitySpaceNormal);
#endif

#ifdef INSTANCEDSTEREO
	int i = VSInput.instanceID;
	PSInput.position = mul(WORLDVIEWPROJ_STEREO[i], entitySpacePosition);
#else
	PSInput.position = mul(WORLDVIEWPROJ, entitySpacePosition);
#endif



#ifdef GEOMETRY_INSTANCEDSTEREO
	PSInput.instanceID = VSInput.instanceID;
#endif 

#ifdef VERTEXSHADER_INSTANCEDSTEREO
	PSInput.renTarget_id = VSInput.instanceID;
#endif

#ifdef INSTANCEDSTEREO
	float L = lightIntensity(WORLD_STEREO, entitySpacePosition, entitySpaceNormal);
#else
	float L = lightIntensity(WORLD, entitySpacePosition, entitySpaceNormal);
#endif

#ifdef USE_OVERLAY
	L += OVERLAY_COLOR.a * 0.35;
#endif

#ifdef TINTED_ALPHA_TEST
	PSInput.alphaTestMultiplier = OVERLAY_COLOR.aaaa;
#endif

	PSInput.light = float4(L.xxx * TILE_LIGHT_COLOR.rgb, 1.0);

#ifdef COLOR_BASED
	PSInput.color = VSInput.color;
#endif

#ifdef USE_OVERLAY
	PSInput.overlayColor = OVERLAY_COLOR;
#endif

#if( !defined(NO_TEXTURE) || !defined(COLOR_BASED) || defined(USE_COLOR_BLEND) )
	PSInput.uv = VSInput.texCoords;
#endif

#ifdef USE_UV_ANIM
	PSInput.uv.xy = UV_ANIM.xy + (PSInput.uv.xy * UV_ANIM.zw);
#endif


#ifdef LONEL_SLIME_CHUNK
int lonel_slime_chunk_x = int(UV_ANIM.x);
int lonel_slime_chunk_y = int(UV_ANIM.y);

#ifdef LONEL_SLIME_CHUNK_Z1_X
lonel_slime_chunk_x+=1;
#endif
#ifdef LONEL_SLIME_CHUNK_Z2_X
lonel_slime_chunk_x+=2;
#endif
#ifdef LONEL_SLIME_CHUNK_F1_X
lonel_slime_chunk_x-=1;
#endif
#ifdef LONEL_SLIME_CHUNK_F2_X
lonel_slime_chunk_x-=2;
#endif

#ifdef LONEL_SLIME_CHUNK_Z1_Y
lonel_slime_chunk_y+=1;
#endif
#ifdef LONEL_SLIME_CHUNK_Z2_Y
lonel_slime_chunk_y+=2;
#endif
#ifdef LONEL_SLIME_CHUNK_F1_Y
lonel_slime_chunk_y-=1;
#endif
#ifdef LONEL_SLIME_CHUNK_F2_Y
lonel_slime_chunk_y-=2;
#endif

PSInput.lonel_slime = slime_chunk(lonel_slime_chunk_x,lonel_slime_chunk_y);
#endif



#ifdef GLINT
	PSInput.layerUV.xy = calculateLayerUV(VSInput.texCoords, UV_OFFSET.x, UV_ROTATION.x);
	PSInput.layerUV.zw = calculateLayerUV(VSInput.texCoords, UV_OFFSET.y, UV_ROTATION.y);
#endif

	//fog
	PSInput.fogColor.rgb = FOG_COLOR.rgb;
	PSInput.fogColor.a = clamp(((PSInput.position.z / RENDER_DISTANCE) - FOG_CONTROL.x) / (FOG_CONTROL.y - FOG_CONTROL.x), 0.0, 1.0);
}

