// import 'package:flutter/material.dart';

// class InputField extends StatelessWidget {
//   final TextEditingController controller;
//   final void Function(String) onSend;
//   final VoidCallback onAttach;
//   final bool enabled;
  
//   const InputField({
//     super.key,
//     required this.controller,
//     required this.onSend,
//     required this.onAttach,
//     this.enabled = true,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final isDark = theme.brightness == Brightness.dark;

//     return SafeArea(
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//         color: isDark ? const Color(0xFF121212) : Colors.grey.shade100,
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             // 📎 Attach PDF button
//             IconButton(
//               icon: const Icon(Icons.attach_file),
//               color: enabled
//                   ? Colors.tealAccent.shade700
//                   : Colors.grey.shade600,
//               onPressed: enabled ? onAttach : null,
//               tooltip: 'Upload PDF',
//             ),

//             // 🧠 Text input box
//             Expanded(
//               child: AnimatedContainer(
//                 duration: const Duration(milliseconds: 200),
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: isDark
//                       ? Colors.grey.shade900
//                       : Colors.white,
//                   borderRadius: BorderRadius.circular(24),
//                   boxShadow: [
//                     if (!isDark)
//                       BoxShadow(
//                         color: Colors.grey.shade300,
//                         blurRadius: 4,
//                         offset: const Offset(0, 1),
//                       ),
//                   ],
//                   border: Border.all(
//                     color: enabled
//                         ? Colors.teal.shade300
//                         : Colors.grey.shade700,
//                     width: 1.2,
//                   ),
//                 ),
//                 child: TextField(
//                   controller: controller,
//                   enabled: enabled,
//                   textInputAction: TextInputAction.send,
//                   decoration: const InputDecoration(
//                     border: InputBorder.none,
//                     hintText: "Type your message...",
//                     hintStyle: TextStyle(color: Colors.grey),
//                   ),
//                   style: TextStyle(
//                     color: isDark ? Colors.white : Colors.black87,
//                   ),
//                   onSubmitted: (value) {
//                     if (enabled && value.trim().isNotEmpty) {
//                       onSend(value.trim());
//                     }
//                   },
//                 ),
//               ),
//             ),

//             const SizedBox(width: 8),

//             // 🚀 Send button
//             AnimatedOpacity(
//               duration: const Duration(milliseconds: 300),
//               opacity: enabled ? 1 : 0.5,
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: enabled
//                       ? Colors.tealAccent.shade700
//                       : Colors.grey.shade700,
//                   shape: BoxShape.circle,
//                   boxShadow: [
//                     if (enabled)
//                       BoxShadow(
//                         color: Colors.tealAccent.withValues(alpha: 0.3),
//                         blurRadius: 6,
//                         offset: const Offset(0, 3),
//                       ),
//                   ],
//                 ),
//                 child: IconButton(
//                   icon: const Icon(Icons.send, color: Colors.white),
//                   onPressed: enabled
//                       ? () {
//                           final text = controller.text.trim();
//                           if (text.isNotEmpty) onSend(text);
//                         }
//                       : null,
//                   tooltip: 'Send',
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'dart:io';
import 'package:flutter/material.dart';

class InputField extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSend;
  final VoidCallback onAttach;
  final bool enabled;
  final List<File>? attachedFiles;
  final VoidCallback? onRemoveAttachment;

  const InputField({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.enabled,
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

          // 🧠 Input Area (chips above, text below)
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
                  // 🗂 Attached Files (if any)
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
                              avatar: const Icon(
                                Icons.picture_as_pdf,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              label: Text(
                                fileName,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                              backgroundColor: isDark
                                  ? Colors.grey[850]
                                  : Colors.grey[200],
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: onRemoveAttachment,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // ✏️ Expanding Text Field
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: TextField(
                      controller: controller,
                      enabled: enabled,
                      minLines: 1,
                      maxLines: 5, // expands up to 5 lines
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: "Type your message...",
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onSubmitted: onSend,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🚀 Send Button
          IconButton(
            icon: const Icon(Icons.send_rounded),
            color: Colors.tealAccent,
            onPressed: enabled
                ? () {
                    if (controller.text.trim().isNotEmpty) {
                      onSend(controller.text.trim());
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
