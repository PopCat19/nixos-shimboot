#version 320 es
precision highp float;

// Input texture coordinates
in vec2 v_texcoord;

// Output fragment color
out vec4 fragColor;

// Input texture and time uniform
uniform sampler2D tex;
uniform float time;

// [Debug Toggles]
#define DEBUG_CA       1       // Toggle chromatic aberration effect
#define DEBUG_BLOOM    1       // Toggle bloom effect
#define DEBUG_VIGNETTE 0       // Toggle vignette effect
#define DEBUG_PIXEL    0       // Toggle pixelation effect
#define COLOR_DEPTH_ENABLED 0  // Enable color depth reduction
#define DEBUG_SCANLINE 0       // Toggle scanline effect
#define DEBUG_VHS_OVERLAY 1    // Toggle VHS effect
#define DEBUG_GLITCH   1       // Toggle glitch effect
#define DEBUG_DRIFT    0       // Toggle drifting effect
#define DEBUG_COLOR_TEMP 0     // Toggle color temperature adjustment
#define DEBUG_VIBRATION 0      // Toggle CRT buzz vibration effect
#define DEBUG_GRAIN     0      // Toggle cinematic grain effect

// [Effect Parameters]
// Bloom Parameters
#define BLOOM_INTENSITY       0.16
#define BLOOM_RADIUS          0.008
#define BLOOM_SAMPLES         64
#define BLOOM_TINT            vec3(1.1, 0.9, 0.9)
#define BLOOM_THRESHOLD       0.0
#define BLOOM_SOFT_THRESHOLD  1.0
#define BLOOM_FALLOFF_CURVE   32.0

// Glitch Parameters
#define GLITCH_STRENGTH        1.0
#define GLITCH_PROBABILITY     0.20
#define GLITCH_INTERVAL        3.0
#define GLITCH_DURATION        0.12   // at least 120ms
#define GLITCH_SPEED           64.0   // configurable bounce speed

// Vignette Parameters
#define VIGNETTE_STRENGTH      0.4
#define VIGNETTE_RADIUS        1.6
#define VIGNETTE_SMOOTHNESS    0.8
#define VIGNETTE_ASPECT        vec2(1.0, 1.0)
#define VIGNETTE_COLOR         vec3(0.0, 0.0, 0.0)
#define VIGNETTE_OFFSET        vec2(0.0, 0.0)
#define VIGNETTE_EXPONENT      1.0
#define VIGNETTE_MODE          0

// Chromatic Aberration Parameters
#define CA_RED_STRENGTH     0.001
#define CA_BLUE_STRENGTH    0.001
#define CA_FALLOFF          1.0
#define CA_ANGLE            0.0
#define CA_FALLOFF_EXPONENT 1.0
#define CA_CENTER_STRENGTH  3.0

// Scanline Parameters
#define SCANLINE_OPACITY     0.2
#define SCANLINE_FREQUENCY   1.0
#define SCANLINE_SPEED       -1.0
#define SCANLINE_THICKNESS   0.2

// Drifting Effect Parameters
#define DRIFT_MODE 1
#define DRIFT_SPEED -1.6
#define DRIFT_RADIUS 0.002
#define DRIFT_AMPLITUDE 0.002
#define DRIFT_FREQUENCY 1.2
#define DRIFT_DIRECTION vec2(1.0, 0.5)

// CRT Buzz Vibration Parameters
#define VIBRATION_AMPLITUDE 0.0004
#define VIBRATION_BASE_FREQ 75.0
#define VIBRATION_NOISE_FREQ 120.0
#define VIBRATION_NOISE_STRENGTH 0.4

// Color Settings
#define COLOR_DEPTH 16
const float COLOR_TEMPERATURE = 4000.0;
const float COLOR_TEMPERATURE_STRENGTH = 1.0;

// Pixelation Effect
#define PIXEL_GRID_SIZE 360.0

// VHS Overlay Parameters
#define VHS_INTENSITY        0.16
#define VHS_JITTER_STRENGTH  0.004
#define VHS_WAVE_FREQ        2.0
#define VHS_WAVE_AMPLITUDE   0.003
#define VHS_COLOR_SHIFT      0.0015
#define VHS_NOISE_BAND_FREQ  0.8
#define VHS_NOISE_BAND_STRENGTH 0.25

