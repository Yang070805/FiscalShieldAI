#version 460 core

#include <flutter/runtime_effect.glsl>

// ═══ Uniforms ═══
uniform vec2 uResolution;
uniform float uTime;
uniform vec2 uGlassCenter;
uniform vec2 uGlassSize;
uniform vec2 uMouse;
uniform float uMouseDown;
uniform float uAspectRatio;

// ═══ 工具函数 ═══
float smoothstep(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

vec2 rotate(vec2 p, float a) {
    float c = cos(a), s = sin(a);
    return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// ═══ SDF ═══
float roundedRectSDF(vec2 p, vec2 halfSize, float radius) {
    vec2 q = abs(p) - halfSize + radius;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
}

// ═══ 噪声 ═══
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i), hash(i + vec2(1, 0)), f.x),
        mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x),
        f.y
    );
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p *= 2.1;
        a *= 0.48;
    }
    return v;
}

// ═══ 液态玻璃 ═══
void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uResolution;

    // 宽高比校正
    vec2 ac = vec2(uv.x * uAspectRatio, uv.y);
    vec2 gc = vec2(uGlassCenter.x * uAspectRatio, uGlassCenter.y);
    vec2 gs = vec2(uGlassSize.x * uAspectRatio, uGlassSize.y);

    vec2 p = ac - gc;
    float t = uTime;

    // ── 鼠标交互 ──
    vec2 mouseOff = vec2(0.0);
    if (uMouseDown > 0.5) {
        vec2 mc = vec2(uMouse.x * uAspectRatio, uMouse.y);
        mouseOff = (mc - gc) * 0.2;
    }

    // ── 液态表面扭曲（多层叠加）──
    vec2 d = p;
    // 大波浪
    d.x += sin(p.y * 3.5 + t * 0.8) * 0.012;
    d.y += cos(p.x * 2.8 + t * 0.6) * 0.010;
    // 细涟漪
    d.x += sin(p.y * 8.0 + t * 1.5) * 0.004;
    d.y += cos(p.x * 7.0 + t * 1.2) * 0.003;
    // FBM 液态扰动
    float n = fbm(p * 6.0 + t * 0.25);
    d += (vec2(n, fbm(p * 6.0 + vec2(5.2, 1.3) + t * 0.2)) - 0.5) * 0.018;
    d += mouseOff;

    // ── SDF ──
    float radius = gs.x * 0.32;
    float dist = roundedRectSDF(d, gs * 0.5, radius);

    // ── 法线（SDF 梯度）──
    float e = 0.0008;
    vec2 norm = vec2(
        roundedRectSDF(d + vec2(e, 0), gs * 0.5, radius) -
        roundedRectSDF(d - vec2(e, 0), gs * 0.5, radius),
        roundedRectSDF(d + vec2(0, e), gs * 0.5, radius) -
        roundedRectSDF(d - vec2(0, e), gs * 0.5, radius)
    ) / (2.0 * e);
    norm = normalize(norm);

    // ── 折射 ──
    float edge = 1.0 - smoothstep(-0.025, 0.015, dist);
    float refractStr = edge * 0.09;

    // 色散（RGB 通道分离 → 彩虹边缘）
    float refractR = refractStr * 1.04;
    float refractG = refractStr * 1.00;
    float refractB = refractStr * 0.96;

    vec2 uvR = uv + norm * refractR;
    vec2 uvG = uv + norm * refractG;
    vec2 uvB = uv + norm * refractB;

    // ── 背景渐变 ──
    vec3 bgBase = mix(
        vec3(0.082, 0.118, 0.180),
        vec3(0.102, 0.157, 0.278),
        uv.y
    );
    // 动态光斑
    float g1 = smoothstep(0.9, 0.0, length(uv - vec2(0.25 + sin(t * 0.3) * 0.1, 0.3)));
    float g2 = smoothstep(0.7, 0.0, length(uv - vec2(0.75 + cos(t * 0.2) * 0.08, 0.65)));
    float g3 = smoothstep(0.5, 0.0, length(uv - vec2(0.5 + sin(t * 0.4) * 0.15, 0.5)));
    bgBase += vec3(0.035, 0.06, 0.065) * g1;
    bgBase += vec3(0.04, 0.045, 0.055) * g2;
    bgBase += vec3(0.05, 0.04, 0.07) * g3;

    // ── 折射后采样（色散）──
    vec3 sampleColor(vec2 ruv) {
        vec3 c = mix(
            vec3(0.082, 0.118, 0.180),
            vec3(0.102, 0.157, 0.278),
            ruv.y
        );
        float lg1 = smoothstep(0.9, 0.0, length(ruv - vec2(0.25 + sin(t * 0.3) * 0.1, 0.3)));
        float lg2 = smoothstep(0.7, 0.0, length(ruv - vec2(0.75 + cos(t * 0.2) * 0.08, 0.65)));
        float lg3 = smoothstep(0.5, 0.0, length(ruv - vec2(0.5 + sin(t * 0.4) * 0.15, 0.5)));
        c += vec3(0.035, 0.06, 0.065) * lg1;
        c += vec3(0.04, 0.045, 0.055) * lg2;
        c += vec3(0.05, 0.04, 0.07) * lg3;
        return c;
    }

    vec3 glassR = sampleColor(uvR);
    vec3 glassG = sampleColor(uvG);
    vec3 glassB = sampleColor(uvB);
    vec3 glassColor = vec3(glassR.r, glassG.g, glassB.b);

    // ── 内部深度渐变（暗角 + 底部加深）──
    float depth = 1.0 - smoothstep(0.2, 0.9, length(d / gs));
    glassColor *= 0.82 + depth * 0.18;
    // 底部微妙暗角
    float bottomShade = smoothstep(-0.1, 0.3, d.y / gs.y);
    glassColor *= 0.88 + bottomShade * 0.12;

    // ── 菲涅尔高光 ──
    float fresnel = pow(1.0 - abs(dot(norm, vec2(0.0, 1.0))), 4.0);

    // 主高光（随时间缓慢移动）
    vec2 hp1 = vec2(sin(t * 0.35) * 0.25 + 0.5, cos(t * 0.25) * 0.15 + 0.35);
    float hl1 = smoothstep(0.28, 0.0, length(d / gs - hp1)) * 0.45;

    // 次高光
    vec2 hp2 = vec2(cos(t * 0.45) * 0.2 + 0.6, sin(t * 0.55) * 0.12 + 0.55);
    float hl2 = smoothstep(0.22, 0.0, length(d / gs - hp2)) * 0.3;

    // 边缘高光带（rim light — 更锐利）
    float rim = smoothStep(0.025, 0.0, abs(dist));
    float rimGlow = smoothStep(0.05, 0.0, abs(dist)) * 0.6;

    // ── 合成 ──
    vec3 color = mix(bgBase, glassColor, edge * 0.7);

    // 菲涅尔高光
    color += vec3(0.88, 0.94, 0.97) * hl1 * fresnel;
    color += vec3(0.78, 0.88, 0.94) * hl2 * fresnel * 0.6;

    // 边缘发光
    color += vec3(0.42, 0.66, 0.69) * rim * 0.5;
    color += vec3(0.55, 0.78, 0.82) * rimGlow;

    // 内部微光（液态流动感）
    float innerGlow = fbm(d * 12.0 + t * 0.4) * 0.08 * edge;
    color += vec3(0.3, 0.5, 0.55) * innerGlow;

    // ── 最终混合 ──
    float alpha = smoothStep(0.012, -0.012, dist);
    color = mix(bgBase, color, alpha);

    fragColor = vec4(color, 1.0);
}
