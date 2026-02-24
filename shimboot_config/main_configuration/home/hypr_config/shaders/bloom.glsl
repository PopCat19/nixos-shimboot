#version 320 es
precision highp float;

in vec2 v_texcoord;
out vec4 fragColor;

uniform sampler2D tex;
uniform float time;

const float BLOOM_INTENSITY      = 0.16;
const float BLOOM_RADIUS         = 0.004;
const int   BLOOM_RADIAL_SAMPLES = 8;
const int   DIRECTIONS           = 32;
const float BLOOM_THRESHOLD      = 0.96;
const float BLOOM_SOFT_THRESHOLD = 0.4;
const int   BLOOM_PASSES         = 6;
const float BLOOM_SIGMA_SCALE    = 0.9;
const float BLOOM_PASS_FALLOFF   = 0.4;
const float BLOOM_CENTER_WEIGHT  = 2.0;
const vec3 BLOOM_TINT            = vec3(1.1, 0.9, 0.85);
const float BLOOM_LUM_R_WEIGHT   = 0.299;
const float BLOOM_LUM_G_WEIGHT   = 0.587;
const float BLOOM_LUM_B_WEIGHT   = 0.114;

const float PI = 3.14159265359;

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float luminance(vec3 c) {
    return dot(c, vec3(BLOOM_LUM_R_WEIGHT, BLOOM_LUM_G_WEIGHT, BLOOM_LUM_B_WEIGHT));
}

vec3 calculateBloom(vec2 uv) {
    vec3 bloomAccum = vec3(0.0);
    float totalWeight = 0.0;

    const int BLUR_PASSES = BLOOM_PASSES;
    float blurSizes[BLUR_PASSES];
    blurSizes[0] = BLOOM_RADIUS * 0.3;
    blurSizes[1] = BLOOM_RADIUS * 0.7;
    blurSizes[2] = BLOOM_RADIUS * 1.3;
    blurSizes[3] = BLOOM_RADIUS * 2.2;
    blurSizes[4] = BLOOM_RADIUS * 3.8;
    blurSizes[5] = BLOOM_RADIUS * 5.5;

    for (int pass = 0; pass < BLUR_PASSES; pass++) {
        vec3 passBlur = vec3(0.0);
        float passWeight = 0.0;
        float blurSize = blurSizes[pass];

        int samplesPerAxis = BLOOM_RADIAL_SAMPLES;

        for (int dir = 0; dir < DIRECTIONS; dir++) {
            float angle = float(dir) * (2.0 * PI / float(DIRECTIONS));
            vec2 direction = vec2(cos(angle), sin(angle));

            for (int s = 1; s <= samplesPerAxis; s++) {
                float t = float(s) / float(samplesPerAxis);
                float radius = blurSize * t;

                vec2 sampleUV = uv + direction * radius;
                vec3 sampleColor = texture(tex, sampleUV).rgb;
                float sampleLum = luminance(sampleColor);
                float sampleMask = smoothstep(
                    BLOOM_THRESHOLD - BLOOM_SOFT_THRESHOLD,
                    BLOOM_THRESHOLD + BLOOM_SOFT_THRESHOLD,
                    sampleLum
                );

                float sigma = blurSize * BLOOM_SIGMA_SCALE;
                float gaussianWeight = exp(-(radius * radius) / (2.0 * sigma * sigma));
                float weight = gaussianWeight * sampleMask;

                passBlur += sampleColor * weight;
                passWeight += weight;
            }
        }

        vec3 centerColor = texture(tex, uv).rgb;
        float centerLum = luminance(centerColor);
        float centerMask = smoothstep(
            BLOOM_THRESHOLD - BLOOM_SOFT_THRESHOLD,
            BLOOM_THRESHOLD + BLOOM_SOFT_THRESHOLD,
            centerLum
        );
        float centerWeight = BLOOM_CENTER_WEIGHT * centerMask;
        passBlur += centerColor * centerWeight;
        passWeight += centerWeight;

        if (passWeight > 0.0) {
            passBlur /= passWeight;
        }

        float passContribution = exp(-float(pass) * BLOOM_PASS_FALLOFF);
        bloomAccum += passBlur * passContribution;
        totalWeight += passContribution;
    }

    if (totalWeight > 0.0) {
        bloomAccum /= totalWeight;
    }

    return bloomAccum * BLOOM_INTENSITY * BLOOM_TINT;
}

void main() {
    vec2 uv = v_texcoord;

    vec4 base = texture(tex, uv);
    vec3 color = base.rgb;
    float alpha = base.a;

    color += calculateBloom(uv);

    fragColor = vec4(color, alpha);
}
