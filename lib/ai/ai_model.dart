/// Model class untuk menyimpan hasil prediksi dari LSTM model
/// Output: 5 skor kebugaran (sleep_score, hrv_score, rhr_score, recovery_score, readiness_score)

class FitnessScores {
  final double sleepScore;
  final double hrvScore;
  final double rhrScore;
  final double recoveryScore;
  final double readinessScore;
  final DateTime timestamp;

  FitnessScores({
    required this.sleepScore,
    required this.hrvScore,
    required this.rhrScore,
    required this.recoveryScore,
    required this.readinessScore,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory FitnessScores.fromJson(Map<String, dynamic> json) {
    return FitnessScores(
      sleepScore: (json['sleep_score'] as num).toDouble(),
      hrvScore: (json['hrv_score'] as num).toDouble(),
      rhrScore: (json['rhr_score'] as num).toDouble(),
      recoveryScore: (json['recovery_score'] as num).toDouble(),
      readinessScore: (json['readiness_score'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sleep_score': sleepScore,
      'hrv_score': hrvScore,
      'rhr_score': rhrScore,
      'recovery_score': recoveryScore,
      'readiness_score': readinessScore,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Get overall fitness score (uses Readiness Score as requested)
  double get overallScore => readinessScore;

  /// Get score label for display
  String getScoreLabel(double score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    if (score >= 20) return 'Poor';
    return 'Very Poor';
  }

  @override
  String toString() {
    return 'FitnessScores(sleep: $sleepScore, hrv: $hrvScore, rhr: $rhrScore, recovery: $recoveryScore, readiness: $readinessScore)';
  }
}

/// Model class untuk input data kesehatan (1 timestep)
class HealthDataPoint {
  final double stepTotal;
  final double calories;
  final double heartRate;
  final double stress;
  final DateTime? timestamp;

  HealthDataPoint({
    required this.stepTotal,
    required this.calories,
    required this.heartRate,
    required this.stress,
    this.timestamp,
  });

  /// Convert ke list format untuk API request
  List<double> toList() {
    return [stepTotal, calories, heartRate, stress];
  }

  factory HealthDataPoint.fromJson(Map<String, dynamic> json) {
    return HealthDataPoint(
      stepTotal: (json['StepTotal'] ?? json['steps'] ?? 0).toDouble(),
      calories: (json['Calories'] ?? json['calories'] ?? 0).toDouble(),
      heartRate: (json['heart_rate'] ?? json['heartRate'] ?? 0).toDouble(),
      stress: (json['stress'] ?? 0).toDouble(),
      timestamp: json['timestamp'] != null 
          ? DateTime.tryParse(json['timestamp'].toString())
          : null,
    );
  }

  @override
  String toString() {
    return 'HealthDataPoint(steps: $stepTotal, cal: $calories, hr: $heartRate, stress: $stress)';
  }
}

/// Container untuk 6 timestep data (input model)
class HealthDataSequence {
  final List<HealthDataPoint> dataPoints;

  HealthDataSequence(this.dataPoints) {
    if (dataPoints.length != 6) {
      throw ArgumentError('HealthDataSequence requires exactly 6 data points');
    }
  }

  /// Convert ke format API request: [[4 values], [4 values], ...]
  List<List<double>> toApiFormat() {
    return dataPoints.map((point) => point.toList()).toList();
  }

  factory HealthDataSequence.fromManualInput({
    required List<double> steps,
    required List<double> calories,
    required List<double> heartRates,
    required List<double> stressLevels,
  }) {
    if (steps.length != 6 || calories.length != 6 || 
        heartRates.length != 6 || stressLevels.length != 6) {
      throw ArgumentError('All input lists must have exactly 6 values');
    }

    final points = List.generate(6, (i) => HealthDataPoint(
      stepTotal: steps[i],
      calories: calories[i],
      heartRate: heartRates[i],
      stress: stressLevels[i],
    ));

    return HealthDataSequence(points);
  }
}
