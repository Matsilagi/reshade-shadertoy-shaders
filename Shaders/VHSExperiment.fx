#include "ReShade.fxh"

uniform int iVHS_resolutionX <
	ui_type = "drag";
	ui_min = 1.0;
	ui_max = BUFFER_WIDTH;
	ui_label = "Screen Resolution Width [VHS]";
	ui_tooltip = "The pixels per width in the output picture.";
> = 320;

uniform int iVHS_resolutionY <
	ui_type = "drag";
	ui_min = 1.0;
	ui_max = BUFFER_HEIGHT;
	ui_label = "Screen Resolution Height [VHS]";
	ui_tooltip = "The pixels per height in the output picture.";
> = 240;

uniform bool bVHS_doColorCorrection <
	ui_type = "combo";
	ui_label = "Color Correction [VHS]";
	ui_tooltip = "The picture will be more pink/purple.";
> = false;

uniform float fVHS_bleedAmount <
	ui_type = "drag";
	ui_min = "0.0";
	ui_max = "15.0";
	ui_label = "Bleed Stretch [VHS]";
	ui_tooltip = "Length of the bleeding.";
> = 3.0;

uniform float fVHS_noiseSpeed <
	ui_type = "drag";
	ui_min = "-1.5";
	ui_max = "1.5";
	ui_label = "Noise Speed [VHS]";
	ui_tooltip = "Speed and Direction of the Tape Noise.";
> = 1.0;

//Helpers
#define mod(x,y) (x-y*floor(x/y))

uniform float Timer < source = "timer"; >;

texture VHSChannel0_tex {
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RGBA32F;
};

sampler VHSChannel0 {
	Texture = VHSChannel0_tex;
};

texture VHSChannel1_tex <source="sh_noise_med.png";> { Width=256; Height=256; Format = RGBA8;};

sampler VHSChannel1 { Texture=VHSChannel1_tex; MinFilter=LINEAR; MagFilter=LINEAR; };

//Shader Code

#define V float2(0.0,1.0)
#define PI 3.14159265
#define VHSRES float2(iVHS_resolutionX,iVHS_resolutionY)
#define saturate(i) clamp(i,0.,1.)
#define validuv(v) (abs(v.x-0.5)<0.5&&abs(v.y-0.5)<0.5)

float v2random( float2 uv ) {
  return tex2D( VHSChannel1, mod( uv, float2( 1.0,1.0 ) ) ).x;
}

float3 rgb2yiq(float3 c)
{   
	return float3(
	0.2989*c.x + 0.5959*c.y + 0.2115*c.z,
	0.5870*c.x - 0.2744*c.y - 0.5229*c.z,
	0.1140*c.x - 0.3216*c.y + 0.3114*c.z);
};

float3 yiq2rgb(float3 c)
{				
	return float3(
	1.0*c.x +1.0*c.y +1.0*c.z,
	0.956*c.x - 0.2720*c.y - 1.1060*c.z,
	0.6210*c.x - 0.6474*c.y + 1.7046*c.z);
};

float3 vhsTex2D( float2 uv ) {
  if ( validuv( uv ) ) {
    float3 y = V.yxx * rgb2yiq( tex2D( ReShade::BackBuffer, uv ).xyz );
    float3 c = V.xyy * rgb2yiq( tex2D( ReShade::BackBuffer, uv - fVHS_bleedAmount * V.yx / VHSRES.x ).xyz );
    return yiq2rgb( y + c );
  }
  return float3( 0.1, 0.1, 0.1 );
}

