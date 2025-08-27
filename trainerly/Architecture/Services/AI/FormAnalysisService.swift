import Foundation
import Vision
import CoreML
import AVFoundation
import UIKit
import Combine

// MARK: - Form Analysis Service Protocol
protocol FormAnalysisServiceProtocol {
    func analyzeForm(from image: UIImage) async throws -> FormAnalysisResult
    func analyzeForm(from video: URL) async throws -> [FormAnalysisResult]
    func startRealTimeAnalysis() -> FormAnalysisStream
    func stopRealTimeAnalysis()
    func getFormTips(for exercise: Exercise, formScore: Double) async throws -> [FormTip]
}

// MARK: - Form Analysis Service
final class FormAnalysisService: NSObject, FormAnalysisServiceProtocol {
    
    // MARK: - Properties
    private let visionProcessor: VisionProcessorProtocol
    private let geminiService: GeminiServiceProtocol
    private let formModel: FormAnalysisModel?
    private let poseDetector: VNDetectHumanBodyPoseRequest
    private let videoCapture: AVCaptureSession?
    private var analysisStream: FormAnalysisStream?
    
    // MARK: - Initialization
    init(visionProcessor: VisionProcessorProtocol, geminiService: GeminiServiceProtocol) {
        self.visionProcessor = visionProcessor
        self.geminiService = geminiService
        
        // Initialize pose detection
        self.poseDetector = VNDetectHumanBodyPoseRequest()
        
        // Initialize video capture for real-time analysis
        self.videoCapture = AVCaptureSession()
        
        // Load CoreML model for form analysis
        do {
            self.formModel = try FormAnalysisModel()
        } catch {
            print("❌ Failed to load form analysis model: \(error)")
            self.formModel = nil
        }
        
        super.init()
        
        setupVideoCapture()
    }
    
    // MARK: - Public Methods
    func analyzeForm(from image: UIImage) async throws -> FormAnalysisResult {
        // Convert image to CIImage
        guard let ciImage = CIImage(image: image) else {
            throw FormAnalysisError.invalidImage
        }
        
        // Detect human pose
        let poseObservations = try await detectPose(in: ciImage)
        
        // Analyze form using CoreML model
        let formScore = try await analyzeFormWithML(poseObservations: poseObservations)
        
        // Get detailed analysis using Gemini Vision
        let detailedAnalysis = try await getDetailedAnalysis(image: image, poseObservations: poseObservations)
        
        // Generate form tips
        let formTips = try await generateFormTips(formScore: formScore, analysis: detailedAnalysis)
        
        return FormAnalysisResult(
            formScore: formScore,
            confidence: calculateConfidence(poseObservations: poseObservations),
            keyPoints: extractKeyPoints(from: poseObservations),
            analysis: detailedAnalysis,
            tips: formTips,
            timestamp: Date()
        )
    }
    
    func analyzeForm(from video: URL) async throws -> [FormAnalysisResult] {
        let asset = AVAsset(url: video)
        let duration = try await asset.load(.duration)
        let frameCount = Int(CMTimeGetSeconds(duration) * 30) // 30 FPS
        
        var results: [FormAnalysisResult] = []
        
        // Extract frames and analyze each
        for frameIndex in stride(from: 0, to: frameCount, by: 3) { // Analyze every 3rd frame
            let time = CMTime(seconds: Double(frameIndex) / 30.0, preferredTimescale: 600)
            
            guard let image = try await extractFrame(from: asset, at: time) else { continue }
            
            let result = try await analyzeForm(from: image)
            results.append(result)
        }
        
        return results
    }
    
    func startRealTimeAnalysis() -> FormAnalysisStream {
        let stream = FormAnalysisStream()
        self.analysisStream = stream
        
        // Start video capture
        startVideoCapture()
        
        return stream
    }
    
    func stopRealTimeAnalysis() {
        stopVideoCapture()
        analysisStream?.complete()
        analysisStream = nil
    }
    
    func getFormTips(for exercise: Exercise, formScore: Double) async throws -> [FormTip] {
        let context = buildFormTipsContext(for: exercise, formScore: formScore)
        
        let aiResponse = try await geminiService.generateFormTips(context: context)
        
        return try parseFormTips(aiResponse, for: exercise)
    }
    
