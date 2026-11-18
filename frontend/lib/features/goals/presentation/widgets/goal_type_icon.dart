import 'package:flutter/material.dart';

import '../../domain/entities/goal_type.dart';

extension GoalTypeIcon on GoalType {
  IconData get icon => switch (this) {
    GoalType.home => Icons.home_outlined,
    GoalType.education => Icons.school_outlined,
    GoalType.retirement => Icons.beach_access_outlined,
    GoalType.car => Icons.directions_car_outlined,
    GoalType.wedding => Icons.favorite_border,
    GoalType.travel => Icons.flight_takeoff,
    GoalType.emergencyFund => Icons.health_and_safety_outlined,
    GoalType.other => Icons.flag_outlined,
  };
}
