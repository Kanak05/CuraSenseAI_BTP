import 'dart:convert';
import 'dart:collection';
import 'dart:io' show File, Platform;
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
  final List<Message> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final LlamaService llamaService = LlamaService();
  final LinkedHashMap<String, List<Message>> _chats = LinkedHashMap();
  final List<File> _attachedFiles = []; // store selected PDFs
  bool _isLoading = false;
  bool _isDrawerOpen = false;
  // ignore: unused_field
  String? _errorMessage;
  String? _currentChatId; // to track which chat is open

  // File? selectedPdf; // store selected PDF
  String userQuestion = "";

  

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

  // void _moveChatToTop(String chatId) {
  //   if (!_chats.containsKey(chatId)) return;
  //   final chatMessages = _chats.remove(chatId);
  //   _chats.remove(chatId);
  //   _chats.addEntries([MapEntry(chatId, chatMessages!)]); // Reinsert at end → top when reversed
  // }

  Future<void> _updateCurrentChat() async {
    if (_currentChatId == null) return;
    _chats[_currentChatId!] = List.from(_messages);
    await _saveChats();
  }

  // ✅ Load saved chats from SharedPreferences
  Future<void> _loadChats() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('chats');

    if (data != null) {
      final decoded = jsonDecode(data) as Map<String, dynamic>;

      setState(() {
        _chats
          ..clear()
          ..addEntries(
            decoded.entries.map(
              (entry) {
                final messages = (entry.value as List)
                    .map((m) => Message.fromJson(Map<String, dynamic>.from(m)))
                    .toList();
                return MapEntry(entry.key, messages);
              },
            ),
          );
      });
    }
  }



  // ✅ Save chats to SharedPreferences
  Future<void> _saveChats() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_chats.map((key, value) {
      return MapEntry(key, value.map((m) => m.toJson()).toList());
    }));
    await prefs.setString('chats', encoded);
  }

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

  void _sendMessage(String text) async {
    if (text.trim().isEmpty && _attachedFiles.isEmpty) return;

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

    // ✅ DO NOT CLEAR FILES HERE — needed for upload
    _controller.clear();
    _scrollToBottom();

    try {
      String combinedResponse = "";
      print("🧾 Sending message: '$text'");
      print("📎 Attached files count: ${_attachedFiles.length}");

      // ✅ Send each PDF one by one
      if (_attachedFiles.isNotEmpty) {
        for (var file in _attachedFiles) {
          print("📄 Uploading file: ${file.path}");
          final reply = await llamaService.generateResponse(
            text.trim().isEmpty ? "Analyze this report" : text.trim(),
            pdfFile: file,
          );
          combinedResponse += "\n\n📄 **${file.path.split('/').last}**:\n$reply";
        }
      } else {
        // ✅ Text-only mode
        combinedResponse = await llamaService.generateResponse(text.trim());
      }

      if (mounted) {
        setState(() {
          _messages.add(Message(text: combinedResponse.trim(), isUser: false));
          _isLoading = false;
          _attachedFiles.clear(); // ✅ clear after upload done
        });
        await _updateCurrentChat();
        _scrollToBottom();
      }
    } catch (e) {
      String message = e.toString().contains('Connection refused')
          ? 'Cannot reach the AI server. Please check your backend connection.'
          : 'Failed to get response: $e';
      if (mounted) {
        setState(() {
          _errorMessage = message;
          _isLoading = false;
        });
        _showSnackBar(message, isError: true);
      }
    }
  }


  Future<void> _pickAndAnalyzePdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        print("⚠️ No file selected");
        return;
      }

      final allowedFiles = <File>[];

      for (final file in result.files) {
        if (file.path == null) continue;
        final selected = File(file.path!);
        final sizeInMB = selected.lengthSync() / (1024 * 1024);

        if (sizeInMB > 5) {
          _showSnackBar("${file.name} is too large (max 5MB).", isError: true);
        } else {
          allowedFiles.add(selected);
          print("✅ Added file: ${file.path}");
        }
      }

      if (allowedFiles.isEmpty) return;

      setState(() {
        _attachedFiles.addAll(allowedFiles);
      });

      _scrollToBottom();
      _showSnackBar("${allowedFiles.length} file(s) attached");

    } catch (e) {
      _showSnackBar("Error selecting PDF: $e", isError: true);
    }
  }


  void _showSnackBar(String message, {bool isError = false}) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Hide any currently visible snackbar before showing a new one
    scaffoldMessenger.hideCurrentSnackBar();

    final bgColor = isError
        ? Colors.redAccent.shade700
        : (Theme.of(context).brightness == Brightness.dark
            ? Colors.tealAccent.shade400
            : Colors.teal.shade600);

    final snackBar = SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: bgColor,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(
        top: kToolbarHeight + 10, // ✅ Position below AppBar
        left: 12,
        right: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      dismissDirection: DismissDirection.up,
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: 'OK',
        textColor: Colors.white,
        onPressed: () {},
      ),
    );

    // Show the snackbar using ScaffoldMessenger
    scaffoldMessenger.showSnackBar(snackBar);
  }



  // ✅ Save current chat before clearing it
  void _newChat() async {
  // ✅ Save only if there are messages and the chat was never stored yet
    if (_messages.isNotEmpty && _currentChatId != null) {
      // Prevent duplicate chat entries — update only existing one
      _chats[_currentChatId!] = List.from(_messages);
      await _saveChats();
    }

    // ✅ Clear and reset for a new session
    setState(() {
      _messages.clear();
      _errorMessage = null;
      _currentChatId = null; // start fresh
    });
    if (!mounted) return;
    // Close drawer if open
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      onDrawerChanged: (isOpen) {
        setState(() => _isDrawerOpen = isOpen);
      },
      drawer: Drawer(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF101010)
            : Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // HEADER
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.fromARGB(255, 10, 101, 117),
                    Color.fromARGB(255, 0, 150, 136),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.medical_services, size: 48, color: Colors.white),
                  const SizedBox(height: 8),
                  const Text(
                    'CuraSeanse AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'A Medical Assistant',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            // ✅ NEW CHAT = save old + clear messages
            ListTile(
              leading: const Icon(Icons.add_comment, color: Colors.tealAccent),
              title: const Text('New Chat'),
              onTap: () {
                Navigator.pop(context);
                _newChat();
              },
            ),

            // ✅ CHATS EXPANDER
            ExpansionTile(
              leading: const Icon(Icons.chat_bubble_outline, color: Colors.tealAccent),
              title: const Text('Chats'),
              collapsedIconColor: Colors.tealAccent,
              iconColor: Colors.tealAccent,
              children: _chats.isEmpty
                  ? [
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No chats yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ]
                  : _chats.entries.toList().reversed.map((entry) {
                      final chatId = entry.key;
                      final messages = entry.value;
                      final title = messages.isEmpty
                          ? 'New Chat'
                          : messages.first.text.length > 40
                              ? '${messages.first.text.substring(0, 40)}...'
                              : messages.first.text;

                      // 👇 Local state variable for hover tracking
                      bool isHovered = false;

                      return StatefulBuilder(
                        builder: (context, setHover) {
                          return MouseRegion(
                            onEnter: (_) => setHover(() => isHovered = true),
                            onExit: (_) => setHover(() => isHovered = false),
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                setState(() {
                                  _currentChatId = chatId;
                                  _messages
                                    ..clear()
                                    ..addAll(messages);
                                });
                              },
                              onLongPress: () async {
                                // 📱 Mobile fallback: show delete confirmation
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Chat'),
                                    content: const Text(
                                        'Are you sure you want to delete this chat?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.redAccent),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  setState(() => _chats.remove(chatId));
                                  await _saveChats();
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                color: isHovered
                                    ? Colors.teal.withValues(alpha: 0.1)
                                    : Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                child: Row(
                                  children: [
                                    const Icon(Icons.chat, color: Colors.tealAccent),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // 🗑 Delete icon fades in on hover
                                    AnimatedOpacity(
                                      opacity: isHovered ? 1.0 : 0.0,
                                      duration: const Duration(milliseconds: 200),
                                      child: IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.redAccent, size: 20),
                                        tooltip: 'Delete chat',
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Delete Chat'),
                                              content: const Text(
                                                'Are you sure you want to delete this chat?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context, true),
                                                  child: const Text(
                                                    'Delete',
                                                    style:
                                                        TextStyle(color: Colors.redAccent),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirm == true) {
                                            setState(() {
                                              _chats.remove(chatId);

                                              // ✅ If deleted chat is currently active, reset chat session
                                              if (_currentChatId == chatId) {
                                                _currentChatId = null;
                                                _messages.clear();
                                                _errorMessage = null;
                                              }
                                            });

                                            await _saveChats();

                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content:
                                                      Text('Chat deleted successfully.'),
                                                  duration: Duration(seconds: 2),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
            ),

            // SETTINGS
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.tealAccent),
              title: const Text('Settings'),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.tealAccent),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
      const Divider(),
            // HELP
            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.tealAccent),
              title: const Text('Help & Support'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Help & Support'),
                    content: const Text(
                      'To use this app:\n\n'
                      '• Type your medical questions in the chat\n'
                      '• Upload PDF medical reports using the upload button\n'
                      '• Get AI-powered insights and analysis\n\n'
                      'Note: This is not a substitute for professional medical advice.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
                );
              },
            ),

            // ABOUT
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.tealAccent),
              title: const Text('About'),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'CuraSeanse AI',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '© 2025 Kanak Nagar',
                  
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'An AI-powered medical assistant to help analyze reports '
                      'and answer health-related questions.',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),

      appBar: AppBar(
        title: const Text("CuraSeanse AI"),
      ),

      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        transform: Matrix4.translationValues(_isDrawerOpen ? 240 : 0, 0, 0),
        child: Column(
          children: [
            if (_messages.isEmpty && !_isLoading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.medical_services_outlined,
                          size: 80, color: Colors.teal.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'CuraSeanse AI',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Ask health questions or upload medical reports for analysis',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return ChatBubble(message: message);
                  },
                ),
              ),

            if (_isLoading)
              Container(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Thinking...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
          // if (_attachedFiles.isNotEmpty)
          //   Container(
          //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          //     decoration: BoxDecoration(
          //       color: Theme.of(context).brightness == Brightness.dark
          //           ? Colors.grey[900]
          //           : Colors.grey[100],
          //       border: Border(top: BorderSide(color: Colors.grey.shade300)),
          //     ),
          //     child: SingleChildScrollView(
          //       scrollDirection: Axis.horizontal,
          //       child: Row(
          //         children: _attachedFiles.map((file) {
          //           final fileName = file.path.split(Platform.pathSeparator).last;
          //           return Padding(
          //             padding: const EdgeInsets.only(right: 8),
          //             child: Chip(
          //               avatar: const Icon(
          //                 Icons.picture_as_pdf,
          //                 color: Colors.redAccent,
          //               ),
          //               label: Text(
          //                 fileName,
          //                 overflow: TextOverflow.ellipsis,
          //                 style: const TextStyle(fontWeight: FontWeight.w500),
          //               ),
          //               deleteIcon: const Icon(Icons.close),
          //               onDeleted: () {
          //                 setState(() => _attachedFiles.remove(file));
          //               },
          //               backgroundColor: Theme.of(context).cardColor,
          //               shape: RoundedRectangleBorder(
          //                 borderRadius: BorderRadius.circular(10),
          //                 side: BorderSide(color: Colors.grey.shade400),
          //               ),
          //             ),
          //           );
          //         }).toList(),
          //       ),
          //     ),
          //   ),


            InputField(
              controller: _controller,
              onSend: _sendMessage,
              onAttach: _pickAndAnalyzePdf,
              enabled: !_isLoading,
              attachedFiles: _attachedFiles,
              onRemoveAttachment: () {
                setState(() => _attachedFiles.clear());
              },
            ),
          ],
        ),
      ),
    );
  }
}
