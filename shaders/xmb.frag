#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float u_time;
    float u_width;
    float u_height;
    vec4 u_slidePhases;
    vec4 u_bobPhases;
    vec4 u_bgStart;
    vec4 u_bgMid;
    vec4 u_bgEnd;
    vec4 u_wave1;
    vec4 u_wave2;
    vec4 u_wave3;
    vec4 u_wave4;
};

const float PI = 3.14159265358979323846;

// Deepens and slightly enriches a wave's base color for its bottom gradient stop
vec3 deepenColor(vec3 c) {
    return clamp(pow(max(c, vec3(0.001)), vec3(1.32)) * 0.90, 0.0, 1.0);
}

// Evaluates and composites a single XMB ribbon layer (fill gradient + 2px top crest stroke)
// using analytical piecewise quadratic-Bezier wave geometry.
vec3 compositeWave(
    vec3 dstCol,
    vec2 uv,
    float safeHeight,
    float aspect,
    float topVh,
    float heightVh,
    float periodVh,
    float slideRate,
    float slidePhase,
    float bobPeriod,
    float bobSign,
    float bobPhase,
    float dyc,
    vec4 waveColor,
    float stop0Alpha,
    float stopMidOffset,
    float stopMidAlpha,
    float stopEndAlpha,
    float strokeAlpha,
    bool isBottomWave
) {
    // 1. Vertical bobbing: ±3vh cosine ease-in-out oscillation
    float bobVh = bobSign * 0.03 * cos(PI * (u_time / bobPeriod + bobPhase));
    float stripTop = topVh + bobVh;

    // Early out if pixel is well above the highest possible crest or below the strip
    float vStrip = (uv.y - stripTop) / heightVh;
    float halfAmp = 0.5 * abs(dyc);
    float vMin = 0.40 - halfAmp; // Bounding-box top (0.225 for waves 1-2, 0.25 for waves 3-4)

    // Allow a small margin above vMin for the 2px crest stroke
    float strokeMarginV = 4.0 / max(safeHeight * heightVh, 1.0);
    if (vStrip < vMin - strokeMarginV || vStrip > 1.0 + strokeMarginV) {
        return dstCol;
    }

    // 2. Horizontal coordinate in wave periods (scaled strictly by viewport height vh,
    //    never stretching with aspect ratio)
    float xVh = uv.x * aspect;
    float u = fract(xVh / periodVh + u_time * slideRate + slidePhase);

    // 3. Analytical quadratic Bezier wave: M0 160 Q360 yc 720 160 T1440 160 ...
    //    First half-period u in [0, 0.5), second half-period u in [0.5, 1.0)
    float halfSign = (u < 0.5) ? 1.0 : -1.0;
    float s = (u < 0.5) ? (2.0 * u) : (2.0 * u - 1.0);

    // Curve centerline in strip-normalized vertical coordinates [0, 1]
    float vCurve = 0.40 + halfSign * 2.0 * s * (1.0 - s) * dyc;
    // Derivative dvCurve / du
    float dvDu = halfSign * 4.0 * (1.0 - 2.0 * s) * dyc;

    // 4. Exact screen-pixel slope (dY_px / dX_px) and perpendicular Euclidean distance in pixels
    float slopePx = (heightVh / periodVh) * dvDu;
    float dyPx = (vStrip - vCurve) * heightVh * safeHeight;
    float dPerpPx = dyPx * inversesqrt(1.0 + slopePx * slopePx);

    // Bottom edge anti-aliasing if the bottom of the strip is visible on screen
    float bottomDistPx = (1.0 - vStrip) * heightVh * safeHeight;
    float bottomMask = clamp(0.5 + bottomDistPx, 0.0, 1.0);

    // Top edge anti-aliased fill coverage (pixels below the curve have dPerpPx > 0)
    float fillGeomMask = clamp(0.5 + dPerpPx, 0.0, 1.0) * bottomMask;

    // 5. Evaluate 3-stop vertical linear gradient in objectBoundingBox coordinates [vMin, 1.0]
    if (fillGeomMask > 0.0005) {
        float g = clamp((vStrip - vMin) / max(1.0 - vMin, 0.0001), 0.0, 1.0);

        vec3 c0 = isBottomWave
            ? clamp(mix(waveColor.rgb, vec3(0.88, 0.92, 1.0), 0.34), 0.0, 1.0)
            : vec3(1.0);
        vec3 c1 = waveColor.rgb;
        vec3 c2 = deepenColor(waveColor.rgb);

        vec3 gradRgb;
        float gradAlpha;
        if (g < stopMidOffset) {
            float t = g / stopMidOffset;
            gradRgb = mix(c0, c1, t);
            gradAlpha = mix(stop0Alpha, stopMidAlpha, t);
        } else {
            float t = (g - stopMidOffset) / (1.0 - stopMidOffset);
            gradRgb = mix(c1, c2, t);
            gradAlpha = mix(stopMidAlpha, stopEndAlpha, t);
        }

        float finalFillAlpha = clamp(gradAlpha * waveColor.a * fillGeomMask, 0.0, 1.0);
        dstCol = mix(dstCol, gradRgb, finalFillAlpha);
    }

    // 6. Crisp 2px anti-aliased white crest stroke
    //    Half-width = 1.0px, with 1.0px sub-pixel AA feathering across [-1.5, +1.5]
    float strokeMask = clamp(1.5 - abs(dPerpPx), 0.0, 1.0);
    if (strokeMask > 0.0005) {
        float finalStrokeAlpha = clamp(strokeAlpha * waveColor.a * strokeMask, 0.0, 1.0);
        dstCol = mix(dstCol, vec3(1.0), finalStrokeAlpha);
    }

    return dstCol;
}

