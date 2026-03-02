import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

class DevicePage extends StatefulWidget {
  final VoidCallback onStartSession;

  const DevicePage({super.key, required this.onStartSession});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> with WidgetsBindingObserver {
  final FlutterReactiveBle ble = FlutterReactiveBle();

  StreamSubscription? scanSubscription;
  StreamSubscription? connectionSubscription;
  StreamSubscription? notifySubscription;

  bool isScanning = false;
  bool isConnected = false;
  double batteryLevel = 0.0;

  final Uuid serviceUuidFull = Uuid.parse(
    "0000b001-0000-1000-8000-00805f9b34fb",
  );
  final Uuid charUuidFull = Uuid.parse("0000c001-0000-1000-8000-00805f9b34fb");

  QualifiedCharacteristic? targetCharacteristic;

  bool _isCleaningUp = false;
  bool _isConnecting = false;
  bool _didStartConnectFlow = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupBle();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    final loc = await Permission.locationWhenInUse.request();
    debugPrint("Perms scan=$scan connect=$connect loc=$loc");
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      debugPrint("App paused/detached → cleaning BLE");
      _cleanupBle();
    } else if (state == AppLifecycleState.resumed) {
      debugPrint("App resumed → checking connection");
      if (isConnected && targetCharacteristic != null) {
        _startListening();
      }
    }
  }

  Future<void> handleConnect() async {
    if (!mounted) return;
    if (isScanning || isConnected || _isConnecting) return;

    _isConnecting = true;
    _didStartConnectFlow = false;

    setState(() => isScanning = true);

    try {
      await scanSubscription?.cancel();
      scanSubscription = null;

      scanSubscription = ble
          .scanForDevices(
            withServices: [],
            scanMode: ScanMode.balanced,
          )
          .listen(
        (device) async {
          if (device.name != "SHIFT_Vest") return;
          if (_didStartConnectFlow) return;
          _didStartConnectFlow = true;

          debugPrint("Found SHIFT_Vest: ${device.id}");

          await scanSubscription?.cancel();
          scanSubscription = null;

          if (mounted) setState(() => isScanning = false);

          await Future.delayed(const Duration(milliseconds: 1200));

          await _connectToDevice(device);
        },
        onError: (e) async {
          debugPrint("Scan error: $e");
          await scanSubscription?.cancel();
          scanSubscription = null;
          if (mounted) setState(() => isScanning = false);
        },
      );

      await Future.delayed(const Duration(seconds: 15));
      if (!mounted) return;

      if (isScanning && !_didStartConnectFlow) {
        debugPrint("Scan timeout: no device found");
        await scanSubscription?.cancel();
        scanSubscription = null;
        if (mounted) setState(() => isScanning = false);
      }
    } catch (e) {
      debugPrint("Scan setup error: $e");
      await scanSubscription?.cancel();
      scanSubscription = null;
      if (mounted) setState(() => isScanning = false);
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> _connectToDevice(DiscoveredDevice device) async {
    const maxAttempts = 4;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        debugPrint("🔌 Connect attempt ${attempt + 1}/$maxAttempts to ${device.id}");

        await connectionSubscription?.cancel();
        connectionSubscription = null;

        final delayMs = [0, 700, 1500, 2500][attempt];
        if (delayMs > 0) await Future.delayed(Duration(milliseconds: delayMs));

        final completer = Completer<void>();

        connectionSubscription = ble.connectToDevice(
          id: device.id,
          servicesWithCharacteristicsToDiscover: {
            serviceUuidFull: [charUuidFull],
          },
          connectionTimeout: const Duration(seconds: 12),
        ).listen((update) async {
          if (!mounted) return;

          debugPrint("Connection state: ${update.connectionState}");

          if (update.connectionState == DeviceConnectionState.connected) {
            setState(() => isConnected = true);

            await Future.delayed(const Duration(milliseconds: 600));
            await _subscribeDirect(device.id);

            if (!completer.isCompleted) completer.complete();
          }

          if (update.connectionState == DeviceConnectionState.disconnected) {
            if (!completer.isCompleted) completer.completeError("disconnected");
          }
        }, onError: (e) {
          if (!completer.isCompleted) completer.completeError(e);
        });

        await completer.future;
        debugPrint("✅ Connected + subscribed");
        return;
      } catch (e) {
        debugPrint("❌ Attempt ${attempt + 1} failed: $e");
        await _cleanupBle();

        if (attempt == maxAttempts - 1) {
          debugPrint("🚨 All connect attempts failed");
          return;
        }
      }
    }
  }

  Future<void> _subscribeDirect(String deviceId) async {
    if (targetCharacteristic != null) return;

    targetCharacteristic = QualifiedCharacteristic(
      serviceId: serviceUuidFull,
      characteristicId: charUuidFull,
      deviceId: deviceId,
    );

    notifySubscription?.cancel();
    notifySubscription = ble.subscribeToCharacteristic(targetCharacteristic!).listen(
      (value) {
        if (!mounted) return;
        if (value.isNotEmpty) {
          setState(() {
            batteryLevel = (value[0] / 100.0).clamp(0.0, 1.0);
          });
        }
      },
      onError: (e) async {
        debugPrint("Notification error: $e");
        await _cleanupBle();
      },
    );

    debugPrint("📡 Subscribed to characteristic");
  }

  void _startListening() {
    if (targetCharacteristic == null) {
      debugPrint("Cannot start listening: no target characteristic");
      return;
    }
    debugPrint(
      "Listening started for ${targetCharacteristic!.characteristicId}",
    );
  }

  Future<void> handleDisconnect() async {
    debugPrint("🚨 User requested disconnect");
    await _cleanupBle();
  }

  Future<void> _cleanupBle() async {
    if (_isCleaningUp) return;
    _isCleaningUp = true;

    debugPrint("🔥 BLE cleanup started");

    if (targetCharacteristic != null) {
      try {
        notifySubscription?.cancel();
        notifySubscription = null;
        debugPrint("Subscription stream cancelled");
      } catch (e) {
        debugPrint("Unsubscribe/cleanup warning (ignored): $e");
      }
    }

    connectionSubscription?.cancel();
    connectionSubscription = null;

    scanSubscription?.cancel();
    scanSubscription = null;

    targetCharacteristic = null;

    if (mounted) {
      setState(() {
        isConnected = false;
        isScanning = false;
        batteryLevel = 0.0;
      });
    }

    debugPrint("✅ Cleanup finished");
    _isCleaningUp = false;
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isConnected ? _buildConnectedUI() : _buildDisconnectedUI(),
        ),
      ),
    );
  }

  Widget _buildDisconnectedUI() {
    return Column(
      children: [
        const Text(
          "SHIFT",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        _cardWrapper(
          child: Column(
            children: [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.white10,
                  child: Icon(Icons.bluetooth, color: Colors.white),
                ),
                title: const Text(
                  "SHIFT Vest",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  isScanning ? "Scanning..." : "Not Connected",
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: _statusIndicator(label: "Offline", isOnline: false),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isScanning ? null : handleConnect,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: const Color.fromARGB(255, 8, 92, 236),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isScanning
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Connect to Vest",
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedUI() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "SHIFT Performance",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Text(
            "Monitor your real-time data",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),

          _cardWrapper(
            color: const Color(0xFF0D231F),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Colors.white10,
                    child: Icon(Icons.bluetooth, color: Colors.green),
                  ),
                  title: const Text(
                    "Vest Status",
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    "Connected",
                    style: TextStyle(color: Colors.greenAccent),
                  ),
                  trailing: _statusIndicator(label: "Online", isOnline: true),
                ),
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Battery Level",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Text(
                      "${(batteryLevel * 100).toInt()}%",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: batteryLevel,
                    backgroundColor: Colors.white10,
                    color: batteryLevel < 0.2
                        ? Colors.redAccent
                        : Colors.greenAccent,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: handleDisconnect,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 45),
                    side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.red,
                  ),
                  child: const Text(
                    "Disconnect Device",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _cardWrapper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Sensor Status",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _sensorContainer(
                  _sensorRow(Icons.favorite, "BPM/Oximeter", isConnected),
                ),
                const SizedBox(height: 12),
                _sensorContainer(
                  _sensorRow(
                    Icons.grid_3x3,
                    "3-Axis Accelerometer",
                    isConnected,
                  ),
                ),
                const SizedBox(height: 12),
                _sensorContainer(
                  _sensorRow(Icons.thermostat, "Temp/Humidity", isConnected),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: isConnected ? widget.onStartSession : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              backgroundColor: const Color.fromARGB(255, 8, 92, 236),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Start New Session",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Helpers ---

  Widget _sensorContainer(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _sensorRow(IconData icon, String name, bool isActive) {
    return Row(
      children: [
        Icon(icon, color: isActive ? Colors.blueAccent : Colors.grey, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 12,
                    color: isActive ? Colors.greenAccent : Colors.redAccent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isActive ? "Active" : "Inactive",
                    style: TextStyle(
                      color: isActive ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusIndicator({required String label, required bool isOnline}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isOnline ? Colors.green.withOpacity(0.1) : Colors.black26,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline
              ? Colors.greenAccent.withOpacity(0.5)
              : Colors.white10,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isOnline ? Colors.greenAccent : Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _cardWrapper({required Widget child, Color? color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? const Color(0xFF1A1C2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}