// Grain Parameters
#define GRAIN_INTENSITY 0.08
#define GRAIN_SIZE 800.0
#define GRAIN_SPEED 0.5

const float PI = 3.14159265359;

// --- Utility Functions ---
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

// --- Grain Effect ---
vec3 applyGrain(vec2 uv, vec3 color, float time) {
#if DEBUG_GRAIN
    float noise = random(uv * GRAIN_SIZE + time * GRAIN_SPEED);
    float grain = (noise - 0.5) * 2.0;
    return mix(color, color + grain * GRAIN_INTENSITY, 0.5);
#else
    return color;
#endif
}

// --- Color Depth Reduction ---
vec3 applyColorDepthReduction(vec3 color) {
#if COLOR_DEPTH_ENABLED
    ivec3 bits;
    if (COLOR_DEPTH == 8) {
        bits = ivec3(3, 3, 2);
    } else if (COLOR_DEPTH == 16) {
        bits = ivec3(5, 6, 5);
    } else if (COLOR_DEPTH == 24) {
        bits = ivec3(8, 8, 8);
    } else {
        return color;
    }
    vec3 maxValues = pow(vec3(2.0), vec3(bits)) - 1.0;
    return floor(color * maxValues + 0.5) / maxValues;
#else
    return color;
#endif
}

// --- Pixelation Effect ---
vec2 pixelate(vec2 uv) {
#if DEBUG_PIXEL
    vec2 grid = vec2(PIXEL_GRID_SIZE, PIXEL_GRID_SIZE * (VIGNETTE_ASPECT.y / VIGNETTE_ASPECT.x));
    vec2 pixelUV = floor(uv * grid) / grid;
    return pixelUV;
#else
    return uv;
#endif
}

vec3 applyPixelGrid(vec2 uv, vec3 color) {
#if DEBUG_PIXEL
    vec2 grid = vec2(PIXEL_GRID_SIZE, PIXEL_GRID_SIZE * (VIGNETTE_ASPECT.y / VIGNETTE_ASPECT.x));
    vec2 pixelCoord = uv * grid;
    vec2 gridLine = smoothstep(0.95, 0.99, fract(pixelCoord));
    float gridMask = 1.0 - max(gridLine.x, gridLine.y);
    return color * mix(vec3(0.2), vec3(1.0), gridMask);
#else
    return color;
#endif
}

// --- Core Functions ---
vec3 colorTemperatureToRGB(float temperature) {
    mat3 m = (temperature <= 6500.0) ? mat3(
        0.0, -2902.1955373783176, -8257.7997278925690,
        0.0, 1669.5803561666639, 2575.2827530017594,
        1.0, 1.3302673723350029, 1.8993753891711275
    ) : mat3(
        1745.0425298314172, 1216.6168361476490, -8257.7997278925690,
        -2666.3474220535695, -2173.1012343082230, 2575.2827530017594,
        0.55995389139931482, 0.70381203140554553, 1.8993753891711275
    );
    vec3 result = clamp(vec3(m[0] / (vec3(clamp(temperature, 1000.0, 40000.0)) + m[1]) + m[2]), vec3(0.0), vec3(1.0));
    return mix(result, vec3(1.0), smoothstep(1000.0, 0.0, temperature));
}

// --- Post-Processing Effects ---
float computeVignette(vec2 uv) {
    vec2 coord = (uv - 0.5 - VIGNETTE_OFFSET) * 2.0 * VIGNETTE_ASPECT;
    float dist = length(coord);
    dist = pow(dist, VIGNETTE_EXPONENT);
    return smoothstep(VIGNETTE_RADIUS, VIGNETTE_RADIUS - VIGNETTE_SMOOTHNESS, dist);
}

