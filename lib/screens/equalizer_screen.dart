import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/equalizer_service.dart';
import '../theme/app_theme.dart';

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  final _eq = EqualizerService();

  @override
  void initState() {
    super.initState();
    _eq.initialize().then((_) {
      if (mounted) setState(() {});
    });
    _eq.addListener(_onEqChanged);
  }

  @override
  void dispose() {
    _eq.removeListener(_onEqChanged);
    super.dispose();
  }

  void _onEqChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEnabled = _eq.isEnabled;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101012) : const Color(0xFFF6F6F9),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? const Color(0xFF101012) : Colors.white,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white : Colors.black,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Ecualizador',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.4,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CupertinoSwitch(
              activeTrackColor: AppTheme.appleMusicRed,
              value: isEnabled,
              onChanged: (val) {
                _eq.setEnabled(val);
              },
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        children: [
          // 1. Interactive Frequency Response Curve
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181C) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(
                painter: _FrequencyCurvePainter(
                  gains: _eq.bandGains,
                  isEnabled: isEnabled,
                  isDark: isDark,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 2. Presets Carousel
          Text(
            'PRESETS DE AUDIO',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: EqualizerService.defaultPresets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final preset = EqualizerService.defaultPresets[idx];
                final isSelected = _eq.currentPresetName == preset.name;

                return ChoiceChip(
                  label: Text(preset.name),
                  selected: isSelected,
                  onSelected: isEnabled
                      ? (selected) {
                          if (selected) _eq.setPreset(preset.name);
                        }
                      : null,
                  selectedColor: AppTheme.appleMusicRed,
                  backgroundColor: isDark ? const Color(0xFF1F1F24) : Colors.white,
                  labelStyle: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.appleMusicRed
                        : (isDark ? Colors.white12 : Colors.black12),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(19),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 28),

          // 3. 5-Band Vertical Sliders
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181C) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '+12 dB',
                      style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _eq.currentPresetName,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.appleMusicRed),
                    ),
                    const Text(
                      '-12 dB',
                      style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 190,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (index) {
                      final freq = EqualizerService.frequencies[index];
                      final label = freq >= 1000 ? '${(freq / 1000).toStringAsFixed(freq % 1000 == 0 ? 0 : 1)}k' : '${freq}Hz';
                      final gain = _eq.bandGains[index];

                      return Column(
                        children: [
                          Text(
                            '${gain > 0 ? "+" : ""}${gain.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 4,
                                  activeTrackColor: isEnabled ? AppTheme.appleMusicRed : Colors.grey,
                                  inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                                  thumbColor: isEnabled ? Colors.white : Colors.grey,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                ),
                                child: Slider(
                                  value: gain,
                                  min: -12.0,
                                  max: 12.0,
                                  onChanged: isEnabled
                                      ? (val) {
                                          _eq.setBandGain(index, val);
                                        }
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 4. Audio Effects: Bass Boost & Virtualizer
          Text(
            'EFECTOS ESPACIALES',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181C) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Column(
              children: [
                // Bass Boost
                Row(
                  children: [
                    Icon(CupertinoIcons.speaker_3_fill, color: AppTheme.appleMusicRed, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Refuerzo de graves (Bass Boost)',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Realce dinámico de frecuencias bajas',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${(_eq.bassBoost * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                Slider(
                  activeColor: AppTheme.appleMusicRed,
                  value: _eq.bassBoost,
                  onChanged: isEnabled ? (val) => _eq.setBassBoost(val) : null,
                ),

                const Divider(height: 20),

                // Virtualizer
                Row(
                  children: [
                    const Icon(CupertinoIcons.headphones, color: Color(0xFF5856D6), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Virtualizador Espacial 3D',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Ampliación del escenario estéreo surround',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${(_eq.virtualizer * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                Slider(
                  activeColor: const Color(0xFF5856D6),
                  value: _eq.virtualizer,
                  onChanged: isEnabled ? (val) => _eq.setVirtualizer(val) : null,
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _FrequencyCurvePainter extends CustomPainter {
  final List<double> gains;
  final bool isEnabled;
  final bool isDark;

  _FrequencyCurvePainter({
    required this.gains,
    required this.isEnabled,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final midY = h / 2;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, midY), Offset(w, midY), gridPaint);
    canvas.drawLine(Offset(0, midY - h * 0.35), Offset(w, midY - h * 0.35), gridPaint);
    canvas.drawLine(Offset(0, midY + h * 0.35), Offset(w, midY + h * 0.35), gridPaint);

    if (gains.isEmpty) return;

    final points = <Offset>[];
    final stepX = w / (gains.length + 1);

    points.add(Offset(0, isEnabled ? midY - (gains.first / 12.0) * (h * 0.40) : midY));
    for (int i = 0; i < gains.length; i++) {
      final x = (i + 1) * stepX;
      final gain = gains[i];
      final y = isEnabled ? midY - (gain / 12.0) * (h * 0.40) : midY;
      points.add(Offset(x, y));
    }
    points.add(Offset(w, isEnabled ? midY - (gains.last / 12.0) * (h * 0.40) : midY));

    // Spline curve
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    // Fill gradient
    final fillPath = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isEnabled
            ? [
                AppTheme.appleMusicRed.withValues(alpha: 0.35),
                AppTheme.appleMusicRed.withValues(alpha: 0.0),
              ]
            : [
                Colors.grey.withValues(alpha: 0.15),
                Colors.grey.withValues(alpha: 0.0),
              ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(fillPath, fillPaint);

    // Stroke line
    final linePaint = Paint()
      ..color = isEnabled ? AppTheme.appleMusicRed : Colors.grey
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Draw control point dots
    for (int i = 1; i < points.length - 1; i++) {
      final pt = points[i];
      canvas.drawCircle(
        pt,
        4.5,
        Paint()..color = isEnabled ? Colors.white : Colors.grey,
      );
      canvas.drawCircle(
        pt,
        2.5,
        Paint()..color = isEnabled ? AppTheme.appleMusicRed : Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FrequencyCurvePainter oldDelegate) {
    return oldDelegate.isEnabled != isEnabled || oldDelegate.gains != gains;
  }
}
