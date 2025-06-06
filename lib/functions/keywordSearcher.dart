import 'dart:convert';
import 'package:http/http.dart' as http;

Future<(String, String?)?> fetchSummary(String title) async {
  final encodedTitle = Uri.encodeComponent(title);
  final url = 'https://en.wikipedia.org/api/rest_v1/page/summary/$encodedTitle';

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    // print(data);

    return (
      data['extract'].toString(),
      data['thumbnail']?['source'].toString()
    );
  } else {
    // print('Failed to fetch summary: ${response.statusCode}');
    return null;
  }
}
