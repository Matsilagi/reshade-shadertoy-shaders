/*

Source: https://www.shadertoy.com/view/wlScWG

Original by Hatchling @ ShaderToy

Ported by Lucas Melo (luluco250)

*/

#include "ReShade.fxh"

static const float PI = 3.14159265359;

// Adjust these values to control the look of the encoding.

// Increasing this value increases ringing artifacts. Careful, higher values are
// expensive.
static const int WINDOW_RADIUS = 20;

// Simulated AM signal transmission.
static const float AM_CARRIERSIGNAL_WAVELENGTH = 2.0;
static const float AM_DECODE_HIGHPASS_WAVELENGTH = 2.0;
static const float AM_DEMODULATE_WAVELENGTH = 2.0;

// Wavelength of the color signal.
static const float COLORBURST_WAVELENGTH_ENCODER = 2.5;
static const float COLORBURST_WAVELENGTH_DECODER = 2.5;

// Lowpassing of luminance before encoding.
// If this value is less than the colorburst wavelength,
// luminance values will be interpreted as chrominance,
// resulting in color fringes near edges.
static const float YLOWPASS_WAVELENGTH = 1.0;

// The higher these values are, the more smeary colors will be.
static const float ILOWPASS_WAVELENGTH = 8.0;
static const float QLOWPASS_WAVELENGTH = 11.0;

// The higher this value, the blurrier the image.
static const float DECODE_LOWPASS_WAVELENGTH = 2.0;

// Change the overall scale of the NTSC-style encoding and decoding artifacts.
static const float NTSC_SCALE = 1.0;

static const float PHASE_ALTERNATION = 3.1415927;

// Amount of TV static.
static const float NOISE_STRENGTH = 0.1;

// Saturation control.
static const float SATURATION = 2.0;

// Offsets shape of window. This can make artifacts smear to one side or the
// other.
static const float WINDOW_BIAS = 0.0;

static const float3x3 MatrixRGBToYIQ = float3x3(
	// 0.299, 0.595, 0.2115,
	// 0.587, -0.274, -0.5227,
	// 0.114, -0.3213, 0.3112);
	0.299, 0.587, 0.114,
	0.595,-0.274,-0.3213,
	0.2115,-0.5227, 0.3112);

static const float3x3 MatrixYIQToRGB = float3x3(
	1.0,  0.956,  0.619,
	1.0, -0.272, -0.647,
	1.0, -1.106, 1.703);

uniform int FrameCount <source = "framecount";>;

uniform float Timer <source = "timer";>;

// RNG algorithm credit: https://www.shadertoy.com/view/wtSyWm
/*uint wang_hash(inout uint seed)
{
    seed = uint(seed ^ uint(61)) ^ uint(seed >> uint(16));
    seed *= uint(9);
    seed = seed ^ (seed >> 4);
    seed *= uint(0x27d4eb2d);
    seed = seed ^ (seed >> 15);

    return seed;
}*/

float Hash(inout float seed)
{
	//return seed = frac(sin(seed) * 93457.5453);
	seed = 1664525 * seed + 1013904223;

	return seed;
}

float RandomFloat01(inout float state)
{
	return sin(Hash(state) / 4294967296.0) * 0.5 + 0.5;
}

float RandomFloat01(float2 uv)
{
	static const float A = 23.2345;
	static const float B = 84.1234;
	static const float C = 56758.9482;

    return frac(sin(dot(uv, float2(A, B))) * C + Timer * 0.001);
}

// NOTE: Window functions expect a range from -1 to 1.
float Sinc(float x)
{
	if (x == 0.0)
		return 1.0;

    x *= PI;

	return sin(x) / x;
}

float WindowCosine(float x)
{
    x = atan(x);
    x += WINDOW_BIAS;
    x = tan(x);

	return cos(PI * x) * 0.5 + 0.5;
}