vec3 applyChromaticAberration(vec2 uv, out float alpha) {
    vec2 dir = (uv - 0.5) * CA_FALLOFF;
    float cosA = cos(CA_ANGLE);
    float sinA = sin(CA_ANGLE);
    dir = vec2(dir.x * cosA - dir.y * sinA, dir.x * sinA + dir.y * cosA);
    float dist = length(dir);
    float edgeComponent = pow(dist, CA_FALLOFF_EXPONENT);
    float centerComponent = (1.0 - edgeComponent) * CA_CENTER_STRENGTH;
    float totalFalloff = edgeComponent + centerComponent;
    float strength_r = totalFalloff * CA_RED_STRENGTH;
    float strength_b = totalFalloff * CA_BLUE_STRENGTH;
    alpha = texture(tex, uv).a;
    return vec3(
        texture(tex, uv + dir * strength_r).r,
        texture(tex, uv).g,
        texture(tex, uv - dir * strength_b).b
    );
}

// --- Bloom ---
vec3 calculateBloom(vec2 uv) {
    vec3 color = vec3(0.0);
    float total = 0.0;
    const float goldenAngle = 2.39996;
    float currentAngle = 0.0;

    const int SCALES = 3;
    float scaleRadius[SCALES];
    scaleRadius[0] = BLOOM_RADIUS * 0.5;
    scaleRadius[1] = BLOOM_RADIUS * 1.5;
    scaleRadius[2] = BLOOM_RADIUS * 3.0;

    for (int s = 0; s < SCALES; s++) {
        for (int i = 0; i < BLOOM_SAMPLES / SCALES; i++) {
            float ratio = sqrt(float(i) / float(BLOOM_SAMPLES / SCALES));
            float radius = ratio * scaleRadius[s];
            currentAngle += goldenAngle;
            vec2 dir = vec2(cos(currentAngle), sin(currentAngle)) * radius;
            vec2 sampleUV = uv + dir;

            vec3 sampleColor = texture(tex, sampleUV).rgb;
            float luminance = dot(sampleColor, vec3(0.299, 0.587, 0.114));

            float softThreshold = smoothstep(
                BLOOM_THRESHOLD - BLOOM_SOFT_THRESHOLD,
                BLOOM_THRESHOLD + BLOOM_SOFT_THRESHOLD,
                luminance
            );

            float weight = exp(-(radius * radius) * BLOOM_FALLOFF_CURVE) * softThreshold;
            color += sampleColor * weight;
            total += weight;
        }
    }

    return (color / max(total, 0.001)) * BLOOM_INTENSITY * BLOOM_TINT;
}

// --- Scanline Effect ---
float applyScanlines(vec2 uv, float time) {
    float scan = sin(uv.y * SCANLINE_FREQUENCY * PI + time * SCANLINE_SPEED);
    scan = smoothstep(1.0 - SCANLINE_THICKNESS, 1.0, scan);
    return 1.0 - scan * SCANLINE_OPACITY;
}

// --- VHS Effect ---
vec3 applyVHSEffect(vec2 uv, float time, vec3 originalColor) {
#if DEBUG_VHS_OVERLAY
    float jitter = (random(vec2(time, uv.y)) - 0.5) * VHS_JITTER_STRENGTH;
    uv.x += jitter;

    uv.y += sin(uv.x * VHS_WAVE_FREQ + time * 1.5) * VHS_WAVE_AMPLITUDE;

    vec3 vhsColor = vec3(
        texture(tex, uv + vec2( VHS_COLOR_SHIFT, 0.0)).r,
        texture(tex, uv).g,
        texture(tex, uv - vec2( VHS_COLOR_SHIFT, 0.0)).b
    );

    float bandNoise = step(1.0 - VHS_NOISE_BAND_FREQ, random(vec2(time, floor(uv.y * 480.0))));
    if (bandNoise > 0.5) {
        float noise = (random(uv * time) - 0.5) * VHS_NOISE_BAND_STRENGTH;
        vhsColor += vec3(noise);
    }

    return mix(originalColor, vhsColor, VHS_INTENSITY);
#else
    return originalColor;
#endif
}

// --- Drift ---
vec2 applyDrift(vec2 uv, float time) {
    vec2 driftOffset = vec2(0.0);
    #if DRIFT_MODE == 0
        float driftAngle = time * DRIFT_SPEED;
        driftOffset = vec2(cos(driftAngle), sin(driftAngle)) * DRIFT_RADIUS;
    #elif DRIFT_MODE == 1
        driftOffset.x = sin(time * DRIFT_SPEED * DRIFT_FREQUENCY) * DRIFT_AMPLITUDE;
        driftOffset.y = cos(time * DRIFT_SPEED * DRIFT_FREQUENCY) * DRIFT_AMPLITUDE;
    #elif DRIFT_MODE == 2
        driftOffset = DRIFT_DIRECTION * (time * DRIFT_SPEED);
    #endif
    return uv + driftOffset;
}

