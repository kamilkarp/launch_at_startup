import 'dart:typed_data';

import 'package:launch_at_startup/src/app_auto_launcher.dart';
import 'package:rxdart/rxdart.dart';
import 'package:win32_registry/win32_registry.dart'
    if (dart.library.html) 'noop.dart';

class AppAutoLauncherImplWindows extends AppAutoLauncher {
  AppAutoLauncherImplWindows({
    required String appName,
    required String appPath,
    List<String> args = const [],
  }) : super(appName: appName, appPath: appPath, args: args) {
    _registryValue = args.isEmpty ? appPath : '$appPath ${args.join(' ')}';
  }

  late String _registryValue;

  RegistryKey get _regKey => Registry.openPath(
        RegistryHive.currentUser,
        path: r'Software\Microsoft\Windows\CurrentVersion\Run',
        desiredAccessRights: AccessRights.allAccess,
      );

  RegistryKey get _enabledDisabledRegKey => Registry.openPath(
        RegistryHive.currentUser,
        path:
            r'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run',
        desiredAccessRights: AccessRights.allAccess,
      );

  @override
  Future<bool> isEnabled() async {
    String? value = _regKey.getValueAsString(appName);

    return value == _registryValue && await _isEnabled();
  }

  @override
  Future<bool> enable() async {
    _regKey.createValue(RegistryValue(
      appName,
      RegistryValueType.string,
      _registryValue,
    ));

    final bytes = Uint8List(12);
    bytes[0] = 2;

    _enabledDisabledRegKey
        .createValue(RegistryValue(appName, RegistryValueType.binary, bytes));

    return true;
  }

  @override
  Future<bool> disable() async {
    _regKey.deleteValue(appName);
    _enabledDisabledRegKey.deleteValue(appName);

    return true;
  }

  @override
  Stream<bool> observeIsEnabled() {
    final regKey = _regKey;
    final enabledKey = _enabledDisabledRegKey;

    return Rx.merge([
      regKey.observeValuesChanges(),
      enabledKey.observeValuesChanges(),
    ]).asyncMap((event) => _isEnabled());
  }

  Future<bool> _isEnabled() async {
    final value = _enabledDisabledRegKey.getValue(appName);

    if (value == null) {
      return false;
    }

    final data = value.data;

    if (data is! Uint8List) {
      return false;
    }

    if (data.length != 12) {
      return false;
    }

    if (data[0].isEven) {
      return true;
    } else {
      return false;
    }
  }
}
