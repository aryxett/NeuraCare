import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Production URL on Render
  static const String baseUrl = 'https://cognify-ai-jgmj.onrender.com/api';

  // ── Network Hardening Helpers ──
  static Future<http.Response> _safeRequest(Future<http.Response> Function() requestFunc) async {
    try {
      return await requestFunc().timeout(const Duration(seconds: 60)); // Increased to handle Render free tier wake up
    } on TimeoutException {
      throw Exception('Request timed out while waiting for server to wake up.');
    } on SocketException {
      throw Exception('Unable to connect to the server. Offline mode currently unavailable.');
    } catch (e) {
      throw Exception('Unable to fetch data right now. Please try again later.');
    }
  }

  static Exception _handleError(http.Response response, String defaultMessage, {String? url}) {
    String message = defaultMessage;
    if (url != null) message += " (URL: $url)";
    
    try {
      final data = jsonDecode(response.body);
      if (data is Map) {
        if (data.containsKey('error')) return Exception(data['error'] + (url != null ? " [$url]" : ""));
        if (data.containsKey('detail')) return Exception(data['detail'] + (url != null ? " [$url]" : ""));
      }
    } catch (_) {}
    return Exception(message);
  }

  // ── Token Management ──
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('cognify_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cognify_token', token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cognify_token');
    await prefs.remove('cognify_user');
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Auth ──
  static Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final response = await _safeRequest(() => http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    ));
    if (response.statusCode == 201) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data'];
    }
    throw _handleError(response, 'Registration failed');
  }

  static Future<String> login(String email, String password) async {
    final response = await _safeRequest(() => http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'username=${Uri.encodeComponent(email)}&password=${Uri.encodeComponent(password)}',
    ));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        final data = json['data'];
        final token = data['access_token'];
        await saveToken(token);
        return token;
      }
    }
    throw _handleError(response, 'Login failed');
  }

  static Future<Map<String, dynamic>> getMe() async {
    final response = await _safeRequest(() async => http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: await _authHeaders(),
    ));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data'];
    }
    throw _handleError(response, 'Failed to get user');
  }

  // ══════════════════════════════════════════════════
  // ── NEW PHASE 5: Mobile Integration Target APIs ──
  // ══════════════════════════════════════════════════

  static Future<Map<String, dynamic>> submitPhase2DailyLog({
    required int userId,
    required double sleepHours,
    required double screenTime,
    required int mood,
    required bool exercise,
  }) async {
    final response = await _safeRequest(() async => http.post(
      Uri.parse('$baseUrl/submit-daily-log'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'user_id': userId,
        'sleep_hours': sleepHours,
        'screen_time': screenTime,
        'mood': mood,
        'exercise': exercise,
      }),
    ));
    if (response.statusCode == 201) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data'];
    }
    throw _handleError(response, 'Failed to submit daily log');
  }

  static Future<Map<String, dynamic>> getMoodCheckInStatus() async {
    const url = '$baseUrl/mood-checkin/status';
    final response = await _safeRequest(() async => http.get(
      Uri.parse(url),
      headers: await _authHeaders(),
    ));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data'];
    }
    throw _handleError(response, 'Failed to get mood check-in status', url: url);
  }

  static Future<Map<String, dynamic>> submitMoodCheckIn(String mood) async {
    const url = '$baseUrl/mood-checkin';
    final response = await _safeRequest(() async => http.post(
      Uri.parse(url),
      headers: await _authHeaders(),
      body: jsonEncode({'mood': mood}),
    ));
    if (response.statusCode == 201) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data'];
    }
    throw _handleError(response, 'Failed to submit mood check-in', url: url);
  }

  static Future<Map<String, dynamic>> getAnalyticsDashboardSummary() async {
    const url = '$baseUrl/analytics/dashboard-summary';
    final response = await _safeRequest(() async => http.get(
      Uri.parse(url),
      headers: await _authHeaders(),
    ));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data'];
    }
    throw _handleError(response, 'Failed to get dashboard summary', url: url);
  }

  static Future<Map<String, dynamic>> getAnalyticsWeeklyTrends() async {
    const url = '$baseUrl/analytics/weekly-trends';
    final response = await _safeRequest(() async => http.get(
      Uri.parse(url),
      headers: await _authHeaders(),
    ));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data'];
    }
    throw _handleError(response, 'Failed to get weekly trends', url: url);
  }

  // ══════════════════════════════════════════════════
  // ── NEW PHASE 7: Fitbit API Integration ──
  // ══════════════════════════════════════════════════

  static Future<String> getFitbitAuthUrl() async {
    final response = await _safeRequest(() async => http.get(
      Uri.parse('$baseUrl/fitbit/login'),
      headers: await _authHeaders(),
    ));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data']['auth_url'];
    }
    throw _handleError(response, 'Failed to fetch Fitbit Auth URL');
  }

  static Future<Map<String, dynamic>> getFitbitDailyData() async {
    final response = await _safeRequest(() async => http.get(
      Uri.parse('$baseUrl/fitbit/daily-data'),
      headers: await _authHeaders(),
    ));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data'];
    }
    throw _handleError(response, 'Failed to fetch Fitbit Daily Data');
  }

  static Future<Map<String, dynamic>> exchangeFitbitCode(String code) async {
    final response = await _safeRequest(() async => http.post(
      Uri.parse('$baseUrl/fitbit/exchange-code?code=${Uri.encodeComponent(code)}'),
      headers: await _authHeaders(),
    ));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data'];
    }
    throw _handleError(response, 'Fitbit exchange failed');
  }

  // ══════════════════════════════════════════════════
  // ── Old Dashboard Endpoints (preserved for backward compatibility) ──
  // ══════════════════════════════════════════════════

  static Future<Map<String, dynamic>> submitDailyData({
    required double sleepHours,
    required double screenTime,
    required int mood,
    required bool exercise,
  }) async {
    final response = await _safeRequest(() async => http.post(
      Uri.parse('$baseUrl/submit-daily-data'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'sleep_hours': sleepHours,
        'screen_time': screenTime,
        'mood': mood,
        'exercise': exercise,
      }),
    ));
    if (response.statusCode == 201) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data'];
    }
    throw _handleError(response, 'Failed to submit daily data');
  }

  static Future<Map<String, dynamic>> getDashboardSummary() async {
    final response = await _safeRequest(() async => http.get(
      Uri.parse('$baseUrl/dashboard-summary'),
      headers: await _authHeaders(),
    ));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data'];
    }
    throw _handleError(response, 'Failed to get dashboard summary');
  }

  static Future<Map<String, dynamic>> getWeeklyTrends() async {
    final response = await _safeRequest(() async => http.get(
      Uri.parse('$baseUrl/weekly-trends'),
      headers: await _authHeaders(),
    ));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data'];
    }
    throw _handleError(response, 'Failed to get weekly trends');
  }

  static Future<Map<String, dynamic>> createBehaviorLog(Map<String, dynamic> data) async {
    final response = await _safeRequest(() async => http.post(
      Uri.parse('$baseUrl/behavior-logs/'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    ));
    if (response.statusCode == 201) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data'];
    }
    throw _handleError(response, 'Failed to create log');
  }

  static Future<List<dynamic>> getBehaviorLogs({int limit = 30}) async {
    final response = await _safeRequest(() async => http.get(
      Uri.parse('$baseUrl/behavior-logs/?limit=$limit'),
      headers: await _authHeaders(),
    ));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data']['logs'] ?? [];
    }
    throw _handleError(response, 'Failed to get logs');
  }

  static Future<Map<String, dynamic>> createPrediction(Map<String, dynamic> data) async {
    final response = await _safeRequest(() async => http.post(
      Uri.parse('$baseUrl/predictions/predict'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    ));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data'];
    }
    throw _handleError(response, 'Failed to create prediction');
  }

  static Future<List<dynamic>> getPredictions({int limit = 30}) async {
    final response = await _safeRequest(() async => http.get(
      Uri.parse('$baseUrl/predictions/?limit=$limit'),
      headers: await _authHeaders(),
    ));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data']['predictions'] ?? [];
    }
    throw _handleError(response, 'Failed to get predictions');
  }

  static Future<Map<String, dynamic>> getInsights() async {
    final response = await _safeRequest(() async => http.get(
      Uri.parse('$baseUrl/insights/'),
      headers: await _authHeaders(),
    ));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data'];
    }
    throw _handleError(response, 'Failed to get insights');
  }

  static Future<Map<String, dynamic>> clearHistory() async {
    const url = '$baseUrl/analytics/clear-history';
    final response = await _safeRequest(() async => http.delete(
      Uri.parse(url),
      headers: await _authHeaders(),
    ));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json;
    }
    throw _handleError(response, 'Failed to clear history', url: url);
  }

  // ══════════════════════════════════════════════════
  // ── NEW PHASE 8: AI Therapy Assistant Endpoints ──
  // ══════════════════════════════════════════════════

  static Future<Map<String, dynamic>> submitJournalEntry(String content) async {
    final response = await _safeRequest(() async => http.post(
      Uri.parse('$baseUrl/therapy/journal'),
      headers: await _authHeaders(),
      body: jsonEncode({'content': content}),
    ));
    if (response.statusCode == 201) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data'];
    }
    throw _handleError(response, 'Failed to submit journal entry');
  }

  static Future<List<dynamic>> getJournalHistory() async {
    final response = await _safeRequest(() async => http.get(
      Uri.parse('$baseUrl/therapy/journal'),
      headers: await _authHeaders(),
    ));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data'];
    }
    throw _handleError(response, 'Failed to get journal history');
  }

  static Future<Map<String, dynamic>> sendChatMessage(String message) async {
    final response = await _safeRequest(() async => http.post(
      Uri.parse('$baseUrl/therapy/chat'),
      headers: await _authHeaders(),
      body: jsonEncode({'message': message}),
    ));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data'];
    }
    throw _handleError(response, 'Failed to send chat message');
  }

  static Future<List<dynamic>> getChatHistory() async {
    final response = await _safeRequest(() async => http.get(
      Uri.parse('$baseUrl/therapy/chat'),
      headers: await _authHeaders(),
    ));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data'];
    }
    throw _handleError(response, 'Failed to get chat history');
  }

  // ══════════════════════════════════════════════════
  // ── NEW PHASE 3: Chat Conversation Management ──
  // ══════════════════════════════════════════════════

  static Future<List<dynamic>> getConversations() async {
    final response = await _safeRequest(() async => http.get(
      Uri.parse('$baseUrl/chat/conversations'),
      headers: await _authHeaders(),
    ));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data']['conversations'];
    }
    throw _handleError(response, 'Failed to load conversations');
  }

  static Future<Map<String, dynamic>> createConversation({String title = "New Conversation"}) async {
    final response = await _safeRequest(() async => http.post(
      Uri.parse('$baseUrl/chat/conversations'),
      headers: await _authHeaders(),
      body: jsonEncode({'title': title}),
    ));
    if (response.statusCode == 201) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data'];
    }
    throw _handleError(response, 'Failed to create conversation');
  }

  static Future<void> deleteConversation(String conversationId) async {
    final response = await _safeRequest(() async => http.delete(
      Uri.parse('$baseUrl/chat/conversations/$conversationId'),
      headers: await _authHeaders(),
    ));
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to delete conversation');
    }
  }

  static Future<List<dynamic>> getConversationMessages(String conversationId) async {
    final response = await _safeRequest(() async => http.get(
      Uri.parse('$baseUrl/chat/conversations/$conversationId/messages'),
      headers: await _authHeaders(),
    ));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data']['messages'];
    }
    throw _handleError(response, 'Failed to load messages');
  }

  static Future<Map<String, dynamic>> sendConversationMessage(String conversationId, String message) async {
    final response = await _safeRequest(() async => http.post(
      Uri.parse('$baseUrl/chat/conversations/$conversationId/messages'),
      headers: await _authHeaders(),
      body: jsonEncode({'content': message}),
    ));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data'];
    }
    throw _handleError(response, 'Failed to send message');
  }

  // ── Life Pattern Discovery (Phase 2) ──
  static Future<Map<String, dynamic>> getLifePatterns() async {
    final response = await _safeRequest(() async => http.get(
      Uri.parse('$baseUrl/analytics/life-patterns'),
      headers: await _authHeaders(),
    ));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) return json['data'];
    }
    throw _handleError(response, 'Failed to get life patterns');
  }
}
