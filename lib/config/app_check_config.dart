/// App Check Configuration
/// Konfigurasi untuk mengatur Firebase App Check

class AppCheckConfig {
  // MAIN CONFIGURATION
  static const bool enableAppCheck = false; // Set true untuk aktifkan App Check

  // ADVANCED CONFIGURATION
  static const bool forceDebugProvider = true; // Always use debug provider
  static const bool enableTokenLogging = true; // Log App Check tokens
  static const bool showAppCheckErrors = true; // Show App Check errors in UI
  static const int appCheckTimeoutSeconds =
      10; // Timeout for App Check operations

  // DEBUG CONFIGURATION
  static const bool enableDebugSplash = false; // Use debug splash screen
  static const bool enableVerboseLogging = true; // Detailed logging
  static const bool enableDebugMenu = true; // Show debug menu in settings

  // ERROR HANDLING
  static const bool continueOnAppCheckError =
      true; // Continue if App Check fails
  static const bool showRetryOnError = true; // Show retry button on errors

  /// Get human readable configuration status
  static String getConfigStatus() {
    final buffer = StringBuffer();
    buffer.writeln('App Check: ${enableAppCheck ? "✅ ENABLED" : "❌ DISABLED"}');
    buffer.writeln('Debug Provider: ${forceDebugProvider ? "✅ YES" : "❌ NO"}');
    buffer.writeln('Token Logging: ${enableTokenLogging ? "✅ YES" : "❌ NO"}');
    buffer.writeln('Error Display: ${showAppCheckErrors ? "✅ YES" : "❌ NO"}');
    buffer.writeln('Timeout: ${appCheckTimeoutSeconds}s');
    buffer.writeln(
      'Continue on Error: ${continueOnAppCheckError ? "✅ YES" : "❌ NO"}',
    );
    buffer.writeln('Debug Menu: ${enableDebugMenu ? "✅ YES" : "❌ NO"}');
    return buffer.toString();
  }
}
