// TODO-3: implement the Clustered Deferred fullscreen vertex shader

// This shader should be very simple as it does not need all of the information passed by the the naive vertex shader.

struct FullscreenVertexOut {
    @builtin(position) position: vec4f,
    @location(0) uv: vec2f
}

const QUAD_POSITIONS: array<vec2f, 6> = array<vec2f, 6>(
    vec2f(-1.0, -1.0),
    vec2f(1.0, -1.0),
    vec2f(-1.0, 1.0),
    vec2f(-1.0, 1.0),
    vec2f(1.0, -1.0),
    vec2f(1.0, 1.0)
);

const QUAD_UVS: array<vec2f, 6> = array<vec2f, 6>(
    vec2f(0.0, 0.0),
    vec2f(1.0, 0.0),
    vec2f(0.0, 1.0),
    vec2f(0.0, 1.0),
    vec2f(1.0, 0.0),
    vec2f(1.0, 1.0)
);

@vertex
fn main(@builtin(vertex_index) vertexIndex: u32) -> FullscreenVertexOut {
    var out: FullscreenVertexOut;
    let idx = vertexIndex % 6u;
    out.position = vec4f(QUAD_POSITIONS[idx], 0.0, 1.0);
    out.uv = QUAD_UVS[idx];
    return out;
}