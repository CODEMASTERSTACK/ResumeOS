import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../features/projects/domain/entities/project_model.dart';
import '../../../../features/projects/data/repositories/project_repository.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

// ── In-Memory Cache for Rate-Limit Optimization ───────────────────
final _githubRepoCache = StateProvider<Map<String, dynamic>>((ref) => {});

class GitHubRepoViewScreen extends ConsumerStatefulWidget {
  final String projectId;

  const GitHubRepoViewScreen({super.key, required this.projectId});

  @override
  ConsumerState<GitHubRepoViewScreen> createState() => _GitHubRepoViewScreenState();
}

class _GitHubRepoViewScreenState extends ConsumerState<GitHubRepoViewScreen> {
  ProjectModel? _project;
  bool _isLoadingProject = true;
  String? _errorMessage;

  // Repo coordinates parsed from URL
  String? _owner;
  String? _repo;

  // View state: 'home', 'code', 'file'
  String _currentView = 'home';

  // Navigation states for File Explorer
  List<String> _currentPathSegments = [];
  List<dynamic> _currentFolderContents = [];
  bool _isLoadingContents = false;
  String? _explorerError;

  // Navigation states for File Reader
  String? _currentFileName;
  String _currentFileContent = '';
  bool _isLoadingFile = false;
  String? _fileReaderError;

  // Live repository details from GitHub API
  Map<String, dynamic>? _repoDetails;
  int _contributorCount = 0;
  String _readmeMarkdown = '';
  bool _isLoadingRepoDetails = true;

  @override
  void initState() {
    super.initState();
    _loadProjectAndDetails();
  }

