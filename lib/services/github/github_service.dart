import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// GitHub repository data returned from the API
class GitHubRepo {
  final int id;
  final String name;
  final String fullName;
  final String? description;
  final String htmlUrl;
  final String? language;
  final List<String> topics;
  final int stars;
  final bool isPrivate;
  final DateTime? pushedAt;

  const GitHubRepo({
    required this.id,
    required this.name,
    required this.fullName,
    this.description,
    required this.htmlUrl,
    this.language,
    this.topics = const [],
    this.stars = 0,
    this.isPrivate = false,
    this.pushedAt,
  });

  factory GitHubRepo.fromJson(Map<String, dynamic> json) => GitHubRepo(
        id: json['id'] as int,
        name: json['name'] as String,
        fullName: json['full_name'] as String,
        description: json['description'] as String?,
        htmlUrl: json['html_url'] as String,
        language: json['language'] as String?,
        topics: (json['topics'] as List<dynamic>?)?.cast<String>() ?? [],
        stars: json['stargazers_count'] as int? ?? 0,
        isPrivate: json['private'] as bool? ?? false,
        pushedAt: json['pushed_at'] != null
            ? DateTime.tryParse(json['pushed_at'] as String)
            : null,
      );

  /// Convert into a ProjectModel-compatible map for pre-filling the add project form
  Map<String, dynamic> toProjectPrefill() => {
        'title': name,
        'description': description ?? '',
        'githubRepo': htmlUrl,
        'technologies': language != null ? [language!] : <String>[],
        'tags': topics.take(5).toList(),
      };
}

// ── GitHub Service ─────────────────────────────────────────

class GitHubService {
  static const _baseUrl = 'https://api.github.com';

  /// Fetch public (and optionally private) repos for the authenticated user.
  /// [token] is the GitHub OAuth access token from Firebase's GithubAuthProvider.
  Future<List<GitHubRepo>> fetchUserRepos(String token,
      {int perPage = 50}) async {
    final repos = <GitHubRepo>[];
    int page = 1;

    while (true) {
      final uri = Uri.parse(
          '$_baseUrl/user/repos?per_page=$perPage&page=$page&sort=pushed&type=owner');
      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      });

      if (resp.statusCode != 200) {
        throw Exception('GitHub API error ${resp.statusCode}: ${resp.body}');
      }

      final data = jsonDecode(resp.body) as List<dynamic>;
      if (data.isEmpty) break;

      repos.addAll(data
          .map((e) => GitHubRepo.fromJson(e as Map<String, dynamic>))
          .where((r) => !r.isPrivate || true)); // include all repos

      if (data.length < perPage) break;
      page++;
      if (page > 5) break; // Cap at 250 repos
    }

    return repos;
  }

  /// Fetch repository languages breakdown.
  Future<List<String>> fetchRepoLanguages(
      String token, String owner, String repo) async {
    final uri = Uri.parse('$_baseUrl/repos/$owner/$repo/languages');
    final resp = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/vnd.github+json',
    });

    if (resp.statusCode != 200) return [];
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data.keys.toList();
  }

  /// Fetch public repositories for a specific GitHub username without requiring an OAuth token.
  Future<List<GitHubRepo>> fetchPublicReposByUsername(String username,
      {int perPage = 50}) async {
    final repos = <GitHubRepo>[];
    int page = 1;

    while (true) {
      final uri = Uri.parse(
          '$_baseUrl/users/$username/repos?per_page=$perPage&page=$page&sort=updated');
      final resp = await http.get(uri, headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'ai-career-os', // User agent recommended by GitHub API
      });

      if (resp.statusCode != 200) {
        throw Exception('GitHub API error ${resp.statusCode}: ${resp.body}');
      }

      final data = jsonDecode(resp.body) as List<dynamic>;
      if (data.isEmpty) break;

      repos.addAll(data
          .map((e) => GitHubRepo.fromJson(e as Map<String, dynamic>))
          .where((r) => !r.isPrivate)); // public repos only

      if (data.length < perPage) break;
      page++;
      if (page > 5) break; // Cap at 250 repos
    }

    return repos;
  }
}

// ── Provider ───────────────────────────────────────────────

final gitHubServiceProvider = Provider<GitHubService>((_) => GitHubService());

/// Stores the GitHub OAuth token captured after sign-in
final gitHubTokenProvider = StateProvider<String?>((ref) => null);

/// Fetches repos; only runs when a token is available
final gitHubReposProvider =
    FutureProvider<List<GitHubRepo>>((ref) async {
  final token = ref.watch(gitHubTokenProvider);
  if (token == null) return [];

  final service = ref.read(gitHubServiceProvider);
  return service.fetchUserRepos(token);
});
