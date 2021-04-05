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

#include "defs.h"

typedef struct FrameUniforms {
    metal::float4x4 projectionViewModel;
} FrameUniforms;

struct VertexInput {
    float3 position [[attribute(VertexAttributePosition)]];
    half4 color [[attribute(VertexAttributeColor)]];
};

struct ShaderInOut {
    float4 position [[position]];
    half4 color;
};

vertex ShaderInOut vert(
    VertexInput in [[stage_in]],
    constant FrameUniforms& uniforms [[buffer(FrameUniformBuffer)]])
{
    ShaderInOut out;
    float4 pos = float4(in.position, 1.0);
    out.position = uniforms.projectionViewModel * pos;
    out.color = in.color / 255.0;
    return out;
}

fragment half4 frag(
    ShaderInOut in [[stage_in]])
{
    return in.color;
}
