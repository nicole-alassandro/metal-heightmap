// Copyright (C) 2021  Nicole Alassandro

// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option)
// any later version.

// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
// more details.

// You should have received a copy of the GNU General Public License along
// with this program.  If not, see <http://www.gnu.org/licenses/>.

#include <metal_stdlib>
#include "defs.h"

using namespace metal;

typedef struct FrameUniforms {
    float4x4 modelMatrix;
    float4x4 perspectiveMatrix;
} FrameUniforms;

struct VertexInput {
    float2 position [[attribute(0)]];
};

struct FragmentInput {
    float4 position [[position]];
    float2 texture;
};

vertex FragmentInput vert(
    VertexInput in [[stage_in]],
    constant FrameUniforms& uniforms [[buffer(FrameUniformBuffer)]],
    texture2d<half> heightmap [[texture(0)]])
{
    constexpr sampler nearestSampler (mag_filter::nearest,
                                      min_filter::nearest);

    // TODO
    half4 sample = heightmap.sample(nearestSampler, in.position);

    FragmentInput out;
    out.position = (
        uniforms.perspectiveMatrix
      * uniforms.modelMatrix
      * float4(in.position, -1.0, 1.0)
    );
    out.texture = (in.position.xy + 1.0f) / 2.0f;
    return out;
}

fragment half4 frag(
    FragmentInput in [[stage_in]],
    texture2d<half> heightmap [[texture(0)]])
{
    constexpr sampler linearSampler (mag_filter::linear,
                                     min_filter::linear);

    half4 color = heightmap.sample(linearSampler, in.texture);
    // return half4(in.texture.x, in.texture.y, 255, 255);
    return half4(color.r, color.r, color.r, 0);
}
