#include <flutter/runtime_effect.glsl>

uniform vec2 resolution;
uniform float threshold;
uniform float contrast;
uniform sampler2D image;

out vec4 fragColor;

void main() {
    // Mevcut pikselin konumu
    vec2 uv = FlutterFragCoord().xy / resolution;
    vec2 step = 1.0 / resolution;

    // Etraftaki pikselleri oku (Sobel Edge Detection)
    float tleft = texture(image, uv + vec2(-step.x, -step.y)).r;
    float left = texture(image, uv + vec2(-step.x, 0.0)).r;
    float bleft = texture(image, uv + vec2(-step.x, step.y)).r;
    float top = texture(image, uv + vec2(0.0, -step.y)).r;
    float bottom = texture(image, uv + vec2(0.0, step.y)).r;
    float tright = texture(image, uv + vec2(step.x, -step.y)).r;
    float right = texture(image, uv + vec2(step.x, 0.0)).r;
    float bright = texture(image, uv + vec2(step.x, step.y)).r;

    // Kenarları hesapla
    float x = tleft + 2.0*left + bleft - tright - 2.0*right - bright;
    float y = -tleft - 2.0*top - tright + bleft + 2.0*bottom + bright;
    float color = sqrt((x*x) + (y*y));

    // Çizgiyi siyah, arkayı beyaz yap ve kontrast ekle
    color = 1.0 - color;
    color = (color - 0.5) * contrast + 0.5;

    // Kullanıcının belirlediği hassasiyete göre kes
    if (color < threshold) {
        color = 0.0; // Siyah çizgi
    } else {
        color = 1.0; // Beyaz kağıt
    }

    fragColor = vec4(vec3(color), 1.0);
}