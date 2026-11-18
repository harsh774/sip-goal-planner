import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/currency.dart';
import '../../../../core/domain/scaled.dart';
import '../../../../core/format/money_formatter.dart';
import '../../../../core/presentation/haptics/haptics.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/gold_button.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../projection/domain/entities/projection.dart';
import '../../../projection/presentation/bloc/plan_preview_cubit.dart';
import '../../../projection/presentation/widgets/plan_preview_panel.dart';
import '../../domain/entities/goal_type.dart';
import '../../domain/validation/goal_form_validator.dart';
import '../bloc/goal_form_bloc.dart';
import '../widgets/goal_type_icon.dart';

const _livePreviewMonthlySipText = 'Live preview · monthly SIP needed';
const _detailsText = 'Details';
const _loadingYourGoalText = 'Loading your goal';
const _weCouldntLoadThisText = 'We couldn’t load this goal.';
const _typeANumberOrText = 'Type a number or drag the slider. Your plan updates as you go.';
const _theyreMarkedInRedText = 'They’re marked in red below.';
const _couldntSaveYourGoalText = 'Couldn’t save your goal.';
const _goalNameText = 'Goal name';
const _currencyText = 'Currency';
const _targetDateText = 'Target date';
const _expectedReturnAYearText = 'Expected return (% a year)';
const _yearlySipIncreaseText = 'Yearly SIP increase';
const _inflationAYearText = 'Inflation (% a year)';
const _cancelText = 'Cancel';

class GoalFormPage extends StatelessWidget {
  const GoalFormPage({super.key, this.goalId, this.template});

  final String? goalId;
  final GoalType? template;

  @override
  Widget build(BuildContext context) {
    final currency = context.read<AuthBloc>().state.user?.defaultCurrency ?? Currency.inr;
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<GoalFormBloc>()
            ..add(GoalFormStarted(defaultCurrency: currency, goalId: goalId, template: template)),
        ),
        BlocProvider(create: (_) => sl<PlanPreviewCubit>()),
      ],
      child: BlocListener<GoalFormBloc, GoalFormState>(
        listenWhen: (a, b) => a.validation != b.validation || a.status != b.status,
        listener: (context, state) {
          context.read<PlanPreviewCubit>().update(state.validation?.draft);
          if (state.status == GoalFormStatus.saved) context.pop(state.saved?.id);
        },
        child: const _GoalFormView(),
      ),
    );
  }
}

const _wideLayout = 900.0;
const _fillInTheFormText = 'Fill in the form to see your plan';
const _nothingMoreNeededText = 'Nothing more needed';
const _cautiousText = 'Cautious';
const _balancedText = 'Balanced';
const _growthText = 'Growth';
const _editGoalText = 'Edit goal';
const _newGoalText = 'New goal';
const _yourGoalText = 'Your goal';
const _fixedOnceAGoalText = 'Fixed once a goal is saved.';
const _chooseADateText = 'Choose a date';
const _assumptionsText = 'Assumptions';
const _theseRatesAreIllustrativeText =
    'These rates are illustrative assumptions used for the estimate. Real returns and inflation will differ.';
const _alsoCalledStepUpText = 'Also called step-up. 0 keeps it the same.';
const _howFastPricesRiseText = 'How fast prices rise.';
const _saveChangesText = 'Save changes';
const _saveGoalText = 'Save goal';

PlanPreviewPanel _previewPanel(GoalFormInput input, Projection? projection) => PlanPreviewPanel(
  projection: projection,
  currency: input.currency,
  target: Scaled.tryParse(input.targetAmount)?.let(Scaled.toDouble),
  targetDate: input.targetDate,
  stepUpPct: input.annualStepUp,
);

/// Phones: the live preview stays in view as a bar under the form; tap it for the details.
class _MobilePreviewBar extends StatelessWidget {
  const _MobilePreviewBar();

