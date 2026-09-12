import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Network status enum
enum NetworkStatus {
  online,
  offline,
}

/// Reactive provider streaming the current network status
final networkStatusProvider = StreamProvider<NetworkStatus>((ref) {
  final connectivity = Connectivity();

  // Helper to map list of results to status
  NetworkStatus mapResults(List<ConnectivityResult> results) {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return NetworkStatus.offline;
    }
    return NetworkStatus.online;
  }

  final controller = StreamController<NetworkStatus>();

  // Check initial state
  connectivity.checkConnectivity().then((results) {
    if (!controller.isClosed) {
      controller.add(mapResults(results));
    }
  });

  // Listen to connectivity changes
  final subscription = connectivity.onConnectivityChanged.listen((results) {
    if (!controller.isClosed) {
      controller.add(mapResults(results));
    }
  });

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Convenience helper to check connectivity imperatively
class NetworkInfo {
  NetworkInfo._();

  static Future<bool> isConnected() async {
    final results = await Connectivity().checkConnectivity();
    return results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
  }
}
