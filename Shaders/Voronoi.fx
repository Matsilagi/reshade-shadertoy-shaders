#include "ReShade.fxh"

texture   texNoise  < string source = "Textures/mcnoise.png";  > {Width = BUFFER_WIDTH;Height = BUFFER_HEIGHT;Format = RGBA8;};
sampler2D SamplerNoise
{
	Texture = texNoise;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU = Repeat;
	AddressV = Repeat;
};
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

float2 hash2( float2 p )
{
	return tex2D( SamplerNoise, (p+0.5)/256.0).xy;
}

float3 voronoi( in float2 x )
{
    	float2 n = floor(x);
    	float2 f = frac(x);
	float2 mg, mr;

   	float md = 8.0;
    	for( int j=-1; j<=1; j++ )
    	for( int i=-1; i<=1; i++ )
    	{
        	float2 g = float2(float(i),float(j));
		float2 o = hash2( n + g );
	       	o = 0.5 + 0.5*sin( Timer.x*0.0005 + 6.2831*o );
	        float2 r = g + o - f;
        	float d = dot(r,r);
	       	if( d<md )
        	{
            		md = d;
            		mr = r;
            	mg = g;
        	}
    	}

   	md = 8.0;
    	for( int k=-2; k<=2; k++ )
    	for( int l=-2; l<=2; l++ )
    	{
        	float2 g = mg + float2(float(l),float(k));
		float2 o = hash2( n + g );
        	o = 0.5 + 0.5*sin( Timer.x*0.0005 + 6.2831*o );
        	float2 r = g + o - f;

        	if( dot(mr-r,mr-r)>0.00001 )
        	md = min( md, dot( 0.5*(mr+r), normalize(r-mr) ) );
    	}

    	return float3( md, mr );
}

float4 PS_Voronoi(VS_OUTPUT_POST IN) : COLOR
{
	float2 p = IN.txcoord.xy*4;
	p.x *= aspect;
    	float3 c = voronoi( 8.0*p );

    	float3 col = c.x*(0.5 + 0.5*sin(64.0*c.x));

    	col = lerp( float3(1.0,0.6,0.0), col, smoothstep( 0.04, 0.07, c.x ) );
	float dd = length( c.yz );
	col = lerp( float3(1.0,0.6,0.1), col, smoothstep( 0.0, 0.12, dd) );
	col += float3(1.0,0.6,0.1)*(1.0-smoothstep( 0.0, 0.04, dd));

	return col.xyzz;
}


technique Voronoi
{
	pass Voronoi
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_Voronoi;
	}
}