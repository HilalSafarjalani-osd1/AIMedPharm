import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

/// General failure from the API/Server
class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

/// Failure specifically when reading text from image
class OcrFailure extends Failure {
  const OcrFailure(super.message);
}

/// Failure when the AI cannot format or understand the ingredients
class AiFailure extends Failure {
  const AiFailure(super.message);
}

/// Failure when no internet connection is detected
class ConnectionFailure extends Failure {
  const ConnectionFailure([super.message = "No Internet Connection"]);
}
