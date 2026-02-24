#version 320 es
precision highp float;

in vec2 v_texcoord;
out vec4 fragColor;

uniform sampler2D tex;
uniform float time;

const bool ENABLE_CHROMATIC_ABERRATION = true;
const bool ENABLE_PIXELATION           = false;
const bool ENABLE_GLITCH               = true;
const bool ENABLE_FILM_GRAIN           = true;
const bool ENABLE_COLOR_BLEED          = true;

const struct ChromaticAberration {
    float red_offset;
    float blue_offset;
    float falloff;
    float falloff_exp;
    float center_boost;
    float angle;
} CA = ChromaticAberration(0.001, 0.001, 1.0, 1.0, 3.0, 0.0);

const struct Pixelation {
    float grid_size;
} PIXEL = Pixelation(960.0);

const struct Glitch {
    float strength;
    float probability;
    float interval;
    float duration;
    float speed;
} GLITCH = Glitch(1.0, 0.20, 3.0, 0.12, 64.0);

const struct FilmGrain {
    float intensity;
    float size;
    float speed;
    float luma_amount;
    float chroma_amount;
} GRAIN = FilmGrain(0.08, 1.6, 15.0, 0.7, 0.3);

const struct ColorBleed {
    float strength;
    float distance;
    int   samples;
} BLEED = ColorBleed(0.4, 0.003, 8);

const float PI = 3.14159265359;
const vec3  LUMA_WEIGHTS = vec3(0.299, 0.587, 0.114);

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float hash(vec3 p) {
    vec3 q = fract(p * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

vec2 hash22(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    q += dot(q, q.yzx + 33.33);
    return fract((q.xx + q.yz) * q.zy);
}

vec2 get_resolution() {
    return 1.0 / vec2(length(dFdx(v_texcoord)), length(dFdy(v_texcoord)));
}

float luma(vec3 color) {
    return dot(color, LUMA_WEIGHTS);
}

vec3 sample_rgb_split(vec2 uv_r, vec2 uv_g, vec2 uv_b) {
    return vec3(
        texture(tex, uv_r).r,
        texture(tex, uv_g).g,
        texture(tex, uv_b).b
    );
}

vec2 pixelate_uv(vec2 uv) {
    if (!ENABLE_PIXELATION) return uv;

    return floor(uv * PIXEL.grid_size) / PIXEL.grid_size;
}

vec3 sample_with_chromatic_aberration(vec2 uv) {
    if (!ENABLE_CHROMATIC_ABERRATION) {
        return texture(tex, uv).rgb;
    }

    vec2 dir = (uv - 0.5) * CA.falloff;
    float c = cos(CA.angle);
    float s = sin(CA.angle);
    dir = mat2(c, -s, s, c) * dir;

    float dist = length(dir);
    float falloff_curve = pow(dist, CA.falloff_exp);
    float falloff = falloff_curve + (1.0 - falloff_curve) * CA.center_boost;

    vec2 offset = dir * falloff;
    return sample_rgb_split(
        uv + offset * CA.red_offset,
        uv,
        uv - offset * CA.blue_offset
    );
}

vec3 apply_color_bleed(vec2 uv, vec3 color) {
    if (!ENABLE_COLOR_BLEED) return color;

    vec3 bleed_accumulator = vec3(0.0);
    float step = BLEED.distance / float(BLEED.samples);

    for (int i = 1; i <= BLEED.samples; i++) {
        vec2 sample_uv = uv - vec2(float(i) * step, 0.0);
        bleed_accumulator += texture(tex, sample_uv).rgb;
    }

    vec3 bleed_avg = bleed_accumulator / float(BLEED.samples);

    float orig_luma = luma(color);
    vec3 orig_chroma = color - orig_luma;
    vec3 bleed_chroma = bleed_avg - luma(bleed_avg);

    return vec3(orig_luma) + mix(orig_chroma, bleed_chroma, BLEED.strength);
}

vec3 apply_glitch(vec2 uv, vec3 color) {
    if (!ENABLE_GLITCH) return color;

    float interval_id = floor(time / GLITCH.interval);
    float time_in_interval = fract(time / GLITCH.interval);

    float trigger_hash = hash(vec2(interval_id, 0.0));
    bool is_glitch_active = trigger_hash < GLITCH.probability &&
                            time_in_interval < GLITCH.duration;

    if (!is_glitch_active) return color;

    float strength = GLITCH.strength * sin(time_in_interval * GLITCH.speed * PI);
    vec2 glitch_uv = uv;

    float scanline_id = floor(uv.y * 480.0);
    float line_rand = hash(vec2(scanline_id, time));
    if (line_rand > 0.985) {
        float shift = 0.02 * strength * (hash(vec2(line_rand, time)) - 0.5);
        glitch_uv.x += shift;
    }

    glitch_uv.x += sin(uv.y * 40.0 + time * 6.0) * 0.002 * strength;

    float rgb_shift = 0.0015 * sin(time * 2.0 + uv.y * 10.0) * strength;
    vec3 glitch_color = sample_rgb_split(
        glitch_uv + vec2(rgb_shift, 0.0),
        glitch_uv,
        glitch_uv - vec2(rgb_shift, 0.0)
    );

    float block_id = floor(uv.y * 20.0);
    float block_trigger = hash(vec2(block_id, floor(time * 10.0)));
    if (block_trigger > 0.95) {
        float block_shift = (hash(vec2(block_id, time)) - 0.5) * 0.05 * strength;
        glitch_color = sample_rgb_split(
            glitch_uv + vec2(block_shift, 0.0),
            glitch_uv,
            glitch_uv - vec2(block_shift, 0.0)
        );
    }

    return mix(color, glitch_color, strength);
}

vec3 apply_pixel_grid(vec2 uv, vec3 color) {
    if (!ENABLE_PIXELATION) return color;

    vec2 grid_coords = fract(uv * PIXEL.grid_size);
    vec2 grid_lines = smoothstep(0.95, 0.99, grid_coords);
    float grid_mask = 1.0 - max(grid_lines.x, grid_lines.y);

    return color * mix(vec3(0.2), vec3(1.0), grid_mask);
}

vec3 apply_film_grain(vec2 uv, vec3 color) {
    if (!ENABLE_FILM_GRAIN) return color;

    float frame = floor(mod(time, 1000.0) * GRAIN.speed);
    vec2 grain_uv = (uv * get_resolution()) / max(GRAIN.size, 0.1);
    grain_uv += hash22(vec2(frame)) * 100.0;

    float mono_grain = hash(vec3(grain_uv, frame));

    vec3 chroma_grain = vec3(
        hash(vec3(grain_uv + 0.1, frame)),
        hash(vec3(grain_uv + 0.2, frame)),
        hash(vec3(grain_uv + 0.3, frame))
    );

    float response = 1.0 - pow(luma(color), 2.0);

    color += (mono_grain - 0.5) * GRAIN.intensity * GRAIN.luma_amount * response;
    color += (chroma_grain - 0.5) * GRAIN.intensity * GRAIN.chroma_amount * response;

    return clamp(color, 0.0, 1.0);
}

void main() {
    float alpha = texture(tex, v_texcoord).a;

    vec2 uv = pixelate_uv(v_texcoord);

    vec3 color = sample_with_chromatic_aberration(uv);
    color = apply_color_bleed(uv, color);
    color = apply_glitch(uv, color);
    color = apply_pixel_grid(uv, color);
    color = apply_film_grain(uv, color);

    fragColor = vec4(color, alpha);
}
