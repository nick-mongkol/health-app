import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

/// Pick CSV file and return its content as string (works on web and mobile)
Future<String?> pickCSVContent() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['csv'],
    withData: true, // Important for web - loads file bytes
  );

  if (result != null && result.files.single.bytes != null) {
    // Use bytes (works on web and mobile)
    final bytes = result.files.single.bytes!;
    return utf8.decode(bytes);
  }
  return null;
}

/// Parse CSV content and extract 6 timesteps of health data
/// Returns List<List<double>> with shape (6, 4)
Future<List<List<double>>> readAndPreprocessCSVContent(String csvContent) async {
  final rows = const CsvToListConverter().convert(csvContent);

  if (rows.isEmpty) {
    throw Exception("CSV file is empty");
  }

  final header = rows.first;
  final dataRows = rows.sublist(1); // Remove header

  int idxSteps = header.indexOf('StepTotal');
  int idxCalories = header.indexOf('Calories');
  int idxHr = header.indexOf('heart_rate');
  int idxStress = header.indexOf('stress');

  if ([idxSteps, idxCalories, idxHr, idxStress].contains(-1)) {
    throw Exception(
      "CSV harus memiliki kolom: StepTotal, Calories, heart_rate, stress\n"
      "Kolom yang ditemukan: ${header.join(', ')}"
    );
  }

  if (dataRows.length < 6) {
    throw Exception("CSV harus memiliki minimal 6 baris data (6 Jam), ditemukan: ${dataRows.length} baris");
  }

  // Ambil 6 baris terakhir
  final lastRows = dataRows.length > 6 
      ? dataRows.sublist(dataRows.length - 6)
      : dataRows.take(6).toList();

  return lastRows.map((row) {
    return [
      (row[idxSteps] as num).toDouble(),
      (row[idxCalories] as num).toDouble(),
      (row[idxHr] as num).toDouble(),
      (row[idxStress] as num).toDouble(),
    ];
  }).toList();
}

/// Combined function: pick CSV and parse it
Future<List<List<double>>?> pickAndParseCSV() async {
  final content = await pickCSVContent();
  if (content == null) return null;
  return readAndPreprocessCSVContent(content);
}
