// TODO-3: implement the Clustered Deferred fullscreen fragment shader

// Similar to the Forward+ fragment shader, but with vertex information coming from the G-buffer instead.

@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;

@group(${bindGroup_gbuffer}) @binding(0) var positionTex: texture_2d<f32>;
@group(${bindGroup_gbuffer}) @binding(1) var normalTex: texture_2d<f32>;
@group(${bindGroup_gbuffer}) @binding(2) var albedoTex: texture_2d<f32>;

struct FragmentInput{
    @location(0) uv: vec2f,
    @builtin(position) fragCoord: vec4f
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {
    let pixelCoord = vec2<i32>(in.fragCoord.xy);

    let worldSample = textureLoad(positionTex, pixelCoord, 0);
    let normalSample = textureLoad(normalTex, pixelCoord, 0);
    let albedoSample = textureLoad(albedoTex, pixelCoord, 0);

    if (albedoSample.a < 0.5){
        discard;
    }

    let worldPos = worldSample.xyz;
    let normal = normalize(normalSample.xyz);

    let clipPos = camera.viewProjMat * vec4f(worldPos, 1.0);
    let ndcPos = clipPos.xyz / clipPos.w;

    let viewPos = camera.viewMat * vec4f(worldPos, 1.0);
    let viewZ = viewPos.z;

    let nx = clamp(ndcPos.x * 0.5 + 0.5, 0.0, 1.0);
    let ny = clamp(ndcPos.y * 0.5 + 0.5, 0.0, 1.0);

    let XClusters = f32(${XClusters});
    let YClusters = f32(${YClusters});
    let ZClusters = f32(${ZClusters});

    let clusterX = u32(clamp(floor(nx * XClusters), 0.0, XClusters - 1.0));
    let clusterY = u32(clamp(floor(ny * XClusters), 0.0, YClusters - 1.0));

    let safeViewZ = max(-viewZ, camera.nearPlane);
    let invLogDepth = 1.0 / log(camera.farPlane / camera.nearPlane);
    let zFrac = clamp(log(safeViewZ / camera.nearPlane) * invLogDepth, 0.0, 0.999999);
    let clusterZ = u32(floor(zFrac * ZClusters));

    let clusterIdx = clusterZ * ${XClusters} * ${YClusters} + clusterY * ${XClusters} + clusterX;
    let numClusterLights = clusterSet.clusters[clusterIdx].numLights;

    var totalLight = vec3f(0.0);
    for (var i: u32 = 0u; i < numClusterLights; i = i + 1u) {
        let lightIdx = clusterSet.clusters[clusterIdx].lightIndices[i];
        let light = lightSet.lights[lightIdx];
        totalLight += calculateLightContrib(light, worldPos, normal);
    }

    return vec4f(albedoSample.rgb * totalLight, 1.0);
}