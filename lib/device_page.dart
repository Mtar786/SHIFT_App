import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'live_session_screen.dart';

class DevicePage extends StatefulWidget {
  final VoidCallback onStartSession;
  // Callback to bubble the parsed JSON up to the NavigationWrapper
  final Function(Map<String, dynamic>) onDataReceived;

  const DevicePage({
    super.key,
    required this.onStartSession,
    required this.onDataReceived,
  });

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
  double batteryLevel = 1.0;
  double bpm = 0.0;
  double blood_oxygen = 0.0;
  double temperature = 0.0;
  int quality = 0;
  String alarms = "";

  final GlobalKey<LiveSessionScreenState> _sessionKey = GlobalKey();

  final Uuid serviceUuidFull = Uuid.parse("0000b001-0000-1000-8000-00805f9b34fb");
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
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _cleanupBle();
    }
  }

  Future<void> handleConnect() async {
    if (!mounted || isScanning || isConnected || _isConnecting) return;

    _isConnecting = true;
    _didStartConnectFlow = false;
    setState(() => isScanning = true);

    try {
      await scanSubscription?.cancel();
      scanSubscription = ble.scanForDevices(withServices: []).listen(
        (device) async {
          if (device.name != "SHIFT_Vest" || _didStartConnectFlow) return;
          _didStartConnectFlow = true;

          await scanSubscription?.cancel();
          scanSubscription = null;
          if (mounted) setState(() => isScanning = false);

          await _connectToDevice(device);
        },
        onError: (e) => _cleanupBle(),
      );

      // Auto-stop scan after 15s if nothing found
      Future.delayed(const Duration(seconds: 15), () {
        if (isScanning && !_didStartConnectFlow) _cleanupBle();
      });
    } catch (e) {
      _cleanupBle();
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> _connectToDevice(DiscoveredDevice device) async {
    connectionSubscription = ble.connectToDevice(
      id: device.id,
      servicesWithCharacteristicsToDiscover: {serviceUuidFull: [charUuidFull]},
      connectionTimeout: const Duration(seconds: 12),
    ).listen((update) async {
      if (update.connectionState == DeviceConnectionState.connected) {
        // CRITICAL: Request higher MTU for JSON strings (e.g., 150 bytes)
        try {
          await ble.requestMtu(deviceId: device.id, mtu: 150);
        } catch (e) {
          debugPrint("MTU Request failed: $e");
        }

        setState(() => isConnected = true);
        await _subscribeDirect(device.id);
      } else if (update.connectionState == DeviceConnectionState.disconnected) {
        _cleanupBle();
      }
    }, onError: (e) => _cleanupBle());
  }

  Future<void> _subscribeDirect(String deviceId) async {
    targetCharacteristic = QualifiedCharacteristic(
      serviceId: serviceUuidFull,
      characteristicId: charUuidFull,
      deviceId: deviceId,
    );

    notifySubscription?.cancel();
    notifySubscription = ble.subscribeToCharacteristic(targetCharacteristic!).listen(
      (value) {
        if (!mounted || value.isEmpty) return;

        try {
          // 1. Decode bytes to String
          String rawJson = utf8.decode(value);
          // 2. Parse JSON
          Map<String, dynamic> data = jsonDecode(rawJson);

          // 3. Update local data
          setState(() {
            // Mapping keys: b -> battery, o -> oxygen, t -> temp, q -> quality, a -> status
            bpm = (data['b'] ?? 0.0).toDouble();
            blood_oxygen = (data['o'] ?? 0.0).toDouble();
            temperature = (data['t'] ?? 0.0).toDouble();
            quality = data['q'] ?? 0;
            if (data['a'] != null && (data['a'] as List).isNotEmpty) {
              alarms = data['a'][0];
            }
          });
          debugPrint("Parsed Data: B:$bpm, O:$blood_oxygen, T:$temperature, Q:$quality, A:$alarms");

          // 4. Send the whole map to the parent (NavigationWrapper)
          widget.onDataReceived(data);

        } catch (e) {
          debugPrint("JSON Parse Error: $e");
        }
      },
      onError: (e) => _cleanupBle(),
    );
  }

  Future<void> _cleanupBle() async {
    if (_isCleaningUp) return;
    _isCleaningUp = true;

    await notifySubscription?.cancel();
    await connectionSubscription?.cancel();
    await scanSubscription?.cancel();

    notifySubscription = null;
    connectionSubscription = null;
    scanSubscription = null;
    targetCharacteristic = null;

    if (mounted) {
      setState(() {
        isConnected = false;
        isScanning = false;
        batteryLevel = 1.0;
      });
    }
    _isCleaningUp = false;
  }

  // --- UI REMAINS THE SAME ---
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
        const Text("SHIFT", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 20),
        _cardWrapper(
          child: Column(
            children: [
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.white10, child: Icon(Icons.bluetooth, color: Colors.white)),
                title: const Text("SHIFT Vest", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(isScanning ? "Scanning..." : "Not Connected", style: const TextStyle(color: Colors.grey)),
                trailing: _statusIndicator(label: "Offline", isOnline: false),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isScanning ? null : handleConnect,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: const Color.fromARGB(255, 8, 92, 236),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isScanning
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Connect to Vest", style: TextStyle(fontSize: 16)),
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
        children: [
          const Text("SHIFT Performance", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const Text("Monitor your real-time data", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          _cardWrapper(
            color: const Color(0xFF0D231F),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(backgroundColor: Colors.white10, child: Icon(Icons.bluetooth, color: Colors.green)),
                  title: const Text("Vest Status", style: TextStyle(color: Colors.white)),
                  subtitle: const Text("Connected", style: TextStyle(color: Colors.greenAccent)),
                  trailing: _statusIndicator(label: "Online", isOnline: true),
                ),
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Battery Level", style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text("${(batteryLevel * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: batteryLevel,
                    backgroundColor: Colors.white10,
                    color: batteryLevel < 0.2 ? Colors.redAccent : Colors.greenAccent,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _cleanupBle,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 45),
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Disconnect Device", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _cardWrapper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Sensor Status", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _sensorContainer(_sensorRow(Icons.favorite, "BPM/Oximeter", isConnected)),
                const SizedBox(height: 12),
                _sensorContainer(_sensorRow(Icons.grid_3x3, "3-Axis Accelerometer", isConnected)),
                const SizedBox(height: 12),
                _sensorContainer(_sensorRow(Icons.thermostat, "Temp/Humidity", isConnected)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: widget.onStartSession,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              backgroundColor: const Color.fromARGB(255, 8, 92, 236),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Start New Session", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Helpers
  Widget _sensorContainer(Widget child) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)), child: child);
  Widget _sensorRow(IconData icon, String name, bool isActive) => Row(children: [Icon(icon, color: isActive ? Colors.blueAccent : Colors.grey, size: 24), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)), Row(children: [Icon(Icons.check_circle_outline, size: 12, color: isActive ? Colors.greenAccent : Colors.redAccent), const SizedBox(width: 4), Text(isActive ? "Active" : "Inactive", style: TextStyle(color: isActive ? Colors.greenAccent : Colors.redAccent, fontSize: 11))])]))]);
  Widget _statusIndicator({required String label, required bool isOnline}) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isOnline ? Colors.green.withOpacity(0.1) : Colors.black26, borderRadius: BorderRadius.circular(20), border: Border.all(color: isOnline ? Colors.greenAccent.withOpacity(0.5) : Colors.white10)), child: Text(label, style: TextStyle(color: isOnline ? Colors.greenAccent : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)));
  Widget _cardWrapper({required Widget child, Color? color}) => Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: color ?? const Color(0xFF1A1C2E), borderRadius: BorderRadius.circular(20)), child: child);
  void _startListening() => debugPrint("Listening started");
}