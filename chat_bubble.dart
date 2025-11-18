import 'dart:io';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/material.dart';
import '../models/message.dart';

class ChatBubble extends StatelessWidget {
  final Message message;
  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Colors.tealAccent.withValues(alpha: 0.8)
              : Colors.grey[800],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft:
                isUser ? const Radius.circular(14) : const Radius.circular(0),
            bottomRight:
                isUser ? const Radius.circular(0) : const Radius.circular(14),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // 🗨️ Message text
            if (message.text.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ Selectable message text
                  Expanded(
                    child: SelectableText(
                      message.text,
                      style: TextStyle(
                        color: isUser ? Colors.black : Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ),

                  // 📋 Copy button only for AI messages
                  if (!isUser)
                    IconButton(
                      icon: const Icon(Icons.copy,
                          size: 18, color: Colors.white70),
                      tooltip: "Copy response",
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: message.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Response copied to clipboard!"),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                ],
              ),

            // 📄 Show attachments under text
            if (message.attachments != null &&
                message.attachments!.isNotEmpty)
              Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: message.attachments!.map((fileInfo) {
                  final fileName = fileInfo["name"]!;
                  final filePath = fileInfo["path"]!;
                  return GestureDetector(
                    onTap: () async {
                      final file = File(filePath);
                      if (await file.exists()) {
                        await OpenFilex.open(filePath);
                      } else {
                        if (! context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("File not found: $fileName"),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isUser
                              ? Colors.black26
                              : Colors.tealAccent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.picture_as_pdf,
                              size: 18, color: Colors.redAccent),
                          const SizedBox(width: 6),
                          Text(
                            fileName,
                            style: TextStyle(
                              color: isUser ? Colors.black : Colors.white,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
