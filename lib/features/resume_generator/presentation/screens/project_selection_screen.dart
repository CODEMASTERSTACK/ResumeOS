import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF07060F),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 20),
          ),
        ),
        title: Text(
          'Select Projects',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Aurora background
          Positioned(
            top: -60,
            left: -60,
            width: 200,
            height: 200,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFF0F6),
              ),
            ),
          ),
          Positioned(
            top: -120,
            left: -120,
            width: screenHeight * 0.5,
            height: screenHeight * 0.4,
            child: Transform.rotate(
              angle: -0.15,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFEC53B0).withValues(alpha: 0.5),
                      const Color(0xFF723FFD).withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -50,
            left: -50,
            width: screenHeight * 0.35,
            height: screenHeight * 0.35,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF723FFD).withValues(alpha: 0.25),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80.0, sigmaY: 80.0),
              child: Container(
                color: const Color(0xFF07060F).withValues(alpha: 0.35),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: rankedAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFCBE349),
                  strokeWidth: 2,
                ),
              ),
              error: (e, _) => Center(
                child: Text(
                  e.toString(),
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
              data: (ranked) {
                if (ranked.isEmpty) {
                  return _NoProjectsState(
                    onAdd: () => context.push('/projects/add'),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI ranked your projects by how well they\nmatch this job description.',
                            style: GoogleFonts.outfit(
                              color: Colors.white38,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: Text(
                                  selectedIds.isEmpty
                                      ? 'None selected'
                                      : '${selectedIds.length} selected',
                                  key: ValueKey(selectedIds.length),
                                  style: GoogleFonts.outfit(
                                    color: selectedIds.isEmpty
                                        ? Colors.white24
                                        : const Color(0xFFCBE349),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (selectedIds.isNotEmpty)
                                GestureDetector(
                                  onTap: () => ref
                                      .read(
                                          selectedProjectIdsProvider.notifier)
                                      .state = {},
                                  child: Text(
                                    'Clear all',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white24,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ],
                      ),
                    ),

                    // ── Project List ───────────────────────
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        itemCount: ranked.length,
                        itemBuilder: (context, i) {
                          final (project, score) = ranked[i];
                          final isSelected =
                              selectedIds.contains(project.id);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ProjectCard(
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
                            ),
                          );
                        },
                      ),
                    ),

                    // ── Bottom CTA ─────────────────────────
                    _BottomCTA(
                      selectedCount: selectedIds.length,
                      onTap: selectedIds.isEmpty
                          ? null
                          : () => context
                              .push(RouteNames.generateSelectTemplate),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Project Card ───────────────────────────────────────────
// Uses Stack to implement a left accent bar separately from the
// card body so borderRadius works with a uniform card border.

class _ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final double score;
  final int rank;
  final bool isSelected;
  final VoidCallback onToggle;

  const _ProjectCard({
    required this.project,
    required this.score,
    required this.rank,
    required this.isSelected,
    required this.onToggle,
  });

  Color get _scoreColor {
    final pct = (score * 100).round();
    if (pct >= 65) return const Color(0xFF10B981);
    if (pct >= 35) return const Color(0xFFF59E0B);
    return Colors.white30;
  }

  @override
  Widget build(BuildContext context) {
    final scorePct = (score * 100).round().clamp(0, 100);
    final displaySkills = <String>{
      ...project.technologies,
      ...project.linkedSkills,
    }.take(4).toList();

    return GestureDetector(
      onTap: onToggle,
      child: Stack(
        children: [
          // ── Card body — uniform border (required for borderRadius) ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Rank — large muted number, not a badge
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$rank',
                      style: GoogleFonts.outfit(
                        color: isSelected
                            ? const Color(0xFFCBE349).withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.12),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title + skills
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.title,
                          style: GoogleFonts.outfit(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (displaySkills.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            displaySkills.join('  ·  '),
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Match score — understated, right-aligned
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$scorePct%',
                        style: GoogleFonts.outfit(
                          color: _scoreColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'match',
                        style: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.18),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 14),

                  // Selection indicator — minimal circle
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? const Color(0xFFCBE349)
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFCBE349)
                            : Colors.white.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 12,
                            color: Color(0xFF07060F),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),

          // ── Left accent bar — separate overlay, avoids non-uniform border ──
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: isSelected ? 3.0 : 0.0,
              decoration: const BoxDecoration(
                color: Color(0xFFCBE349),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom CTA — sticky, frosted ──────────────────────────

class _BottomCTA extends StatelessWidget {
  final int selectedCount;
  final VoidCallback? onTap;

  const _BottomCTA({required this.selectedCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = onTap != null;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(context).padding.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF07060F).withValues(alpha: 0.7),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.07),
                width: 1,
              ),
            ),
          ),
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 17),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFCBE349)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color:
                              const Color(0xFFCBE349).withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      isActive
                          ? 'Choose Template'
                          : 'Select at least 1 project',
                      key: ValueKey(isActive),
                      style: GoogleFonts.outfit(
                        color: isActive
                            ? const Color(0xFF07060F)
                            : Colors.white24,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF07060F),
                      size: 18,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── No Projects State ──────────────────────────────────────

class _NoProjectsState extends StatelessWidget {
  final VoidCallback onAdd;
  const _NoProjectsState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Icon(
                Icons.code_rounded,
                size: 28,
                color: Colors.white30,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No projects yet',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add at least one project to your profile so AI can rank it for this role.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white38,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBE349),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFFCBE349).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  'Add Project',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF07060F),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
