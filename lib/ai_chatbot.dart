import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIChatbot extends StatefulWidget {
  const AIChatbot({super.key});

  @override
  State<AIChatbot> createState() => _AIChatbotState();
}

class _AIChatbotState extends State<AIChatbot> {
  final TextEditingController _controller = TextEditingController();
  late final GenerativeModel _model; // Defined here once
  
  final List<Map<String, String>> _messages = [
    {
      "role": "bot", 
      "text": "Hi! I'm your SHIFT AI Coach. I've analyzed your session history. Ready to optimize your performance?"
    }
  ];

  final String _apiKey = "AIzaSyC3nLmkC6-IIn_7MynItVbYpNAI1lrucXU"; 

  @override
  void initState() {
    super.initState();
    // Initialize the model once when the page opens
    _model = GenerativeModel(
      model: 'gemini-1.5-flash', 
      apiKey: _apiKey,
      systemInstruction: Content.system(
        "You are the SHIFT AI Performance Coach. You analyze data from the SHIFT Vest, "
        "focusing on BPM (Heart Rate), SpO2 (Blood Oxygen), and Heat Stress. "
        "Your goal is to help athletes optimize their training while staying safe. "
        "Be encouraging, technical, and professional."
      ),
    );
  }

  void _sendMessage() async {
    if (_controller.text.isEmpty) return;

    String userText = _controller.text;
    setState(() {
      _messages.add({"role": "user", "text": userText});
      _controller.clear();
    });

    try {
      // Use the pre-initialized _model
      final content = [Content.text(userText)];
      final response = await _model.generateContent(content);

      setState(() {
        _messages.add({"role": "bot", "text": response.text ?? "I'm having trouble thinking right now."});
      });
    } catch (e) {
      setState(() {
        _messages.add({"role": "bot", "text": "Error: Check your API key or internet connection."});
      });
    }
  }

  // ... build methods remain the same as your code ...
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("AI Performance Coach", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                bool isUser = _messages[index]["role"] == "user";
                return _buildChatBubble(isUser, _messages[index]["text"]!);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(bool isUser, String text) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF085CEC) : const Color(0xFF1A1C2E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 16),
          ),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
      ),
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Ask about your performance...",
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1A1C2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: const CircleAvatar(
              backgroundColor: Color(0xFF085CEC),
              child: Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
