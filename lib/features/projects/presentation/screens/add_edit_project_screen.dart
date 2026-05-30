import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/projects/data/repositories/project_repository.dart';
import '../../../../features/projects/domain/entities/project_model.dart';
import '../../../../services/ai/gemini_service.dart';
import '../../../../services/github/github_service.dart';
import '../../../../shared/widgets/app_button.dart';
import 'package:uuid/uuid.dart';

class AddEditProjectScreen extends ConsumerStatefulWidget {
  final String? projectId;

  const AddEditProjectScreen({super.key, this.projectId});

  @override
  ConsumerState<AddEditProjectScreen> createState() =>
      _AddEditProjectScreenState();
}

class _AddEditProjectScreenState extends ConsumerState<AddEditProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _githubCtrl = TextEditingController();
  final _liveCtrl = TextEditingController();
  final _techCtrl = TextEditingController();

  List<String> _technologies = [];
  bool _isLoading = false;
  bool _isGeneratingAI = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.projectId != null) {
      _isEditing = true;
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    final project = await ref
        .read(projectRepositoryProvider)
        .getProject(uid, widget.projectId!);
    if (project != null && mounted) {
      setState(() {
        _titleCtrl.text = project.title;
        _descCtrl.text = project.description;
        _githubCtrl.text = project.githubRepo;
        _liveCtrl.text = project.liveUrl;
        _technologies = List.from(project.technologies);
      });
    }
  }

  void _addTech(String tech) {
    final t = tech.trim();
    if (t.isNotEmpty && !_technologies.contains(t)) {
      setState(() => _technologies.add(t));
      _techCtrl.clear();
    }
  }

  Future<void> _generateAISummary() async {
    if (_titleCtrl.text.isEmpty || _descCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill in title and description first')),
      );
      return;
    }
    setState(() => _isGeneratingAI = true);
    try {
      final ai = ref.read(geminiServiceImplProvider);
      final result = await ai.rewriteProjectBullets(
        projectTitle: _titleCtrl.text,
        projectDescription: _descCtrl.text,
        technologies: _technologies,
        targetRole: 'Software Engineer',
        keywords: _technologies,
      );
      if (mounted) {
        _descCtrl.text = result.bullets.join('\n• ');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI summary generated!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.aiError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingAI = false);
    }
  }

  Future<void> _importFromGitHub() async {
    final token = ref.read(gitHubTokenProvider);
    if (token == null) {
      _showGitHubTokenDialog();
      return;
    }
    _showGitHubRepoPicker(token);
  }

  void _showGitHubTokenDialog() {
    final tokenCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.code_rounded, color: AppColors.accent),
              SizedBox(width: 8),
              Text('GitHub Integration'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Direct importing is available when you sign in with GitHub on the Login screen.',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Alternatively, enter a GitHub Personal Access Token (PAT) below to fetch your repositories:',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tokenCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Personal Access Token',
                  hintText: 'ghp_...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final pat = tokenCtrl.text.trim();
                if (pat.isNotEmpty) {
                  ref.read(gitHubTokenProvider.notifier).state = pat;
                  Navigator.of(context).pop();
                  _showGitHubRepoPicker(pat);
                }
              },
              child: const Text('Connect PAT', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showGitHubRepoPicker(String token) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final reposAsyncValue = ref.watch(gitHubReposProvider);
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select GitHub Repository',
                        style: AppTypography.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap a repository to automatically pre-fill your project details.',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: reposAsyncValue.when(
                      data: (repos) {
                        if (repos.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.folder_open_rounded, size: 48, color: AppColors.textSecondary),
                                const SizedBox(height: 12),
                                Text('No repositories found', style: AppTypography.titleMedium),
                              ],
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: repos.length,
                          separatorBuilder: (_, __) => Divider(color: AppColors.border.withOpacity(0.1)),
                          itemBuilder: (context, index) {
                            final repo = repos[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      repo.name,
                                      style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (repo.language != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        repo.language!,
                                        style: AppTypography.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (repo.description != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      repo.description!,
                                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_outline_rounded, size: 14, color: AppColors.warning),
                                      const SizedBox(width: 4),
                                      Text('${repo.stars}', style: AppTypography.caption),
                                      const SizedBox(width: 16),
                                      Text(
                                        'Pushed: ${repo.pushedAt != null ? "${repo.pushedAt!.year}-${repo.pushedAt!.month.toString().padLeft(2, '0')}-${repo.pushedAt!.day.toString().padLeft(2, '0')}" : "unknown"}',
                                        style: AppTypography.caption,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              onTap: () {
                                setState(() {
                                  _titleCtrl.text = repo.name;
                                  _descCtrl.text = repo.description ?? '';
                                  _githubCtrl.text = repo.htmlUrl;
                                  if (repo.language != null && !_technologies.contains(repo.language!)) {
                                    _technologies.add(repo.language!);
                                  }
                                  for (final topic in repo.topics) {
                                    if (!_technologies.contains(topic)) {
                                      _technologies.add(topic);
                                    }
                                  }
                                });
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Pre-filled details from "${repo.name}"! Use "AI Enhance" to write professional bullets.'),
                                    backgroundColor: AppColors.success,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                      loading: () => const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: AppColors.accent),
                            SizedBox(height: 16),
                            Text('Fetching your GitHub repositories...'),
                          ],
                        ),
                      ),
                      error: (err, stack) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                              const SizedBox(height: 12),
                              Text('Failed to load repositories', style: AppTypography.titleMedium),
                              const SizedBox(height: 4),
                              Text(err.toString(), style: AppTypography.caption, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => ref.invalidate(gitHubReposProvider),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);
    try {
      final project = ProjectModel(
        id: widget.projectId ?? const Uuid().v4(),
        uid: uid,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        githubRepo: _githubCtrl.text.trim(),
        liveUrl: _liveCtrl.text.trim(),
        technologies: _technologies,
      );

      if (_isEditing) {
        await ref
            .read(projectRepositoryProvider)
            .updateProject(uid, widget.projectId!, project.toJson());
      } else {
        await ref.read(projectRepositoryProvider).addProject(uid, project);
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.genericError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _githubCtrl.dispose();
    _liveCtrl.dispose();
    _techCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Project' : AppStrings.addProject),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Title
            _FormField(
              label: 'Project Title *',
              child: TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                    hintText: 'e.g., AI Resume Builder'),
                validator: (v) =>
                    v?.isEmpty == true ? 'Title is required' : null,
              ),
            ),
            const SizedBox(height: 16),

            // Description
            _FormField(
              label: 'Description *',
              action: _isGeneratingAI
                  ? null
                  : TextButton.icon(
                      onPressed: _generateAISummary,
                      icon: const Icon(Icons.auto_awesome_rounded,
                          size: 14, color: AppColors.accent),
                      label: Text(
                        'AI Enhance',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.accent,
                        ),
                      ),
                    ),
              child: TextFormField(
                controller: _descCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText:
                      'Describe what you built, your role, and impact...',
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    v?.isEmpty == true ? 'Description is required' : null,
              ),
            ),
            if (_isGeneratingAI)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI is rewriting your bullets...',
                      style: AppTypography.caption.copyWith(
                          color: AppColors.accent),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Technologies
            _FormField(
              label: 'Technologies',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _techCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Type tech and press Enter...',
                          ),
                          onSubmitted: _addTech,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _addTech(_techCtrl.text),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                  if (_technologies.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _technologies.map((tech) {
                        return Chip(
                          label: Text(tech),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () =>
                              setState(() => _technologies.remove(tech)),
                          backgroundColor: AppColors.accentContainer,
                          labelStyle: AppTypography.labelMedium.copyWith(
                            color: AppColors.accent,
                          ),
                          side: const BorderSide(
                              color: AppColors.accentContainer),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // GitHub
            _FormField(
              label: 'GitHub Repository URL',
              action: TextButton.icon(
                onPressed: _importFromGitHub,
                icon: const Icon(Icons.cloud_download_rounded,
                    size: 14, color: AppColors.accent),
                label: Text(
                  'Import Repository',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.accent,
                  ),
                ),
              ),
              child: TextFormField(
                controller: _githubCtrl,
                decoration: const InputDecoration(
                  hintText: 'https://github.com/username/repo',
                  prefixIcon: Icon(Icons.code, size: 18),
                ),
                keyboardType: TextInputType.url,
              ),
            ),
            const SizedBox(height: 16),

            // Live URL
            _FormField(
              label: 'Live Demo URL',
              child: TextFormField(
                controller: _liveCtrl,
                decoration: const InputDecoration(
                  hintText: 'https://myproject.com',
                  prefixIcon: Icon(Icons.open_in_new, size: 18),
                ),
                keyboardType: TextInputType.url,
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            AppButton(
              label: _isEditing ? AppStrings.saveChanges : 'Add Project',
              onTap: _isLoading ? null : _save,
              isLoading: _isLoading,
              variant: AppButtonVariant.primary,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: AppStrings.cancel,
              onTap: () => context.pop(),
              variant: AppButtonVariant.ghost,
            ),
          ],
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final Widget child;
  final Widget? action;

  const _FormField({
    required this.label,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTypography.labelLarge),
            if (action != null) action!,
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
