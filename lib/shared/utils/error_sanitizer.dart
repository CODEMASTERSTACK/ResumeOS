class ErrorSanitizer {
  static String sanitize(String rawError) {
    final lower = rawError.toLowerCase();
    
    // Allow user-friendly auth errors to pass through
    if (lower.contains('incorrect email or password') ||
        lower.contains('password must be at least') ||
        lower.contains('valid email address') ||
        lower.contains('network error') ||
        lower.contains('cancelled') ||
        lower.contains('aborted') ||
        lower.contains('no account found') ||
        lower.contains('already exists') ||
        lower.contains('passwords do not match')) {
      return rawError;
    }
    
    // Map system-level errors (Firebase, Firestore, Database, Socket, Server, etc.) to a general user-friendly message
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
        rawError.contains('Exception:') || 
        rawError.contains('FirebaseException') ||
        rawError.contains('SocketException') ||
        rawError.contains('HttpException')) {
      return 'Something went wrong. Please check your connection and try again.';
    }
    
    return rawError;
  }
}
