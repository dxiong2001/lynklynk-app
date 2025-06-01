import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:huggingface_dart/huggingface_dart.dart';

Future<List<String>> extractKeywords(String text) async {
  HfInference hfInference = HfInference('${dotenv.env['HUGGING_FACE']}');

  String textSample = (await hfInference.summarize(
          inputs: [text],
          parameters: {"do_sample": false},
          model: 'facebook/bart-large-cnn'))[0]['summary_text']
      .toString();
  print(textSample);

  List result = await hfInference.tokenClassification(
    inputs: [text],
    model: "dslim/bert-base-NER",
  );
  List<String> resultS =
      List<String>.from(result[0].map((e) => e['word'].toString()).toList())
          .toSet()
          .toList();
  print(resultS);

  return [];
}
