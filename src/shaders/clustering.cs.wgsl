// TODO-2: implement the light clustering compute shader

// ------------------------------------
// Calculating cluster bounds:
// ------------------------------------
// For each cluster (X, Y, Z):
//     - Calculate the screen-space bounds for this cluster in 2D (XY).
//     - Calculate the depth bounds for this cluster in Z (near and far planes).
//     - Convert these screen and depth bounds into view-space coordinates.
//     - Store the computed bounding box (AABB) for the cluster.

// ------------------------------------
// Assigning lights to clusters:
// ------------------------------------
// For each cluster:
//     - Initialize a counter for the number of lights in this cluster.

//     For each light:
//         - Check if the light intersects with the cluster’s bounding box (AABB).
//         - If it does, add the light to the cluster's light list.
//         - Stop adding lights if the maximum number of lights is reached.

//     - Store the number of lights assigned to this cluster.

@group(${bindGroup_scene}) @binding(0) var<uniform>             camera : CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read>       lightSet : LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read_write> clusterSet : ClusterSet;

fn ndcToView(ndc_xy: vec2<f32>, depth_view: f32, invProj: mat4x4f) -> vec3<f32> {
    let clipNear = vec4<f32>(ndc_xy.x, ndc_xy.y, -1.0, 1.0);
    let clipFar  = vec4<f32>(ndc_xy.x, ndc_xy.y,  1.0, 1.0);

    let vpNearH = invProj * clipNear;
    let vpFarH  = invProj * clipFar;

    let vpNear = vpNearH.xyz / vpNearH.w;
    let vpFar  = vpFarH.xyz  / vpFarH.w;

    let targetZ = -depth_view;

    let denom = vpFar.z - vpNear.z;
    if (abs(denom) < 1e-6) {
        return vpNear;
    }

    let t = (targetZ - vpNear.z) / denom;
    return vpNear + (vpFar - vpNear) * t;
}

@compute @workgroup_size(8, 8, 4)
fn main(@builtin(global_invocation_id) globalIdx: vec3u) {
    let XClusters = u32(${XClusters});
    let YClusters = u32(${YClusters});
    let ZClusters = u32(${ZClusters});

    if (globalIdx.x >= XClusters || globalIdx.y >= YClusters || globalIdx.z >= ZClusters){
        return;
    }

    let clusterIndex = globalIdx.z * XClusters * YClusters + globalIdx.y * XClusters + globalIdx.x;

    let resolution  = camera.canvasResolution;  

    let tileSize = vec2<f32>(resolution.x / f32(XClusters), resolution.y / f32(YClusters));
    let minPixel = vec2<f32>(f32(globalIdx.x), f32(globalIdx.y)) * tileSize;
    let maxPixel = minPixel + tileSize;

    var ndc00 = vec2<f32>(minPixel.x, minPixel.y) / resolution;
    ndc00 = ndc00 * 2.0 - vec2<f32>(1.0, 1.0);
    var ndc01 = vec2<f32>(minPixel.x, maxPixel.y) / resolution;
    ndc01 = ndc01 * 2.0 - vec2<f32>(1.0, 1.0);
    var ndc10 = vec2<f32>(maxPixel.x, minPixel.y) / resolution;
    ndc10 = ndc10 * 2.0 - vec2<f32>(1.0, 1.0);
    var ndc11 = vec2<f32>(maxPixel.x, maxPixel.y) / resolution;
    ndc11 = ndc11 * 2.0 - vec2<f32>(1.0, 1.0);

    let viewz = f32(globalIdx.z) / f32(ZClusters);
    let zDiff = camera.farPlane / camera.nearPlane;
    let zmin = camera.nearPlane * pow(zDiff, viewz);
    let zmax  = camera.farPlane * pow(zDiff, viewz);

    let v000 = ndcToView(ndc00, zmin, camera.invProjMat);
    let v001 = ndcToView(ndc00, zmax, camera.invProjMat);
    let v010 = ndcToView(ndc01, zmin, camera.invProjMat);
    let v011 = ndcToView(ndc01, zmax, camera.invProjMat);
    let v100 = ndcToView(ndc10, zmin, camera.invProjMat);
    let v101 = ndcToView(ndc10, zmax, camera.invProjMat);
    let v110 = ndcToView(ndc11, zmin, camera.invProjMat);
    let v111 = ndcToView(ndc11, zmax, camera.invProjMat);

    var minAABB = min(min(v000, v001), min(v010, v011));
    minAABB = min(minAABB, min(min(v100, v101), min(v110, v111)));
    var maxAABB = max(max(v000, v001), max(v010, v011));
    maxAABB = max(maxAABB, max(max(v100, v101), max(v110, v111)));

    clusterSet.clusters[clusterIndex].minBounds = minAABB;
    clusterSet.clusters[clusterIndex].maxBounds = maxAABB;

    var count: u32 = 0u;
    let maxLights = u32(${maxLightsPerCluster});
    //let radius = f32(${testLightRadius});
    let radius = 2; // Hardcode for unknown reason

    for (var i: u32 = 0u; i < lightSet.numLights; i = i + 1u) {
        if (count >= maxLights){
            break;
        }

        let lightPos = lightSet.lights[i].pos;
        let lightView = camera.viewMat * vec4<f32>(lightPos, 1.0);
        let approach = clamp(lightView.xyz, minAABB, maxAABB);
        let distance = length(approach - lightView.xyz);
        if (distance <= radius) {
            clusterSet.clusters[clusterIndex].lightIndices[count] = i;
            count = count + 1u;
        }
    }

    clusterSet.clusters[clusterIndex].numLights = count;
}