float Encode(
	sampler sp,
	float2 uv,
	float pixelWidth,
	bool alternatePhase)
{
    float3 yiq = 0.0;
    float windowWeight = 0.0;

	[unroll]
	for (int i = -WINDOW_RADIUS; i <= WINDOW_RADIUS; i++)
    {
		// Extend padding by one since we don't want to include a sample at the
		// very edge, which will be 0.
        float window = WindowCosine(i / float(WINDOW_RADIUS + 1));

		float3 sincYiq = float3(
			Sinc(i / YLOWPASS_WAVELENGTH) / YLOWPASS_WAVELENGTH,
			Sinc(i / ILOWPASS_WAVELENGTH) / ILOWPASS_WAVELENGTH,
			Sinc(i / QLOWPASS_WAVELENGTH) / QLOWPASS_WAVELENGTH);

        float2 uvWithOffset = float2(uv.x + i * pixelWidth, uv.y);

        float3 yiqSample = mul(
			MatrixRGBToYIQ,
			saturate(tex2D(sp, uvWithOffset).rgb));
			// clamp(0.0, 1.0, tex2D(sp, uvWithOffset).xyz));

		yiq += yiqSample * sincYiq * window;
        windowWeight += window;
    }
    //yiq /= windowWeight;

    float phase = uv.x * PI / (COLORBURST_WAVELENGTH_ENCODER * pixelWidth);

    if (alternatePhase)
        phase += PHASE_ALTERNATION;

    float phaseAM = uv.x * PI / (AM_CARRIERSIGNAL_WAVELENGTH * pixelWidth);

	float s, c;
	sincos(phase, s, c);

    return (yiq.x + s * yiq.y + c * yiq.z) * sin(phaseAM);
}

float DecodeAM(sampler sp, float2 uv, float pixelWidth)
{
    float originalSignal = tex2D(sp, uv).x;
    float phaseAM = uv.x * PI / (AM_DEMODULATE_WAVELENGTH * pixelWidth);
    float decoded = 0.0;
    float windowWeight = 0.0;

	[unroll]
	for (int i = -WINDOW_RADIUS; i <= WINDOW_RADIUS; i++)
    {
		// Extend padding by one since we don't want to include a sample at the
		// very edge, which will be 0.
        float window = WindowCosine(i / float(WINDOW_RADIUS + 1));
        float2 uvWithOffset = float2(uv.x + i * pixelWidth, uv.y);

        float sinc =
			Sinc(i / AM_DECODE_HIGHPASS_WAVELENGTH) /
			AM_DECODE_HIGHPASS_WAVELENGTH;

        float encodedSample = tex2D(sp, uvWithOffset).x;

    	decoded += encodedSample * sinc * window;
        windowWeight += window;
    }

    return decoded * sin(phaseAM) * 4.0;
}

float3 DecodeNTSC(
	sampler sp,
	float2 uv,
	float pixelWidth,
	float2 rng,
	bool alternatePhase)
{
    float seed = rng.y;

    float rowNoiseIntensity = RandomFloat01(seed);
    rowNoiseIntensity = pow(abs(rowNoiseIntensity), 500.0) * 1.0;

    float horizOffsetNoise = RandomFloat01(seed) * 2.0 - 1.0;
    horizOffsetNoise *= rowNoiseIntensity * 0.1 * NOISE_STRENGTH;

    float phaseNoise = RandomFloat01(seed) * 2.0 - 1.0;
    phaseNoise *= rowNoiseIntensity * 0.5 * PI * NOISE_STRENGTH;

    float frequencyNoise = RandomFloat01(seed) * 2.0 - 1.0;
    frequencyNoise *= rowNoiseIntensity * 0.1 * PI * NOISE_STRENGTH;

    float alt = (alternatePhase) ? PHASE_ALTERNATION : 0.0;

    float3 yiq = 0.0;
    float windowWeight = 0.0;

	[unroll]
	for (int i = -WINDOW_RADIUS; i <= WINDOW_RADIUS; i++)
    {
		// Extend padding by one since we don't want to include a sample at the
		// very edge, which will be 0.
        float window = WindowCosine(i / float(WINDOW_RADIUS + 1));

        float2 uvWithOffset = float2(uv.x + i * pixelWidth, uv.y);
    	float phase =
			uvWithOffset.x * PI /
			((COLORBURST_WAVELENGTH_DECODER + frequencyNoise) * pixelWidth) +
			phaseNoise + alt;

		float s, c;
		sincos(phase, s, c);

		float3 sincYiq = float3(
			Sinc(i / DECODE_LOWPASS_WAVELENGTH) / DECODE_LOWPASS_WAVELENGTH,
			s,
			c);

        float encodedSample = tex2D(sp, uvWithOffset).x;

		yiq += encodedSample * sincYiq * window;
        windowWeight += window;
    }

    yiq.yz *= SATURATION / windowWeight;

    return max(0.0, mul(MatrixYIQToRGB, yiq));
}

