enum GoalType {
  home('home', 'Home'),
  education('education', 'Education'),
  retirement('retirement', 'Retirement'),
  car('car', 'Car'),
  wedding('wedding', 'Wedding'),
  travel('travel', 'Travel'),
  emergencyFund('emergency_fund', 'Emergency fund'),
  other('other', 'Other');

  const GoalType(this.code, this.label);

  final String code;
  final String label;

  static GoalType fromCode(String code) => values.firstWhere(
    (t) => t.code == code,
    orElse: () => throw FormatException('Unknown goal type: $code'),
  );
}
