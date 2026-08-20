import 'dart:convert';
import 'package:flutter/material.dart';
// Using a minimal custom chat UI instead of dash_chat_2 to avoid package conflicts.
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'language_provider.dart';

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({Key? key}) : super(key: key);

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  List<Map<String, String>> messages = []; // simple list: {"who":"user|bot","text":"..."}
  Map<String, dynamic> allResponses = {};
  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
  // no special user objects needed for simple UI
    _loadResponses();
  }

  Future<void> _loadResponses() async {
    final jsonString = await rootBundle.loadString("assets/chatbot_data.json");
    allResponses = json.decode(jsonString);
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() => messages.insert(0, {"who": "user", "text": text}));
    _botReply(text.toLowerCase());
  }

  void _botReply(String query) async {
    final langCode = context.read<LanguageProvider>().languageCode;
    final responses = allResponses[langCode] ?? allResponses['en'];
    String reply = responses['hi']; // default greeting

    if (query.contains('vaccine') || query.contains('vaksin') || query.contains('टीका')) {
      reply = responses['vaccines'];
    } else if (query.contains('camp') || query.contains('शिबिर') || query.contains('કેમ્પ')) {
      reply = responses['health_camp'];
    } else if (query.contains('healthy') || query.contains('आरोग्य') || query.contains('સ્વાસ્થ્ય')) {
      reply = responses['healthy_tips'];
    }

  setState(() => messages.insert(0, {"who": "bot", "text": reply}));

    await tts.setLanguage(langCode);
    await tts.speak(reply);
  }

  void _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(onResult: (result) {
        if (result.finalResult) {
          setState(() => _isListening = false);
          _sendMessage(result.recognizedWords);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.watch<LanguageProvider>().languageCode;
    final inputController = TextEditingController();
    return Scaffold(
      appBar: AppBar(
        title: Text("Health Assistant (${langCode.toUpperCase()})"),
        actions: [
          PopupMenuButton<String>(
            onSelected: (code) => context.read<LanguageProvider>().setLanguage(code),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'en', child: Text('English')),
              PopupMenuItem(value: 'hi', child: Text('हिन्दी')),
              PopupMenuItem(value: 'mr', child: Text('मराठी')),
              PopupMenuItem(value: 'ta', child: Text('தமிழ்')),
              PopupMenuItem(value: 'gu', child: Text('ગુજરાતી')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (ctx, i) {
                final m = messages[i];
                final who = m['who'] ?? 'bot';
                final text = m['text'] ?? '';
                return ListTile(
                  title: Align(
                    alignment: who == 'user' ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: who == 'user' ? Colors.blue[100] : Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                      child: Text(text),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(children: [
              Expanded(child: TextField(controller: inputController, decoration: const InputDecoration(hintText: 'Type your question...'))),
              IconButton(icon: Icon(_isListening ? Icons.mic : Icons.mic_none), color: _isListening ? Colors.red : Colors.blue, onPressed: _startListening),
              ElevatedButton(onPressed: () { _sendMessage(inputController.text); inputController.clear(); }, child: const Text('Send'))
            ]),
          )
        ],
      ),
    );
  }
}
