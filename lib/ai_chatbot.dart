import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'session_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIChatbot extends StatefulWidget {
  const AIChatbot({super.key});

  @override
  State<AIChatbot> createState() => _AIChatbotState();
}

class _AIChatbotState extends State<AIChatbot> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";

  // Gemeni API Models 
  final List<String> _modelList = [
    'gemini-3.1-flash-lite-preview', // Best "Workhorse" for physiological stat
    'gemini-3.1-pro-preview',       // Advanced reasoning (Migrated from 3.0 Pro)
    'gemini-1.5-flash',            // Reliable legacy fallback
  ];

  late GenerativeModel _model;
  int _currentModelIndex = 0;

  final List<Map<String, String>> _messages = [
    {
      "role": "bot",
      "text": "Hi — I’m your SHIFT AI Coach.\n\nTap Analyze Latest to review your performance metrics."
    }
  ];


  Map<String, dynamic>? _latestAnalysis;
  bool _isAnalyzing = false;

  SessionItemData? get _latestSession {
    final history = SessionManager().history;
    return history.isNotEmpty ? history.first : null;
  }

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  void _initModel() {
    _model = GenerativeModel(
      model: _modelList[_currentModelIndex],
      apiKey: _apiKey,
      systemInstruction: Content.system(
        "You are the SHIFT AI Performance Coach. Analyze HR, Oxygen, and Temp. "
        "Prioritize safety and technical accuracy. Be concise.",
      ),
    );
  }

  void _switchToFallbackModel() {
    if (_currentModelIndex < _modelList.length - 1) {
      setState(() {
        _currentModelIndex++;
        _initModel();
      });
      debugPrint("🔄 Migrating to model: ${_modelList[_currentModelIndex]}");
    }
  }

  String _latestSessionAsText() {
    final s = _latestSession;
    if (s == null) return "No sessions recorded.";
    return "Date: ${s.title}, HR: ${s.avgHrBpm} BPM, O2: ${s.avgOxygen}%, Temp: ${s.avgTemperature}°C, Alerts: ${s.alerts}";
  }

  // --- CORE LOGIC ---

  Future<void> _analyzeLatestSession() async {
    // Check if there is actually data to analyze
    if (_latestSession == null) {
      setState(() {
        _messages.add({
          "role": "bot",
          "text": "I don't see any recorded sessions yet. Please record a session before asking for an analysis!"
        });
      });
      _scrollToBottom();
      return; 
    }

    setState(() { _isAnalyzing = true; _latestAnalysis = null; });

    try {
      final prompt = """
      Analyze the LATEST session below. Return ONLY valid JSON.
      DATA: ${_latestSessionAsText()}
      JSON structure:
      {
        "status": "Green/Yellow/Red",
        "observations": ["point 1", "point 2"],
        "safety": ["tip 1"]
      }
      """;

      final response = await _model.generateContent([Content.text(prompt)]);
      
      if (response.text != null) {
        setState(() {
          // Clean the response text to ensure it is valid JSON
          String cleanJson = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
          _latestAnalysis = jsonDecode(cleanJson);
        });
        debugPrint(" Analysis Success: ${_modelList[_currentModelIndex]}");
      }
    } catch (e) {
      debugPrint(" Analysis Error: $e");
      _switchToFallbackModel();
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
      final prompt = "User Question: $userText\n\nLatest Data: ${_latestSessionAsText()}";
      final response = await _model.generateContent([Content.text(prompt)]);

      setState(() {
        _messages.add({"role": "bot", "text": response.text ?? "I'm having trouble processing that."});
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint(" Chat Error: $e");
      if (_currentModelIndex < _modelList.length - 1) {
        _switchToFallbackModel();
        _sendChatMessage(); 
      } else {
        _handleError(e);
      }
    }
  }

  void _handleError(Object e) {
    String msg = "Connection error. Please check your API key.";
    if (e.toString().contains("403")) msg = "Access Denied. Check Google AI Studio permissions.";
    setState(() => _messages.add({"role": "bot", "text": msg}));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
        );
      }
    });
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("SHIFT AI Coach", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                _buildAnalyzeButton(),
                if (_latestAnalysis != null) _buildAnalysisCard(),
                const Divider(color: Colors.white10, height: 40),
                ..._messages.map((m) => _chatBubble(m)),
              ],
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isAnalyzing ? null : _analyzeLatestSession,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF085CEC),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: _isAnalyzing 
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Text("Analyze Latest Session", style: TextStyle(color: Colors.white, letterSpacing: 1.1)),
      ),
    );
  }

  Widget _buildAnalysisCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("SESSION INSIGHTS", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
              Text(_latestAnalysis!["status"] ?? "", style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          ...(_latestAnalysis!["observations"] as List? ?? []).map((o) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text("• $o", style: const TextStyle(color: Colors.white70, fontSize: 13)),
          )),
          const Divider(color: Colors.white10),
          Text("TIP: ${_latestAnalysis!["safety"]?[0] ?? "Continue monitoring stats."}", 
              style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _chatBubble(Map<String, String> m) {
    bool isUser = m['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF085CEC) : const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(m['text']!, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 30),
      color: Colors.black,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Ask about your data...",
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF1F2937),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Color(0xFF085CEC), size: 28),
            onPressed: _sendChatMessage,
          ),
        ],
      ),
    );
  }
}
