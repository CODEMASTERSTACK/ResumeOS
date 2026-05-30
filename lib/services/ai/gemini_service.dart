import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_service.dart';

/// Gemini / OpenRouter Cloudflare API Gateway client service
class GeminiService implements AIService {
  static const _gatewayUrl = String.fromEnvironment(
    'AI_GATEWAY_URL',
    defaultValue: 'https://smartresume-backend.kanasingh974.workers.dev/v1/ai/generate',
  );

  GeminiService();

  Future<Map<String, dynamic>> _callGateway(String action, Map<String, dynamic> data) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User is not authenticated');
      }

      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Failed to retrieve authentication token');
      }

      final prefs = await SharedPreferences.getInstance();
      final customGeminiKey = prefs.getString('custom_gemini_api_key') ?? '';
      final customOpenRouterKey = prefs.getString('custom_openrouter_api_key') ?? '';

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      };

      if (customGeminiKey.isNotEmpty) {
        headers['x-custom-gemini-key'] = customGeminiKey;
      }
      if (customOpenRouterKey.isNotEmpty) {
        headers['x-custom-openrouter-key'] = customOpenRouterKey;
      }

      final body = jsonEncode({
        'action': action,
        'data': data,
      });

      final response = await http.post(
        Uri.parse(_gatewayUrl),
        headers: headers,
        body: body,
      );

      if (response.statusCode != 200) {
        final errBody = response.body;
        Map<String, dynamic>? parsedErr;
        try {
          parsedErr = jsonDecode(errBody) as Map<String, dynamic>;
        } catch (_) {}
        final errMsg = parsedErr?['error'] ?? 'Status code ${response.statusCode}';
        throw Exception('API Gateway error: $errMsg');
      }

      final parsed = jsonDecode(response.body) as Map<String, dynamic>;
      return parsed;
    } catch (e) {
      throw Exception('AI Operation Failed: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> analyzeJobDescription(String jobDescription) async {
    return _callGateway('analyzeJobDescription', {
      'jobDescription': jobDescription,
    });
  }

  @override
  Future<ProjectRewriteResult> rewriteProjectBullets({
    required String projectTitle,
    required String projectDescription,
    required List<String> technologies,
    required String targetRole,
    required List<String> keywords,
    List<String> linkedSkills = const [],
  }) async {
    final result = await _callGateway('rewriteProjectBullets', {
      'projectTitle': projectTitle,
      'projectDescription': projectDescription,
      'technologies': technologies,
      'targetRole': targetRole,
      'keywords': keywords,
      'linkedSkills': linkedSkills,
    });
    return ProjectRewriteResult.fromJson(result);
  }

  @override
  Future<String> generateProfessionalSummary({
    required String candidateBackground,
    required String targetRole,
    required List<String> keywords,
    required List<String> topSkills,
  }) async {
    final result = await _callGateway('generateProfessionalSummary', {
      'candidateBackground': candidateBackground,
      'targetRole': targetRole,
      'keywords': keywords,
      'topSkills': topSkills,
    });
    return result['summary'] as String? ?? '';
  }

  Future<String> generateAuthenticSummary({
    required String name,
    required String currentRole,
    required List<String> skills,
    required List<Map<String, dynamic>> experience,
    required List<Map<String, dynamic>> education,
    required List<Map<String, dynamic>> projects,
    required List<Map<String, dynamic>> certifications,
    required List<Map<String, dynamic>> achievements,
    String? currentSummary,
  }) async {
    final result = await _callGateway('generateAuthenticSummary', {
      'name': name,
      'currentRole': currentRole,
      'skills': skills,
      'experience': experience,
      'education': education,
      'projects': projects,
      'certifications': certifications,
      'achievements': achievements,
      'currentSummary': currentSummary ?? '',
    });
    return result['summary'] as String? ?? '';
  }
}

final geminiServiceImplProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});
