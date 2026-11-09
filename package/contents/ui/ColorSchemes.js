.pragma library

var PRESETS = [
    {
        id: "celestial_silk",
        name: "Celestial Silk (Light)",
        bgStart: "#c9d6e8",
        bgMid: "#b8c8df",
        bgEnd: "#c4d0e4",
        wave1: "#8fb0e8",
        wave2: "#9a8fe0",
        wave3: "#7aa2e6",
        wave4: "#3f58b0"
    },
    {
        id: "ps3_sapphire",
        name: "PS3 Midnight Sapphire (Dark)",
        bgStart: "#0f2042",
        bgMid: "#09152e",
        bgEnd: "#050b1a",
        wave1: "#5aa9e6",
        wave2: "#6c75e0",
        wave3: "#3a86ff",
        wave4: "#1d3e7a"
    },
    {
        id: "emerald_breeze",
        name: "Emerald Breeze (Light)",
        bgStart: "#c8e4dc",
        bgMid: "#b5d8ce",
        bgEnd: "#c1dfd6",
        wave1: "#74c69d",
        wave2: "#56b89e",
        wave3: "#48a98c",
        wave4: "#236b56"
    },
    {
        id: "emerald_depths",
        name: "Emerald Depths (Dark)",
        bgStart: "#0d2b26",
        bgMid: "#081c18",
        bgEnd: "#04110e",
        wave1: "#52b788",
        wave2: "#48cae4",
        wave3: "#2d8a68",
        wave4: "#184e3b"
    },
    {
        id: "amethyst_dusk",
        name: "Amethyst Dusk (Dark)",
        bgStart: "#231942",
        bgMid: "#17102e",
        bgEnd: "#0e091e",
        wave1: "#be95c4",
        wave2: "#9f86c0",
        wave3: "#7b52ab",
        wave4: "#4a2c7a"
    },
    {
        id: "sakura_mist",
        name: "Sakura Mist (Light)",
        bgStart: "#ead4de",
        bgMid: "#dfc3d0",
        bgEnd: "#e6ced9",
        wave1: "#e5989b",
        wave2: "#d88ca4",
        wave3: "#c97a95",
        wave4: "#8f3d5e"
    },
    {
        id: "sunset_amber",
        name: "Sunset Amber (Dark)",
        bgStart: "#2d162c",
        bgMid: "#1e0f21",
        bgEnd: "#120816",
        wave1: "#f4a261",
        wave2: "#e76f51",
        wave3: "#d6576b",
        wave4: "#7a284b"
    },
    {
        id: "crimson_silk",
        name: "Crimson Silk (Dark)",
        bgStart: "#2b0912",
        bgMid: "#1b050b",
        bgEnd: "#0f0306",
        wave1: "#e63946",
        wave2: "#d9385a",
        wave3: "#a4133c",
        wave4: "#590d22"
    },
    {
        id: "monochrome_silver",
        name: "Monochrome Silver (Dark)",
        bgStart: "#1e2229",
        bgMid: "#14171c",
        bgEnd: "#0c0e12",
        wave1: "#adb5bd",
        wave2: "#8d99ae",
        wave3: "#6c757d",
        wave4: "#343a40"
    }
];

function getPresetById(id) {
    for (var i = 0; i < PRESETS.length; ++i) {
        if (PRESETS[i].id === id) {
            return PRESETS[i];
        }
    }
    return PRESETS[0];
}

function clamp(v, minVal, maxVal) {
    return Math.max(minVal, Math.min(maxVal, v));
}

function wrapHue(h) {
    var r = h % 1.0;
    return r < 0.0 ? r + 1.0 : r;
}

function parseRgb(c) {
    if (typeof c === "object" && c !== null && c.r !== undefined) {
        return { r: clamp(c.r, 0, 1), g: clamp(c.g, 0, 1), b: clamp(c.b, 0, 1) };
    }
    var s = String(c || "#5b8dd9").trim();
    if (s.charAt(0) === "#") {
        s = s.substring(1);
    }
    if (s.length === 8) {
        // #AARRGGBB from QColor
        s = s.substring(2);
    }
    if (s.length === 3) {
        s = s[0] + s[0] + s[1] + s[1] + s[2] + s[2];
    }
    var num = parseInt(s, 16);
    if (isNaN(num)) {
        return { r: 0.357, g: 0.553, b: 0.851 };
    }
    return {
        r: ((num >> 16) & 255) / 255.0,
        g: ((num >> 8) & 255) / 255.0,
        b: (num & 255) / 255.0
    };
}

function rgbToHsl(r, g, b) {
    var max = Math.max(r, g, b);
    var min = Math.min(r, g, b);
    var h = 0;
    var s = 0;
    var l = (max + min) / 2.0;

    if (max !== min) {
        var d = max - min;
        s = l > 0.5 ? d / (2.0 - max - min) : d / (max + min);
        switch (max) {
            case r:
                h = (g - b) / d + (g < b ? 6.0 : 0.0);
                break;
            case g:
                h = (b - r) / d + 2.0;
                break;
            case b:
                h = (r - g) / d + 4.0;
                break;
        }
        h /= 6.0;
    }
    return { h: h, s: s, l: l };
}

