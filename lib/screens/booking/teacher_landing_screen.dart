import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';

import 'booking_web_screen.dart';

class TeacherLandingScreen extends StatefulWidget {
  final String shortname;

  const TeacherLandingScreen({super.key, required this.shortname});

  @override
  State<TeacherLandingScreen> createState() => _TeacherLandingScreenState();
}

enum TeacherAction { preferred, specificDay }

class _TeacherLandingScreenState extends State<TeacherLandingScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  bool _loading = true;
  String? _error;

  String? _firstName;
  String? _lastName;
  String? _phone;
  String? _email;
  String? _photoUrl;
  String? _bio;

  TeacherAction _action = TeacherAction.preferred;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  bool _termsAccepted = false;
  bool _downloadAppChecked = true;

  late final AnimationController _bounceController;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _bounce = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
    _startBounceLoop();
    _loadProfile();
  }

  void _startBounceLoop() {
    _bounceController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  String get _fullName {
    final fn = (_firstName ?? '').trim();
    final ln = (_lastName ?? '').trim();
    final combined = '$fn $ln'.trim();
    return combined.isEmpty ? 'Substitute Teacher' : combined;
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final callable = _functions.httpsCallable('getUserByShortname');
      final result = await callable.call({'shortname': widget.shortname});
      final data = Map<String, dynamic>.from(result.data as Map);

      setState(() {
        _firstName = data['firstName'] as String?;
        _lastName = data['lastName'] as String?;
        _phone = data['phone'] as String?;
        _email = data['email'] as String?;
        _photoUrl = data['photoUrl'] as String?;
        _bio = data['bio'] as String?;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unable to load profile.';
        _loading = false;
      });
    }
  }

  Future<void> _showTeacherTerms() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms & Conditions'),
        content: SingleChildScrollView(
          child: Text.rich(
            TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: const [
                TextSpan(
                  text: 'Sub67 quickly connects teachers to a sub quickly, utilizing existing systems and infrastructure.\n\n',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text:
                      'To proceed, you may enter third‑party credentials (such as Frontline/ESS) to sign in and submit actions on your behalf. '
                      'Credentials are intended to be stored locally on your device (not in the Sub67 database). '
                      'We may collect limited app usage data to improve user experience. '
                      'Automations may run scripts to fill specific fields on the third‑party site based on your selections.\n',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String>?> _promptFrontlineCredentials() async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Frontline / ESS Login'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              const Text(
                'Your credentials are intended to be stored locally on your device only.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(context, {
                'username': usernameController.text.trim(),
                'password': passwordController.text,
              });
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  bool get _canContinue {
    if (!_termsAccepted) return false;
    if (_action == TeacherAction.specificDay && _selectedDay == null) return false;
    return true;
  }

  Future<void> _next() async {
    final creds = await _promptFrontlineCredentials();
    if (!mounted || creds == null) return;

    // For now, we pass the date selection into the existing webview screen.
    final dates = <DateTime>[];
    if (_action == TeacherAction.specificDay && _selectedDay != null) {
      dates.add(_selectedDay!);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingWebScreen(
          shortname: widget.shortname,
          selectedDates: dates,
        ),
      ),
    );

    // If they asked to download the app, we can later deep-link to store.
    // For now this is just a preference toggle.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('sub67.com/${widget.shortname}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          // Copy URL
                          await Clipboard.setData(
                            ClipboardData(text: 'sub67.com/${widget.shortname}'),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Link copied')),
                            );
                          }
                        },
                        child: CircleAvatar(
                          radius: 56,
                          backgroundImage: (_photoUrl ?? '').isNotEmpty ? NetworkImage(_photoUrl!) : null,
                          child: (_photoUrl ?? '').isEmpty
                              ? Text(
                                  _fullName.isNotEmpty ? _fullName[0].toUpperCase() : 'S',
                                  style: const TextStyle(fontSize: 28),
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        _fullName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if ((_bio ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          _bio!.trim(),
                          style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _infoRow('Phone', _phone),
                    _infoRow('Email', _email),
                    _infoRow('Link', 'sub67.com/${widget.shortname}'),
                    const SizedBox(height: 16),
                    Text(
                      'Choose what you’d like to do:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: RadioListTile<TeacherAction>(
                        value: TeacherAction.preferred,
                        groupValue: _action,
                        onChanged: (v) => setState(() => _action = v!),
                        title: Text('Add $_fullName (${_phone ?? 'no phone'}) to preferred teaching list?*'),
                      ),
                    ),
                    Card(
                      child: RadioListTile<TeacherAction>(
                        value: TeacherAction.specificDay,
                        groupValue: _action,
                        onChanged: (v) => setState(() => _action = v!),
                        title: Text('Request $_fullName (${_phone ?? 'no phone'}) for a specific day?'),
                      ),
                    ),
                    if (_action == TeacherAction.specificDay) ...[
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: TableCalendar(
                            firstDay: DateTime.now().subtract(const Duration(days: 1)),
                            lastDay: DateTime.now().add(const Duration(days: 365)),
                            focusedDay: _focusedDay,
                            selectedDayPredicate: (day) => _selectedDay != null && isSameDay(_selectedDay, day),
                            onDaySelected: (selected, focused) {
                              setState(() {
                                _selectedDay = selected;
                                _focusedDay = focused;
                              });
                            },
                            onPageChanged: (focused) => _focusedDay = focused,
                            calendarStyle: const CalendarStyle(
                              isTodayHighlighted: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                ScaleTransition(
                                  scale: _termsAccepted
                                      ? const AlwaysStoppedAnimation(1.0)
                                      : Tween<double>(begin: 1.0, end: 1.05).animate(_bounce),
                                  child: Checkbox(
                                    value: _termsAccepted,
                                    onChanged: (v) {
                                      setState(() {
                                        _termsAccepted = v ?? false;
                                        if (_termsAccepted) {
                                          _bounceController.stop();
                                        }
                                      });
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _showTeacherTerms,
                                    child: const Text(
                                      'I Agree to the Terms and Conditions',
                                      style: TextStyle(decoration: TextDecoration.underline),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Checkbox(
                                  value: _downloadAppChecked,
                                  onChanged: (v) => setState(() => _downloadAppChecked = v ?? false),
                                ),
                                const Expanded(
                                  child: Text(
                                    'Download the app! For a smoother experience and to unlock other features download the app on your mobile device!',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _canContinue ? _next : null,
                        child: const Text('Next'),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _infoRow(String label, String? value) {
    final v = (value ?? '').trim();
    return ListTile(
      title: Text(label),
      subtitle: Text(v.isEmpty ? '—' : v),
      trailing: IconButton(
        icon: const Icon(Icons.copy),
        onPressed: v.isEmpty
            ? null
            : () async {
                await Clipboard.setData(ClipboardData(text: v));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$label copied')),
                  );
                }
              },
      ),
    );
  }
}

