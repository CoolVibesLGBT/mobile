import 'package:flutter/physics.dart';

/// Reanimated 4.1.6 defaults used by the original mobile app: mass 4 and
/// relative energy termination at 6e-9. Flutter's mass-1 default feels different.
class MobileSpring extends SpringSimulation {
  final double target, stiffness, mass, initialEnergy;
  MobileSpring(
    double start,
    this.target,
    double velocity, {
    this.stiffness = 900,
    double damping = 120,
    this.mass = 4,
  }) : initialEnergy =
           .5 * stiffness * (start - target) * (start - target) +
           .5 * mass * velocity * velocity,
       super(
         SpringDescription(mass: mass, stiffness: stiffness, damping: damping),
         start,
         target,
         velocity,
       );
  @override
  bool isDone(double time) {
    final displacement = super.x(time) - target;
    final velocity = super.dx(time);
    return initialEnergy == 0 ||
        (.5 * stiffness * displacement * displacement +
                    .5 * mass * velocity * velocity) /
                initialEnergy <=
            6e-9;
  }

  @override
  double x(double time) => isDone(time) ? target : super.x(time);
  @override
  double dx(double time) => isDone(time) ? 0 : super.dx(time);
}
