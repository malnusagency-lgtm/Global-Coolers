class ApiConfig {
  /// Defines the base URL for the Node.js backend.
  /// Use `10.0.2.2` if running an Android emulator targeting a local server.
  /// Use `localhost` or `127.0.0.1` for Flutter Web or iOS Simulator.
  static const String baseUrl = 'http://localhost:5000/api';

  // Auth endpoints
  static const String login = '$baseUrl/auth/login';
  static const String profile = '$baseUrl/auth/profile';

  // Pickups endpoints
  static const String pickups = '$baseUrl/pickups';
  static const String schedulePickup = '$baseUrl/pickups/schedule';

  // Rewards endpoints
  static const String rewards = '$baseUrl/rewards';
}
