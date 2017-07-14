#include "ReShade.fxh"

uniform float4 Timer < source = "timer"; >;
#define PIOVER180 	0.017453292
#define aspect          (BUFFER_RCP_HEIGHT/BUFFER_RCP_WIDTH)

float mod(float x, float y)
{
  return x - y * floor(x/y);
}

float4 PS_Wave(float4 vpos : SV_Position, float2 txcoord : TEXCOORD): SV_Target0
{
	float4 color=tex2D(ReShade::BackBuffer, txcoord.xy);

	float2 uv2 = txcoord.xy;

	float3 COLOR2 = float3(183.0, 152.0, 30.0)/255.0;
	float3 COLOR1 = float3(50.0, 40.0, 0.0)/255.0;
	float BLOCK_WIDTH = 0.005;

	float c1 = mod(uv2.x, 2.0 * BLOCK_WIDTH);
	c1 = step(BLOCK_WIDTH, c1);
	
	float c2 = mod(uv2.y, 2.0 * BLOCK_WIDTH);
	c2 = step(BLOCK_WIDTH, c2);
	
	color.xyz = lerp(uv2.x * COLOR1, uv2.y * COLOR2 , c1 * c2);

	float2 uv3 = txcoord.xy;
	float3 wave_color = 0;
	float wave_width = 0.01;
	uv3  = -1.0 + 2.0 * uv3;
	uv3.y += 0.1;
	for(float i = 0.0; i < 10.0; i++) {
		
		uv3.y += (0.07 * sin(uv3.x + i/7.0 + Timer.x*0.002 ));
		wave_width = abs(1.0 / (150.0 * uv3.y));
		wave_color += float3(wave_width * 1.9, wave_width * 1.5, wave_width);
	}
	
	color.xyz = color.xyz + wave_color;

	return color;
}

technique Wave
{
	pass Wave
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_Wave;
	}
}