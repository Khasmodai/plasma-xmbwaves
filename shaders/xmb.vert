#version 440

layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;

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

out gl_PerVertex { vec4 gl_Position; };

void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = qt_Matrix * qt_Vertex;
}