  @override
  Widget build(BuildContext context) {
    final input = context.select((GoalFormBloc b) => b.state.input);
    final projection = context.watch<PlanPreviewCubit>().state;
    if (input == null) return const SizedBox.shrink();

    final headline = switch (projection) {
      null => _fillInTheFormText,
      final p when p.onTrack => _nothingMoreNeededText,
      final p => '${MoneyFormatter.full(p.level.firstYearSip, input.currency)} / month',
    };

    return Material(
      color: AppColors.layer2,
      elevation: 12,
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: AppColors.layer,
            showDragHandle: true,
            builder: (_) => SingleChildScrollView(
              padding: const .only(bottom: 16),
              child: _previewPanel(input, projection),
            ),
          ),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.gold, width: 2)),
            ),
            padding: const .symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    mainAxisSize: .min,
                    children: [
                      const Text(
                        _livePreviewMonthlySipText,
                        style: TextStyle(fontSize: 12, color: AppColors.text2),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: Text(
                          headline,
                          key: ValueKey(headline),
                          style: TextStyle(
                            fontSize: projection == null ? 14 : 22,
                            fontWeight: .w500,
                            color: projection == null ? AppColors.text2 : AppColors.gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(_detailsText, style: TextStyle(color: AppColors.gold)),
                const Icon(Icons.keyboard_arrow_up, color: AppColors.gold),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalFormView extends StatelessWidget {
  const _GoalFormView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GoalFormBloc>().state;
    final narrow = MediaQuery.sizeOf(context).width < _wideLayout;
    final editing = state.status == GoalFormStatus.editing || state.status == GoalFormStatus.saving;
    return AppShell(
      bottomBar: narrow && editing ? const _MobilePreviewBar() : null,
      child: switch (state.status) {
        GoalFormStatus.loading => const LoadingView(label: _loadingYourGoalText),
        GoalFormStatus.loadFailed => ErrorView(
          title: _weCouldntLoadThisText,
          failure: state.failure!,
          onRetry: () => context.read<GoalFormBloc>().add(
            GoalFormStarted(defaultCurrency: Currency.inr, goalId: state.goalId),
          ),
        ),
        _ => _GoalForm(key: ValueKey(state.goalId), initial: state.input!),
      },
    );
  }
}

class _GoalForm extends StatefulWidget {
  const _GoalForm({super.key, required this.initial});

  final GoalFormInput initial;

  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> {
  late final _name = TextEditingController(text: widget.initial.name);
  late final _target = TextEditingController(text: widget.initial.targetAmount);
  late final _corpus = TextEditingController(text: widget.initial.currentCorpus);
  late final _return = TextEditingController(text: widget.initial.expectedReturn);
  late GoalType? _type = widget.initial.type;
  late Currency _currency = widget.initial.currency;
  late DateTime? _date = widget.initial.targetDate;
  late String _stepUp = widget.initial.annualStepUp;
  late String _inflation = widget.initial.inflation;

  static final _decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'));
  static const _returnPresets = [(_cautiousText, '8'), (_balancedText, '10'), (_growthText, '12')];

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _corpus.dispose();
    _return.dispose();
    super.dispose();
  }

  void _changed() {
    context.read<GoalFormBloc>().add(
      GoalFormChanged(
        GoalFormInput(
          name: _name.text,
          type: _type,
          currency: _currency,
          targetAmount: _target.text,
          targetDate: _date,
          currentCorpus: _corpus.text,
          expectedReturn: _return.text,
          annualStepUp: _stepUp,
          inflation: _inflation,
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime(now.year + 5, now.month, now.day),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: DateTime(now.year + 100),
    );
    if (picked == null) return;
    setState(() => _date = picked);
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GoalFormBloc>().state;
    final errors = state.visibleErrors;
    final preview = context.watch<PlanPreviewCubit>().state;

    final form = _formFields(state, errors);

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Text(state.isEdit ? _editGoalText : _newGoalText, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 4),
        const Text(_typeANumberOrText, style: TextStyle(color: AppColors.text2)),
        if (errors.isNotEmpty) ...[
          const SizedBox(height: 16),
          NoticeBanner(
            icon: Icons.error_outline,
            color: AppColors.danger,
            background: AppColors.dangerBg,
            title: errors.length == 1
                ? '1 field needs your attention.'
                : '${errors.length} fields need your attention.',
            body: _theyreMarkedInRedText,
          ),
        ],
        if (state.failure != null && errors.isEmpty) ...[
          const SizedBox(height: 16),
          NoticeBanner(
            icon: Icons.error_outline,
            color: AppColors.danger,
            background: AppColors.dangerBg,
            title: _couldntSaveYourGoalText,
            body: '${state.failure!.message} Your changes are still here.',
          ),
        ],
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, c) => MediaQuery.sizeOf(context).width >= _wideLayout
              ? Row(
                  crossAxisAlignment: .start,
                  children: [
                    Expanded(flex: 3, child: form),
                    const SizedBox(width: 32),
                    Expanded(flex: 2, child: _previewPanel(state.input!, preview)),
                  ],
                )
              : form,
        ),
      ],
    );
  }

  Widget _formFields(GoalFormState state, Map<String, String> errors) {
    final saving = state.status == GoalFormStatus.saving;
    return Container(
      color: AppColors.layer,
      padding: const .all(24),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          const _SectionTitle(_yourGoalText),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in GoalType.values)
                ChoiceChip(
                  avatar: Icon(
                    t.icon,
                    size: 16,
                    color: _type == t ? AppColors.onGold : AppColors.gold,
                  ),
                  label: Text(
                    t.label,
                    style: TextStyle(color: _type == t ? AppColors.onGold : AppColors.text),
                  ),
                  selected: _type == t,
                  onSelected: (_) {
                    setState(() => _type = t);
                    _changed();
                  },
                ),
            ],
          ),
          if (errors['goal_type'] case final e?) _ErrorText(e),
          const SizedBox(height: 24),
          TextField(
            controller: _name,
            onChanged: (_) => _changed(),
            decoration: InputDecoration(labelText: _goalNameText, errorText: errors['name']),
          ),
          const SizedBox(height: 24),
          _row([
            DropdownButtonFormField<Currency>(
              initialValue: _currency,
              decoration: InputDecoration(
                labelText: _currencyText,
                helperText: state.isEdit ? _fixedOnceAGoalText : null,
                errorText: errors['currency'],
              ),
              dropdownColor: AppColors.layer,
              items: [
                for (final c in Currency.values) DropdownMenuItem(value: c, child: Text(c.code)),
              ],
              onChanged: state.isEdit
                  ? null
                  : (c) {
                      setState(() => _currency = c!);
                      _changed();
                    },
            ),
            TextField(
              controller: _target,
              onChanged: (_) => _changed(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_decimal],
              decoration: InputDecoration(
                labelText: 'Target amount (${_currency.symbol.trim()})',
                errorText: errors['target_amount'],
              ),
            ),
          ]),
          const SizedBox(height: 24),
          _row([
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: _targetDateText,
                  errorText: errors['target_date'],
                  suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                ),
                child: Text(
                  _date == null ? _chooseADateText : DateFormats.dayMonthYear.format(_date!),
                  style: TextStyle(color: _date == null ? AppColors.text3 : AppColors.text),
                ),
              ),
            ),
            TextField(
              controller: _corpus,
              onChanged: (_) => _changed(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_decimal],
              decoration: InputDecoration(
                labelText: 'Already invested for this goal (${_currency.symbol.trim()})',
                errorText: errors['current_corpus'],
              ),
            ),
          ]),
          const SizedBox(height: 32),
          const _SectionTitle(_assumptionsText),
          const Text(
            _theseRatesAreIllustrativeText,
            style: TextStyle(fontSize: 13, color: AppColors.text2),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, value) in _returnPresets)
                ChoiceChip(
                  label: Text(
                    '$label · $value%',
                    style: TextStyle(
                      color: _return.text == value ? AppColors.onGold : AppColors.text,
                    ),
                  ),
                  selected: _return.text == value,
                  onSelected: (_) {
                    setState(() => _return.text = value);
                    _changed();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _return,
            onChanged: (_) {
              setState(() {});
              _changed();
            },
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_decimal],
            decoration: InputDecoration(
              labelText: _expectedReturnAYearText,
              errorText: errors['expected_return_pct'],
            ),
          ),
          const SizedBox(height: 24),
          _PercentSlider(
            label: _yearlySipIncreaseText,
            help: _alsoCalledStepUpText,
            value: _stepUp,
            max: 25,
            error: errors['annual_step_up_pct'],
            onChanged: (v) {
              setState(() => _stepUp = v);
              _changed();
            },
          ),
          const SizedBox(height: 16),
          _PercentSlider(
            label: _inflationAYearText,
            help: _howFastPricesRiseText,
            value: _inflation,
            max: 12,
            error: errors['inflation_pct'],
            onChanged: (v) {
              setState(() => _inflation = v);
              _changed();
            },
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: .end,
            children: [
              TextButton(
                onPressed: saving ? null : () => context.pop(),
                child: const Text(_cancelText),
              ),
              const SizedBox(width: 12),
              GoldButton(
                loading: saving,
                onPressed: () => context.read<GoalFormBloc>().add(const GoalFormSubmitted()),
                child: Text(state.isEdit ? _saveChangesText : _saveGoalText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(List<Widget> children) => LayoutBuilder(
    builder: (context, c) => c.maxWidth >= 520
        ? Row(
            crossAxisAlignment: .start,
            children: [
              Expanded(child: children[0]),
              const SizedBox(width: 16),
              Expanded(child: children[1]),
            ],
          )
        : Column(children: [children[0], const SizedBox(height: 24), children[1]]),
  );
}

class _PercentSlider extends StatelessWidget {
  const _PercentSlider({
    required this.label,
    required this.help,
    required this.value,
    required this.max,
    required this.onChanged,
    this.error,
  });

  final String label;
  final String help;
  final String value;
  final int max;
  final ValueChanged<String> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final current = (Scaled.tryParse(value) ?? 0) / 100;
    return Column(
      crossAxisAlignment: .start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.text2)),
            ),
            Text('$value%', style: const TextStyle(fontWeight: .w600)),
          ],
        ),
        Slider(
          value: current.clamp(0, max.toDouble()),
          max: max.toDouble(),
          divisions: max * 2,
          label: '$value%',
          semanticFormatterCallback: (v) => '$label ${Scaled.formatCompact((v * 100).round())}%',
          onChanged: (v) {
            final next = Scaled.formatCompact((v * 100).round());
            if (next == value) return;
            Haptics.tick();
            onChanged(next);
          },
        ),
        Text(
          error ?? help,
          style: TextStyle(fontSize: 12, color: error == null ? AppColors.text2 : AppColors.danger),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .only(bottom: 12),
    child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: .w600)),
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .only(top: 8),
    child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
  );
}

extension _Let<T extends Object> on T {
  R let<R>(R Function(T) f) => f(this);
}