    // MARK: - Private Methods
    private func detectPose(in image: CIImage) async throws -> [VNHumanBodyPoseObservation] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectHumanBodyPoseRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: FormAnalysisError.poseDetectionFailed(error))
                    return
                }
                
                let observations = request.results as? [VNHumanBodyPoseObservation] ?? []
                continuation.resume(returning: observations)
            }
            
            let handler = VNImageRequestHandler(ciImage: image, options: [:])
            try handler.perform([request])
        }
    }
    
    private func analyzeFormWithML(poseObservations: [VNHumanBodyPoseObservation]) async throws -> Double {
        guard let model = formModel else {
            throw FormAnalysisError.modelNotLoaded
        }
        
        guard let observation = poseObservations.first else {
            throw FormAnalysisError.noPoseDetected
        }
        
        // Extract pose features
        let poseFeatures = try extractPoseFeatures(from: observation)
        
        // Run ML model
        let prediction = try model.prediction(pose_features: poseFeatures)
        
        // Convert prediction to form score (0-100)
        let formScore = Double(prediction.form_score) * 100.0
        
        return max(0.0, min(100.0, formScore))
    }
    
    private func extractPoseFeatures(from observation: VNHumanBodyPoseObservation) throws -> MLMultiArray {
        // Extract 17 key points from pose observation
        let keyPoints = try observation.recognizedPoints(.all)
        
        // Create feature array for ML model
        let featureArray = try MLMultiArray(shape: [1, 34], dataType: .float32) // 17 points * 2 coordinates
        
        var index = 0
        for pointName in VNHumanBodyPoseObservation.JointName.allCases {
            if let point = keyPoints[pointName] {
                featureArray[index] = NSNumber(value: point.location.x)
                featureArray[index + 1] = NSNumber(value: point.location.y)
                index += 2
            } else {
                featureArray[index] = NSNumber(value: 0.0)
                featureArray[index + 1] = NSNumber(value: 0.0)
                index += 2
            }
        }
        
        return featureArray
    }
    
    private func getDetailedAnalysis(image: UIImage, poseObservations: [VNHumanBodyPoseObservation]) async throws -> String {
        let context = buildAnalysisContext(image: image, poseObservations: poseObservations)
        
        return try await geminiService.analyzeFormImage(context: context)
    }
    
    private func generateFormTips(formScore: Double, analysis: String) async throws -> [FormTip] {
        let context = buildTipsContext(formScore: formScore, analysis: analysis)
        
        let aiResponse = try await geminiService.generateFormTips(context: context)
        
        return try parseFormTips(aiResponse, for: nil)
    }
    
    private func calculateConfidence(poseObservations: [VNHumanBodyPoseObservation]) -> Double {
        guard let observation = poseObservations.first else { return 0.0 }
        
        let keyPoints = try? observation.recognizedPoints(.all)
        let validPoints = keyPoints?.values.filter { $0.confidence > 0.5 }.count ?? 0
        let totalPoints = keyPoints?.count ?? 1
        
        return Double(validPoints) / Double(totalPoints)
    }
    
    private func extractKeyPoints(from observations: [VNHumanBodyPoseObservation]) -> [KeyPoint] {
        guard let observation = observations.first else { return [] }
        
        let keyPoints = try? observation.recognizedPoints(.all)
        
        return keyPoints?.compactMap { (name, point) in
            guard point.confidence > 0.3 else { return nil }
            
            return KeyPoint(
                name: name.rawValue,
                x: point.location.x,
                y: point.location.y,
                confidence: point.confidence
            )
        } ?? []
    }
    
    private func extractFrame(from asset: AVAsset, at time: CMTime) async throws -> UIImage? {
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Video Capture Setup
    private func setupVideoCapture() {
        guard let videoCapture = videoCapture else { return }
        
        // Configure video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if videoCapture.canAddInput(videoInput) {
                videoCapture.addInput(videoInput)
            }
        } catch {
            print("❌ Failed to setup video input: \(error)")
        }
        
        // Configure video output
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .userInitiated))
        
        if videoCapture.canAddOutput(videoOutput) {
            videoCapture.addOutput(videoOutput)
        }
    }
    
    private func startVideoCapture() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.videoCapture?.startRunning()
        }
    }
    
    private func stopVideoCapture() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.videoCapture?.stopRunning()
        }
    }
    
    // MARK: - Context Building
    private func buildAnalysisContext(image: UIImage, poseObservations: [VNHumanBodyPoseObservation]) -> [String: Any] {
        return [
            "image": image,
            "pose_observations_count": poseObservations.count,
            "analysis_type": "form_analysis"
        ]
    }
    
    private func buildTipsContext(formScore: Double, analysis: String) -> [String: Any] {
        return [
            "form_score": formScore,
            "analysis": analysis,
            "request_type": "form_tips"
        ]
    }
    
    private func buildFormTipsContext(for exercise: Exercise, formScore: Double) -> [String: Any] {
        return [
            "exercise_name": exercise.name,
            "exercise_category": exercise.category ?? "unknown",
            "muscle_groups": exercise.muscleGroups ?? [],
            "form_score": formScore,
            "request_type": "exercise_specific_tips"
        ]
    }
    
    // MARK: - Parsing
    private func parseFormTips(_ response: String, for exercise: Exercise?) -> [FormTip] {
        // Parse AI response for form tips
        // This would parse the response and create FormTip objects
        return []
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension FormAnalysisService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let uiImage = UIImage(ciImage: ciImage)
        
        // Analyze form in real-time
        Task {
            do {
                let result = try await analyzeForm(from: uiImage)
                analysisStream?.send(result)
            } catch {
                print("❌ Real-time form analysis failed: \(error)")
            }
        }
    }
}

