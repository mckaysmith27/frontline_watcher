import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';

class BookingWebScreen extends StatefulWidget {
  final String shortname;
  final List<DateTime> selectedDates;

  const BookingWebScreen({
    super.key,
    required this.shortname,
    required this.selectedDates,
  });

  @override
  State<BookingWebScreen> createState() => _BookingWebScreenState();
}

class _BookingWebScreenState extends State<BookingWebScreen> {
  late final WebViewController _controller;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _showOverlay = true;
  bool _termsAccepted = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCredentials();
    _initializeWebView();
  }

  Future<void> _loadCredentials() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final username = await _secureStorage.read(
      key: 'ess_username_${user.uid}',
    );
    final password = await _secureStorage.read(
      key: 'ess_password_${user.uid}',
    );

    if (username != null && password != null) {
      setState(() {
        _usernameController.text = username;
        _passwordController.text = password;
      });
    }
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // Inject credentials and fill form when page loads
            _injectCredentials();
          },
        ),
      )
      ..loadRequest(
        Uri.parse(
          'https://absencesub.frontlineeducation.com/request?dates=${_formatDates(widget.selectedDates)}',
        ),
      );
  }

  String _formatDates(List<DateTime> dates) {
    return dates.map((date) => 
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
    ).join(',');
  }

  Future<void> _injectCredentials() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      return;
    }

    // Inject JavaScript to fill ESS login form
    final script = '''
      (function() {
        const usernameField = document.querySelector('input[name="username"], input[type="text"][id*="user"], input[id*="username"]');
        const passwordField = document.querySelector('input[name="password"], input[type="password"][id*="pass"], input[id*="password"]');
        
        if (usernameField) {
          usernameField.value = '${_usernameController.text}';
          usernameField.dispatchEvent(new Event('input', { bubbles: true }));
        }
        
        if (passwordField) {
          passwordField.value = '${_passwordController.text}';
          passwordField.dispatchEvent(new Event('input', { bubbles: true }));
        }
      })();
    ''';

    await _controller.runJavaScript(script);
  }

  Future<void> _saveCredentials() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _secureStorage.write(
      key: 'ess_username_${user.uid}',
      value: _usernameController.text,
    );
    await _secureStorage.write(
      key: 'ess_password_${user.uid}',
      value: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Substitute'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_showOverlay) _buildOverlay(),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return Container(
      color: Colors.white.withOpacity(0.95),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Guide to Requesting a Substitute',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const Text(
                'Please follow these steps:',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              _buildStep('1', 'Fill in the substitute request form with the selected dates'),
              _buildStep('2', 'Review all information carefully'),
              _buildStep('3', 'Submit the request'),
              const SizedBox(height: 32),
              CheckboxListTile(
                title: const Text('I agree to the Terms of Service'),
                value: _termsAccepted,
                onChanged: (value) {
                  setState(() {
                    _termsAccepted = value ?? false;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (!_termsAccepted || _usernameController.text.isEmpty || _passwordController.text.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'ESS Username',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'ESS Password',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Your credentials will be saved securely on your device only.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: (_termsAccepted && 
                            _usernameController.text.isNotEmpty && 
                            _passwordController.text.isNotEmpty)
                    ? () async {
                        await _saveCredentials();
                        await _injectCredentials();
                        setState(() {
                          _showOverlay = false;
                        });
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('I Understand, Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
