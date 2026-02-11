import 'package:flutter/material.dart';

class DevicePage extends StatefulWidget {
  // Callback function to trigger navigation in the parent
  final VoidCallback onStartSession;

  const DevicePage({super.key, required this.onStartSession});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  bool isConnected = false;
  double batteryLevel = 0.0;

  void handleConnect() {
    setState(() {
      isConnected = true;
      batteryLevel = 0.1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isConnected ? _buildConnectedUI() : _buildDisconnectedUI(),
      ),
    );
  }

  // --- View 1: Disconnected UI ---
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
                subtitle: const Text("Not Connected", style: TextStyle(color: Colors.grey)),
                trailing: _statusIndicator(label: "Offline", isOnline: false),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: handleConnect,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: const Color.fromARGB(255, 8, 92, 236),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Connect to Vest", style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- View 2: Connected UI ---
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
                      "${(batteryLevel.clamp(0.0, 1.0) * 100).toInt()}%",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: batteryLevel.clamp(0.0, 1.0),
                    backgroundColor: Colors.white10,
                    color: batteryLevel < 0.2 ? Colors.redAccent : Colors.greenAccent,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => setState(() => isConnected = false),
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
                _sensorContainer(_sensorRow(Icons.favorite, "BPM/Oximeter", true)),
                const SizedBox(height: 12),
                _sensorContainer(_sensorRow(Icons.grid_3x3, "3-Axis Accelerometer", true)),
                const SizedBox(height: 12),
                _sensorContainer(_sensorRow(Icons.thermostat, "Temp/Humidity", true)),
              ],
            ),
          ),

          const SizedBox(height: 24),
          ElevatedButton(
            // TRIGGER NAVIGATION HERE
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