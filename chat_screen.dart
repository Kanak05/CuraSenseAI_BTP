import 'dart:convert';
import 'dart:collection';
import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/llama_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/input_field.dart';
import '../models/message.dart';
import '../screens/settings_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final LlamaService _llamaService = LlamaService();

  // In-memory chat store: chatId -> messages
  final LinkedHashMap<String, List<Message>> _chats = LinkedHashMap();

  // Current open chat
  String? _currentChatId;
  final List<Message> _messages = [];

  // Attachments
  final List<File> _attachedFiles = [];

  bool _isLoading = false;
  bool _isDrawerOpen = false;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ----------------------------------
  // Persistence helpers
  // ----------------------------------
  String _generateChatId() => DateTime.now().millisecondsSinceEpoch.toString();

  Future<void> _saveChats() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_chats.map((key, value) {
      return MapEntry(key, value.map((m) => m.toJson()).toList());
    }));
    await prefs.setString('chats', encoded);
  }

  Future<void> _loadChats() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('chats');
    if (data == null) return;

    try {
      final decoded = jsonDecode(data) as Map<String, dynamic>;
      setState(() {
        _chats.clear();
        decoded.forEach((key, value) {
          final msgs = (value as List)
              .map((m) => Message.fromJson(Map<String, dynamic>.from(m)))
              .toList();
          _chats[key] = msgs;
        });
      });
    } catch (e) {
      if (kDebugMode) print('Failed to load chats: $e');
    }
  }

  // ----------------------------------
  // Chat management
  // ----------------------------------
  Future<void> _newChat() async {
    // Save current only if it exists and has messages
    if (_currentChatId != null && _messages.isNotEmpty) {
      _chats[_currentChatId!] = List.from(_messages);
      await _saveChats();
    }

    setState(() {
      _currentChatId = _generateChatId();
      _messages.clear();
      _attachedFiles.clear();
      _errorMessage = null;
    });

    // Close drawer on mobile if open
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  Future<void> _switchToChat(String chatId) async {
    final messages = _chats[chatId] ?? [];
    setState(() {
      _currentChatId = chatId;
      _messages
        ..clear()
        ..addAll(List.from(messages));
      _errorMessage = null;
    });

    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  // ----------------------------------
  // Messaging
  // ----------------------------------
  String? _errorMessage;

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty && _attachedFiles.isEmpty) return;

    // Ensure chat id exists
    if (_currentChatId == null) {
      _currentChatId = _generateChatId();
      _chats[_currentChatId!] = [];
    }

    final userMessage = Message(
      text: text.trim(),
      isUser: true,
      attachments: _attachedFiles.map((file) {
        final name = file.path.split(Platform.pathSeparator).last;
        return {"name": name, "path": file.path};
      }).toList(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _errorMessage = null;
    });

    // Save immediately after user message — prevents loss if app quits
    _chats[_currentChatId!] = List.from(_messages);
    await _saveChats();

    _controller.clear();
    _scrollToBottom();

    try {
      String combinedResponse = '';

      // If there are PDFs attached, send sequentially so backend can process them
      if (_attachedFiles.isNotEmpty) {
        for (final file in _attachedFiles) {
          final reply = await _llamaService.generateResponse(
            text.trim().isEmpty ? 'Analyze this report' : text.trim(),
            pdfFile: file,
          );
          combinedResponse += '\n\n📄 **${file.path.split(Platform.pathSeparator).last}**:\n$reply';
        }
      } else {
        combinedResponse = await _llamaService.generateResponse(text.trim());
      }

      if (!mounted) return;

      final aiMessage = Message(text: combinedResponse.trim(), isUser: false);

      setState(() {
        _messages.add(aiMessage);
        _isLoading = false;
        _attachedFiles.clear();
      });

      // Save after AI reply as well
      _chats[_currentChatId!] = List.from(_messages);
      await _saveChats();

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });

      _showSnackBar(
        e.toString().contains('Connection refused')
            ? 'Cannot reach the AI server. Please check your backend connection.'
            : 'Failed to get response: $e',
        isError: true,
      );
    }
  }

  // ----------------------------------
  // File picker
  // ----------------------------------
  Future<void> _pickAndAnalyzePdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      final allowedFiles = <File>[];

      for (final file in result.files) {
        if (file.path == null) continue;
        final selected = File(file.path!);
        final sizeInMB = selected.lengthSync() / (1024 * 1024);
        if (sizeInMB > 5) {
          _showSnackBar('${file.name} is too large (max 5MB).', isError: true);
        } else {
          allowedFiles.add(selected);
        }
      }

      if (allowedFiles.isEmpty) return;

      setState(() => _attachedFiles.addAll(allowedFiles));
      _scrollToBottom();
      _showSnackBar('${allowedFiles.length} file(s) attached');
    } catch (e) {
      _showSnackBar('Error selecting PDF: $e', isError: true);
    }
  }

  void _removeAttachment(File file) => setState(() => _attachedFiles.remove(file));

  // ----------------------------------
  // UI helpers
  // ----------------------------------
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();

    final bgColor = isError
        ? Colors.redAccent.shade700
        : (Theme.of(context).brightness == Brightness.dark
            ? Colors.tealAccent.shade400
            : Colors.teal.shade600);

    final snackBar = SnackBar(
      content: Text(
        message,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      ),
      backgroundColor: bgColor,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(top: kToolbarHeight + 10, left: 12, right: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      duration: const Duration(seconds: 3),
    );

    scaffoldMessenger.showSnackBar(snackBar);
  }

  // ----------------------------------
  // Build
  // ----------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      onDrawerChanged: (isOpen) => setState(() => _isDrawerOpen = isOpen),
      drawer: _buildDrawer(context),
      appBar: AppBar(title: const Text('CuraSeanse AI')),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        transform: Matrix4.translationValues(_isDrawerOpen ? 240 : 0, 0, 0),
        child: Column(children: [
          Expanded(child: _buildChatArea(context)),
          if (_isLoading) _buildLoadingIndicator(),
          InputField(
            controller: _controller,
            onSend: _sendMessage,
            onAttach: _pickAndAnalyzePdf,
            enabled: !_isLoading,
            attachedFiles: _attachedFiles,
            onRemoveAttachment: () => setState(() => _attachedFiles.clear()),
            isListening: false,
            onMicPressed: () {},
          ),
        ]),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF101010)
          : Colors.white,
      child: ListView(padding: EdgeInsets.zero, children: [
        DrawerHeader(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color.fromARGB(255, 10, 101, 117), Color.fromARGB(255, 0, 150, 136)],
            ),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.medical_services, size: 48, color: Colors.white),
            const SizedBox(height: 8),
            const Text('CuraSeanse AI', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const Text('A Medical Assistant', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),

        ListTile(
          leading: const Icon(Icons.add_comment, color: Colors.tealAccent),
          title: const Text('New Chat'),
          onTap: _newChat,
        ),

        ExpansionTile(
          leading: const Icon(Icons.chat_bubble_outline, color: Colors.tealAccent),
          title: const Text('Chats'),
          collapsedIconColor: Colors.tealAccent,
          iconColor: Colors.tealAccent,
          children: _chats.isEmpty
              ? [const Padding(padding: EdgeInsets.all(16.0), child: Text('No chats yet.', style: TextStyle(color: Colors.grey)))]
              : _chats.entries.toList().reversed.map((entry) {
                  final chatId = entry.key;
                  final messages = entry.value;
                  final title = messages.isEmpty
                      ? 'New Chat'
                      : (messages.first.text.length > 40 ? '${messages.first.text.substring(0, 40)}...' : messages.first.text);

                  return ListTile(
                    leading: const Icon(Icons.chat, color: Colors.tealAccent),
                    title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => _switchToChat(chatId),
                    onLongPress: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Chat'),
                          content: const Text('Are you sure you want to delete this chat?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        setState(() {
                          _chats.remove(chatId);
                          if (_currentChatId == chatId) {
                            _currentChatId = null;
                            _messages.clear();
                          }
                        });
                        await _saveChats();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat deleted successfully.'), duration: Duration(seconds: 2)));
                        }
                      }
                    },
                  );
                }).toList(),
        ),

        ListTile(
          leading: const Icon(Icons.settings, color: Colors.tealAccent),
          title: const Text('Settings'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.tealAccent),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
          },
        ),

        const Divider(),

        ListTile(
          leading: const Icon(Icons.help_outline, color: Colors.tealAccent),
          title: const Text('Help & Support'),
          onTap: () => showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Help & Support'),
              content: const Text(
                'To use this app:\n\n' '• Type your medical questions in the chat\n' '• Upload PDF medical reports using the upload button\n' '• Get AI-powered insights and analysis\n\n' 'Note: This is not a substitute for professional medical advice.'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))],
            ),
          ),
        ),

        ListTile(
          leading: const Icon(Icons.info_outline, color: Colors.tealAccent),
          title: const Text('About'),
          onTap: () => showAboutDialog(
            context: context,
            applicationName: 'CuraSeanse AI',
            applicationVersion: '1.0.0',
            applicationLegalese: '© 2025 Kanak Nagar',
            children: const [SizedBox(height: 16), Text('An AI-powered medical assistant to help analyze reports and answer health-related questions.')],
          ),
        ),
      ]),
    );
  }

  Widget _buildChatArea(BuildContext context) {
    if (_messages.isEmpty && !_isLoading) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.medical_services_outlined, size: 80, color: Colors.teal.shade300),
          const SizedBox(height: 16),
          Text('CuraSeanse AI', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text('Ask health questions or upload medical reports for analysis', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)),
          ),
        ]),
      );
    }

    return Column(children: [
      if (_attachedFiles.isNotEmpty) _buildAttachmentChips(),
      Expanded(
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _messages.length,
          itemBuilder: (context, index) => ChatBubble(message: _messages[index]),
        ),
      ),
    ]);
  }

  Widget _buildAttachmentChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, border: Border(top: BorderSide(color: Colors.grey.shade300))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: _attachedFiles.map((file) {
          final fileName = file.path.split(Platform.pathSeparator).last;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              avatar: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
              label: Text(fileName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
              deleteIcon: const Icon(Icons.close),
              onDeleted: () => _removeAttachment(file),
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade400)),
            ),
          );
        }).toList()),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 12),
        Text('Thinking...', style: TextStyle(color: Colors.grey)),
      ]),
    );
  }
}
