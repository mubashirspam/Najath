/// HTTP transport: the single Dio entry point, the response envelope every
/// remote source returns, and the connectivity signal the offline layers read.
library;

export 'src/api_response.dart';
export 'src/connectivity_interceptor.dart';
export 'src/connectivity_provider.dart';
export 'src/dio_client.dart';
