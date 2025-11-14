import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const baseUrl = "http://127.0.0.1:8000"; // change to your PC IP for phone

  static Future<String> askQuestion(String q) async {
    final res = await http.post(Uri.parse("$baseUrl/ask"),
        body: {"question": q});
    if (res.statusCode == 200) {
      return jsonDecode(res.body)['answer'];
    }
    return "Error: ${res.statusCode}";
  }

  static Future<String> analyzeFile(File file) async {
    var req = http.MultipartRequest("POST", Uri.parse("$baseUrl/analyze_report"));
    req.files.add(await http.MultipartFile.fromPath('file', file.path));
    var res = await req.send();
    final body = await res.stream.bytesToString();
    return jsonDecode(body)['summary'];
  }
}
