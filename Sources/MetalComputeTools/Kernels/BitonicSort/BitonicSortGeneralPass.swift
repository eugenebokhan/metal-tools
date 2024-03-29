import MetalTools

extension BitonicSort {
    final class GeneralPass {
        // MARK: - Properties

        let pipelineState: MTLComputePipelineState
        private let deviceSupportsNonuniformThreadgroups: Bool

        // MARK: - Init

        convenience init(
            context: MTLContext,
            scalarType: MTLPixelFormat.ScalarType
        ) throws {
            try self.init(
                library: context.library(for: .module),
                scalarType: scalarType
            )
        }

        init(
            library: MTLLibrary,
            scalarType: MTLPixelFormat.ScalarType
        ) throws {
            self.deviceSupportsNonuniformThreadgroups = library.device.supports(feature: .nonUniformThreadgroups)

            let constantValues = MTLFunctionConstantValues()
            constantValues.set(
                self.deviceSupportsNonuniformThreadgroups,
                at: 0
            )

            let `extension` = "_" + scalarType.rawValue
            self.pipelineState = try library.computePipelineState(
                function: "bitonicSortGeneralPass" + `extension`,
                constants: constantValues
            )
        }

        // MARK: - Encode

        func callAsFunction(
            data: MTLBuffer,
            params: SIMD2<UInt32>,
            gridSize: Int,
            unitSize: Int,
            in commandBuffer: MTLCommandBuffer
        ) {
            self.encode(
                data: data,
                params: params,
                gridSize: gridSize,
                unitSize: unitSize,
                in: commandBuffer
            )
        }

        func callAsFunction(
            data: MTLBuffer,
            params: SIMD2<UInt32>,
            gridSize: Int,
            unitSize: Int,
            using encoder: MTLComputeCommandEncoder
        ) {
            self.encode(
                data: data,
                params: params,
                gridSize: gridSize,
                unitSize: unitSize,
                using: encoder
            )
        }

        func encode(
            data: MTLBuffer,
            params: SIMD2<UInt32>,
            gridSize: Int,
            unitSize: Int,
            in commandBuffer: MTLCommandBuffer
        ) {
            commandBuffer.compute { encoder in
                encoder.label = "Bitonic Sort General Pass"
                self.encode(
                    data: data,
                    params: params,
                    gridSize: gridSize,
                    unitSize: unitSize,
                    using: encoder
                )
            }
        }

        func encode(
            data: MTLBuffer,
            params: SIMD2<UInt32>,
            gridSize: Int,
            unitSize: Int,
            using encoder: MTLComputeCommandEncoder
        ) {
            encoder.setBuffers(data)
            encoder.setValue(UInt32(gridSize), at: 1)
            encoder.setValue(params, at: 2)

            if self.deviceSupportsNonuniformThreadgroups {
                encoder.dispatch1d(
                    state: self.pipelineState,
                    exactly: gridSize,
                    threadgroupWidth: unitSize
                )
            } else {
                encoder.dispatch1d(
                    state: self.pipelineState,
                    covering: gridSize,
                    threadgroupWidth: unitSize
                )
            }
        }
    }
}
