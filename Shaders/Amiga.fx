//                       _                                       _ _ _ _ _ _ _ 
//       /\             (_)                                     | | | | | | | |
//      /  \   _ __ ___  _  __ _  __ _  __ _  __ _  __ _  __ _  | | | | | | | |
//     / /\ \ | '_ ` _ \| |/ _` |/ _` |/ _` |/ _` |/ _` |/ _` | | | | | | | | |
//    / ____ \| | | | | | | (_| | (_| | (_| | (_| | (_| | (_| | |_|_|_|_|_|_|_|
//   /_/    \_\_| |_| |_|_|\__, |\__,_|\__,_|\__,_|\__,_|\__,_| (_|_|_|_|_|_|_)
//                          __/ |                                              
//                         |___/

//By @unitzeroone
//Check out http://www.youtube.com/watch?feature=player_detailpage&v=ZmIf-5MuQ7c#t=26s for context.
//Decyphering the code&magic numbers and optimizing is left as excercise to the reader ;-)

//-1/5/2013 FIX : Windows was rendering "inverted z checkerboard" on entire screen.
//-1/5/2013 CHANGE : Did a modification for the starting position, so ball doesn't start at bottom right.
//-1/5/2013 CHANGE : Tweaked edge bounce.

#include "ReShade.fxh"

#define PI 3.1415926536

static const float2 res = float2(320.0, 200.0);
static const float2 ps = float2(0.003125, 0.005); //reciprocal of res (which means it's 1 / res)
static const float3x3 mRot = float3x3(0.9553, -0.2955, 0.0, 0.2955, 0.9553, 0.0, 0.0, 0.0, 1.0);
static const float3 ro = float3(0.0, 0.0, -4.0);

static const float3 cRed = float3(1.0, 0.0, 0.0);
static const float3 cWhite = float3(1.0, 1.0, 1.0);
static const float3 cGrey = float3(0.66, 0.66, 0.66);
static const float3 cPurple = float3(0.51, 0.29, 0.51);

static const float maxx = 0.378;

uniform float fAmigaBoingBall_Timer <source="timer";>;

uniform float fAmigaBoingBall_shadowX <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_label = "Shadow X [BoingBall]";
> = 0.57;

uniform float fAmigaBoingBall_shadowY <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_label = "Shadow Y [BoingBall]";
> = 0.29;


//a float2 version is needed to avoid implict conversion warnings/problems
float2 mod2(float2 x, float2 y) {
	return x - y * floor(x / y);
}

float mod2(float x, float y) {
	return x - y * floor(x / y);
}

float3 PS_Amiga(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target {
	float timer = fAmigaBoingBall_Timer * 0.001;
	float asp = ReShade::ScreenSize.y / ReShade::ScreenSize.x;
	float2 uvR = floor(uv * res);
	float2 g = step(2.0, mod2(uvR, 16.0));
	float3 bgcol = lerp(cPurple, lerp(cPurple, cGrey, g.x), g.y);
	uv = uvR * ps;
	float xt = mod2(timer + 1.0, 6.0);
	float dir = (step(xt, 3.0) - 0.5) * -2.0;
	uv.x += (maxx * 2.0 * dir) * mod2(xt, 3.0) / 3.0 + (-maxx * dir);
	uv.y += abs(sin(4.5 + timer * 1.3)) * 0.5 - 0.3;
	bgcol = lerp(bgcol, bgcol - float3(0.2, 0.2, 0.2),1.0 - step(0.12, length(float2(uv.x, uv.y * asp) - float2(fAmigaBoingBall_shadowX, fAmigaBoingBall_shadowY))));
	float3 rd = normalize(float3((uv * 2.0 - 1.0) * float2(1.0, asp), 1.5));
	float b = dot(rd, ro);
	float t1 = b * b - 15.6;
    float t = -b - sqrt(t1);
	float3 nor = mul(normalize(ro + rd * t), mRot);
	float2 tuv = floor(float2(atan2(nor.x, nor.z) / PI + ((floor((timer * -dir) * 60.0) / 60.0) * 0.5), acos(nor.y) / PI) * 8.0);
	return lerp(bgcol, lerp(cRed, cWhite, clamp(mod2(tuv.x + tuv.y, 2.0), 0.0, 1.0)), 1.0 - step(t1, 0.0));
}

technique Boing {
	pass BoingBall {
		VertexShader=PostProcessVS;
		PixelShader=PS_Amiga;
	}
}

//small edits by luluco250