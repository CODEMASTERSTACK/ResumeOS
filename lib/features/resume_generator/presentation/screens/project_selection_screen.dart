import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../features/projects/domain/entities/project_model.dart';
import '../../../../routes/route_names.dart';
import 'ai_analysis_screen.dart';

// ── Selected Projects Provider ─────────────────────────────

final selectedProjectIdsProvider =
    StateProvider<Set<String>>((ref) => {});

// ── Project Selection Screen ───────────────────────────────

class ProjectSelectionScreen extends ConsumerWidget {
  const ProjectSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankedAsync = ref.watch(rankedProjectsProvider);
    final selectedIds = ref.watch(selectedProjectIdsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(AppStrings.selectProjects),
        elevation: 0,
      ),
      body: rankedAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(e.toString())),
        data: (ranked) {
          if (ranked.isEmpty) {
            return _NoProjectsState(
              onAdd: () => context.push('/projects/add'),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.selectProjectsSubtitle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${selectedIds.length} selected',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  itemCount: ranked.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final (project, score) = ranked[i];
                    final isSelected =
                        selectedIds.contains(project.id);
                    return _RankedProjectTile(
                      project: project,
                      score: score,
                      rank: i + 1,
                      isSelected: isSelected,
                      onToggle: () {
                        final ids = Set<String>.from(selectedIds);
                        if (isSelected) {
                          ids.remove(project.id);
                        } else {
                          ids.add(project.id);
                        }
                        ref
                            .read(selectedProjectIdsProvider.notifier)
                            .state = ids;
                      },
                    );
                  },
                ),
              ),
              // CTA
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton(
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () => context.push(
                          RouteNames.generateSelectTemplate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    disabledBackgroundColor:
                        AppColors.accentContainer,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    selectedIds.isEmpty
                        ? 'Select at least 1 project'
                        : 'Choose Template →',
                    style: AppTypography.labelLarge.copyWith(
                      color: selectedIds.isEmpty
                          ? AppColors.textMuted
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RankedProjectTile extends StatelessWidget {
  final ProjectModel project;
  final double score;
  final int rank;
  final bool isSelected;
  final VoidCallback onToggle;

  const _RankedProjectTile({
    required this.project,
    required this.score,
    required this.rank,
    required this.isSelected,
    required this.onToggle,
  });

  Color get _rankColor {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final scorePct = (score * 100).round().clamp(0, 100);

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentContainer
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _rankColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: AppTypography.labelSmall.copyWith(
                    color: _rankColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project.title,
                      style: AppTypography.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  (() {
                    final displaySkills = {
                      ...project.technologies,
                      ...project.linkedSkills,
                    }.toList();
                    if (displaySkills.isEmpty) return const SizedBox.shrink();
                    return Text(
                      displaySkills.take(5).join(' · '),
                      style: AppTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  })(),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Match score
            Column(
              children: [
                Text(
                  '$scorePct%',
                  style: AppTypography.labelMedium.copyWith(
                    color: scorePct >= 50
                        ? AppColors.success
                        : AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text('match', style: AppTypography.caption),
              ],
            ),
            const SizedBox(width: 10),
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accent
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoProjectsState extends StatelessWidget {
  final VoidCallback onAdd;
  const _NoProjectsState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.code_outlined,
              size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text('No projects yet',
              style: AppTypography.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Add at least one project to your profile first.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onAdd,
            child: const Text('Add Project'),
          ),
        ],
      ),
    );
  }
}
