import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../ai/ai_model.dart';

/// Service untuk berkomunikasi dengan Flask API backend
class PredictionService {
  // Default ke localhost untuk development if .env invalid
  static String defaultBaseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:5000';
  
  final String baseUrl;
  final http.Client _client;

  PredictionService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? defaultBaseUrl,
        _client = client ?? http.Client();

  /// Health check endpoint
  Future<bool> isServerHealthy() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'healthy' && data['model_loaded'] == true;
      }
      return false;
    } catch (e) {
      print('Health check failed: $e');
      return false;
    }
  }

  /// Predict fitness scores dari HealthDataSequence
  Future<FitnessScores> predict(HealthDataSequence sequence) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/predict'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'data': sequence.toApiFormat()}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          return FitnessScores.fromJson(data['predictions']);
        } else {
          throw PredictionException(data['error'] ?? 'Unknown error');
        }
      } else {
        throw PredictionException('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is PredictionException) rethrow;
      throw PredictionException('Network error: $e');
    }
  }

  /// Predict dari raw data list
  Future<FitnessScores> predictFromRawData(List<List<double>> data) async {
    if (data.length != 6 && data.length != 7) {
      throw PredictionException('Data must have 6 or 7 timesteps');
    }
    for (var i = 0; i < data.length; i++) {
      if (data[i].length != 4) {
        throw PredictionException('Timestep $i must have exactly 4 features');
      }
    }

    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/predict'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'data': data}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['success'] == true) {
          return FitnessScores.fromJson(responseData['predictions']);
        } else {
          throw PredictionException(responseData['error'] ?? 'Unknown error');
        }
      } else {
        throw PredictionException('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is PredictionException) rethrow;
      throw PredictionException('Network error: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}

/// Custom exception untuk prediction errors
class PredictionException implements Exception {
  final String message;
  PredictionException(this.message);

  @override
  String toString() => 'PredictionException: $message';
}
