/// HTTP transport: the single Dio entry point, the failure classifier every
/// response passes through, and the connectivity signal the offline layers read.
library;

export 'src/connectivity_interceptor.dart';
export 'src/connectivity_provider.dart';
export 'src/dio_client.dart';
export 'src/failure_mapper.dart';