void VHS_PS1(in float4 pos : SV_POSITION, in float2 txcoord : TEXCOORD0, out float4 color : COLOR0){
  float2 frgcoord = txcoord * ReShade::ScreenSize;
  float2 uv = frgcoord.xy / VHSRES;
  float time = Timer;

  float2 uvn = uv;
  float2 y_inv = uvn;
  
  if (__RENDERER__ == 0x09300 || __RENDERER__ == 0x0A100 || __RENDERER__ == 0x0B000){
	y_inv = 1-uvn.y;
  }
  
  float3 col = float3( 0.0, 0.0, 0.0 );

  // tape wave
  uvn.x += ( v2random( float2( y_inv.y / 10.0, ((time*0.001)*fVHS_noiseSpeed) / 10.0 ) / 1.0 ) - 0.5 ) / VHSRES.x * 2.0;
  uvn.x += ( v2random( float2( y_inv.y, ((time*0.001)*fVHS_noiseSpeed) * 10.0 ) ) - 0.5 ) / VHSRES.x * 2.0;

  // tape crease
  float tcPhase = smoothstep( 0.9, 0.96, sin( y_inv.y * 8.0 - ( ((time*0.001)*fVHS_noiseSpeed) + 0.14 * v2random( ((time*0.001)*fVHS_noiseSpeed) * float2( 0.67, 0.59 ) ) ) * PI * 1.2 ) );
  float tcNoise = smoothstep( 0.3, 1.0, v2random( float2( y_inv.y * 4.77, ((time*0.001)*fVHS_noiseSpeed) ) ) );
  float tc = tcPhase * tcNoise;
  uvn.x = uvn.x - tc / VHSRES.x * 8.0;

  // switching noise
  float snPhase = smoothstep( 6.0 / VHSRES.y, 0.0, y_inv.y );
  y_inv.y += snPhase * 0.3;
  uvn.x += snPhase * ( ( v2random( float2( uv.y * 100.0, ((time*0.001)*fVHS_noiseSpeed) * 10.0 ) ) - 0.5 ) / VHSRES.x * 24.0 );

  // fetch
  col = vhsTex2D( uvn );

  // crease noise
  float cn = tcNoise * ( 0.3 + 0.7 * tcPhase );
  if ( 0.29 < cn ) {
    float2 uvt = ( uvn + V.yx * v2random( float2( uvn.y, ((time*0.001)*fVHS_noiseSpeed) ) ) ) * float2( 0.1, 1.0 );
    float n0 = v2random( uvt );
    float n1 = v2random( uvt + V.yx / VHSRES.x );
    if ( n1 < n0 ) {
      col = lerp( col, 2.0 * V.yyy, pow( n0, 5.0 ) );
    }
  }

  // switching color modification
  col = lerp(
    col,
    col.yzx,
    snPhase * 0.4
  );

  // ac beat
  col *= 1.0 + 0.1 * smoothstep( 0.4, 0.6, v2random( float2( 0.0, 0.1 * ( uv.y + (time*0.001) * 0.2 ) ) / 10.0 ) );

  // color noise
  col *= 0.9 + 0.1 * tex2D( VHSChannel1, mod( uvn * float2( 1.0, 1.0 ) + (time*0.001) * float2( 5.97, 4.45 ), float2( 1.0,1.0 ) ) ).xyz;
  col = saturate( col );

  // yiq
  col = rgb2yiq( col );
  
  if (bVHS_doColorCorrection){
	col = float3( 0.1, -0.1, 0.0 ) + float3( 0.7, 2.0, 3.4 ) * col;
  }
  
  col = yiq2rgb( col );

  color = float4( col, 1.0 );
}

void VHS_PS2(in float4 pos : SV_POSITION, in float2 txcoord : TEXCOORD0, out float4 col : COLOR0){
  float2 frgcoord = txcoord * ReShade::ScreenSize;
  float2 uv = frgcoord.xy / ReShade::ScreenSize.xy / ReShade::ScreenSize.xy * VHSRES;
  col = tex2D( VHSChannel0, uv );
}

technique VHS_Exp {
	pass VHS_Exp1 {
		VertexShader = PostProcessVS;
		PixelShader = VHS_PS1;
		RenderTarget = VHSChannel0_tex;
	}
	pass VHS_Exp2 {
		VertexShader = PostProcessVS;
		PixelShader = VHS_PS2;
	}
}