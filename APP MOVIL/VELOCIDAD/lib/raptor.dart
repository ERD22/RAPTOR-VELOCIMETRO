import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

void raptorMain() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const SpeedometerApp());
}

class SpeedometerApp extends StatelessWidget {
  const SpeedometerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Raptor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SpeedometerScreen(),
    );
  }
}

class SpeedometerScreen extends StatefulWidget {
  const SpeedometerScreen({super.key});

  @override
  State<SpeedometerScreen> createState() => _SpeedometerScreenState();
}

class _SpeedometerScreenState extends State<SpeedometerScreen>
    with TickerProviderStateMixin {
  double _speedKmh = 0.0;
  double _speedMph = 0.0;
  bool _useMetric = true;
  String _status = 'Iniciando...';
  bool _isTracking = false;
  StreamSubscription<Position>? _positionStream;

  Position? _lastPosition;
  DateTime? _lastUpdate;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _status = 'Activa el GPS del dispositivo');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _status = 'Permiso de ubicación denegado');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _status = 'Permiso denegado permanentemente');
      return;
    }

    _startTracking();
  }

  void _startTracking() {
    if (mounted) {
      setState(() {
        _isTracking = true;
        _status = 'GPS activo';
      });
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).listen(
      (Position position) {
        _updateFromPosition(position);
      },
      onError: (error) {
        if (mounted) setState(() => _status = 'Error GPS: $error');
      },
    );
  }

  void _updateFromPosition(Position position) {
    final double speedMs = position.speed;
    final double kmh = speedMs < 0 ? 0.0 : speedMs * 3.6;
    final double mph = kmh * 0.621371;

    if (mounted) {
      setState(() {
        _speedKmh = kmh;
        _speedMph = mph;
        _lastPosition = position;
        _lastUpdate = DateTime.now();
        _status = 'GPS activo · Precisión ${position.accuracy.toStringAsFixed(1)} m';
      });
    }
  }

  void _stopTracking() {
    _positionStream?.cancel();
    if (mounted) {
      setState(() {
        _isTracking = false;
        _status = 'Pausado';
        _speedKmh = 0.0;
        _speedMph = 0.0;
        _lastPosition = null;
        _lastUpdate = null;
      });
    }
  }

  void _toggleTracking() {
    if (_isTracking) {
      _stopTracking();
    } else {
      _startTracking();
    }
  }

  void _toggleUnit() {
    setState(() {
      _useMetric = !_useMetric;
      if (_lastPosition != null) {
        _updateFromPosition(_lastPosition!);
      }
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  double get _displaySpeed => _useMetric ? _speedKmh : _speedMph;

  @override
  Widget build(BuildContext context) {
    final double maxSpeed = _useMetric ? 220.0 : 140.0;
    final String unit = _useMetric ? 'km/h' : 'mph';
    const double gaugeSize = 340;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white70),
                          onPressed: _initLocation,
                        ),
                        Text(
                          'VELOCÍMETRO',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                letterSpacing: 3,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                        ),
                        IconButton(
                          icon: Icon(
                            _useMetric ? Icons.social_distance : Icons.speed,
                            color: Colors.white70,
                          ),
                          onPressed: _toggleUnit,
                          tooltip: _useMetric ? 'Cambiar a mph' : 'Cambiar a km/h',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: SizedBox(
                        width: gaugeSize,
                        height: gaugeSize,
                        child: _SpeedometerGauge(
                          speedValue: _displaySpeed,
                          maxSpeed: maxSpeed,
                          unit: unit,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _InfoCard(
                      label: 'Estado',
                      value: _status,
                      icon: Icons.gps_fixed,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoCard(
                            label: 'Latitud',
                            value: _lastPosition != null
                                ? _lastPosition!.latitude.toStringAsFixed(5)
                                : '--',
                            icon: Icons.location_on,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InfoCard(
                            label: 'Longitud',
                            value: _lastPosition != null
                                ? _lastPosition!.longitude.toStringAsFixed(5)
                                : '--',
                            icon: Icons.location_on_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoCard(
                            label: 'Altitud',
                            value: _lastPosition != null
                                ? '${_lastPosition!.altitude.toStringAsFixed(0)} m'
                                : '--',
                            icon: Icons.terrain,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InfoCard(
                            label: 'Actualización',
                            value: _lastUpdate != null
                                ? '${DateTime.now().difference(_lastUpdate!).inMilliseconds} ms'
                                : '--',
                            icon: Icons.timer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _toggleTracking,
                        icon: Icon(_isTracking ? Icons.pause : Icons.play_arrow),
                        label: Text(
                          _isTracking ? 'DETENER' : 'INICIAR',
                          style: const TextStyle(letterSpacing: 2),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isTracking ? Colors.redAccent : Colors.greenAccent,
                          foregroundColor: Colors.black,
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          );
  }
}

class SpeedometerPainter extends CustomPainter {
  final double value;
  final double maxSpeed;
  final String unit;
  final String speedText;

  SpeedometerPainter({
    required this.value,
    required this.maxSpeed,
    required this.unit,
    required this.speedText,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final backgroundPaint = Paint()
      ..color = const Color(0xFF151B2B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, backgroundPaint);

    final ringPaint = Paint()
      ..color = const Color(0xFF2A344A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 8, ringPaint);

    const startAngle = 135.0 * math.pi / 180.0;
    const sweepAngle = 270.0 * math.pi / 180.0;

    final tickPaint = Paint()
      ..color = Colors.white38
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final majorTickPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final tickCount = 44;
    for (int i = 0; i <= tickCount; i++) {
      final angle = startAngle + (sweepAngle / tickCount) * i;
      final isMajor = i % 4 == 0;
      final innerRadius = isMajor ? radius - 36 : radius - 24;
      final outerRadius = radius - 16;
      final p1 = center +
          Offset(math.cos(angle) * innerRadius, math.sin(angle) * innerRadius);
      final p2 = center +
          Offset(math.cos(angle) * outerRadius, math.sin(angle) * outerRadius);
      canvas.drawLine(p1, p2, isMajor ? majorTickPaint : tickPaint);
    }

    final textStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.8),
      fontSize: radius * 0.12,
      fontWeight: FontWeight.w500,
    );
    final textPainterConfig = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    final step = maxSpeed / 11;
    for (int i = 0; i <= 11; i++) {
      final speedValue = (step * i).round();
      final angle = startAngle + (sweepAngle / 11) * i;
      final textRadius = radius - 58;
      final textCenter = center +
          Offset(
            math.cos(angle) * textRadius,
            math.sin(angle) * textRadius,
          );
      textPainterConfig.text = TextSpan(
        text: speedValue.toString(),
        style: textStyle,
      );
      textPainterConfig.layout();
      textPainterConfig.paint(
        canvas,
        textCenter -
            Offset(textPainterConfig.width / 2, textPainterConfig.height / 2),
      );
    }

    final progressPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.greenAccent,
          Colors.yellowAccent,
          Colors.orangeAccent,
          Colors.redAccent,
        ],
        stops: const [0.25, 0.5, 0.75, 1.0],
        startAngle: 0.0,
        endAngle: sweepAngle,
        transform: GradientRotation(startAngle - math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: radius - 28),
        startAngle,
        sweepAngle * value,
      );
    canvas.drawPath(path, progressPaint);

    final needleAngle = startAngle + sweepAngle * value;
    final needleLength = radius - 44;
    final needlePaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final needleTip = center +
        Offset(math.cos(needleAngle) * needleLength,
            math.sin(needleAngle) * needleLength);
    canvas.drawLine(center, needleTip, needlePaint);

    final centerDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8, centerDotPaint);

    final speedValueStyle = TextStyle(
      color: Colors.white,
      fontSize: radius * 0.45,
      fontWeight: FontWeight.bold,
      height: 1.0,
    );
    textPainterConfig.text = TextSpan(text: speedText, style: speedValueStyle);
    textPainterConfig.layout();
    textPainterConfig.paint(
      canvas,
      center -
          Offset(textPainterConfig.width / 2,
              textPainterConfig.height / 2 + radius * 0.02),
    );

    final unitStyle = TextStyle(
      color: Colors.white70,
      fontSize: radius * 0.16,
      fontWeight: FontWeight.w400,
    );
    textPainterConfig.text = TextSpan(text: unit, style: unitStyle);
    textPainterConfig.layout();
    textPainterConfig.paint(
      canvas,
      center +
          Offset(-textPainterConfig.width / 2, radius * 0.22),
    );
  }

  @override
  bool shouldRepaint(covariant SpeedometerPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.speedText != speedText ||
        oldDelegate.unit != unit ||
        oldDelegate.maxSpeed != maxSpeed;
  }
}

class _SpeedometerGauge extends StatefulWidget {
  final double speedValue;
  final double maxSpeed;
  final String unit;

  const _SpeedometerGauge({
    required this.speedValue,
    required this.maxSpeed,
    required this.unit,
  });

  @override
  State<_SpeedometerGauge> createState() => _SpeedometerGaugeState();
}

class _SpeedometerGaugeState extends State<_SpeedometerGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _lastValue = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.value = 0.0;
  }

  @override
  void didUpdateWidget(covariant _SpeedometerGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = (widget.speedValue / widget.maxSpeed).clamp(0.0, 1.0);
    if ((target - _lastValue).abs() < 0.001) return;
    _lastValue = target;

    _animation = Tween<double>(
      begin: _controller.value,
      end: target,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _speedText {
    if (widget.speedValue < 1) return '0';
    return widget.speedValue.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: SpeedometerPainter(
            value: _animation.value,
            maxSpeed: widget.maxSpeed,
            unit: widget.unit,
            speedText: _speedText,
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151B2B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.white54),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
