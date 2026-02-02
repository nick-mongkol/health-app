import 'package:flutter/material.dart';
import '../ai/ai_model.dart';
import '../data/huawei_data_parser.dart';
import '../data/csv_reader.dart';
import '../services/prediction_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final PredictionService _predictionService = PredictionService();
  
  FitnessScores? _scores;
  bool _isLoading = false;
  String? _errorMessage;
  bool _serverHealthy = false;
  
  // Controllers untuk manual input
  final List<TextEditingController> _stepsControllers = 
      List.generate(6, (_) => TextEditingController(text: '5000'));
  final List<TextEditingController> _caloriesControllers = 
      List.generate(6, (_) => TextEditingController(text: '200'));
  final List<TextEditingController> _heartRateControllers = 
      List.generate(6, (_) => TextEditingController(text: '72'));
  final List<TextEditingController> _stressControllers = 
      List.generate(6, (_) => TextEditingController(text: '30'));

  @override
  void initState() {
    super.initState();
    _checkServerHealth();
  }

  Future<void> _checkServerHealth() async {
    final healthy = await _predictionService.isServerHealthy();
    setState(() => _serverHealthy = healthy);
  }

  Future<void> _predictFromManualInput() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final steps = _stepsControllers.map((c) => double.tryParse(c.text) ?? 0).toList();
      final calories = _caloriesControllers.map((c) => double.tryParse(c.text) ?? 0).toList();
      final heartRates = _heartRateControllers.map((c) => double.tryParse(c.text) ?? 0).toList();
      final stress = _stressControllers.map((c) => double.tryParse(c.text) ?? 0).toList();

      final sequence = HealthDataSequence.fromManualInput(
        steps: steps,
        calories: calories,
        heartRates: heartRates,
        stressLevels: stress,
      );

      final scores = await _predictionService.predict(sequence);
      setState(() => _scores = scores);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _predictFromJson() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sequence = await HuaweiDataParser.pickAndParseJsonFile();
      if (sequence == null) {
        setState(() => _isLoading = false);
        return;
      }

      final scores = await _predictionService.predict(sequence);
      setState(() => _scores = scores);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _predictFromCsv() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await pickAndParseCSV();
      if (data == null) {
        setState(() => _isLoading = false);
        return;
      }

      final scores = await _predictionService.predictFromRawData(data);
      setState(() => _scores = scores);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    for (var c in _stepsControllers) c.dispose();
    for (var c in _caloriesControllers) c.dispose();
    for (var c in _heartRateControllers) c.dispose();
    for (var c in _stressControllers) c.dispose();
    _predictionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildServerStatus(),
                const SizedBox(height: 24),
                _buildInputOptions(),
                const SizedBox(height: 24),
                if (_isLoading) _buildLoadingIndicator(),
                if (_errorMessage != null) _buildErrorMessage(),
                if (_scores != null) _buildScoreCards(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.fitness_center,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smartwatch Health Monitor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Text(
                //   'Powered by LSTM Deep Learning',
                //   style: TextStyle(
                //     color: Colors.white70,
                //     fontSize: 14,
                //   ),
                // ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildServerStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _serverHealthy 
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _serverHealthy ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _serverHealthy ? Icons.cloud_done : Icons.cloud_off,
            color: _serverHealthy ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _serverHealthy 
                  ? 'Server Connected - Ready for predictions'
                  : 'Server Offline - Start the backend first',
              style: TextStyle(
                color: _serverHealthy ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _checkServerHealth,
          ),
        ],
      ),
    );
  }

  Widget _buildInputOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Masukan Data Kesehatan Smartwatch Anda',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Quick action buttons
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.upload_file,
                label: 'Upload JSON',
                subtitle: 'Huawei Export',
                onTap: _predictFromJson,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.table_chart,
                label: 'Upload CSV',
                subtitle: 'Health Sync',
                onTap: _predictFromCsv,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Manual input section
        _buildManualInputSection(),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.1),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualInputSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header dengan penjelasan
          const Row(
            children: [
              Icon(Icons.edit, color: Colors.white70, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Input Manual Data Kesehatan',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Penjelasan cara input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Cara Mengisi:',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  '• Masukkan 6 data per jam dari smartwatch Anda\n'
                  '• T1-T6 = Jam ke-1 sampai Jam ke-6\n'
                  '• Data bisa diambil dari Huawei Health app',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Header kolom timestep
          Padding(
            padding: const EdgeInsets.only(left: 100),
            child: Row(
              children: List.generate(6, (i) => Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Jam ${i + 1}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              )),
            ),
          ),
          const SizedBox(height: 8),
          
          // Input rows
          _buildInputRow('Langkah', _stepsControllers, Icons.directions_walk, '5000'),
          _buildInputRow('Kalori', _caloriesControllers, Icons.local_fire_department, '200'),
          _buildInputRow('Detak Jantung', _heartRateControllers, Icons.favorite, '72'),
          _buildInputRow('Tingkat Stres', _stressControllers, Icons.psychology, '30'),
          
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _predictFromManualInput,
              icon: const Icon(Icons.analytics),
              label: const Text(
                'Analisis Skor Kebugaran',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366f1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(String label, List<TextEditingController> controllers, IconData icon, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Label di kiri
          SizedBox(
            width: 92,
            child: Row(
              children: [
                Icon(icon, color: Colors.white54, size: 14),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Input fields
          Expanded(
            child: Row(
              children: List.generate(6, (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i > 0 ? 4 : 0),
                  child: TextField(
                    controller: controllers[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      hintText: hint,
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 10),
                    ),
                  ),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: const Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              color: Color(0xFF6366f1),
            ),
            SizedBox(height: 16),
            Text(
              'Analyzing your health data...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fitness Scores',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Overall score card
        _buildOverallScoreCard(),
        const SizedBox(height: 16),
        
        // Individual scores
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _buildScoreCard('Sleep', _scores!.sleepScore, Icons.bedtime, const Color(0xFF8b5cf6)),
            _buildScoreCard('HRV', _scores!.hrvScore, Icons.timeline, const Color(0xFF06b6d4)),
            _buildScoreCard('Resting HR', _scores!.rhrScore, Icons.favorite, const Color(0xFFef4444)),
            _buildScoreCard('Recovery', _scores!.recoveryScore, Icons.refresh, const Color(0xFF22c55e)),
            // _buildScoreCard('Readiness', _scores!.readinessScore, Icons.bolt, const Color(0xFFf59e0b)),
          ],
        ),
      ],
    );
  }

  Widget _buildOverallScoreCard() {
    final overall = _scores!.overallScore;
    final label = _scores!.getScoreLabel(overall);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6366f1),
            const Color(0xFF8b5cf6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366f1).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overall Fitness',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            child: Center(
              child: Text(
                '${overall.toInt()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(String title, double score, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                '${score.toInt()}%',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
