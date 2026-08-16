import 'package:flutter/foundation.dart';

/// A single `resource:action` capability.
///
/// Hand-written rather than generated: the shape is stable, and keeping it out
/// of `screen_registry.dart` means the generated file has no logic in it.
@immutable
class Permission {
  const Permission(this.resource, this.action);

  /// Parses the wire form, `"attendance:mark"`. Returns null for anything that
  /// is not exactly one colon-separated pair, so a malformed server payload
  /// silently drops the entry rather than granting something unintended.
  static Permission? tryParse(String wire) {
    final parts = wire.split(':');
    if (parts.length != 2) return null;
    if (parts[0].isEmpty || parts[1].isEmpty) return null;
    return Permission(parts[0], parts[1]);
  }

  final String resource;
  final String action;

  String get wire => '$resource:$action';

  @override
  bool operator ==(Object other) =>
      other is Permission && other.resource == resource && other.action == action;

  @override
  int get hashCode => Object.hash(resource, action);

  @override
  String toString() => wire;
}

/// An immutable set of granted permissions with a cheap membership test.
///
/// Backed by the wire strings rather than [Permission] objects so a policy
/// decoded from JSON needs no per-entry allocation on the hot path — `can` is
/// called on every guarded widget build.
@immutable
class PermissionSet {
  const PermissionSet(this._wires);

  const PermissionSet.empty() : _wires = const {};

  factory PermissionSet.fromWire(Iterable<String> wires) {
    return PermissionSet({
      for (final wire in wires)
        if (Permission.tryParse(wire) != null) wire,
    });
  }

  final Set<String> _wires;

  Set<String> get wires => Set.unmodifiable(_wires);

  bool get isEmpty => _wires.isEmpty;

  bool has(Permission permission) => _wires.contains(permission.wire);

  bool can(String resource, String action) => _wires.contains('$resource:$action');

  /// True when the role holds any action at all on [resource]. Useful for
  /// deciding whether a whole section is worth rendering.
  bool touches(String resource) {
    final prefix = '$resource:';
    return _wires.any((w) => w.startsWith(prefix));
  }

  @override
  bool operator ==(Object other) =>
      other is PermissionSet &&
      other._wires.length == _wires.length &&
      other._wires.containsAll(_wires);

  @override
  int get hashCode => Object.hashAllUnordered(_wires);

  @override
  String toString() => 'PermissionSet(${_wires.length} granted)';
}
