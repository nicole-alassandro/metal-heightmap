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
} vertex;

enum {
    GRID_SIZE = 25,
    VERTEX_COUNT = GRID_SIZE * GRID_SIZE,
    INDEX_COUNT = ((GRID_SIZE - 1) * (GRID_SIZE - 1)) * 6,

    MAX_INFLIGHT_BUFFERS = 3,
};

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
    id<MTLBuffer>              _uniformBuffer[MAX_INFLIGHT_BUFFERS];
    id<MTLBuffer>              _vertexBuffer;
    id<MTLBuffer>              _indexBuffer;
    id<MTLTexture>             _heightmap;

    size_t _frameNum;
    dispatch_semaphore_t _frameSemaphore;
}

-(id)initWithView:(MTKView*)view
{
    _frameNum = 0;
    _frameSemaphore = dispatch_semaphore_create(MAX_INFLIGHT_BUFFERS);

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
    vertDesc.attributes[0].bufferIndex = 0;

    vertDesc.layouts[0].stride = sizeof(vertex);
    vertDesc.layouts[0].stepRate = 1;
    vertDesc.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;

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

    {
        vertex   * const vertices = malloc(sizeof(vertex)   * VERTEX_COUNT);
        uint16_t * const indices  = malloc(sizeof(uint16_t) * INDEX_COUNT);

        size_t vi = 0;
        size_t ii = 0;

        for (size_t y = 0; y < GRID_SIZE; ++y) {
            for (size_t x = 0; x < GRID_SIZE; ++x) {
                vertices[vi++] = (vertex){
                    .pos={
                        ((float)x / (float)(GRID_SIZE - 1)) * 2.0f - 1.0f,
                        ((float)y / (float)(GRID_SIZE - 1)) * 2.0f - 1.0f,
                    }
                };

                if (y < GRID_SIZE - 1 && x < GRID_SIZE - 1)
                {
                    const size_t leftTop     = y * GRID_SIZE + x;
                    const size_t leftBottom  = (y + 1) * GRID_SIZE + x;
                    const size_t rightBottom = (y + 1) * GRID_SIZE + x + 1;
                    const size_t rightTop    = y * GRID_SIZE + x + 1;

                    indices[ii++] = rightTop;
                    indices[ii++] = leftBottom;
                    indices[ii++] = leftTop;

                    indices[ii++] = rightBottom;
                    indices[ii++] = leftBottom;
                    indices[ii++] = rightTop;
                }
            }
        }

        _vertexBuffer = [
            _device
            newBufferWithBytes:vertices
            length:sizeof(vertex) * VERTEX_COUNT
            options:MTLResourceStorageModeShared
        ];

        _indexBuffer = [
            _device
            newBufferWithBytes:indices
            length:sizeof(uint16_t) * INDEX_COUNT
            options:MTLResourceStorageModeShared
        ];

        free(vertices);
        free(indices);
    }

    for (size_t i = 0; i < MAX_INFLIGHT_BUFFERS; ++i)
    {
        _uniformBuffer[i] = [
            _device
            newBufferWithLength:sizeof(FrameUniforms)
            options:MTLResourceCPUCacheModeWriteCombined
        ];
    }

    _commandQueue = [_device newCommandQueue];

    return self;
}

-(void)drawInMTKView:(MTKView*)view
{
    dispatch_semaphore_wait(_frameSemaphore, DISPATCH_TIME_FOREVER);

    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    if (!renderPassDescriptor)
        return;

    const size_t bufferIndex = _frameNum % MAX_INFLIGHT_BUFFERS;

    {
        simd_float4x4 perspectiveMatrix;

        {
            const float nearZ = 0.01f;
            const float farZ  = 100.0f;

            perspectiveMatrix = simd_float4x4FromGLKMatrix(
                GLKMatrix4MakePerspective(
                    M_PI / 4.0f, 1.0f, nearZ, farZ
                )
            );

            // Metal clip space is [0,1] rather than [-1,1]
            // https://forums.raywenderlich.com/t/ios-metal-tutorial-with-swift-part-5-switching-to-metalkit/19283
            const float zs = farZ / (nearZ - farZ);
            perspectiveMatrix.columns[2][2] = zs;
            perspectiveMatrix.columns[3][2] = zs * nearZ;
        }

        simd_float4x4 modelMatrix = simd_float4x4FromGLKMatrix(
            GLKMatrix4MakeTranslation(
                0.0f,
                0.0f,
                -4.0f
            )
        );

        modelMatrix = simd_mul(
            modelMatrix,
            simd_float4x4FromGLKMatrix(
                GLKMatrix4MakeRotation(
                    M_PI / 2.0f,
                    -1.0f,
                    0.0f,
                    0.0f
                )
            )
        );

        modelMatrix = simd_mul(
            modelMatrix,
            simd_float4x4FromGLKMatrix(
                GLKMatrix4MakeRotation(
                    cosf((float)_frameNum * 0.0275f),
                    0.0f,
                    0.0f,
                    1.0f
                )
            )
        );

        FrameUniforms* const uniforms = (FrameUniforms*)[
            _uniformBuffer[bufferIndex]
            contents
        ];

        uniforms->modelMatrix       = modelMatrix;
        uniforms->perspectiveMatrix = perspectiveMatrix;
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
        [encoder setVertexBuffer:_uniformBuffer[bufferIndex]
                 offset:0
                 atIndex:1];
        [encoder setVertexBuffer:_vertexBuffer
                 offset:0
                 atIndex:0];

        [encoder setVertexTexture:_heightmap
                 atIndex:0];
        [encoder setFragmentTexture:_heightmap
                 atIndex:0];

        [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                 indexCount:INDEX_COUNT
                 indexType:MTLIndexTypeUInt16
                 indexBuffer:_indexBuffer
                 indexBufferOffset:0
                 instanceCount:1];

        [encoder endEncoding];

        [commandBuffer presentDrawable:view.currentDrawable];

        __weak dispatch_semaphore_t semaphore = _frameSemaphore;
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> commandBuffer){
            dispatch_semaphore_signal(semaphore);
        }];

        [commandBuffer commit];
    }

    _frameNum++;
}

-(void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {}
@end
