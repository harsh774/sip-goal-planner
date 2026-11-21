/// The newest entry in a goal's history, as reported by the API (`action`).
enum GoalAction {
  created('created'),
  updated('updated'),
  deleted('deleted'),
  completed('completed');

  const GoalAction(this.code);

  final String code;

  /// Null for a missing or unknown code, so a newer server value can't break goal parsing.
  static GoalAction? tryFromCode(String? code) {
    for (final action in values) {
      if (action.code == code) return action;
    }
    return null;
  }
}
