/// Custom functional Failure definitions.
abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

/// Failure representing server-side or database connection errors.
class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

/// Failure representing local storage or SharedPreferences errors.
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// Failure representing network unavailability.
class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// Failure representing authentication or authorization errors.
class AuthFailure extends Failure {
  const AuthFailure(super.message);
}
