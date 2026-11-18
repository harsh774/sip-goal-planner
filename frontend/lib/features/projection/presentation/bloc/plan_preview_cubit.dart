import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../goals/domain/entities/goal.dart';
import '../../domain/entities/projection.dart';
import '../../domain/usecases/calculate_projection.dart';

/// Live plan for the goal form. Runs the local engine on every valid draft;
/// `null` means the form is invalid and the preview is hidden.
class PlanPreviewCubit extends Cubit<Projection?> {
  PlanPreviewCubit(this._calculate) : super(null);

  final CalculateProjection _calculate;

  void update(GoalDraft? draft) => emit(draft == null ? null : _calculate(draft));
}
