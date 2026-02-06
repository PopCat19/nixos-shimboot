#version 320 es
precision highp float;

in vec2 v_texcoord;
out vec4 fragColor;

uniform sampler2D tex;

const float TEMPERATURE           = 3200.0;
const float TEMPERATURE_STRENGTH  = 1.0;
const float LUMINANCE_PRESERVATION_FACTOR = 1.0;
const float MIN_LUMINANCE         = 1e-5;
const vec3 LUMINANCE_WEIGHTS      = vec3(0.2126, 0.7152, 0.0722);

const float PI = 3.14159265359;

vec3 colorTemperatureToRGB(float temperature) {
    mat3 lowTempMatrix = mat3(
        vec3(0.0, -2902.1955373783176, -8257.7997278925690),
        vec3(0.0, 1669.5803561666639, 2575.2827530017594),
        vec3(1.0, 1.3302673723350029, 1.8993753891711275)
    );

    mat3 highTempMatrix = mat3(
        vec3(1745.0425298314172, 1216.6168361476490, -8257.7997278925690),
        vec3(-2666.3474220535695, -2173.1012343082230, 2575.2827530017594),
        vec3(0.55995389139931482, 0.70381203140554553, 1.8993753891711275)
    );

    mat3 m = (temperature <= 6500.0) ? lowTempMatrix : highTempMatrix;
    float clampedTemp = clamp(temperature, 1000.0, 40000.0);

    vec3 tempColor = clamp(
        vec3(m[0] / (vec3(clampedTemp) + m[1]) + m[2]),
        vec3(0.0),
        vec3(1.0)
    );

    return mix(tempColor, vec3(1.0), smoothstep(1000.0, 0.0, temperature));
}

vec3 preserveLuminance(vec3 color, float preservationFactor) {
    float originalLuminance = dot(color, LUMINANCE_WEIGHTS);
    float adjustedLuminance = max(originalLuminance, MIN_LUMINANCE);

    return mix(
        color,
        color * (originalLuminance / adjustedLuminance),
        preservationFactor
    );
}

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    vec3 color = pixColor.rgb;

    color = preserveLuminance(color, LUMINANCE_PRESERVATION_FACTOR);

    color = mix(
        color,
        color * colorTemperatureToRGB(TEMPERATURE),
        TEMPERATURE_STRENGTH
    );

    fragColor = vec4(color, pixColor.a);
}
