import Foundation

public protocol ProgressReporting: Sendable {
    func updateProgress(fractionCompleted: Double, message: String?)
}
