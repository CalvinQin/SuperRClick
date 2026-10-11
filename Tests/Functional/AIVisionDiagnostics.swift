// Read-only diagnostic for synthetic fixture images; no application state or external services.
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

@main
private enum AIVisionDiagnostics {
    static func main() throws {
        guard CommandLine.arguments.count == 2,
              let image = NSImage(contentsOfFile: CommandLine.arguments[1]),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            fatalError("Pass a generated fixture PNG")
        }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        print("Observations: \(request.results?.count ?? 0)")
        guard let observation = request.results?.first else { return }
        print("Foreground instances: \(observation.allInstances)")
        let mask = try observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
        let original = CIImage(cgImage: cgImage)
        let filter = CIFilter.blendWithMask()
        filter.inputImage = original
        filter.maskImage = CIImage(cvPixelBuffer: mask)
        filter.backgroundImage = CIImage(color: .clear)
        print("Original extent: \(original.extent)")
        guard let output = filter.outputImage else { print("No filter output"); return }
        print("Filter extent: \(output.extent); infinite=\(output.extent.isInfinite)")
        let context = CIContext()
        let uncropped = context.createCGImage(output, from: output.extent)
        print("Uncropped render: \(uncropped != nil)")
        let cropped = context.createCGImage(output, from: original.extent)
        print("Source-bounds render: \(cropped != nil)")
    }
}
