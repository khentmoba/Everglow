import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:html_unescape/html_unescape.dart';
import '../models/academy_question.dart';

class TriviaApiService {
  static const String _baseUrl = 'https://opentdb.com/api.php';
  static const String _tokenUrl = 'https://opentdb.com/api_token.php';
  static const String _tokenKey = 'opentdb_session_token';
  static const String _tokenTimestampKey = 'opentdb_token_timestamp';

  final _unescape = HtmlUnescape();
  String? _sessionToken;

  Future<void> initSession() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionToken = prefs.getString(_tokenKey);
    final timestamp = prefs.getInt(_tokenTimestampKey);

    // Tokens expire after 6 hours of inactivity
    if (_sessionToken == null ||
        timestamp == null ||
        DateTime.now().millisecondsSinceEpoch - timestamp >
            6 * 60 * 60 * 1000) {
      await _requestNewToken();
    }
  }

  Future<void> _requestNewToken() async {
    final response = await http.get(Uri.parse('$_tokenUrl?command=request'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['response_code'] == 0) {
        _sessionToken = data['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, _sessionToken!);
        await prefs.setInt(
          _tokenTimestampKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      }
    }
  }

  Future<void> resetSession() async {
    if (_sessionToken == null) return;

    final response = await http.get(
      Uri.parse('$_tokenUrl?command=reset&token=$_sessionToken'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['response_code'] == 0) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          _tokenTimestampKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      }
    }
  }

  Future<List<AcademyQuestion>> fetchQuestions({
    required int categoryId,
    int amount = 50,
    int retryCount = 0,
  }) async {
    if (_sessionToken == null) await initSession();

    final url =
        '$_baseUrl?amount=$amount&category=$categoryId&type=multiple&token=$_sessionToken';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final responseCode = data['response_code'] as int;

      switch (responseCode) {
        case 0: // Success
          final results = data['results'] as List;
          return results
              .map((json) => _mapJsonToQuestion(json, categoryId))
              .toList();

        case 3: // Token Not Found
          await _requestNewToken();
          return fetchQuestions(categoryId: categoryId, amount: amount);

        case 4: // Token Empty
          await resetSession();
          return fetchQuestions(categoryId: categoryId, amount: amount);

        case 5: // Rate Limit
          if (retryCount < 3) {
            final delay = Duration(seconds: (5 * (retryCount + 1)));
            await Future.delayed(delay);
            return fetchQuestions(
              categoryId: categoryId,
              amount: amount,
              retryCount: retryCount + 1,
            );
          }
          throw Exception('OpenTDB Rate Limit exceeded after retries.');

        default:
          throw Exception('OpenTDB API Error: Code $responseCode');
      }
    } else {
      throw Exception('Failed to load trivia: ${response.statusCode}');
    }
  }

  AcademyQuestion _mapJsonToQuestion(
    Map<String, dynamic> json,
    int categoryId,
  ) {
    final questionText = _unescape.convert(json['question']);
    final correctAnswer = _unescape.convert(json['correct_answer']);
    final incorrectAnswers = (json['incorrect_answers'] as List)
        .map((ans) => _unescape.convert(ans as String))
        .toList();

    final options = [...incorrectAnswers, correctAnswer]..shuffle();
    final correctIndex = options.indexOf(correctAnswer);

    return AcademyQuestion(
      id: AcademyQuestion.generateId(questionText),
      questionText: questionText,
      options: options,
      correctOptionIndex: correctIndex,
      category: _mapCategoryId(categoryId),
    );
  }

  String _mapCategoryId(int categoryId) {
    switch (categoryId) {
      case 18:
      case 19:
        return 'engineering';
      case 22:
      case 23:
        return 'tourism';
      case 12:
        return 'music';
      case 9:
        return 'general';
      case 32:
        return 'cartoons';
      case 26:
        return 'celebrities';
      case 11:
        return 'film';
      case 10:
        return 'books';
      default:
        return 'general';
    }
  }

  static List<int> getApiCategoryIds(String category) {
    switch (category) {
      case 'engineering':
        return [18, 19];
      case 'tourism':
        return [22, 23];
      case 'music':
        return [12];
      case 'general':
        return [9];
      case 'cartoons':
        return [32];
      case 'celebrities':
        return [26];
      case 'film':
        return [11];
      case 'books':
        return [10];
      default:
        return [9];
    }
  }
}
