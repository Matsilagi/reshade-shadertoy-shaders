#include "ReShade.fxh"

uniform float4 Timer < source = "timer"; >;
#define PIOVER180 	0.017453292
#define aspect          (BUFFER_RCP_HEIGHT/BUFFER_RCP_WIDTH)
struct VS_OUTPUT_POST
{
	float4 vpos  : POSITION;
	float2 txcoord : TEXCOORD0;
};

VS_OUTPUT_POST VS_PostProcess(in uint id : SV_VertexID)
{
	VS_OUTPUT_POST OUT;
	OUT.txcoord.x = (id == 2) ? 2.0 : 0.0;
	OUT.txcoord.y = (id == 1) ? 2.0 : 0.0;
	OUT.vpos = float4(OUT.txcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
	return OUT;
}

float4 PS_Infinity(VS_OUTPUT_POST IN) : COLOR
{
	
	float2 p = IN.txcoord.xy;
	float4 color = 0;	
	float time = Timer.x*0.001;

	int iterations = 85;

	float3 pointcolor1 = float3(1.9,1.5,1.0);
	float3 pointcolor2 = float3(2.0,1.0,1.8);

	float3 pointcolor = lerp(pointcolor1, pointcolor2, IN.txcoord.x-0.2);	

    	for(int i=0;i<iterations;i++){
  
        	float t = 2.*3.14*float(i)/(float)iterations + sin(time*0.5);
        	float x = -cos(t)+2.0;
       		float y = sin(t*2.0)+2.0;
	      	float2 o = 0.25*float2(x,y);
	       	color.xyz += (0.001/(length((p-o)*float2(aspect,1.0)))*1.25)*pointcolor;
    	}

	return color;
}


technique Infinity
{
	pass Infinity
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_Infinity;
	}
}