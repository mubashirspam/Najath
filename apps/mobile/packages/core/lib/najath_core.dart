/// Cross-cutting primitives shared by every Najath module.
///
/// Nothing here knows about a feature. Layers above import this; it imports
/// nothing from them.
library;

export 'package:fpdart/fpdart.dart' show Either, Left, Right;

export 'src/access/access_policy.dart';
export 'src/access/permission.dart';
export 'src/access/screen_registry.dart';
export 'src/config/app_config.dart';
export 'src/config/env.dart';
export 'src/constants/api_endpoints.dart';
export 'src/constants/app_durations.dart';
export 'src/constants/cache_boxes.dart';
export 'src/constants/secure_storage_keys.dart';
export 'src/error/failure.dart';
export 'src/extensions/context_extensions.dart';
export 'src/l10n/l10n.dart';
export 'src/responsive/breakpoints.dart';
export 'src/responsive/responsive_layout.dart';
export 'src/storage/secure_storage.dart';
export 'src/storage/token_storage.dart';
export 'src/utils/debouncer.dart';
export 'src/utils/ist_date.dart';
