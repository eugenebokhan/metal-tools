import Metal

public extension MTLTexture {
    /// Convenience function that copies the texture's pixel data to a Swift array.
    ///
    /// - Parameters:
    ///   - width: Width of the texture.
    ///   - height: Height of the texture.
    ///   - featureChannels: The number of color components per pixel: must be 1, 2, or 4.
    ///   - initial: This parameter is necessary because we need to give the array
    ///     an initial value. Unfortunately, we can't do `[T](repeating: T(0), ...)`
    ///     since `T` could be anything and may not have an init that takes a literal
    ///     value.
    /// - Returns: Swift array containing texture's pixel data.
    /// - Throws: An error if the resource is unavailable on the CPU or if the feature channels are invalid.
    func array<T>(
        width: Int,
        height: Int,
        featureChannels: Int,
        initial: T
    ) throws -> [T] {
        guard isAccessibleOnCPU
        else { throw MetalError.MTLResourceError.resourceUnavailable }
        guard featureChannels != 3,
              featureChannels <= 4
        else { throw MetalError.MTLTextureError.imageIncompatiblePixelFormat }

        let count = width * height * featureChannels

        let bytesPerRow = width * featureChannels * MemoryLayout<T>.stride

        var bytes = [T](
            repeating: initial,
            count: count
        )

        withUnsafeMutablePointer(to: &bytes) {
            getBytes(
                $0,
                bytesPerRow: bytesPerRow,
                from: .init(
                    origin: .zero,
                    size: .init(
                        width: width,
                        height: height,
                        depth: 1
                    )
                ),
                mipmapLevel: 0
            )
        }

        return bytes
    }
}
