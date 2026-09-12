import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/config/remote_config_service.dart';

/// Gatekeeper widget that blocks access during maintenance mode or force updates
class VersionCheckGate extends StatefulWidget {
  final Widget child;

  const VersionCheckGate({super.key, required this.child});

  @override
  State<VersionCheckGate> createState() => _VersionCheckGateState();
}

class _VersionCheckGateState extends State<VersionCheckGate> {
  AppConfigState? _configState;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkConfig();
  }

  Future<void> _checkConfig() async {
    setState(() => _isLoading = true);
    try {
      final state = await RemoteConfigService.instance.evaluateAppConfig();
      if (mounted) {
        setState(() {
          _configState = state;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openStore(String storeUrl) async {
    final uri = Uri.parse(storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _configState == null) {
      return widget.child;
    }

    final status = _configState?.status ?? AppConfigStatus.normal;

    // 1. Maintenance Mode Screen
    if (status == AppConfigStatus.maintenance) {
      return Scaffold(
        backgroundColor: const Color(0xFF07060F),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBE349).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFCBE349).withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.build_circle_rounded, color: Color(0xFFCBE349), size: 40),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Scheduled Maintenance',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _configState?.maintenanceMessage ??
                      'ResumeOS is undergoing scheduled upgrades to optimize AI models. We will be back online shortly.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _checkConfig,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Check Status Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCBE349),
                    foregroundColor: const Color(0xFF07060F),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 2. Force Update Barrier Screen
    if (status == AppConfigStatus.forceUpdate) {
      return Scaffold(
        backgroundColor: const Color(0xFF07060F),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: const Color(0xFF723FFD).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF723FFD).withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.system_update_rounded, color: Color(0xFFA78BFA), size: 40),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Critical Update Required',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'A major version of ResumeOS is now available. To ensure data security and continue generating resumes, please update your app on Google Play.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Current: v${_configState?.currentVersion} • Minimum: v${_configState?.minVersion}',
                  style: const TextStyle(color: Color(0xFFCBE349), fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => _openStore(_configState?.storeUrl ?? ''),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Update on Google Play'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCBE349),
                    foregroundColor: const Color(0xFF07060F),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. Normal Execution (with optional soft-update banner if applicable)
    return widget.child;
  }
}
