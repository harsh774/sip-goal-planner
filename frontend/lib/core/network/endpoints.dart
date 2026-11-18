abstract final class Endpoints {
  static const register = '/auth/register';
  static const login = '/auth/login';
  static const me = '/auth/me';
  static const password = '/auth/me/password';
  static const goals = '/goals';
  static const publicKey = '/crypto/public-key';
  static const goalsSummary = '/goals/summary';

  static String goal(String id) => '/goals/$id';
}
