import Metal
import CoreVideo

public extension MTLPixelFormat {
    
    init(osType: OSType) throws {
        guard let pixelFormat = osType.compatibleMTLPixelFormat
        else { throw MetalError.MTLPixelFormatError.incompatibleCVPixelFormat }
        self = pixelFormat
    }

    var compatibleCVPixelFormat: OSType? {
        switch self {
        case .r8Unorm: return kCVPixelFormatType_OneComponent8
        case .r16Float: return kCVPixelFormatType_OneComponent16Half
        case .r32Float: return kCVPixelFormatType_OneComponent32Float

        case .rg8Unorm: return kCVPixelFormatType_TwoComponent8
        case .rg16Float: return kCVPixelFormatType_TwoComponent16Half
        case .rg32Float: return kCVPixelFormatType_TwoComponent32Float

        case .bgra8Unorm: return kCVPixelFormatType_32BGRA
        case .rgba8Unorm: return kCVPixelFormatType_32RGBA
        case .rgba16Float: return kCVPixelFormatType_64RGBAHalf
        case .rgba32Float: return kCVPixelFormatType_128RGBAFloat

        case .depth32Float: return kCVPixelFormatType_DepthFloat32
        default: return nil
        }
    }

}
