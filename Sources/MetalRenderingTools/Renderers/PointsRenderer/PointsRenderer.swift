import MetalTools

final public class PointsRender {
    // MARK: - Properties

    /// Point positions described in a normalized coodrinate system.
    public var pointsPositions: [SIMD2<Float>] {
        set {
            self.pointCount = newValue.count
            self.pointsPositionsBuffer = try? self.renderPipelineState
                .device
                .buffer(
                    with: newValue,
                    options: .storageModeShared
                )
        }
        get {
            if let pointsPositionsBuffer = self.pointsPositionsBuffer,
               let pointsPositions = pointsPositionsBuffer.array(
                   of: SIMD2<Float>.self,
                   count: self.pointCount
               )
            {
                return pointsPositions
            } else {
                return []
            }
        }
    }

    /// Point color. Red is default.
    public var color: SIMD4<Float> = .init(1, 0, 0, 1)
    /// Point size in pixels. 40 is default.
    public var pointSize: Float = 40

    private var pointsPositionsBuffer: MTLBuffer?
    private var pointCount: Int = 0

    private let renderPipelineState: MTLRenderPipelineState

    // MARK: - Life Cycle

    /// Creates a new instance of PointsRenderer.
    ///
    /// - Parameters:
    ///   - context: Alloy's Metal context.
    ///   - pixelFormat: Color attachment's pixel format.
    /// - Throws: Library or function creation errors.
    public convenience init(
        context: MTLContext,
        pixelFormat: MTLPixelFormat = .bgra8Unorm
    ) throws {
        try self.init(
            library: context.library(for: Self.self),
            pixelFormat: pixelFormat
        )
    }

    /// Creates a new instance of PointsRenderer.
    ///
    /// - Parameters:
    ///   - library: Alloy's shader library.
    ///   - pixelFormat: Color attachment's pixel format.
    /// - Throws: Function creation error.
    public init(
        library: MTLLibrary,
        pixelFormat: MTLPixelFormat = .bgra8Unorm
    ) throws {
        guard let vertexFunction = library.makeFunction(name: Self.vertexFunctionName),
              let fragmentFunction = library.makeFunction(name: Self.fragmentFunctionName)
        else { throw MetalError.MTLLibraryError.functionCreationFailed }

        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        renderPipelineDescriptor.colorAttachments[0].setup(blending: .alpha)

        self.renderPipelineState = try library.device
            .makeRenderPipelineState(descriptor: renderPipelineDescriptor)
    }

    // MARK: - Rendering

    /// Render points in a target texture.
    ///
    /// - Parameters:
    ///   - renderPassDescriptor: Render pass descriptor to be used.
    ///   - commandBuffer: Command buffer to put the rendering work items into.
    public func render(
        renderPassDescriptor: MTLRenderPassDescriptor,
        commandBuffer: MTLCommandBuffer
    ) throws {
        commandBuffer.render(
            descriptor: renderPassDescriptor,
            self.render(using:)
        )
    }

    /// Render points in a target texture.
    ///
    /// - Parameter renderEncoder: Container to put the rendering work into.
    public func render(using renderEncoder: MTLRenderCommandEncoder) {
        guard self.pointCount != 0
        else { return }

        // Push a debug group allowing us to identify render commands in the GPU Frame Capture tool.
        renderEncoder.pushDebugGroup("Draw Points Geometry")
        // Set render command encoder state.
        renderEncoder.setRenderPipelineState(self.renderPipelineState)
        // Set any buffers fed into our render pipeline.
        renderEncoder.setVertexBuffer(
            self.pointsPositionsBuffer,
            offset: 0,
            index: 0
        )
        renderEncoder.set(
            vertexValue: self.pointSize,
            at: 1
        )
        renderEncoder.set(
            fragmentValue: self.color,
            at: 0
        )
        // Draw.
        renderEncoder.drawPrimitives(
            type: .point,
            vertexStart: 0,
            vertexCount: 1,
            instanceCount: self.pointCount
        )
        renderEncoder.popDebugGroup()
    }

    private static let vertexFunctionName = "pointVertex"
    private static let fragmentFunctionName = "pointFragment"
}
