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
    simd_float4x4 modelMatrix;
    simd_float4x4 perspectiveMatrix;
} FrameUniforms;

typedef struct vertex {
    float pos[2];
    float tex[2];
} vertex;

simd_float4x4 simd_float4x4FromGLKMatrix(GLKMatrix4 mat)
{
    return (simd_float4x4) {
        (simd_float4){mat.m00, mat.m01, mat.m02, mat.m03},
        (simd_float4){mat.m10, mat.m11, mat.m12, mat.m13},
        (simd_float4){mat.m20, mat.m21, mat.m22, mat.m23},
        (simd_float4){mat.m30, mat.m31, mat.m32, mat.m33},
    };
}

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
    id<MTLTexture>             _heightmap;

    long frameNum;
}

-(id)initWithView:(MTKView*)view
{
    _device = view.device;

    view.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;

    NSError* error = nil;

    _heightmap = [
        [[MTKTextureLoader alloc] initWithDevice:_device]
        newTextureWithContentsOfURL:[
            NSURL
            fileURLWithPath:[
                [NSBundle mainBundle]
                pathForResource:@"heightmap"
                ofType:@"png"
            ]
        ]
        options:nil
        error:&error
    ];

    if (!_heightmap) {
        NSLog(@"Failed to load heightmap: %@", error);
        [NSApp terminate:self];
    }

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
    vertDesc.attributes[0].format = MTLVertexFormatFloat2;
    vertDesc.attributes[0].offset = 0;
    vertDesc.attributes[0].bufferIndex = MeshVertexBuffer;

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

    vertex verts[5] = {
        (vertex){
            .pos={-0.5f, -0.5f},
        },
        (vertex){
            .pos={-0.5f, 0.5f},
        },
        (vertex){
            .pos={0.5f, 0.5f},
        },
        (vertex){
            .pos={0.5f, -0.5f},
        },
        (vertex){
            .pos={-0.5f, -0.5f},
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
        simd_float4x4 perspective;

        {
            const float nearZ = 0.01f;
            const float farZ  = 100.0f;

            perspective = simd_float4x4FromGLKMatrix(
                GLKMatrix4MakePerspective(
                    M_PI / 2.0f, 1.0f, nearZ, farZ
                )
            );

            // Metal clip space is [0,1] rather than [-1,1]
            // https://forums.raywenderlich.com/t/ios-metal-tutorial-with-swift-part-5-switching-to-metalkit/19283
            const float zs = farZ / (nearZ - farZ);
            perspective.columns[2][2] = zs;
            perspective.columns[3][2] = zs * nearZ;
        }

        const simd_float4x4 rotation = simd_float4x4FromGLKMatrix(
            GLKMatrix4MakeRotation(
                cosf((float)frameNum * 0.05f),
                0.0f,
                0.0f,
                1.0f
            )
        );

        const simd_float4x4 scale = simd_float4x4FromGLKMatrix(
            GLKMatrix4MakeScale(
                1.0f,
                1.0f,
                (sinf((float)frameNum * 0.05f) + 1.5f) * 2.0f
            )
        );

        FrameUniforms* const uniforms = (FrameUniforms*)[
            _uniformBuffer
            contents
        ];

        // matrix_identity_float4x4
        uniforms->modelMatrix       = simd_mul(rotation, scale);
        uniforms->perspectiveMatrix = perspective;
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
        [encoder setFragmentTexture:_heightmap
                 atIndex:0];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip
                 vertexStart:0
                 vertexCount:5];
        [encoder endEncoding];

        [commandBuffer presentDrawable:view.currentDrawable];
        [commandBuffer commit];
    }
}

-(void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {}
@end
