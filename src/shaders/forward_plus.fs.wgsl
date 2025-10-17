// TODO-2: implement the Forward+ fragment shader

// See naive.fs.wgsl for basic fragment shader setup; this shader should use light clusters instead of looping over all lights

// ------------------------------------
// Shading process:
// ------------------------------------
// Determine which cluster contains the current fragment.
// Retrieve the number of lights that affect the current fragment from the cluster’s data.
// Initialize a variable to accumulate the total light contribution for the fragment.
// For each light in the cluster:
//     Access the light's properties using its index.
//     Calculate the contribution of the light based on its position, the fragment’s position, and the surface normal.
//     Add the calculated contribution to the total light accumulation.
// Multiply the fragment’s diffuse color by the accumulated light contribution.
// Return the final color, ensuring that the alpha component is set appropriately (typically to 1).

@group(${bindGroup_scene}) @binding(0) var<uniform>         camera: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read>   lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read>   clusterSet: ClusterSet;

@group(${bindGroup_material}) @binding(0) var baseColorTex : texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var baseColorSmp : sampler;

struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let diffuseCol = textureSample(baseColorTex, baseColorSmp, in.uv);
    if (diffuseCol.a < 0.5) {
        discard;
    }

    let clipPos = camera.viewProjMat * vec4f(in.pos, 1.0);
    let ndcPos = clipPos.xyz / clipPos.w;

    let viewPos = camera.viewMat * vec4f(in.pos, 1.0);
    let viewZ = viewPos.z;

    let XClusters = f32(${XClusters});
    let YClusters = f32(${YClusters});
    let ZClusters = f32(${ZClusters});

    let nx = clamp(ndcPos.x * 0.5 + 0.5, 0.0, 1.0);
    let ny = clamp(ndcPos.y * 0.5 + 0.5, 0.0, 1.0);

    let countX = u32(clamp(floor(nx * XClusters), 0.0, XClusters - 1.0));
    let countY = u32(clamp(floor(ny * YClusters), 0.0, YClusters - 1.0));
    
    let safeViewZ = max(-viewZ, camera.nearPlane);
    let invLogZPlane = 1.0 / log(camera.farPlane / camera.nearPlane);
    let zFrac = clamp(log(safeViewZ / camera.nearPlane) * invLogZPlane, 0.0, 0.999999);
    let countZ = u32(floor(zFrac * ZClusters));

    let clusterIdx = countZ * ${XClusters} * ${YClusters} + countY * ${XClusters} + countX;
    
    let count = clusterSet.clusters[clusterIdx].numLights;

    var totalLightContrib = vec3<f32>(0.0);
    for (var i: u32 = 0u; i < count; i = i + 1u) {
        let lightIdx = clusterSet.clusters[clusterIdx].lightIndices[i];
        let light = lightSet.lights[lightIdx];
        totalLightContrib += calculateLightContrib(light, in.pos, normalize(in.nor));
    }

    var finalColor = diffuseCol.rgb * totalLightContrib;
    return vec4<f32>(finalColor, 1);
}