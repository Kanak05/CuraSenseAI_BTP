import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class LlamaService {
  final String baseUrl = "http://127.0.0.1:8000"; // use your backend IP

  Future<String> generateResponse(String prompt, {File? pdfFile}) async {
    var url = Uri.parse("$baseUrl/generate");

    var request = http.MultipartRequest("POST", url);
    request.fields["prompt"] = prompt;

    if (pdfFile != null) {
      print("📄 Attaching file: ${pdfFile.path}");
      request.files.add(await http.MultipartFile.fromPath("file", pdfFile.path));
    } else {
      print("⚠️ No file selected, sending prompt only");
    }

    var response = await request.send();
    var responseData = await http.Response.fromStream(response);

    print("🔁 Response status: ${response.statusCode}");
    if (response.statusCode == 200) {
      final decoded = jsonDecode(responseData.body);
      return decoded["text"] ?? "No text field in response";
    } else {
      throw Exception("Failed: ${response.statusCode}, ${responseData.body}");
    }
  }
}
