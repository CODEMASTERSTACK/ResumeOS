class ErrorSanitizer {
  static String sanitize(String rawError) {
    // Clean up typical exception wrappers first
    String cleanError = rawError;
    
    // Loop to strip nested wrappers if any
    bool cleaned = true;
    while (cleaned) {
      cleaned = false;
      if (cleanError.startsWith('Exception: ')) {
        cleanError = cleanError.substring('Exception: '.length);
        cleaned = true;
      }
      if (cleanError.startsWith('API Gateway error: ')) {
        cleanError = cleanError.substring('API Gateway error: '.length);
        cleaned = true;
      }
    }
    
    final lower = cleanError.toLowerCase();
    
    // Allow user-friendly auth and points errors to pass through
    if (lower.contains('incorrect email or password') ||
        lower.contains('password must be at least') ||
        lower.contains('valid email address') ||
        lower.contains('network error') ||
        lower.contains('cancelled') ||
        lower.contains('aborted') ||
        lower.contains('no account found') ||
        lower.contains('already exists') ||
        lower.contains('passwords do not match') ||
        lower.contains('insufficient points') ||
        lower.contains('low balance') ||
        lower.contains('points') ||
        lower.contains('api gateway error') ||
        lower.contains('ai generation failed') ||
        lower.contains('gemini') ||
        lower.contains('openrouter')) {
      return cleanError;
    }
    
    // Map system-level errors (Firebase, Firestore, Database, gRPC, Socket, HTTP, etc.)
    if (lower.contains('firestore') ||
        lower.contains('firebase') ||
        lower.contains('grpc') ||
        lower.contains('database') ||
        lower.contains('socket') ||
        lower.contains('http') ||
        lower.contains('server') ||
        lower.contains('exception') ||
        lower.contains('permission-denied') ||
        lower.contains('unavailable') ||
        lower.contains('timeout') ||
        lower.contains('failed-precondition') ||
        lower.contains('internal-error') ||
        lower.contains('failed to dispatch email') ||
        cleanError.contains('Exception') || 
        cleanError.contains('FirebaseException') ||
        cleanError.contains('SocketException') ||
        cleanError.contains('HttpException')) {
      return 'Something went wrong. Please check your connection and try again.';
    }
    
    return cleanError;
  }
}
