#version 450

// Inputs
layout(location = 0) in vec3 inNormal;
layout(location = 1) in vec2 inUV;
layout(location = 2) in vec3 inViewVec;
layout(location = 3) in vec3 inWorldPos;
layout(location = 4) in vec4 wire_color;
layout(location = 5) noperspective in vec3 edge_dist;

// Uniforms
layout(set = 1, binding = 0) uniform sampler2D terrain_height_tex;
layout(set = 1, binding = 1) uniform sampler2D normal;
layout(set = 1, binding = 2) uniform sampler2D albedo;

struct PointLight {
    vec3 position;
    vec3 color;
    float intensity;
};

struct DirectionalLight {
    vec3 color;
    vec3 direction;
};

struct SpotLight {
    vec3 position;
    vec3 color;
    vec3 direction;
    float angle;
    float intensity;
    float range;
    float smoothness;
};
layout (std140, set = 0, binding = 0) uniform Args {
    mat4 proj;
    mat4 view;
    mat4 model;
    vec2 terrain_size;
    float terrain_height_scale;
    float terrain_height_offset;
    float wireframe;
};

layout (set = 2, binding = 0) uniform Environment {
    vec3 camera_position;
    vec3 ambient_color;
    int point_light_count;
    int directional_light_count;
    int spot_light_count;
};
layout (set = 2, binding = 1) uniform PointLights {
    PointLight plight[128];
};
layout (set = 2, binding = 2) uniform DirectionsLights {
    DirectionalLight dlight[16];
};
layout (set = 2, binding = 3) uniform SpotLights {
    SpotLight slight[128];
};

// layout(set = 2, binding = 4) uniform float toggle_wireframe;
// layout(location = 0) uniform float patch_scale;


// Ouputs
layout(location = 0) out vec4 fragColor;

const float PI = 3.14159265359;

float tex_coord(float coord, vec2 offset) {
    return offset.x + coord * (offset.y - offset.x);
}

vec2 tex_coords(vec2 coord, vec2 u, vec2 v) {
    return vec2(tex_coord(coord.x, u), tex_coord(coord.y, v));
}
float normal_distribution(vec3 N, vec3 H, float a) {
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH*NdotH;

    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return (a2 + 0.0000001) / denom;
}

float geometry(float NdotV, float NdotL, float r2) {
    float a1 = r2 + 1.0;
    float k = a1 * a1 / 8.0;
    float denom = NdotV * (1.0 - k) + k;
    float ggx1 = NdotV / denom;
    denom = NdotL * (1.0 - k) + k;
    float ggx2 = NdotL / denom;
    return ggx1 * ggx2;
}

vec3 fresnel(float HdotV, vec3 fresnel_base) {
    return fresnel_base + (1.0 - fresnel_base) * pow(1.0 - HdotV, 5.0);
}

vec3 compute_light(vec3 attenuation,
                   vec3 light_color,
                   vec3 view_direction,
                   vec3 light_direction,
                   vec3 albedo,
                   vec3 normal,
                   float roughness2,
                   float metallic,
                   vec3 fresnel_base) {

    vec3 halfway = normalize(view_direction + light_direction);
    float normal_distribution = normal_distribution(normal, halfway, roughness2);

    float NdotV = max(dot(normal, view_direction), 0.0);
    float NdotL = max(dot(normal, light_direction), 0.0);
    float HdotV = max(dot(halfway, view_direction), 0.0);
    float geometry = geometry(NdotV, NdotL, roughness2);

    vec3 fresnel = fresnel(HdotV, fresnel_base);
    vec3 diffuse = vec3(1.0) - fresnel;
    diffuse *= 1.0 - metallic;

    vec3 nominator = normal_distribution * geometry * fresnel;
    float denominator = 4 * NdotV * NdotL + 0.0001;
    vec3 specular = nominator / denominator;

    vec3 resulting_light = (diffuse * albedo / PI + specular) * light_color * attenuation * NdotL;
    return resulting_light;
}

