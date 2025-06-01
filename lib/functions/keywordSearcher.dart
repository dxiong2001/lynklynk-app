import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:huggingface_dart/huggingface_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<(String, String?)?> fetchSummary(String title) async {
  final encodedTitle = Uri.encodeComponent(title);
  final url = 'https://en.wikipedia.org/api/rest_v1/page/summary/$encodedTitle';

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    print(data);
    HfInference hfInference = HfInference('${dotenv.env['HUGGING_FACE']}');
    String result = (await hfInference.summarize(
            inputs: [data['extract'] as String?],
            parameters: {"do_sample": false},
            model: 'facebook/bart-large-cnn'))[0]['summary_text']
        .toString();
    return (result, data['thumbnail']?['source'].toString());
  } else {
    print('Failed to fetch summary: ${response.statusCode}');
    return null;
  }
}
