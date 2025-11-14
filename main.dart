
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'screens/settings_screen.dart';
import 'screens/chat_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MedicalAssistantApp(),
    ),
  );
}

class MedicalAssistantApp extends StatelessWidget {
  const MedicalAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'CuraSeanse AI',

          // ✅ Dark & light mode
          theme: themeProvider.isDarkMode
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Colors.tealAccent,
                    secondary: Colors.teal,
                  ),
                  scaffoldBackgroundColor: const Color(0xFF101010),
                  appBarTheme: const AppBarTheme(
                    backgroundColor: Color(0xFF1E1E1E),
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Colors.teal,
                    secondary: Colors.tealAccent,
                  ),
                  scaffoldBackgroundColor: Colors.grey.shade50,
                  appBarTheme: const AppBarTheme(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                ),

          // ✅ Define named routes
          home: const ChatScreen(),
          routes: {
            '/settings': (context) => const SettingsScreen(),
          },

        );
      },
    );
  }
}
