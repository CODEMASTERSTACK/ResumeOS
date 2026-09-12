/// Application-wide configuration and centralized API endpoints
class AppConfig {
  AppConfig._();

  /// Cloudflare Workers Backend Base URL
  static const String backendBaseUrl = 'https://smartresume-backend.kanasingh974.workers.dev';

  /// AI Generation Endpoint
  static const String aiGenerateUrl = '$backendBaseUrl/v1/ai/generate';

  /// Job Openings Aggregator Endpoint (India & Global Remote)
  static const String jobsIndiaUrl = '$backendBaseUrl/v1/jobs/india';

  /// Account Deletion Endpoint
  static const String deleteAccountUrl = '$backendBaseUrl/v1/auth/delete-account';

  /// Public Legal Webpage URLs (for Google Play Console submission)
  static const String privacyPolicyWebUrl = '$backendBaseUrl/privacy';
  static const String termsOfServiceWebUrl = '$backendBaseUrl/terms';

  /// Remote App Configuration & Maintenance Gate
  static const String appConfigUrl = '$backendBaseUrl/v1/app-config';

  /// Client Crash & Error Reporting Telemetry Endpoint
  static const String reportErrorUrl = '$backendBaseUrl/v1/telemetry/report-error';

  /// User Support & Bug Report Submission Endpoint
  static const String submitReportUrl = '$backendBaseUrl/v1/reports/submit';
}
