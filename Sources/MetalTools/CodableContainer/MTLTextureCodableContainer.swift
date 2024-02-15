import Metal

public class MTLTextureCodableContainer: Codable {
    public enum Error: Swift.Error {
        case missingBaseAddress
    }

    private let descriptor: MTLTextureDescriptorCodableContainer
    private var data: Data

    public init(texture: MTLTexture) throws {
        let descriptor = texture.descriptor
        self.descriptor = .init(descriptor: descriptor)

        let sizeAndAlign = texture.device.heapTextureSizeAndAlign(descriptor: descriptor)

        var data = Data(count: sizeAndAlign.size)
        try data.withUnsafeMutableBytes {
            guard let pointer = $0.baseAddress
            else { throw Error.missingBaseAddress }

            guard let pixelFormatSize = texture.pixelFormat.bytesPerPixel
            else { throw MetalError.MTLTextureSerializationError.unsupportedPixelFormat }

            var offset = 0

            for slice in 0 ..< texture.arrayLength {
                for mipMaplevel in 0 ..< texture.mipmapLevelCount {
                    guard let textureView = texture.makeTextureView(
                        pixelFormat: texture.pixelFormat,
                        textureType: texture.textureType,
                        levels: mipMaplevel ..< mipMaplevel + 1,
                        slices: slice ..< slice + 1
                    )
                    else { throw MetalError.MTLTextureSerializationError.dataAccessFailure }

                    var bytesPerRow = pixelFormatSize * textureView.width
                    let bytesPerImage = bytesPerRow * textureView.height

                    // This comes from docs
                    // > When you copy pixels from a MTLTextureType1D or MTLTextureType1DArray texture, use 0.
                    if texture.textureType == .type1D || texture.textureType == .type1DArray {
                        bytesPerRow = 0
                    }

                    textureView.getBytes(
                        pointer.advanced(by: offset),
                        bytesPerRow: bytesPerRow,
                        bytesPerImage: bytesPerImage,
                        from: textureView.region,
                        mipmapLevel: 0,
                        slice: 0
                    )

                    offset += bytesPerImage
                }
            }
        }

        self.data = data
    }

    public func texture(device: MTLDevice) throws -> MTLTexture {
        guard let texture = device.makeTexture(descriptor: self.descriptor.descriptor)
        else { throw MetalError.MTLTextureSerializationError.allocationFailed }

        try self.data.withUnsafeMutableBytes {
            guard let pointer = $0.baseAddress
            else { throw Error.missingBaseAddress }

            guard let pixelFormatSize = texture.pixelFormat.bytesPerPixel
            else { throw MetalError.MTLTextureSerializationError.unsupportedPixelFormat }

            var offset = 0

            for slice in 0 ..< texture.arrayLength {
                for mipMaplevel in 0 ..< texture.mipmapLevelCount {
                    guard let textureView = texture.makeTextureView(
                        pixelFormat: texture.pixelFormat,
                        textureType: texture.textureType,
                        levels: mipMaplevel ..< mipMaplevel + 1,
                        slices: slice ..< slice + 1
                    )
                    else { throw MetalError.MTLTextureSerializationError.dataAccessFailure }

                    var bytesPerRow = pixelFormatSize * textureView.width
                    let bytesPerImage = bytesPerRow * textureView.height

                    // This comes from docs
                    // > When you copy pixels from a MTLTextureType1D or MTLTextureType1DArray texture, use 0.
                    if texture.textureType == .type1D || texture.textureType == .type1DArray {
                        bytesPerRow = 0
                    }

                    textureView.replace(
                        region: textureView.region,
                        mipmapLevel: 0,
                        slice: 0,
                        withBytes: pointer.advanced(by: offset),
                        bytesPerRow: bytesPerRow,
                        bytesPerImage: bytesPerImage
                    )

                    offset += bytesPerImage
                }
            }
        }

        return texture
    }
}