void main() {
    float safeW = max(u_width, 1.0);
    float safeH = max(u_height, 1.0);
    float aspect = safeW / safeH;
    vec2 uv = qt_TexCoord0;

    // 1. Background 135-degree 3-stop linear gradient:
    //    linear-gradient(135deg, bgStart 0%, bgMid 50%, bgEnd 100%)
    vec2 px = uv * vec2(safeW, safeH);
    float bgT = clamp((px.x + px.y) / (safeW + safeH), 0.0, 1.0);
    vec3 col = (bgT < 0.5)
        ? mix(u_bgStart.rgb, u_bgMid.rgb, bgT * 2.0)
        : mix(u_bgMid.rgb, u_bgEnd.rgb, (bgT - 0.5) * 2.0);

    // 2. Wave 1: width 1068vh (1.78vh/period), top 16%, height 55vh, slide 135s (45s/period), bob 11s
    col = compositeWave(
        col, uv, safeH, aspect,
        0.16, 0.55, 1.78, +1.0 / 45.0, u_slidePhases.x,
        11.0, -1.0, u_bobPhases.x, -0.35,
        u_wave1, 0.75, 0.35, 0.45, 0.00, 0.80, false
    );

    // 3. Wave 2: width 1386vh (2.31vh/period), top 24%, height 55vh, slide 186s reverse (62s/period), bob 14s rev
    col = compositeWave(
        col, uv, safeH, aspect,
        0.24, 0.55, 2.31, -1.0 / 62.0, u_slidePhases.y,
        14.0, +1.0, u_bobPhases.y, +0.35,
        u_wave2, 0.60, 0.35, 0.40, 0.00, 0.70, false
    );

    // 4. Wave 3: width 1704vh (2.84vh/period), top 32%, height 55vh, slide 240s (80s/period), bob 17s
    col = compositeWave(
        col, uv, safeH, aspect,
        0.32, 0.55, 2.84, +1.0 / 80.0, u_slidePhases.z,
        17.0, -1.0, u_bobPhases.z, -0.30,
        u_wave3, 0.55, 0.35, 0.40, 0.00, 0.65, false
    );

    // 5. Wave 4: width 1224vh (2.04vh/period), top 34%, height 70vh, slide 300s reverse (100s/period), bob 20s rev
    col = compositeWave(
        col, uv, safeH, aspect,
        0.34, 0.70, 2.04, -1.0 / 100.0, u_slidePhases.w,
        20.0, +1.0, u_bobPhases.w, +0.30,
        u_wave4, 0.75, 0.30, 0.70, 0.60, 0.60, true
    );

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
