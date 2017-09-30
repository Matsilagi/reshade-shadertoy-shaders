#include "ReShade.fxh"

uniform float fLCD_pb <
    ui_label = "LCD Color [LCD]";
    ui_type = "drag";
    ui_min = 0.01;
    ui_max = 3.0;
    ui_step = 0.01;
> = 0.4;

#define mod(x,y) (x-y*floor(x/y))

void PS_LCD1(in float4 pos : SV_POSITION, in float2 txcoord : TEXCOORD0, out float4 fragColor : COLOR0)
{
	float2 fragCoord = txcoord * ReShade::ScreenSize;
    // Get pos relative to 0-1 screen space
    float2 uv = fragCoord.xy / ReShade::ScreenSize.xy;
    
    // Map texture to 0-1 space
    float4 texColor = tex2D(ReShade::BackBuffer,uv);
    
    // Default lcd colour (affects brightness)
	float pb = fLCD_pb;
    float4 lcdColor = float4(pb,pb,pb,1.0);
    
    // Change every 1st, 2nd, and 3rd vertical strip to RGB respectively
    int px = int(mod(fragCoord.x,3.0));
	if (px == 1) lcdColor.r = 1.0;
    else if (px == 2) lcdColor.g = 1.0;
    else lcdColor.b = 1.0;
    
    // Darken every 3rd horizontal strip for scanline
    float sclV = 0.25;
    if (int(mod(fragCoord.y,3.0)) == 0) lcdColor.rgb = float3(sclV,sclV,sclV);
    
    
    fragColor = texColor*lcdColor;
}

technique LCD {
	pass LCD {
		VertexShader=PostProcessVS;
		PixelShader=PS_LCD1;
	}
}
