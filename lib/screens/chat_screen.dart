import 'dart:convert';

import 'package:chatgpt_flutter/LogUtils.dart';
import 'package:flutter/material.dart';
import 'package:chatgpt_flutter/constants.dart';
import 'package:chatgpt_flutter/settings.dart';
import 'package:chatgpt_flutter/models/chat_message.dart';
import 'package:chatgpt_flutter/models/chat_message.dart';
import 'package:chatgpt_flutter/services/chat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key, Settings? settings}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  ChatService? _chatService;
  Settings? _settings;
  ChatHistory? _history;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      _settings = Settings(prefs: prefs);
      _chatService = ChatService(apiKey: _settings!.openaiApiKey);
      _history = ChatHistory(prefs: prefs);
      _messages.addAll(_history!.messages);
    });
  }

  void _sendMessage(String text) async {
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final message = ChatMessage(role: 'user', content: text);
    _messages.add(message);
    _controller.clear();

    try {
      final response = await _chatService!.getCompletion(
          '${_settings!.promptString}\n${_getChatHistory()}\n${message.content}\n');
      final completion = response['choices'][0]['message']['content'];
      LogUtils.error(completion);

      setState(() {
        _isLoading = false;
        final message = ChatMessage(role: 'assistant', content: completion);
        _messages.add(message);
        _history?.addMessage(message);
      });

    } catch (e) {
      LogUtils.error(e.toString());
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message'),
        ),
      );
    }
  }

  String _getChatHistory() {
    final history = _messages
        .where((message) => message.role == 'user')
        .map((message) => message.content.trim())
        .join('\n');

    return _settings!.continueConversationEnable ? history : '';
  }

  Widget _buildLoadingIndicator() {
    return Positioned(
      bottom: 10,
      right: 10,
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildChatMessage(ChatMessage message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: message.role == 'user' ? Colors.blue : Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message.content,
        style: TextStyle(
          color: message.role == 'user' ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('OpenAI Chat'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView.builder(
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return _buildChatMessage(message);
            },
          ),
          if (_isLoading) _buildLoadingIndicator(),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Type a message',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 5,
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: _sendMessage,
                ),
              ),
              SizedBox(width: 10),
              IconButton(
                icon: Icon(Icons.send),
                onPressed: () => _sendMessage(_controller.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