void main()
{

    vec4 albedo_alpha       = texture(albedo, inUV);

    float alpha             = albedo_alpha.a;
    // if(alpha < 1.0) discard;t

    vec3 albedo             = albedo_alpha.rgb;

    //vec4 color = vec4(mix(0.0, 1.0, tileScale / 1000.0), mix(1.0, 0.0, tileScale / 1000.0), 0.0, 1.0);
    // vec3 normal = texture(normal, gs.tex_coord).rgb;
    vec3 normal = texture(normal, inUV).rgb;
    float metallic = 0.;
    float roughness = 1.;

    normal = normal * 2. - 1.;

    float roughness2 = 1.;
    vec3 fresnel_base = mix(vec3(0.04), albedo, 0.);

    vec3 vertex_normal = normalize(vec3(0.0, 1.0, 0.0));
    vec3 vertex_tangent = normalize(vec3(0.0, 0.0, 1.0));
    vec3 vertex_bitangent = normalize(cross(vertex_normal, vertex_tangent));
    mat3 vertex_basis = mat3(vertex_tangent, vertex_bitangent, vertex_normal);
    normal = normalize(vertex_basis * normal);


    // vec3 view_direction = normalize(camera_position - inPosition.xyz);
    vec3 view_direction = normalize(inViewVec);

    vec3 lighting = vec3(0.0);
    // for (uint i = 0u; i < point_light_count; i++) {
    //     vec3 light_direction = normalize(plight[i].position - gs.position);
    //     float attenuation = plight[i].intensity / dot(light_direction, light_direction);

    //     vec3 light = compute_light(vec3(attenuation),
    //                                plight[i].color,
    //                                view_direction,
    //                                light_direction,
    //                                albedo,
    //                                normal,
    //                                roughness2,
    //                                metallic,
    //                                fresnel_base);


    //     lighting += light;
    // }

    for (uint i = 0u; i < directional_light_count; i++) {
        vec3 light_direction = -normalize(dlight[i].direction);
        float attenuation = 1.0;

        vec3 light = compute_light(vec3(attenuation),
                                   dlight[i].color,
                                   view_direction,
                                   light_direction,
                                   albedo,
                                   normal,
                                   roughness2,
                                   metallic,
                                   fresnel_base);
        lighting += light;
    }

    // for (int i = 0; i < spot_light_count; i++) {
    //     vec3 light_vec = slight[i].position - gs.position;
    //     vec3 normalized_light_vec = normalize(light_vec);

    //     // The distance between the current fragment and the "core" of the light
    //     float light_length = length(light_vec);

    //     // The allowed "length", everything after this won't be lit.
    //     // Later on we are dividing by this range, so it can't be 0
    //     float range = max(slight[i].range, 0.00001);

    //     // get normalized range, so everything 0..1 could be lit, everything else can't.
    //     float normalized_range = light_length / max(0.00001, range);

    //     // The attenuation for the "range". If we would only consider this, we'd have a
    //     // point light instead, so we need to also check for the spot angle and direction.
    //     float range_attenuation = max(0.0, 1.0 - normalized_range);

    //     // this is actually the cosine of the angle, so it can be compared with the
    //     // "dotted" frag_angle below a lot cheaper.
    //     float spot_angle = max(slight[i].angle, 0.00001);
    //     vec3 spot_direction = normalize(slight[i].direction);
    //     float smoothness = 1.0 - slight[i].smoothness;

    //     // Here we check if the current fragment is within the "ring" of the spotlight.
    //     float frag_angle = dot(spot_direction, -normalized_light_vec);

    //     // so that the ring_attenuation won't be > 1
    //     frag_angle = max(frag_angle, spot_angle);

    //     // How much is this outside of the ring? (let's call it "rim")
    //     // Also smooth this out.
    //     float rim_attenuation = pow(max((1.0 - frag_angle) / (1.0 - spot_angle), 0.00001), smoothness);

    //     // How much is this inside the "ring"?
    //     float ring_attenuation = 1.0 - rim_attenuation;

    //     // combine the attenuations and intensity
    //     float attenuation = range_attenuation * ring_attenuation * slight[i].intensity;

    //     vec3 light = compute_light(vec3(attenuation),
    //                                slight[i].color,
    //                                view_direction,
    //                                normalize(light_vec),
    //                                albedo,
    //                                normal,
    //                                roughness2,
    //                                metallic,
    //                                fresnel_base);
    //     lighting += light;
    // }

    // Wireframe junk
    float d = min(edge_dist.x, edge_dist.y);
    d = min(d, edge_dist.z);

    float LineWidth = 0.75;
    float mixVal = smoothstep(LineWidth - 1, LineWidth + 1, d);

    vec3 ambient = vec3(0.5) * albedo;
    vec3 color = ambient + lighting;

    if (wireframe == 1.0)
        fragColor = mix(wire_color, vec4(color, 1.0), mixVal);
    else
        fragColor = vec4(color, 1.0); 
}