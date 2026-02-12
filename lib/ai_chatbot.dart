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
      "text":
          "Hi — I’m your SHIFT AI Coach.\n\nTap Analyze Latest to review your most recent session, or ask a question below."
    }
  ];

  Map<String, dynamic>? _latestAnalysis;
  bool _isAnalyzing = false;

  // Always pull fresh data from SessionManager
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
Peak Heat Stress: ${s.peakHeatPercent}%
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
        "You are the SHIFT AI Performance Coach. "
        "You analyze BPM (Heart Rate) and Heat Stress. "
        "Be technical, clear, and concise.",
      ),
    );
  }

  Future<void> _analyzeLatestSession() async {
    final s = _latestSession;

    if (s == null) {
      setState(() {
        _latestAnalysis = null;
        _messages.add({
          "role": "bot",
          "text":
              "No sessions recorded yet. Complete a session first."
        });
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _latestAnalysis = null;
    });

    try {
      final prompt = """
You are a performance analytics engine.

Analyze this session and return ONLY valid JSON.
Do not include markdown.
Do not include text outside JSON.

Session Data:
${_latestSessionAsText()}

Return this exact JSON structure:

{
  "snapshot": {
    "date": "",
    "duration": "",
    "avg_hr": "",
    "peak_heat": "",
    "alerts": ""
  },
  "observations": [],
  "safety": [],
  "recommendations": []
}
""";

      final response = await _model.generateContent([Content.text(prompt)]);
      final raw = response.text ?? "{}";

      final parsed = jsonDecode(raw);

      setState(() {
        _latestAnalysis = parsed;
      });

    } catch (e) {
      setState(() {
        _messages.add({
          "role": "bot",
          "text": "Error generating analysis. Check API quota."
        });
      });
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _sendChatMessage() async {
    final userText = _controller.text.trim();
    if (userText.isEmpty) return;

    _controller.clear();

    setState(() {
      _messages.add({"role": "user", "text": userText});
    });

    try {
      final prompt = """
You are the SHIFT AI Coach.

User question:
$userText

Latest session data:
${_latestSessionAsText()}

Respond in plain text.
Be concise.
""";

      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text ?? "I couldn't respond.";

      setState(() {
        _messages.add({"role": "bot", "text": text});
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 200,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

    } catch (e) {
      setState(() {
        _messages.add({
          "role": "bot",
          "text": "Error: API quota exceeded or invalid key."
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _latestSession;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("AI Performance Coach",
            style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildLatestSessionCard(s),
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

  Widget _buildLatestSessionCard(SessionItemData? s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        s == null
            ? "No sessions recorded yet."
            : "Latest: ${s.title}\nDuration: ${s.duration} | Avg HR: ${s.avgHrBpm} BPM | Heat: ${s.peakHeatPercent}% | Alerts: ${s.alerts}",
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isAnalyzing ? null : _analyzeLatestSession,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF085CEC),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: _isAnalyzing
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Text("Analyze Latest Session"),
      ),
    );
  }

  Widget _buildAnalysisCard(Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Latest Session Analysis",
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          _buildSection("Session Snapshot", data["snapshot"]),
          _buildListSection("Key Observations", data["observations"]),
          _buildListSection("Safety Review", data["safety"]),
          _buildListSection("Training Recommendations", data["recommendations"]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Map snapshot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(
                color: Colors.white70, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text("Date: ${snapshot["date"]}",
            style: const TextStyle(color: Colors.white70)),
        Text("Duration: ${snapshot["duration"]}",
            style: const TextStyle(color: Colors.white70)),
        Text("Avg HR: ${snapshot["avg_hr"]}",
            style: const TextStyle(color: Colors.white70)),
        Text("Peak Heat: ${snapshot["peak_heat"]}",
            style: const TextStyle(color: Colors.white70)),
        Text("Alerts: ${snapshot["alerts"]}",
            style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  Widget _buildListSection(String title, List list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(
                color: Colors.white70, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...list.map<Widget>((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text("• $item",
                  style: const TextStyle(color: Colors.white70)),
            ))
      ],
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final isUser = _messages[index]["role"] == "user";
        return _buildChatBubble(isUser, _messages[index]["text"] ?? "");
      },
    );
  }

  Widget _buildChatBubble(bool isUser, String text) {
    return Align(
      alignment:
          isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
            maxWidth:
                MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color:
              isUser ? const Color(0xFF085CEC) : const Color(0xFF1A1C2E),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style:
                    const TextStyle(color: Colors.white),
                onSubmitted: (_) => _sendChatMessage(),
                decoration: const InputDecoration(
                  hintText:
                      "Ask about your performance...",
                  hintStyle:
                      TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Color(0xFF1A1C2E),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.all(Radius.circular(30)),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.send,
                  color: Color(0xFF085CEC)),
              onPressed: _sendChatMessage,
            ),
          ],
        ),
      ),
    );
  }
}