float4 BufferAPS(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET
{
	float2 fragCoord = uv * BUFFER_SCREEN_SIZE;

	// TODO: Improve RNG.
	// Initialize a random number state based on frag coord and frame.
    // float rngState =
	// 	fragCoord.x * 1973 + fragCoord.y * 9277 + FrameCount * 26699;

	// float rngStateRow = fragCoord.y * 9277 + FrameCount * 26699;

	float rngState = fragCoord.x * 1973 + fragCoord.y * 9277 + FrameCount * 26699 + 1000;
	float rngStateRow = fragCoord.y * 9277 + FrameCount * 26699 + 1000;

    float encoded = Encode(
		ReShade::BackBuffer,
		uv,
		BUFFER_RCP_WIDTH * NTSC_SCALE,
		(FrameCount + int(fragCoord.y)) % 2 == 0);

    float snowNoise = RandomFloat01(rngState) - 0.5;

    float sineNoise =
		sin(uv.x * 200.0 + uv.y * -50.0 + frac(Timer * Timer) * PI * 2.0) *
		0.065;

	float saltPepperNoise = RandomFloat01(rngState) * 2.0 - 1.0;
    saltPepperNoise =
		sign(saltPepperNoise) * pow(abs(saltPepperNoise), 200.0) * 10.0;

    float rowNoise = RandomFloat01(rngStateRow) * 2.0 - 1.0;
    rowNoise *= 0.1;

    float rowSaltPepper = RandomFloat01(rngStateRow) * 2.0 - 1.0;
    rowSaltPepper = sign(rowSaltPepper) * pow(abs(rowSaltPepper), 200.0) * 1.0;

    encoded +=
		(snowNoise + saltPepperNoise + sineNoise + rowNoise + rowSaltPepper) *
		NOISE_STRENGTH;

    return float4(encoded.xxx, 1.0);
}

float4 BufferBPS(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET
{
    float2 fragCoord = uv * BUFFER_SCREEN_SIZE;
    float2 pixelSize = BUFFER_PIXEL_SIZE;

    float value = DecodeAM(ReShade::BackBuffer, uv, pixelSize.x);

	return float4(value.xxx, 1.0);
}

float4 BufferCPS(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET
{
	float2 fragCoord = uv * BUFFER_SCREEN_SIZE;

    float rngStateRow = fragCoord.y * 9277 + FrameCount * 26699 + 1000;
    float rngStateCol = fragCoord.x * 1973 + FrameCount * 26699 + 1000;

	float3 color = DecodeNTSC(
		ReShade::BackBuffer,
		uv,
		BUFFER_RCP_WIDTH * NTSC_SCALE,
		float2(rngStateCol, rngStateRow),
		(FrameCount + int(fragCoord.y)) % 2 == 0);

    return float4(color, 1.0);
}

technique CustomizableNTSCFilterWithAM
{
	pass BufferA
	{
		VertexShader = PostProcessVS;
		PixelShader = BufferAPS;
	}
	pass BufferB
	{
		VertexShader = PostProcessVS;
		PixelShader = BufferBPS;
	}
	pass BufferC
	{
		VertexShader = PostProcessVS;
		PixelShader = BufferCPS;
	}
}
