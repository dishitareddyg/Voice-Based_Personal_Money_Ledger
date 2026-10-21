class ApiPaths {
  ApiPaths._();

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  static const String dashboardSummary = '/dashboard/summary';

  static const String transactions = '/transactions';
  static String transaction(String id) => '/transactions/$id';
  static const String voiceCommands = '/commands';

  static const String calendar = '/calendar';
  static const String loans = '/loans';
  static const String repayments = '/repayments';
  static const String persons = '/persons';
  static String person(String id) => '/persons/$id';
  static const String categories = '/categories';
  static String category(String id) => '/categories/$id';

  static const String adminActions = '/admin/actions';
}
