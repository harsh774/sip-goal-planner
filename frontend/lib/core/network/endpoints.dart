abstract final class Endpoints {
  static const register = '/auth/register';
  static const login = '/auth/login';
  static const me = '/auth/me';
  static const goals = '/goals';

  static String goal(String id) => '/goals/$id';
}
