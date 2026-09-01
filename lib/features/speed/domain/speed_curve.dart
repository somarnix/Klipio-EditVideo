class SpeedPoint {
  const SpeedPoint({required this.time, required this.speed});

  final double time;
  final double speed;
}

class SpeedCurve {
  const SpeedCurve(
      {required this.id, required this.name, required this.points});

  final String id;
  final String name;
  final List<SpeedPoint> points;

  static const normal = SpeedCurve(
    id: 'normal',
    name: 'Normal',
    points: [SpeedPoint(time: 0, speed: 1), SpeedPoint(time: 1, speed: 1)],
  );
}
