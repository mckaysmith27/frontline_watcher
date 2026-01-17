import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class JobWebViewScreen extends StatefulWidget {
  final String jobUrl;

  const JobWebViewScreen({
    super.key,
    required this.jobUrl,
  });

  @override
  State<JobWebViewScreen> createState() => _JobWebViewScreenState();
}

class _JobWebViewScreenState extends State<JobWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasAttemptedAutoFill = false;
  bool _hasShownAcceptAttempt = false;
  bool _hasShownAcceptSuccess = false;
  bool _isLoggedIn = false;
  bool _showAcceptGuidance = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(true) // Enable zoom for better button visibility
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) async {
            setState(() {
              _isLoading = false;
            });
            
            // Attempt to auto-fill login if on login page and credentials exist
            // Credentials stay on device - only used to fill form fields
            if (url.contains('login.frontlineeducation.com') && !_hasAttemptedAutoFill) {
              await _attemptAutoFillLogin();
              _hasAttemptedAutoFill = true;
            } else if (!url.contains('login.frontlineeducation.com')) {
              // User is logged in (not on login page)
              setState(() {
                _isLoggedIn = true;
              });
              
              // Set up Accept button detection and guidance
              await _setupAcceptButtonDetection();
              await _findAndHighlightAcceptButton();
            }
          },
          onWebResourceError: (WebResourceError error) {
            print('WebView error: ${error.description}');
          },
          onUrlChange: (UrlChange change) {
            // Detect if job was accepted (URL change or page content change)
            if (change.url != null && !change.url!.contains('login')) {
              _checkForAcceptSuccess();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.jobUrl));
  }

  Future<void> _findAndHighlightAcceptButton() async {
    // Find Accept button position and show guidance overlay
    try {
      final result = await _controller.runJavaScriptReturningResult('''
        (function() {
          const acceptButton = document.querySelector('a.acceptButton, button:has-text("Accept"), a:has-text("Accept"), [class*="accept"], [id*="accept"]');
          if (acceptButton) {
            const rect = acceptButton.getBoundingClientRect();
            const scrollX = window.pageXOffset || document.documentElement.scrollLeft;
            const scrollY = window.pageYOffset || document.documentElement.scrollTop;
            
            // Scroll button into view and highlight it
            acceptButton.scrollIntoView({ behavior: 'smooth', block: 'center' });
            acceptButton.style.border = '3px solid #4CAF50';
            acceptButton.style.boxShadow = '0 0 20px rgba(76, 175, 80, 0.5)';
            acceptButton.style.zIndex = '10000';
            
            // Add pulsing animation
            acceptButton.style.animation = 'pulse 2s infinite';
            const style = document.createElement('style');
            style.textContent = '@keyframes pulse { 0%, 100% { transform: scale(1); } 50% { transform: scale(1.05); } }';
            document.head.appendChild(style);
            
            return JSON.stringify({
              found: true,
              x: rect.left + scrollX,
              y: rect.top + scrollY,
              width: rect.width,
              height: rect.height
            });
          }
          return JSON.stringify({ found: false });
        })();
      ''');
      
      if (!mounted) return;
      final data = result.toString();
      if (data.contains('"found":true')) {
        setState(() {
          _showAcceptGuidance = true;
        });
      }
    } catch (e) {
      print('[WebView] Error finding accept button: $e');
    }
  }

  Future<void> _attemptAutoFillLogin() async {
    // Get credentials from device keychain (FlutterSecureStorage)
    // These credentials NEVER leave the device - only used to fill form fields
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final creds = await authProvider.getEssCredentials();
    
    if (creds['username'] != null && creds['password'] != null) {
      // Inject JavaScript to fill login form
      // This happens entirely on-device - credentials never transmitted
      final username = creds['username']!;
      final password = creds['password']!;
      
      final script = '''
        (function() {
          // Try to find username/email input
          const usernameSelectors = [
            'input[type="email"]',
            'input[name*="user"]',
            'input[name*="email"]',
            'input[name="username"]',
            'input#username',
            'input[type="text"]'
          ];
          
          const passwordSelectors = [
            'input[type="password"]',
            'input[name="password"]',
            'input#password'
          ];
          
          let usernameField = null;
          let passwordField = null;
          
          for (const selector of usernameSelectors) {
            const field = document.querySelector(selector);
            if (field && field.offsetParent !== null) {
              usernameField = field;
              break;
            }
          }
          
          for (const selector of passwordSelectors) {
            const field = document.querySelector(selector);
            if (field && field.offsetParent !== null) {
              passwordField = field;
              break;
            }
          }
          
          if (usernameField && passwordField) {
            usernameField.value = '$username';
            usernameField.dispatchEvent(new Event('input', { bubbles: true }));
            usernameField.dispatchEvent(new Event('change', { bubbles: true }));
            
            passwordField.value = '$password';
            passwordField.dispatchEvent(new Event('input', { bubbles: true }));
            passwordField.dispatchEvent(new Event('change', { bubbles: true }));
            
            return 'filled';
          }
          return 'fields_not_found';
        })();
      ''';
      
      try {
        final result = await _controller.runJavaScriptReturningResult(script);
        if (result.toString().contains('filled')) {
          print('[WebView] Auto-filled login form using device-stored credentials');
        }
      } catch (e) {
        print('[WebView] Could not auto-fill login: $e');
        // User will need to manually enter credentials - that's fine
      }
    }
  }

  Future<void> _setupAcceptButtonDetection() async {
    // Set up periodic monitoring for Accept button state changes
    _monitorAcceptButton();
  }

  void _monitorAcceptButton() {
    // Check every 1 second for Accept button state changes
    Future.delayed(const Duration(seconds: 1), () async {
      if (!mounted) return;
      
      try {
        final result = await _controller.runJavaScriptReturningResult('''
          (function() {
            try {
              // Check for Accept buttons
              const acceptButtons = document.querySelectorAll('a.acceptButton, button:has-text("Accept"), a:has-text("Accept")');
              let hasAcceptButton = acceptButtons.length > 0;
              let isAccepted = false;
              let buttonWasClicked = false;
              
              // Check if job was accepted (button disabled, hidden, or page shows success)
              acceptButtons.forEach(btn => {
                const btnText = btn.innerText || btn.textContent || '';
                if (btn.disabled || btn.style.display === 'none' || 
                    btn.classList.contains('accepted') || 
                    btnText.toLowerCase().includes('accepted') ||
                    btn.classList.contains('hidden')) {
                  isAccepted = true;
                }
              });
              
              // Also check page content for success indicators
              const bodyText = (document.body?.innerText || '').toLowerCase();
              if (bodyText.includes('accepted') || bodyText.includes('successfully accepted') ||
                  bodyText.includes('job accepted') || bodyText.includes('confirmed') ||
                  bodyText.includes('you have accepted')) {
                isAccepted = true;
              }
              
              // Check if Accept button disappeared (was clicked)
              if (!hasAcceptButton && !isAccepted) {
                // Button was there before but now gone - might be processing
                buttonWasClicked = true;
              }
              
              if (isAccepted) {
                return 'success';
              } else if (buttonWasClicked || (hasAcceptButton && !isAccepted)) {
                return 'attempt';
              }
              return 'none';
            } catch (e) {
              return 'none';
            }
          })();
        ''');
        
        if (!mounted) return;
        final status = result.toString().toLowerCase();
        if (status.contains('attempt') && !_hasShownAcceptAttempt) {
          _showAcceptAttempt();
        } else if (status.contains('success') && !_hasShownAcceptSuccess) {
          _showAcceptSuccess();
        }
      } catch (e) {
        // Ignore errors
      }
      
      _monitorAcceptButton(); // Continue monitoring
    });
  }

  void _showAcceptAttempt() {
    if (!mounted || _hasShownAcceptAttempt) return;
    _hasShownAcceptAttempt = true;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Attempting to accept job...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showAcceptSuccess() {
    if (!mounted || _hasShownAcceptSuccess) return;
    _hasShownAcceptSuccess = true;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Job accepted successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _checkForAcceptSuccess() async {
    // Check page content for success indicators
    try {
      final result = await _controller.runJavaScriptReturningResult('''
        (function() {
          const bodyText = document.body.innerText.toLowerCase();
          const hasAccepted = bodyText.includes('accepted') || 
                             bodyText.includes('successfully') ||
                             bodyText.includes('confirmed');
          const hasAcceptButton = document.querySelector('a.acceptButton, button:has-text("Accept")') === null;
          
          return hasAccepted || hasAcceptButton;
        })();
      ''');
      
      if (result.toString().contains('true') && !_hasShownAcceptSuccess) {
        _showAcceptSuccess();
      }
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          
          // Accept button guidance overlay
          if (_showAcceptGuidance && _isLoggedIn)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: false,
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.touch_app,
                            color: Colors.green,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Tap the highlighted "Accept" button',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'The Accept button is highlighted in green on the page',
                            style: TextStyle(fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _showAcceptGuidance = false;
                              });
                            },
                            child: const Text('Got it'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

