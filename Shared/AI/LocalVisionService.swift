import Cocoa
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

public enum LocalVisionService {
    
    // MARK: - OCR (Text Extraction)
    
    /// Extracts text from an image at the given URL using Vision OCR.
    /// Fast level uses `.fast`, accurate uses `.accurate`.
    public static func extractText(from url: URL, accurate: Bool = true) async throws -> String {
        return try await Task.detached {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = accurate ? .accurate : .fast
            request.usesLanguageCorrection = true
            
            #if os(macOS)
            if #available(macOS 13.0, *) {
                request.automaticallyDetectsLanguage = true
            }
            #endif
            
            let handler = VNImageRequestHandler(url: url, options: [:])
            try handler.perform([request])
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return ""
            }
            
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            return recognizedText
        }.value
    }
    
    // MARK: - Background Removal (macOS 14.0+)
    
    public enum VisionError: Error, LocalizedError {
        case unsupportedOS
        case imageLoadFailed
        case processingFailed
        
        public var errorDescription: String? {
            switch self {
            case .unsupportedOS: return "Background removal requires macOS 14.0 or later."
            case .imageLoadFailed: return "Failed to load image."
            case .processingFailed: return "Failed to process image."
            }
        }
    }
    
    /// Removes the background from an image and returns a transparent PNG Data.
    public static func removeBackground(from url: URL) async throws -> Data {
        #if os(macOS)
        guard #available(macOS 14.0, *) else {
            throw VisionError.unsupportedOS
        }
        
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw VisionError.imageLoadFailed
        }
        
        return try await Task.detached {
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            try handler.perform([request])
            
            guard let result = request.results?.first as? VNInstanceMaskObservation else {
                throw VisionError.processingFailed
            }
            
            let maskPixelBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
            let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
            let originalCIImage = CIImage(cgImage: cgImage)
            
            let filter = CIFilter.blendWithMask()
            filter.inputImage = originalCIImage
            filter.maskImage = maskImage
            filter.backgroundImage = CIImage(color: .clear)
            
            guard let outputImage = filter.outputImage else {
                throw VisionError.processingFailed
            }
            
            let context = CIContext()
            guard let cgOutput = context.createCGImage(outputImage, from: outputImage.extent) else {
                throw VisionError.processingFailed
            }
            
            let newImage = NSImage(cgImage: cgOutput, size: NSSize(width: cgImage.width, height: cgImage.height))
            
            guard let tiffData = newImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                throw VisionError.processingFailed
            }
            
            return pngData
        }.value
        #else
        throw VisionError.unsupportedOS
        #endif
    }
}
