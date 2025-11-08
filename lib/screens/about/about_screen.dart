import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _packageInfo;
  Map<String, String> _deviceInfo = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final pkg = await PackageInfo.fromPlatform();
    final devicePlugin = DeviceInfoPlugin();

    final Map<String, String> device = {};
    try {
      if (kIsWeb) {
        final info = await devicePlugin.webBrowserInfo;
        device['Platform'] = 'Web';
        device['Browser'] = info.browserName.name;
        device['User Agent'] = info.userAgent ?? '-';
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            final info = await devicePlugin.androidInfo;
            device['Platform'] = 'Android';
            device['Device'] = info.model;
            device['Manufacturer'] = info.manufacturer;
            device['Android'] = info.version.release;
            break;
          case TargetPlatform.iOS:
            final info = await devicePlugin.iosInfo;
            device['Platform'] = 'iOS';
            device['Device'] = info.utsname.machine;
            device['System'] = info.systemName;
            device['Version'] = info.systemVersion;
            break;
          case TargetPlatform.windows:
            final info = await devicePlugin.windowsInfo;
            device['Platform'] = 'Windows';
            device['Version'] = info.releaseId;
            device['Build'] = info.buildNumber.toString();
            break;
          case TargetPlatform.macOS:
            final info = await devicePlugin.macOsInfo;
            device['Platform'] = 'macOS';
            device['Device'] = info.model;
            device['OS Version'] = info.osRelease;
            break;
          case TargetPlatform.linux:
            final info = await devicePlugin.linuxInfo;
            device['Platform'] = 'Linux';
            device['Name'] = info.name;
            device['Version'] = info.version ?? '-';
            break;
          default:
            device['Platform'] = defaultTargetPlatform.name;
        }
      }
    } catch (e) {
      device['Info'] = 'Gagal membaca info perangkat: $e';
    }

    if (mounted) {
      setState(() {
        _packageInfo = pkg;
        _deviceInfo = device;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tentang Aplikasi')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          child: const Text(
                            '💰',
                            style: TextStyle(fontSize: 28),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _packageInfo?.appName ?? 'Money Tracker',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Versi ${_packageInfo?.version ?? '-'} (build ${_packageInfo?.buildNumber ?? '-'})',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _packageInfo?.packageName ?? '',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Informasi Perangkat',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: _deviceInfo.entries
                        .map(
                          (e) => ListTile(
                            dense: true,
                            title: Text(e.key),
                            subtitle: Text(e.value),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Lisensi',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Aplikasi ini menggunakan Flutter dan beberapa paket open-source.',
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
