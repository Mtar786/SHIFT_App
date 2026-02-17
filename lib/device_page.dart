import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DevicePage extends StatefulWidget {
  final VoidCallback onStartSession;

  const DevicePage({super.key, required this.onStartSession});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> with WidgetsBindingObserver {
  // Bluetooth state variables
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? sensorChar;

  // Explicitly managed subscriptions
  StreamSubscription? connectionSubscription;
  StreamSubscription? dataSubscription;
  StreamSubscription? scanSubscription;

  bool isConnected = false;
  bool isScanning = false;
  double batteryLevel = 0.0;

  // UUIDs matching Raspberry Pi Python Server
  final String serviceUuid = "B001";
  final String charUuid = "C001";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupBluetooth(); // Nuclear teardown on page exit
    super.dispose();
  }

  // --- Tier 1: Aggressive Memory Protection ---
  void _cleanupBluetooth() {
    debugPrint("🚨 Cleaning up all Bluetooth resources...");
    dataSubscription?.cancel();
    connectionSubscription?.cancel();
    scanSubscription?.cancel();

    dataSubscription = null;
    connectionSubscription = null;
    scanSubscription = null;

    sensorChar = null;
    connectedDevice = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If the app is minimized, we MUST kill the data stream.
    // iOS kills apps that try to update UI/Memory while in the background.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      if (FlutterBluePlus.isScanningNow) FlutterBluePlus.stopScan();
      dataSubscription?.cancel();
      dataSubscription = null;
      sensorChar = null;
    } else if (state == AppLifecycleState.resumed) {
      // Safely re-attach if we are still connected
      if (isConnected && sensorChar != null) {
        _listenToSensorData(sensorChar!);
      }
    }
  }

  // --- Bluetooth Logic ---

  Future<void> handleConnect() async {
    // 1. Check if we're already connecting to prevent "Listener Stacking"
    if (isScanning || isConnected) return;

    await FlutterBluePlus.adapterState
        .where((s) => s == BluetoothAdapterState.on)
        .first;

    setState(() => isScanning = true);

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          if (r.advertisementData.advName == "SHIFT_Vest") {
            await FlutterBluePlus.stopScan();
            scanSubscription?.cancel();
            _establishConnection(r.device);
            break;
          }
        }
      });
    } catch (e) {
      debugPrint("Scan Error: $e");
      if (mounted) setState(() => isScanning = false);
    }
  }

  void _establishConnection(BluetoothDevice device) async {
    try {
      // mtu: null is mandatory on iOS to prevent kernel invalidation crashes
      await device.connect(autoConnect: false, mtu: null, license: License.free);
      connectedDevice = device;

      connectionSubscription = device.connectionState.listen((state) {
        if (mounted) {
          setState(() {
            isConnected = state == BluetoothConnectionState.connected;
            if (!isConnected) {
              isScanning = false;
              _cleanupBluetooth();
            }
          });
        }
      });

      // Increased stabilization delay for iOS 18
      await Future.delayed(const Duration(milliseconds: 800));

      if (connectedDevice == null) return;
      List<BluetoothService> services = await device.discoverServices();

      for (var service in services) {
        if (service.uuid.toString().toUpperCase().contains(serviceUuid)) {
          for (var char in service.characteristics) {
            if (char.uuid.toString().toUpperCase().contains(charUuid)) {
              sensorChar = char;
              _listenToSensorData(char);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Connection Error: $e");
      if (mounted) setState(() => isScanning = false);
    }
  }

  void _listenToSensorData(BluetoothCharacteristic char) async {
    // 2. Kill any "Ghost" listener before starting a new one
    await dataSubscription?.cancel();

    try {
      await char.setNotifyValue(true);
      dataSubscription = char.onValueReceived.listen((value) {
        if (value.isNotEmpty && mounted && isConnected) {
          setState(() {
            // value[0] / 100.0 clamped to ensure it never causes a NaN UI crash
            batteryLevel = (value[0] / 100.0).clamp(0.0, 1.0);
          });
        }
      });
    } catch (e) {
      debugPrint("Data Listen Error: $e");
    }
  }

  // --- Tier 2: Atomic Disconnect (Prevents EXC_BAD_ACCESS) ---
  Future<void> handleDisconnect() async {
    debugPrint("🚨 Starting Atomic Disconnect...");

    // 1. Silence Dart listeners first
    await dataSubscription?.cancel();
    dataSubscription = null;
    sensorChar = null;

    // 2. Store device in a local variable then nullify global ref immediately
    final deviceToKill = connectedDevice;

    setState(() {
      isConnected = false;
      isScanning = false;
      connectedDevice = null;
    });

    // 3. The "Watchdog Window": Wait 1 second for iOS thread to finish its loop
    await Future.delayed(const Duration(seconds: 1));

    // 4. Teardown the native connection
    try {
      if (deviceToKill != null) {
        await deviceToKill.disconnect().timeout(
          const Duration(milliseconds: 500),
          onTimeout: () => debugPrint("Safe Timeout: Hardware will idle-disconnect."),
        );
      }
    } catch (e) {
      debugPrint("Native disconnect handled silently: $e");
    }
  }

  // --- UI Methods (Original Design) ---

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
                leading: const CircleAvatar(
                    backgroundColor: Colors.white10,
                    child: Icon(Icons.bluetooth, color: Colors.white)
                ),
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
        crossAxisAlignment: CrossAxisAlignment.center,
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
                  leading: const CircleAvatar(
                      backgroundColor: Colors.white10,
                      child: Icon(Icons.bluetooth, color: Colors.green)
                  ),
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
                    Text(
                        "${(batteryLevel * 100).toInt()}%",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
                    ),
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
                  onPressed: handleDisconnect,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 45),
                    side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor:Colors.red,
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
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
              Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 12, color: isActive ? Colors.greenAccent : Colors.redAccent),
                  const SizedBox(width: 4),
                  Text(isActive ? "Active" : "Inactive", style: TextStyle(color: isActive ? Colors.greenAccent : Colors.redAccent, fontSize: 11)),
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
          color: isOnline ? Colors.greenAccent.withOpacity(0.5) : Colors.white10,
          width: 1,
        ),
      ),
      child: Text(label, style: TextStyle(color: isOnline ? Colors.greenAccent : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
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