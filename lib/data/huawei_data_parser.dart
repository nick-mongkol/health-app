import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../ai/ai_model.dart';

/// Parser untuk data export dari Huawei Health Privacy Center
/// Format: ZIP file berisi JSON files untuk berbagai data kesehatan
class HuaweiDataParser {
  /// Parse multiple JSON files dari Huawei Health export (String content version)
  static Future<HealthDataSequence> parseFromContent({
    required String? motionContent,
    required String? heartRateContent,
    required String? stressContent,
  }) async {
    final Map<String, List<Map<String, dynamic>>> allData = {
      'steps': [],
      'calories': [],
      'heart_rate': [],
      'stress': [],
    };

    if (motionContent != null) {
      final parsed = _parseMotionData(motionContent);
      allData['steps'] = parsed['steps'] ?? [];
      allData['calories'] = parsed['calories'] ?? [];
    }

    if (heartRateContent != null) {
      allData['heart_rate'] = _parseHeartRateData(heartRateContent);
    }

    if (stressContent != null) {
      allData['stress'] = _parseStressData(stressContent);
    }

    return _combineToSequence(allData);
  }

  /// Parse single combined JSON file from String content
  static Future<HealthDataSequence> parseFromSingleContent(String content) async {
    final data = json.decode(content);

    if (data is List) {
      final points = data
          .map((item) => HealthDataPoint.fromJson(item as Map<String, dynamic>))
          .toList();
      
      if (points.length < 6) {
        throw FormatException('Need at least 6 data points, got ${points.length}');
      }
      return HealthDataSequence(points.sublist(points.length - 6));
    } else if (data is Map) {
      final items = data['data'] as List? ?? [];
      final points = items
          .map((item) => HealthDataPoint.fromJson(item as Map<String, dynamic>))
          .toList();
      
      if (points.length < 6) {
        throw FormatException('Need at least 6 data points, got ${points.length}');
      }
      return HealthDataSequence(points.sublist(points.length - 6));
    }

    throw FormatException('Unsupported JSON format');
  }

  // Helper methods _parseMotionData, _parseHeartRateData, _parseStressData, _combineToSequence
  // remain the same as they operate on Strings or Maps.

  /// Parse motion data from Huawei format
  static Map<String, List<Map<String, dynamic>>> _parseMotionData(String content) {
    try {
      final data = json.decode(content);
      final List<Map<String, dynamic>> steps = [];
      final List<Map<String, dynamic>> calories = [];

      if (data is List) {
        for (var item in data) {
          if (item is Map<String, dynamic>) {
            final time = item['time'] ?? item['timestamp'] ?? '';
            
            if (item.containsKey('steps') || item.containsKey('StepTotal')) {
              steps.add({
                'time': time,
                'value': item['steps'] ?? item['StepTotal'] ?? 0,
              });
            }
            if (item.containsKey('calories') || item.containsKey('Calories')) {
              calories.add({
                'time': time,
                'value': item['calories'] ?? item['Calories'] ?? 0,
              });
            }
          }
        }
      } else if (data is Map && data.containsKey('data')) {
        return _parseMotionData(json.encode(data['data']));
      }

      return {'steps': steps, 'calories': calories};
    } catch (e) {
      print('Error parsing motion data: $e');
      return {'steps': [], 'calories': []};
    }
  }

  /// Parse heart rate data from Huawei format
  static List<Map<String, dynamic>> _parseHeartRateData(String content) {
    try {
      final data = json.decode(content);
      final List<Map<String, dynamic>> result = [];

      if (data is List) {
        for (var item in data) {
          if (item is Map<String, dynamic>) {
            result.add({
              'time': item['time'] ?? item['timestamp'] ?? '',
              'value': item['heart_rate'] ?? item['heartRate'] ?? item['value'] ?? 0,
            });
          }
        }
      } else if (data is Map && data.containsKey('data')) {
        return _parseHeartRateData(json.encode(data['data']));
      }

      return result;
    } catch (e) {
      print('Error parsing heart rate data: $e');
      return [];
    }
  }

  /// Parse stress data from Huawei format
  static List<Map<String, dynamic>> _parseStressData(String content) {
    try {
      final data = json.decode(content);
      final List<Map<String, dynamic>> result = [];

      if (data is List) {
        for (var item in data) {
          if (item is Map<String, dynamic>) {
            result.add({
              'time': item['time'] ?? item['timestamp'] ?? '',
              'value': item['stress'] ?? item['stressLevel'] ?? item['value'] ?? 0,
            });
          }
        }
      } else if (data is Map && data.containsKey('data')) {
        return _parseStressData(json.encode(data['data']));
      }

      return result;
    } catch (e) {
      print('Error parsing stress data: $e');
      return [];
    }
  }

  /// Combine all data sources into 6 timestep sequence
  static HealthDataSequence _combineToSequence(
      Map<String, List<Map<String, dynamic>>> allData) {
    // Get last 6 entries from each, or use defaults
    final steps = allData['steps'] ?? [];
    final calories = allData['calories'] ?? [];
    final heartRates = allData['heart_rate'] ?? [];
    final stressLevels = allData['stress'] ?? [];

    final points = <HealthDataPoint>[];
    
    for (int i = 0; i < 6; i++) {
      final stepVal = i < steps.length 
          ? (steps[steps.length - 6 + i]['value'] as num).toDouble()
          : 5000.0; // default
      final calVal = i < calories.length
          ? (calories[calories.length - 6 + i]['value'] as num).toDouble()
          : 200.0; // default
      final hrVal = i < heartRates.length
          ? (heartRates[heartRates.length - 6 + i]['value'] as num).toDouble()
          : 70.0; // default
      final stressVal = i < stressLevels.length
          ? (stressLevels[stressLevels.length - 6 + i]['value'] as num).toDouble()
          : 30.0; // default

      points.add(HealthDataPoint(
        stepTotal: stepVal,
        calories: calVal,
        heartRate: hrVal,
        stress: stressVal,
      ));
    }

    return HealthDataSequence(points);
  }

  /// Pick dan parse JSON file (Web Compatible)
  static Future<HealthDataSequence?> pickAndParseJsonFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true, // Important for Web
    );

    if (result != null && result.files.single.bytes != null) {
      // Use bytes instead of path
      final content = utf8.decode(result.files.single.bytes!);
      return parseFromSingleContent(content);
    }
    return null;
  }
}
