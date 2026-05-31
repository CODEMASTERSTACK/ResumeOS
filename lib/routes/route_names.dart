/// AI Career OS — Route Names
class RouteNames {
  RouteNames._();

  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String otpVerify = '/otp-verify';
  static const String accountDeleted = '/account-deleted';
  static const String forgotPassword = '/forgot-password';
  static const String terms = '/terms';
  static const String privacy = '/privacy';

  // Onboarding
  static const String onboarding = '/onboarding';
  static const String onboardingWelcome = '/onboarding/welcome';
  static const String onboardingDetails = '/onboarding/details';
  static const String onboardingSkills = '/onboarding/skills';
  static const String onboardingEducation = '/onboarding/education';
  static const String onboardingExperience = '/onboarding/experience';
  static const String onboardingGitHub = '/onboarding/github';
  static const String onboardingComplete = '/onboarding/complete';

  // Shell (bottom nav)
  static const String dashboard = '/dashboard';
  static const String projects = '/projects';
  static const String addProject = '/projects/add';
  static const String editProject = '/projects/edit/:projectId';
  static const String generate = '/generate';
  static const String generateAnalyze = '/generate/analyze';
  static const String generateSelectProjects = '/generate/select-projects';
  static const String generateSelectTemplate = '/generate/select-template';
  static const String generatePreview = '/generate/preview/:resumeId';
  static const String resumeEdit = '/generate/edit/:resumeId';
  static const String history = '/history';
  static const String historyDetail = '/history/:resumeId';
  static const String profile = '/profile';
  static const String editProfileSection = '/profile/edit/:section';
  static const String githubRepoView = '/projects/github-view/:projectId';
}
