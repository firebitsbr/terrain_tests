#version 450

// Inputs
layout(location = 0) in vec3 in_pos;
layout(location = 1) in vec3 in_normal;
layout(location = 2) in vec2 in_uv;
layout(location = 3) in float in_patch_scale;
layout(location = 4) in vec3 in_patch_origin;
layout(location = 5) in ivec4 in_neighbour_scales;

// Uniforms
layout (std140, set = 0, binding = 0) uniform Args {
    mat4 proj;
    mat4 view;
    mat4 model;
    vec2 terrain_size;
    float terrain_height_scale;
    float terrain_height_offset;
    float wireframe;
};


// Outputs
layout(location = 0) out vec3 out_normal;
layout(location = 1) out vec2 out_uv;
layout(location = 2) out ivec4 out_neighbour_scales;

vec2 calcTerrainTexCoord(in vec4 pos)
{
    return vec2(abs(pos.x - model[3][0]) / terrain_size.x, abs(pos.z - model[3][2]) / terrain_size.y);
}

void main()
{
    // Calcuate texture coordantes (u,v) relative to entire terrain
    gl_Position = model * vec4((in_pos.xyz * in_patch_scale) + in_patch_origin, 1.0);
    out_normal = in_normal;
    out_neighbour_scales = in_neighbour_scales;
    out_uv = calcTerrainTexCoord(gl_Position);

}