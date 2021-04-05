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

typedef struct FrameUniforms {
    simd_float4x4 projectionViewModel;
} FrameUniforms;

typedef struct vertex {
    float pos[3];
    unsigned char color[4];
} vertex;

@interface Renderer : NSObject<MTKViewDelegate>
@end

@implementation Renderer {
    id<MTLDevice>              _device;
    id<MTLLibrary>             _library;
    id<MTLCommandQueue>        _commandQueue;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLDepthStencilState>   _depthState;
    id<MTLBuffer>              _uniformBuffer;
    id<MTLBuffer>              _vertfexBuffer;

    long frameNum;
}

-(id)initWithView:(MTKView*)view
{
    _device = view.device;

    view.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;

    NSError * error = nil;

    _library = [
        _device
        newLibraryWithFile:[[NSBundle mainBundle]
                                      pathForResource:@"shaders"
                                      ofType:@"metallib"]
        error:&error
    ];

    if (!_library) {
        NSLog(@"Failed to load shader library: %@", error);
        [NSApp terminate:self];
    }

    id <MTLFunction> vertexFunction   = [_library newFunctionWithName:@"vert"];
    id <MTLFunction> fragmentFunction = [_library newFunctionWithName:@"frag"];

    MTLDepthStencilDescriptor* depthStencilDesc = [MTLDepthStencilDescriptor new];
    depthStencilDesc.depthCompareFunction = MTLCompareFunctionLess;
    depthStencilDesc.depthWriteEnabled = YES;

    _depthState = [
        _device
        newDepthStencilStateWithDescriptor:depthStencilDesc
    ];

    MTLVertexDescriptor* vertDesc = [MTLVertexDescriptor new];
    vertDesc.attributes[VertexAttributePosition].format = MTLVertexFormatFloat3;
    vertDesc.attributes[VertexAttributePosition].offset = 0;
    vertDesc.attributes[VertexAttributePosition].bufferIndex = MeshVertexBuffer;

    vertDesc.attributes[VertexAttributeColor].format = MTLVertexFormatUChar4;
    vertDesc.attributes[VertexAttributeColor].offset = SIZEOF_VERTEX_POS;
    vertDesc.attributes[VertexAttributeColor].bufferIndex = MeshVertexBuffer;

    vertDesc.layouts[MeshVertexBuffer].stride = sizeof(vertex);
    vertDesc.layouts[MeshVertexBuffer].stepRate = 1;
    vertDesc.layouts[MeshVertexBuffer].stepFunction = MTLVertexStepFunctionPerVertex;

    MTLRenderPipelineDescriptor * pipeDesc = [MTLRenderPipelineDescriptor new];
    pipeDesc.sampleCount = view.sampleCount;
    pipeDesc.vertexFunction = vertexFunction;
    pipeDesc.fragmentFunction = fragmentFunction;
    pipeDesc.vertexDescriptor = vertDesc;
    pipeDesc.colorAttachments[0].pixelFormat = view.colorPixelFormat;
    pipeDesc.depthAttachmentPixelFormat = view.depthStencilPixelFormat;
    pipeDesc.stencilAttachmentPixelFormat = view.depthStencilPixelFormat;

    _pipelineState = [
        _device
        newRenderPipelineStateWithDescriptor:pipeDesc
        error:&error
    ];

    if (!_pipelineState) {
        NSLog(@"Failed to create pipeline: %@", error);
        [NSApp terminate:self];
    }

    vertex verts[3] = {
        (vertex){
            .pos={-0.5f, -0.5f, 0.0f},
            .color={255, 0, 0, 255},
        },
        (vertex){
            .pos={0.0f, 0.5f, 0.0f},
            .color={0, 255, 0, 255},
        },
        (vertex){
            .pos={0.5f, -0.5f, 0.0f},
            .color={0, 0, 255, 255},
        },
    };

    _vertfexBuffer = [
        _device
        newBufferWithBytes:verts
        length:sizeof(verts)
        options:MTLResourceStorageModeShared
    ];

    _uniformBuffer = [
        _device
        newBufferWithLength:sizeof(FrameUniforms)
        options:MTLResourceCPUCacheModeWriteCombined
    ];

    frameNum = 0;

    _commandQueue = [_device newCommandQueue];

    return self;
}

-(void)drawInMTKView:(MTKView*)view
{
    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    if (!renderPassDescriptor)
        return;

    frameNum++;

    {
        const float foo = sinf((float)frameNum / 12.0f);

        const float rad = (float)frameNum * 0.01f;
        const float rotation_y = sinf(rad) + foo;
        const float rotation_x = cosf(rad) + foo;

        const simd_float4x4 rotation = (simd_float4x4){
            (simd_float4){rotation_x, -rotation_y, 0.0f, 0.0f},
            (simd_float4){rotation_y,  rotation_x, 0.0f, 0.0f},
            (simd_float4){      0.0f,       -0.0f, 1.0f, 0.0f},
            (simd_float4){      0.0f,        0.0f, 0.0f, 1.0f},
        };

        FrameUniforms* const uniforms = (FrameUniforms*)[
            _uniformBuffer
            contents
        ];
        uniforms->projectionViewModel = rotation;
    }

    {
        id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];

        id<MTLRenderCommandEncoder> encoder = [
            commandBuffer
            renderCommandEncoderWithDescriptor:renderPassDescriptor
        ];

        [encoder setViewport:(MTLViewport){
            0, 0,
            view.drawableSize.width, view.drawableSize.height,
            0, 1
        }];

        [encoder setDepthStencilState:_depthState];
        [encoder setRenderPipelineState:_pipelineState];
        [encoder setVertexBuffer:_uniformBuffer
                 offset:0
                 atIndex:FrameUniformBuffer];
        [encoder setVertexBuffer:_vertfexBuffer
                 offset:0
                 atIndex:MeshVertexBuffer];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle
                 vertexStart:0
                 vertexCount:3];
        [encoder endEncoding];

        [commandBuffer presentDrawable:view.currentDrawable];
        [commandBuffer commit];
    }
}

-(void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {}
@end