// MARK: - Data Models
struct FormAnalysisResult {
    let formScore: Double // 0-100
    let confidence: Double // 0-1
    let keyPoints: [KeyPoint]
    let analysis: String
    let tips: [FormTip]
    let timestamp: Date
}

struct KeyPoint {
    let name: String
    let x: Double
    let y: Double
    let confidence: Float
}

struct FormTip {
    let title: String
    let description: String
    let priority: TipPriority
    let category: TipCategory
}

enum TipPriority: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

enum TipCategory: String, CaseIterable {
    case alignment = "alignment"
    case range = "range_of_motion"
    case tempo = "tempo"
    case breathing = "breathing"
    case safety = "safety"
}

// MARK: - Form Analysis Stream
class FormAnalysisStream {
    private let subject = PassthroughSubject<FormAnalysisResult, Never>()
    
    var publisher: AnyPublisher<FormAnalysisResult, Never> {
        subject.eraseToAnyPublisher()
    }
    
    func send(_ result: FormAnalysisResult) {
        subject.send(result)
    }
    
    func complete() {
        subject.send(completion: .finished)
    }
}

// MARK: - CoreML Model
// This would be a generated CoreML model class
class FormAnalysisModel {
    func prediction(pose_features: MLMultiArray) throws -> FormAnalysisOutput {
        // This would use the actual CoreML model
        // For now, return a mock prediction
        return FormAnalysisOutput(form_score: 0.75)
    }
}

struct FormAnalysisOutput {
    let form_score: Double
}

// MARK: - Error Types
enum FormAnalysisError: LocalizedError {
    case invalidImage
    case poseDetectionFailed(Error)
    case modelNotLoaded
    case noPoseDetected
    case analysisFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image provided for analysis"
        case .poseDetectionFailed(let error):
            return "Failed to detect pose: \(error.localizedDescription)"
        case .modelNotLoaded:
            return "Form analysis model not loaded"
        case .noPoseDetected:
            return "No human pose detected in image"
        case .analysisFailed(let error):
            return "Form analysis failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Protocol Extensions
protocol VisionProcessorProtocol {
    // Vision framework operations
}

protocol GeminiServiceProtocol {
    func analyzeFormImage(context: [String: Any]) async throws -> String
    func generateFormTips(context: [String: Any]) async throws -> String
}
