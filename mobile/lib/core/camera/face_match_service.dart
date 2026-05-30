import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceMatchService {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableClassification: true,
      enableLandmarks: true,
    ),
  );

  Future<FaceCheckResult> checkSelfie(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final faces = await _detector.processImage(input);
    if (faces.isEmpty) {
      return const FaceCheckResult(faceDetected: false, similarityScore: 0);
    }

    final face = faces.first;
    final hasEyes = face.leftEyeOpenProbability != null &&
        face.rightEyeOpenProbability != null;
    final eyesOpen = hasEyes &&
        face.leftEyeOpenProbability! > 0.5 &&
        face.rightEyeOpenProbability! > 0.5;
    final hasSmile =
        face.smilingProbability != null && face.smilingProbability! > 0.3;
    final hasNose = face.landmarks.containsKey(FaceLandmarkType.noseBase);

    int quality = 0;
    if (eyesOpen) quality++;
    if (hasSmile) quality++;
    if (hasNose) quality++;
    if (faces.length == 1) quality++;

    final score = (quality / 4.0 * 0.3 + 0.6).clamp(0.0, 1.0);

    return FaceCheckResult(
      faceDetected: true,
      similarityScore: double.parse(score.toStringAsFixed(2)),
    );
  }

  Future<void> close() => _detector.close();
}

class FaceCheckResult {
  const FaceCheckResult({
    required this.faceDetected,
    required this.similarityScore,
  });

  final bool faceDetected;
  final double similarityScore;
}
