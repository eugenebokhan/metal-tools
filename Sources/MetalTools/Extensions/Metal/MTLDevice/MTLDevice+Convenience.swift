import IOSurface
import Metal

public extension MTLDevice {
    func library(
        from file: URL,
        options: MTLCompileOptions? = nil
    ) throws -> MTLLibrary {
        try self.makeLibrary(
            source: try String(contentsOf: file),
            options: options
        )
    }

    func multisampleRenderTargetPair(
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat,
        sampleCount: Int = 4
    ) throws -> (
        main: MTLTexture,
        resolve: MTLTexture
    ) {
        let mainDescriptor = MTLTextureDescriptor()
        mainDescriptor.width = width
        mainDescriptor.height = height
        mainDescriptor.pixelFormat = pixelFormat
        mainDescriptor.usage = [.renderTarget, .shaderRead]

        let sampleDescriptor = MTLTextureDescriptor()
        sampleDescriptor.textureType = MTLTextureType.type2DMultisample
        sampleDescriptor.width = width
        sampleDescriptor.height = height
        sampleDescriptor.sampleCount = sampleCount
        sampleDescriptor.pixelFormat = pixelFormat
        #if !os(macOS) && !targetEnvironment(macCatalyst)
        sampleDescriptor.storageMode = .memoryless
        #endif
        sampleDescriptor.usage = .renderTarget

        guard let mainTex = makeTexture(descriptor: mainDescriptor),
              let sampleTex = makeTexture(descriptor: sampleDescriptor)
        else { throw MetalError.MTLDeviceError.textureCreationFailed }

        return (main: sampleTex, resolve: mainTex)
    }

    func heap(
        size: Int,
        storageMode: MTLStorageMode,
        cpuCacheMode: MTLCPUCacheMode = .defaultCache
    ) throws -> MTLHeap {
        let descriptor = MTLHeapDescriptor()
        descriptor.size = size
        descriptor.storageMode = storageMode
        descriptor.cpuCacheMode = cpuCacheMode

        guard let heap = makeHeap(descriptor: descriptor)
        else { throw MetalError.MTLDeviceError.heapCreationFailed }
        return heap
    }

    func buffer<T>(
        for _: T.Type,
        count: Int = 1,
        options: MTLResourceOptions = .cpuCacheModeWriteCombined
    ) throws -> MTLBuffer {
        guard let buffer = makeBuffer(
            length: MemoryLayout<T>.stride * count,
            options: options
        )
        else { throw MetalError.MTLDeviceError.bufferCreationFailed }
        return buffer
    }

    func buffer<T>(
        with value: T,
        options: MTLResourceOptions = .cpuCacheModeWriteCombined
    ) throws -> MTLBuffer {
        guard let buffer = withUnsafePointer(to: value, {
            makeBuffer(
                bytes: $0,
                length: MemoryLayout<T>.stride,
                options: options
            )
        })
        else { throw MetalError.MTLDeviceError.bufferCreationFailed }
        return buffer
    }

    func buffer<T>(
        with values: [T],
        options: MTLResourceOptions = .cpuCacheModeWriteCombined
    ) throws -> MTLBuffer {
        let buffer = values.withUnsafeBytes {
            $0.baseAddress.map {
                makeBuffer(
                    bytes: $0,
                    length: MemoryLayout<T>.stride * values.count,
                    options: options
                )
            } ?? nil
        }
        guard let buffer else { throw MetalError.MTLDeviceError.bufferCreationFailed }
        return buffer
    }

    func depthBuffer(
        width: Int,
        height: Int,
        usage: MTLTextureUsage = [],
        storageMode: MTLStorageMode? = nil
    ) throws -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.width = width
        textureDescriptor.height = height
        textureDescriptor.pixelFormat = .depth32Float
        textureDescriptor.usage = usage.union([.renderTarget])
        #if !os(macOS) && !targetEnvironment(macCatalyst)
        textureDescriptor.storageMode = storageMode ?? .memoryless
        #else
        textureDescriptor.storageMode = storageMode ?? .private
        #endif
        guard let texture = makeTexture(descriptor: textureDescriptor)
        else { throw MetalError.MTLDeviceError.textureCreationFailed }
        return texture
    }

    func depthState(
        depthCompareFunction: MTLCompareFunction,
        isDepthWriteEnabled: Bool = true
    ) throws -> MTLDepthStencilState {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = depthCompareFunction
        descriptor.isDepthWriteEnabled = isDepthWriteEnabled
        guard let depthStencilState = makeDepthStencilState(descriptor: descriptor)
        else { throw MetalError.MTLDeviceError.depthStencilStateCreationFailed }
        return depthStencilState
    }

    func texture(
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat,
        options: MTLResourceOptions = [],
        usage: MTLTextureUsage = []
    ) throws -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.width = width
        textureDescriptor.height = height
        textureDescriptor.pixelFormat = pixelFormat
        textureDescriptor.resourceOptions = options
        textureDescriptor.usage = usage
        guard let texture = makeTexture(descriptor: textureDescriptor)
        else { throw MetalError.MTLDeviceError.textureCreationFailed }
        return texture
    }

    func texture(
        iosurface: IOSurfaceRef,
        plane: Int = 0,
        options: MTLResourceOptions = [],
        usage: MTLTextureUsage = []
    ) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.width = IOSurfaceGetWidthOfPlane(iosurface, plane)
        descriptor.height = IOSurfaceGetHeightOfPlane(iosurface, plane)
        descriptor.pixelFormat = try .init(osType: IOSurfaceGetPixelFormat(iosurface))
        descriptor.resourceOptions = options
        descriptor.usage = usage

        guard let texture = makeTexture(
            descriptor: descriptor,
            iosurface: iosurface,
            plane: plane
        )
        else { throw MetalError.MTLDeviceError.textureCreationFailed }

        return texture
    }

    func maxTextureSize(desiredSize: MTLSize) -> MTLSize {
        let maxSide: Int
        if self.supportsOnly8K() {
            maxSide = 8192
        } else {
            maxSide = 16384
        }

        guard desiredSize.width > 0,
              desiredSize.height > 0
        else { return .zero }

        let aspectRatio = Float(desiredSize.width) / Float(desiredSize.height)
        if aspectRatio > 1 {
            let resultWidth = min(desiredSize.width, maxSide)
            let resultHeight = Float(resultWidth) / aspectRatio
            return MTLSize(width: resultWidth, height: Int(resultHeight.rounded()), depth: 0)
        } else {
            let resultHeight = min(desiredSize.height, maxSide)
            let resultWidth = Float(resultHeight) * aspectRatio
            return MTLSize(width: Int(resultWidth.rounded()), height: resultHeight, depth: 0)
        }
    }

    private func supportsOnly8K() -> Bool {
        #if targetEnvironment(macCatalyst)
        return !supportsFamily(.apple3)
        #elseif os(macOS)
        return false
        #else
        if #available(iOS 13.0, *) {
            return !supportsFamily(.apple3)
        } else {
            return !supportsFeatureSet(.iOS_GPUFamily3_v3)
        }
        #endif
    }
}