function hue2rgb(p, q, t) {
    if (t < 0.0) t += 1.0;
    if (t > 1.0) t -= 1.0;
    if (t < 1.0 / 6.0) return p + (q - p) * 6.0 * t;
    if (t < 1.0 / 2.0) return q;
    if (t < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - t) * 6.0;
    return p;
}

function toHexByte(v) {
    var n = Math.round(clamp(v, 0.0, 1.0) * 255.0);
    var s = n.toString(16);
    return s.length < 2 ? "0" + s : s;
}

function hslToHex(h, s, l) {
    h = wrapHue(h);
    s = clamp(s, 0.0, 1.0);
    l = clamp(l, 0.0, 1.0);

    var r, g, b;
    if (s === 0.0) {
        r = g = b = l;
    } else {
        var q = l < 0.5 ? l * (1.0 + s) : l + s - l * s;
        var p = 2.0 * l - q;
        r = hue2rgb(p, q, h + 1.0 / 3.0);
        g = hue2rgb(p, q, h);
        b = hue2rgb(p, q, h - 1.0 / 3.0);
    }
    return "#" + toHexByte(r) + toHexByte(g) + toHexByte(b);
}

// Generates a cohesive, flowing 3-stop background + 4-wave palette from a single seed color.
// style: 0 = Soft Silk (Light), 1 = Deep XMB (Dark), 2 = Rich Dusk
function generateHarmonyPalette(baseColor, style) {
    var rgb = parseRgb(baseColor);
    var hsl = rgbToHsl(rgb.r, rgb.g, rgb.b);
    var h = hsl.h;
    var achromatic = hsl.s < 0.06;
    var sWave = achromatic ? hsl.s : clamp(Math.max(hsl.s, 0.55), 0.40, 0.85);

    var bgStart, bgMid, bgEnd;
    var wave1, wave2, wave3, wave4;

    if (style === 1) {
        // Deep XMB Dark (Midnight style)
        var sDark = achromatic ? hsl.s : clamp(sWave * 0.78, 0.30, 0.68);
        bgStart = hslToHex(h - 4.0 / 360.0, sDark, 0.16);
        bgMid   = hslToHex(h,               sDark, 0.10);
        bgEnd   = hslToHex(h + 6.0 / 360.0, sDark, 0.05);

        wave1 = hslToHex(h - 6.0 / 360.0,  sWave, 0.65);
        wave2 = hslToHex(h + 15.0 / 360.0, clamp(sWave * 0.90, 0, 0.82), 0.62);
        wave3 = hslToHex(h - 10.0 / 360.0, sWave, 0.56);
        wave4 = hslToHex(h + 6.0 / 360.0,  clamp(sWave * 1.05, 0, 0.85), 0.32);
    } else if (style === 2) {
        // Rich Dusk (Twilight mid-dark style)
        var sDusk = achromatic ? hsl.s : clamp(sWave * 0.65, 0.25, 0.58);
        bgStart = hslToHex(h - 6.0 / 360.0, sDusk, 0.28);
        bgMid   = hslToHex(h,               sDusk, 0.20);
        bgEnd   = hslToHex(h + 8.0 / 360.0, sDusk, 0.14);

        wave1 = hslToHex(h - 6.0 / 360.0,  sWave, 0.70);
        wave2 = hslToHex(h + 16.0 / 360.0, clamp(sWave * 0.88, 0, 0.82), 0.66);
        wave3 = hslToHex(h - 10.0 / 360.0, sWave, 0.60);
        wave4 = hslToHex(h + 6.0 / 360.0,  clamp(sWave * 1.02, 0, 0.85), 0.38);
    } else {
        // Soft Silk (Airy Pastel Light style)
        var sBg = achromatic ? hsl.s : clamp(sWave * 0.56, 0.24, 0.44);
        bgStart = hslToHex(h - 3.0 / 360.0, sBg, 0.85);
        bgMid   = hslToHex(h,               clamp(sBg * 1.06, 0, 0.48), 0.80);
        bgEnd   = hslToHex(h + 3.0 / 360.0, clamp(sBg * 0.95, 0, 0.44), 0.83);

        wave1 = hslToHex(h - 4.0 / 360.0,  sWave, 0.74);
        wave2 = hslToHex(h + 18.0 / 360.0, clamp(sWave * 0.86, 0, 0.80), 0.72);
        wave3 = hslToHex(h - 8.0 / 360.0,  sWave, 0.69);
        wave4 = hslToHex(h + 6.0 / 360.0,  clamp(sWave * 0.92, 0, 0.82), 0.47);
    }

    return {
        bgStart: bgStart,
        bgMid: bgMid,
        bgEnd: bgEnd,
        wave1: wave1,
        wave2: wave2,
        wave3: wave3,
        wave4: wave4
    };
}

function resolvePalette(mode, presetId, harmonyColor, harmonyStyle, customColors) {
    if (mode === 1) {
        return generateHarmonyPalette(harmonyColor, harmonyStyle);
    }
    if (mode === 2 && customColors) {
        return {
            bgStart: customColors.bgStart,
            bgMid: customColors.bgMid,
            bgEnd: customColors.bgEnd,
            wave1: customColors.wave1,
            wave2: customColors.wave2,
            wave3: customColors.wave3,
            wave4: customColors.wave4
        };
    }
    return getPresetById(presetId);
}