  Future<void> _loadProjectAndDetails() async {
    try {
      final uid = ref.read(currentUserProvider)?.uid;
      if (uid == null) {
        setState(() {
          _errorMessage = 'User not authenticated.';
          _isLoadingProject = false;
        });
        return;
      }

      final project = await ref.read(projectRepositoryProvider).getProject(uid, widget.projectId);
      if (project == null) {
        setState(() {
          _errorMessage = 'Project not found in your database.';
          _isLoadingProject = false;
        });
        return;
      }

      _project = project;
      _parseOwnerAndRepo(project.githubRepo);

      setState(() {
        _isLoadingProject = false;
      });

      if (_owner != null && _repo != null) {
        _fetchLiveGitHubDetails();
      } else {
        setState(() {
          _isLoadingRepoDetails = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading project: $e';
        _isLoadingProject = false;
      });
    }
  }

  void _parseOwnerAndRepo(String url) {
    if (url.isEmpty) return;
    var cleanUrl = url.trim();
    if (cleanUrl.contains('github.com/')) {
      final parts = cleanUrl.split('github.com/');
      if (parts.length > 1) {
        final path = parts[1];
        final segments = path.split('/');
        if (segments.length >= 2) {
          _owner = segments[0];
          _repo = segments[1];
          // Remove potential query parameters or trailing slashes
          if (_repo!.contains('?')) {
            _repo = _repo!.split('?')[0];
          }
          if (_repo!.endsWith('/')) {
            _repo = _repo!.substring(0, _repo!.length - 1);
          }
        }
      }
    }
  }

  Future<void> _fetchLiveGitHubDetails() async {
    if (_owner == null || _repo == null) return;
    final cacheKey = '${_owner}/${_repo}';
    final cachedData = ref.read(_githubRepoCache)[cacheKey];

    if (cachedData != null) {
      setState(() {
        _repoDetails = cachedData['details'] as Map<String, dynamic>;
        _contributorCount = cachedData['contributors'] as int;
        _readmeMarkdown = cachedData['readme'] as String;
        _isLoadingRepoDetails = false;
      });
      return;
    }

    setState(() {
      _isLoadingRepoDetails = true;
    });

    try {
      // 1. Fetch Repository General Details
      final detailsUri = Uri.parse('https://api.github.com/repos/$_owner/$_repo');
      final detailsResp = await http.get(detailsUri, headers: {'User-Agent': 'ai-career-os'});

      if (detailsResp.statusCode == 200) {
        _repoDetails = jsonDecode(detailsResp.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to load repository details: ${detailsResp.statusCode}');
      }

      // 2. Fetch Contributors Count (Cap to quick fetch)
      final contributorsUri = Uri.parse('https://api.github.com/repos/$_owner/$_repo/contributors?per_page=1');
      final contributorsResp = await http.get(contributorsUri, headers: {'User-Agent': 'ai-career-os'});
      if (contributorsResp.statusCode == 200) {
        final linkHeader = contributorsResp.headers['link'];
        if (linkHeader != null) {
          // Parse page count from Link header rel="last"
          final match = RegExp(r'page=(\d+)>;\s*rel="last"').firstMatch(linkHeader);
          if (match != null) {
            _contributorCount = int.tryParse(match.group(1) ?? '0') ?? 1;
          } else {
            _contributorCount = 1;
          }
        } else {
          final body = jsonDecode(contributorsResp.body) as List<dynamic>;
          _contributorCount = body.length;
        }
      }

      // 3. Fetch Raw README Markdown Content
      final readmeUri = Uri.parse('https://api.github.com/repos/$_owner/$_repo/readme');
      final readmeResp = await http.get(readmeUri, headers: {
        'Accept': 'application/vnd.github.raw',
        'User-Agent': 'ai-career-os',
      });
      if (readmeResp.statusCode == 200) {
        _readmeMarkdown = readmeResp.body;
      } else {
        _readmeMarkdown = '_No README.md found in this repository._';
      }

      // Save to cache
      final cache = Map<String, dynamic>.from(ref.read(_githubRepoCache));
      cache[cacheKey] = {
        'details': _repoDetails,
        'contributors': _contributorCount,
        'readme': _readmeMarkdown,
      };
      ref.read(_githubRepoCache.notifier).state = cache;

      setState(() {
        _isLoadingRepoDetails = false;
      });
    } catch (e) {
      setState(() {
        _readmeMarkdown = '_Error loading details from GitHub API: ${e}_';
        _isLoadingRepoDetails = false;
      });
    }
  }

  // ── File Explorer Logic ──────────────────────────────────────────
  Future<void> _fetchFolderContents() async {
    if (_owner == null || _repo == null) return;
    final path = _currentPathSegments.join('/');
    final cacheKey = '${_owner}/${_repo}/dir/$path';
    final cachedDir = ref.read(_githubRepoCache)[cacheKey];

    if (cachedDir != null) {
      setState(() {
        _currentFolderContents = cachedDir as List<dynamic>;
        _isLoadingContents = false;
        _explorerError = null;
      });
      return;
    }

    setState(() {
      _isLoadingContents = true;
      _explorerError = null;
    });

    try {
      final uri = Uri.parse('https://api.github.com/repos/$_owner/$_repo/contents/$path');
      final resp = await http.get(uri, headers: {'User-Agent': 'ai-career-os'});

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        // Sort directories first, then files
        data.sort((a, b) {
          final typeA = a['type'] as String;
          final typeB = b['type'] as String;
          if (typeA == 'dir' && typeB != 'dir') return -1;
          if (typeA != 'dir' && typeB == 'dir') return 1;
          return (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase());
        });

        final cache = Map<String, dynamic>.from(ref.read(_githubRepoCache));
        cache[cacheKey] = data;
        ref.read(_githubRepoCache.notifier).state = cache;

        setState(() {
          _currentFolderContents = data;
          _isLoadingContents = false;
        });
      } else {
        throw Exception('Failed to load folder contents: ${resp.statusCode}');
      }
    } catch (e) {
      setState(() {
        _explorerError = 'Error fetching folder content: $e';
        _isLoadingContents = false;
      });
    }
  }

  Future<void> _fetchFileContent(String downloadUrl, String name) async {
    final cacheKey = 'file/$downloadUrl';
    final cachedFile = ref.read(_githubRepoCache)[cacheKey];

    setState(() {
      _currentFileName = name;
      _isLoadingFile = true;
      _fileReaderError = null;
      _currentView = 'file';
    });

    if (cachedFile != null) {
      setState(() {
        _currentFileContent = cachedFile as String;
        _isLoadingFile = false;
      });
      return;
    }

    try {
      final resp = await http.get(Uri.parse(downloadUrl));
      if (resp.statusCode == 200) {
        final content = resp.body;

        final cache = Map<String, dynamic>.from(ref.read(_githubRepoCache));
        cache[cacheKey] = content;
        ref.read(_githubRepoCache.notifier).state = cache;

        setState(() {
          _currentFileContent = content;
          _isLoadingFile = false;
        });
      } else {
        throw Exception('Failed to download file content: ${resp.statusCode}');
      }
    } catch (e) {
      setState(() {
        _fileReaderError = 'Error reading file: $e';
        _isLoadingFile = false;
      });
    }
  }

  // ── Navigation Back logic ────────────────────────────────────────
  void _handleBack() {
    if (_currentView == 'file') {
      setState(() {
        _currentView = 'code';
        _currentFileName = null;
        _currentFileContent = '';
      });
    } else if (_currentView == 'code') {
      if (_currentPathSegments.isNotEmpty) {
        setState(() {
          _currentPathSegments.removeLast();
        });
        _fetchFolderContents();
      } else {
        setState(() {
          _currentView = 'home';
        });
      }
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pure Dark GitHub replica background
    const Color githubBg = Color(0xFF0D1117);

    return Scaffold(
      backgroundColor: githubBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: _handleBack,
        ),
        title: _currentView == 'home'
            ? Text(
                _repo ?? 'GitHub Details',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              )
            : _currentView == 'code'
                ? Text(
                    _currentPathSegments.isEmpty ? 'Root' : _currentPathSegments.last,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  )
                : Text(
                    _currentFileName ?? 'File View',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
        actions: [
          if (_currentView == 'home' && _project != null)
            TextButton(
              onPressed: () => context.push('/projects/edit/${_project!.id}'),
              child: const Text(
                'EDIT',
                style: TextStyle(
                  color: AppColors.accentLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoadingProject
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentLight))
          : _errorMessage != null
              ? _buildErrorView(_errorMessage!)
              : _buildMainBody(),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              style: AppTypography.bodyLarge.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainBody() {
    if (_currentView == 'home') {
      return _buildHomeView();
    } else if (_currentView == 'code') {
      return _buildCodeExplorerView();
    } else {
      return _buildFileContentViewer();
    }
  }

  // ── Screen 1: Home View ──────────────────────────────────────────
  Widget _buildHomeView() {
    final ownerName = _owner ?? 'GitHub';
    final repoName = _repo ?? 'Repository';
    final description = _repoDetails?['description'] as String? ?? _project?.description ?? 'No description provided.';
    final stars = _repoDetails?['stargazers_count'] as int? ?? 0;
    final forks = _repoDetails?['forks_count'] as int? ?? 0;
    final issues = _repoDetails?['open_issues_count'] as int? ?? 0;
    final watchers = _repoDetails?['subscribers_count'] as int? ?? 0;
    final branch = _repoDetails?['default_branch'] as String? ?? 'main';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Owner profile row
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: _repoDetails?['owner']?['avatar_url'] != null
                    ? CachedNetworkImage(
                        imageUrl: _repoDetails!['owner']['avatar_url'] as String,
                        width: 18,
                        height: 18,
                        placeholder: (_, __) => Container(color: Colors.white10),
                      )
                    : Container(
                        width: 18,
                        height: 18,
                        color: Colors.white10,
                        child: const Icon(Icons.person, size: 10, color: Colors.white54),
                      ),
              ),
              const SizedBox(width: 8),
              Text(
                ownerName.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Repo Name Title
          Text(
            repoName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Description
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),

          // Stars & Forks Counts
          Row(
            children: [
              const Icon(Icons.star_border_rounded, size: 16, color: Colors.white60),
              const SizedBox(width: 4),
              Text(
                '$stars ${stars == 1 ? "star" : "stars"}',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.call_split_rounded, size: 16, color: Colors.white60),
              const SizedBox(width: 4),
              Text(
                '$forks ${forks == 1 ? "fork" : "forks"}',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Custom outline buttons row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF21262D),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(stars > 0 ? Icons.star : Icons.star_border_rounded, size: 16, color: stars > 0 ? Colors.amber : Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        stars > 0 ? 'STARRED' : 'STAR',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 52,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF21262D),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: const Icon(Icons.call_split_rounded, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Container(
                width: 52,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF21262D),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: const Icon(Icons.notifications_none_rounded, size: 16, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Grid Status Indicators
          _buildInfoTilesGrid(issues, watchers),
          const SizedBox(height: 20),

          // Branch selector row
          Row(
            children: [
              const Icon(Icons.call_split_rounded, size: 16, color: Colors.white54),
              const SizedBox(width: 8),
              const Text(
                'Current branch',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF21262D),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  branch,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // List item trigger rows
          _buildExplorerRow(
            icon: Icons.code_rounded,
            label: 'Code',
            onTap: () {
              setState(() {
                _currentView = 'code';
                _currentPathSegments = [];
              });
              _fetchFolderContents();
            },
          ),
          _buildExplorerRow(
            icon: Icons.history_rounded,
            label: 'Commits',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Commits history is read-only for this repo.')),
              );
            },
          ),
          const SizedBox(height: 24),

          // Readme View Section
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: Colors.white54),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'README.md',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // README markdown box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              border: Border.all(color: const Color(0xFF30363D)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _isLoadingRepoDetails
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(color: AppColors.accentLight),
                    ),
                  )
                : _CustomMarkdownRenderer(
                    markdown: _readmeMarkdown,
                    owner: ownerName,
                    repo: repoName,
                    branch: branch,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTilesGrid(int openIssues, int watchers) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInfoTile(
                color: const Color(0xFF2EA44F), // GitHub green
                icon: Icons.adjust_rounded,
                label: 'Issues',
                value: '$openIssues',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoTile(
                color: const Color(0xFF0969DA), // GitHub blue
                icon: Icons.merge_type_rounded,
                label: 'Pull Requests',
                value: '0',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoTile(
                color: const Color(0xFFD93F0B), // GitHub orange
                icon: Icons.people_outline_rounded,
                label: 'Contributors',
                value: '$_contributorCount',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoTile(
                color: const Color(0xFFEAB308), // GitHub yellow
                icon: Icons.visibility_outlined,
                label: 'Watchers',
                value: '$watchers',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required Color color,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF21262D)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildExplorerRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF21262D))),
        ),
child: Row(
          children: [
            Icon(icon, color: Colors.white54, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Screen 2: Code Explorer View ─────────────────────────────────
  Widget _buildCodeExplorerView() {
    if (_isLoadingContents) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentLight));
    }

    if (_explorerError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            _explorerError!,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_currentFolderContents.isEmpty) {
      return const Center(
        child: Text(
          'This directory is empty.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _currentFolderContents.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF21262D)),
      itemBuilder: (ctx, index) {
        final item = _currentFolderContents[index];
        final name = item['name'] as String;
        final type = item['type'] as String;
        final isDir = type == 'dir';

        return ListTile(
          leading: Icon(
            isDir ? Icons.folder_rounded : Icons.insert_drive_file_outlined,
            color: isDir ? const Color(0xFF54aeff) : Colors.white54,
            size: 20,
          ),
          title: Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 16),
          onTap: () {
            if (isDir) {
              setState(() {
                _currentPathSegments.add(name);
              });
              _fetchFolderContents();
            } else {
              final downloadUrl = item['download_url'] as String?;
              if (downloadUrl != null) {
                _fetchFileContent(downloadUrl, name);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cannot view file contents.')),
                );
              }
            }
          },
        );
      },
    );
  }

  // ── Screen 3: File Content Viewer ────────────────────────────────
  Widget _buildFileContentViewer() {
    if (_isLoadingFile) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentLight));
    }

    if (_fileReaderError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            _fileReaderError!,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Split text into line numbers
    final lines = _currentFileContent.split('\n');

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Line numbers
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(
                  lines.length,
                  (i) => Text(
                    '${i + 1} ',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.white24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Code block
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lines
                    .map(
                      (line) => Text(
                        line,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Color(0xFFC9D1D9), // Sleek GitHub light-grey code color
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── CUSTOM MARKDOWN README RENDERER ───────────────────────────────
class _CustomMarkdownRenderer extends StatelessWidget {
  final String markdown;
  final String owner;
  final String repo;
  final String branch;

  const _CustomMarkdownRenderer({
    required this.markdown,
    required this.owner,
    required this.repo,
    required this.branch,
  });

  String _resolveUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    // Clean up relative path markers
    var cleanPath = path;
    if (cleanPath.startsWith('./')) {
      cleanPath = cleanPath.substring(2);
    }
    return 'https://raw.githubusercontent.com/$owner/$repo/$branch/$cleanPath';
  }

  @override
  Widget build(BuildContext context) {
    final lines = markdown.split('\n');
    final children = <Widget>[];

    bool inCodeBlock = false;
    List<String> codeBlockLines = [];

    for (int i = 0; i < lines.length; i++) {
      var line = lines[i].trim();

      // Handle Code Blocks
      if (line.startsWith('```')) {
        if (inCodeBlock) {
          // Close block
          children.add(Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                codeBlockLines.join('\n'),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFF8B949E),
                ),
              ),
            ),
          ));
          codeBlockLines.clear();
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
        }
        continue;
      }

      if (inCodeBlock) {
        codeBlockLines.add(lines[i]); // Keep original formatting inside block
        continue;
      }

      if (line.isEmpty) {
        children.add(const SizedBox(height: 8));
        continue;
      }

      // Handle Headers
      if (line.startsWith('# ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            line.substring(2),
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ));
      } else if (line.startsWith('## ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(
            line.substring(3),
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ));
      } else if (line.startsWith('### ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            line.substring(4),
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ));
      }

      // Handle Images & Badges
      else if (line.contains('![') && line.contains('](')) {
        // Parse image markdown
        final match = RegExp(r'!\[(.*?)\]\((.*?)\)').firstMatch(line);
        if (match != null) {
          final imageUrl = _resolveUrl(match.group(2)!.trim());
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => Container(
                  height: 150,
                  color: Colors.white10,
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ));
        }
      }

      // Handle bullet items
      else if (line.startsWith('- ') || line.startsWith('* ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(left: 12.0, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(color: Colors.white54, fontSize: 14)),
              Expanded(
                child: _buildRichText(line.substring(2)),
              ),
            ],
          ),
        ));
      }

      // Normal paragraph
      else {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _buildRichText(lines[i].trim()),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildRichText(String text, {double fontSize = 13, Color? color}) {
    final spans = <TextSpan>[];

    // Simple inline parsing for bold (**) and inline code (`)
    final regExp = RegExp(r'(\*\*.*?\*\*|`.*?`)');
    final matches = regExp.allMatches(text);

    int start = 0;
    for (final match in matches) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: TextStyle(fontSize: fontSize, color: color ?? Colors.white70),
        ));
      }

      final matchedText = match.group(0)!;
      if (matchedText.startsWith('**') && matchedText.endsWith('**')) {
        spans.add(TextSpan(
          text: matchedText.substring(2, matchedText.length - 2),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.white,
          ),
        ));
      } else if (matchedText.startsWith('`') && matchedText.endsWith('`')) {
        spans.add(TextSpan(
          text: matchedText.substring(1, matchedText.length - 1),
          style: TextStyle(
            fontSize: fontSize - 1,
            fontFamily: 'monospace',
            backgroundColor: Colors.white10,
            color: AppColors.accentLight,
          ),
        ));
      }

      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: TextStyle(fontSize: fontSize, color: color ?? Colors.white70),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
