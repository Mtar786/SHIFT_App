import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'session_manager.dart';

class AIChatbot extends StatefulWidget {
  const AIChatbot({super.key});

  @override
  State<AIChatbot> createState() => _AIChatbotState();
}

class _AIChatbotState extends State<AIChatbot> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const String _apiKey = "AIzaSyC3nLmkC6-IIn_7MynItVbYpNAI1lrucXU";
  late final GenerativeModel _model;

  final List<Map<String, String>> _messages = [
    {
      "role": "bot",
      "text": "Hi — I’m your SHIFT AI Coach.\n\nTap Analyze Latest to review your metrics from your last session."
    }
  ];

  Map<String, dynamic>? _latestAnalysis;
  bool _isAnalyzing = false;

  // GRAB ONLY THE LATEST: Returns just the first item in history
  SessionItemData? get _latestSession {
    final history = SessionManager().history;
    return history.isNotEmpty ? history.first : null;
  }

  String _latestSessionAsText() {
    final s = _latestSession;
    if (s == null) return "No sessions recorded.";

    return """
Date: ${s.title}
Duration: ${s.duration}
Average HR: ${s.avgHrBpm} BPM
Average Oxygen: ${s.avgOxygen.toStringAsFixed(1)}%
Average Temp: ${s.avgTemperature.toStringAsFixed(1)}°C
Alerts: ${s.alerts}
""";
  }

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
      model: 'gemini-3-flash-preview',
      apiKey: _apiKey,
      systemInstruction: Content.system(
        "You are the SHIFT AI Performance Coach. You analyze the user's latest recorded session. "
        "Provide technical physiological feedback on HR, Oxygen, and Temperature. "
        "Prioritize safety and be concise.",
      ),
    );
  }

  Future<void> _analyzeLatestSession() async {
    final s = _latestSession;
    if (s == null) {
      setState(() {
        _messages.add({"role": "bot", "text": "No session found to analyze."});
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _latestAnalysis = null;
    });

    try {
      final prompt = """
Analyze the LATEST session provided below. Return ONLY valid JSON.

SESSION DATA:
${_latestSessionAsText()}

JSON structure:
{
  "snapshot": {
    "date": "${s.title}",
    "duration": "${s.duration}",
    "avg_hr": "${s.avgHrBpm} BPM",
    "avg_oxygen": "${s.avgOxygen.toStringAsFixed(1)}%",
    "avg_temp": "${s.avgTemperature.toStringAsFixed(1)}°C",
    "alerts": "${s.alerts}"
  },
  "observations": [],
  "safety": [],
  "recommendations": []
}
""";

      final response = await _model.generateContent([Content.text(prompt)]);
      final parsed = jsonDecode(response.text ?? "{}");

      setState(() {
        _latestAnalysis = parsed;
      });
    } catch (e) {
      setState(() {
        _messages.add({"role": "bot", "text": "Error analyzing session."});
      });
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _sendChatMessage() async {
    final userText = _controller.text.trim();
    if (userText.isEmpty) return;
    _controller.clear();

    setState(() => _messages.add({"role": "user", "text": userText}));

    try {
      final prompt = "User Question: $userText\n\nLatest Session Data:\n${_latestSessionAsText()}\n\nRespond concisely in plain text.";
      final response = await _model.generateContent([Content.text(prompt)]);

      setState(() {
        _messages.add({"role": "bot", "text": response.text ?? "No response."});
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _messages.add({"role": "bot", "text": "Error connecting to AI."}));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: const Text("AI Coach")),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 12),
                  _buildAnalyzeButton(),
                  if (_latestAnalysis != null) ...[
                    const SizedBox(height: 12),
                    _buildAnalysisCard(_latestAnalysis!),
                  ],
                  const SizedBox(height: 20),
                  _buildChatList(),
                ],
              ),
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final s = _latestSession;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(16)),
      child: Text(
        s == null ? "No sessions recorded." : "Ready to analyze session: ${s.title}",
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return SizedBox(
      width: double.infinity, height: 48,
      child: ElevatedButton(
        onPressed: _isAnalyzing ? null : _analyzeLatestSession,
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF085CEC), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: _isAnalyzing ? const CircularProgressIndicator(color: Colors.white) : const Text("Analyze Latest Session"),
      ),
    );
  }

  Widget _buildAnalysisCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0B1120), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1E293B))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Session Insights", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildSection("Metrics Snapshot", data["snapshot"]),
          _buildListSection("Observations", data["observations"]),
          _buildListSection("Safety & Tips", data["safety"]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Map snapshot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 8),
        ...snapshot.entries.map((e) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(e.key.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.white60, fontSize: 10)),
              Text(e.value.toString(), style: const TextStyle(color: Colors.white, fontSize: 11)),
            ],
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildListSection(String title, List list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
        ...list.map((item) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text("• $item", style: const TextStyle(color: Colors.white70, fontSize: 12)),
        )),
      ],
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final isUser = _messages[index]["role"] == "user";
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: isUser ? const Color(0xFF085CEC) : const Color(0xFF1A1C2E), borderRadius: BorderRadius.circular(12)),
            child: Text(_messages[index]["text"]!, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller, style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Ask about this session...",
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true, fillColor: const Color(0xFF1A1C2E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                ),
              ),
            ),
            IconButton(icon: const Icon(Icons.send, color: Color(0xFF085CEC)), onPressed: _sendChatMessage),
          ],
        ),
      ),
    );
  }
}