import Metal

final public class SimpleGeometryRenderer {
    // MARK: - Properties

    public let pipelineState: MTLRenderPipelineState

    // MARK: - Init

    public convenience init(
        context: MTLContext,
        pixelFormat: MTLPixelFormat,
        blending: BlendingMode = .alpha,
        label: String = "Simple Geometry Renderer"
    ) throws {
        try self.init(
            library: context.library(for: Self.self),
            pixelFormat: pixelFormat,
            blending: blending,
            label: label
        )
    }

    public init(
        library: MTLLibrary,
        pixelFormat: MTLPixelFormat,
        blending: BlendingMode = .alpha,
        label: String = "Simple Geometry Renderer"
    ) throws {
        guard let vertexFunction = library.makeFunction(name: Self.vertexFunctionName),
              let fragmentFunction = library.makeFunction(name: Self.fragmentFunctionName)
        else { throw MetalError.MTLLibraryError.functionCreationFailed }

        let renderPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineStateDescriptor.label = label
        renderPipelineStateDescriptor.vertexFunction = vertexFunction
        renderPipelineStateDescriptor.fragmentFunction = fragmentFunction
        renderPipelineStateDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        renderPipelineStateDescriptor.colorAttachments[0].setup(blending: blending)
        renderPipelineStateDescriptor.depthAttachmentPixelFormat = .invalid
        renderPipelineStateDescriptor.stencilAttachmentPixelFormat = .invalid

        try self.pipelineState = library.device.makeRenderPipelineState(descriptor: renderPipelineStateDescriptor)
    }

    // MARK: - Render

    public func render(
        geometry: MTLBuffer,
        type: MTLPrimitiveType = .triangle,
        fillMode: MTLTriangleFillMode = .fill,
        indexBuffer: MTLIndexBuffer,
        matrix: float4x4 = float4x4(diagonal: .init(repeating: 1)),
        color: SIMD4<Float> = .init(1, 0, 0, 1),
        using encoder: MTLRenderCommandEncoder
    ) {
        encoder.setVertexBuffer(
            geometry,
            offset: 0,
            index: 0
        )
        encoder.set(
            vertexValue: matrix,
            at: 1
        )
        encoder.set(
            fragmentValue: color,
            at: 0
        )
        encoder.setTriangleFillMode(fillMode)
        encoder.setRenderPipelineState(self.pipelineState)
        encoder.drawIndexedPrimitives(
            type: type,
            indexBuffer: indexBuffer
        )
    }

    public static let vertexFunctionName = "simpleVertex"
    public static let fragmentFunctionName = "simpleFragment"
}
