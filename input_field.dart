import 'dart:io';
import 'package:flutter/material.dart';

class InputField extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSend;
  final VoidCallback onAttach;
  final bool enabled;

  final List<File>? attachedFiles;
  final VoidCallback? onRemoveAttachment;

  // 🎤 NEW: Voice input toggle callbacks
  final bool isListening;
  final VoidCallback onMicPressed;

  const InputField({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.enabled,
    required this.isListening,
    required this.onMicPressed,
    this.attachedFiles,
    this.onRemoveAttachment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasAttachments =
        attachedFiles != null && attachedFiles!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey.shade700, width: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 📎 Attach Button
          IconButton(
            icon: const Icon(Icons.attach_file),
            color: Colors.tealAccent,
            onPressed: enabled ? onAttach : null,
          ),

          // 🧠 Textfield + Attachments
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121212) : Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🗂 Attachment Chips
                  if (hasAttachments)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: attachedFiles!.map((file) {
                          final fileName =
                              file.path.split(Platform.pathSeparator).last;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6, bottom: 4),
                            child: Chip(
                              avatar: const Icon(Icons.picture_as_pdf,
                                  color: Colors.redAccent, size: 18),
                              label: Text(fileName,
                                  style: const TextStyle(fontSize: 13)),
                              backgroundColor:
                                  isDark ? Colors.grey[850] : Colors.grey[200],
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: onRemoveAttachment,
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // ✏️ Expanding TextField
                  TextField(
                    controller: controller,
                    enabled: enabled,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      hintText: "Type your message...",
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                    ),
                    onSubmitted: enabled ? onSend : null,
                  ),
                ],
              ),
            ),
          ),

          // 🎤 Mic Button
          IconButton(
            icon: Icon(
              isListening ? Icons.mic : Icons.mic_none,
              color: isListening ? Colors.redAccent : Colors.tealAccent,
            ),
            tooltip: isListening ? "Stop Listening" : "Start Voice Input",
            onPressed: enabled ? onMicPressed : null,
          ),

          // 🚀 Send Button
          IconButton(
            icon: const Icon(Icons.send_rounded),
            color: Colors.tealAccent,
            onPressed: enabled
                ? () {
                    final text = controller.text.trim();
                    if (text.isNotEmpty) onSend(text);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