// --- CRT Buzz ---
vec2 applyCRTVibration(vec2 uv, float time) {
#if DEBUG_VIBRATION
    float buzz = sin(time * VIBRATION_BASE_FREQ) * VIBRATION_AMPLITUDE;
    float line = floor(uv.y * 480.0);
    float noise = (random(vec2(line, time * VIBRATION_NOISE_FREQ)) - 0.5) 
                  * VIBRATION_AMPLITUDE * VIBRATION_NOISE_STRENGTH;
    uv.y += buzz + noise;
#endif
    return uv;
}

// --- Glitch ---
vec3 applyAnalogGlitch(vec2 uv, float time, vec3 color, float isActive, float tInInterval) {
    if (isActive < 0.5) return color;
    float bounce = sin(tInInterval * GLITCH_SPEED * PI);
    float strength = GLITCH_STRENGTH * bounce;
    float line = floor(uv.y * 480.0);
    float lineNoise = random(vec2(line, time));
    float tearStrength = step(0.985, lineNoise) * 0.02 * strength;
    uv.x += tearStrength * (random(vec2(lineNoise, time)) - 0.5);
    float wave = sin(uv.y * 40.0 + time * 6.0) * 0.002 * strength;
    uv.x += wave;
    float shift = 0.0015 * sin(time * 2.0 + uv.y * 10.0) * strength;
    vec3 analogColor = vec3(
        texture(tex, uv + vec2( shift, 0.0)).r,
        texture(tex, uv).g,
        texture(tex, uv - vec2( shift, 0.0)).b
    );
    return mix(color, analogColor, strength);
}

// --- Main ---
void main() {
    float alpha;
    vec3 color;
    vec2 processedUV = v_texcoord;

    float currentInterval = floor(time / GLITCH_INTERVAL);
    float tInInterval = fract(time / GLITCH_INTERVAL);
    float seedGlitch = random(vec2(currentInterval));
    float intervalActive = step(seedGlitch, GLITCH_PROBABILITY);
    float isActiveGlitch = intervalActive * step(tInInterval, GLITCH_DURATION);

    #if DEBUG_DRIFT
        processedUV = applyDrift(processedUV, time);
    #endif
    #if DEBUG_VIBRATION
        processedUV = applyCRTVibration(processedUV, time);
    #endif

    processedUV = pixelate(processedUV);

    #if DEBUG_CA
        color = applyChromaticAberration(processedUV, alpha);
    #else
        vec4 base = texture(tex, processedUV);
        color = base.rgb;
        alpha = base.a;
    #endif

    #if DEBUG_GLITCH
        color = applyAnalogGlitch(processedUV, time, color, isActiveGlitch, tInInterval);
    #endif

    color = applyPixelGrid(processedUV, color);

    #if DEBUG_BLOOM
        color += calculateBloom(processedUV);
    #endif

    #if DEBUG_COLOR_TEMP
        color = mix(color, color * colorTemperatureToRGB(COLOR_TEMPERATURE), COLOR_TEMPERATURE_STRENGTH);
    #endif

    color = applyColorDepthReduction(color);

    #if DEBUG_SCANLINE
        color *= applyScanlines(v_texcoord, time);
    #endif

    #if DEBUG_VIGNETTE
        float vig = computeVignette(processedUV);
        #if VIGNETTE_MODE == 0
            color *= mix(1.0 - VIGNETTE_STRENGTH, 1.0, vig);
        #else
            color = mix(color * VIGNETTE_COLOR, color, vig);
            color *= mix(1.0 - VIGNETTE_STRENGTH/2.0, 1.0, vig);
        #endif
    #endif

    #if DEBUG_VHS_OVERLAY
        color = applyVHSEffect(processedUV, time, color);
    #endif

    #if DEBUG_GRAIN
        color = applyGrain(processedUV, color, time);
    #endif

    fragColor = vec4(color, alpha);
}
