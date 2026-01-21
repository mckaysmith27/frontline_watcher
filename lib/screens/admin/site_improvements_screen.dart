import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../services/user_role_service.dart';

class _PickedImage {
  const _PickedImage({
    required this.file,
    this.bytes,
  });

  final XFile file;
  final Uint8List? bytes; // Used for web previews/uploads
}

class SiteImprovementsScreen extends StatefulWidget {
  const SiteImprovementsScreen({super.key});

  @override
  State<SiteImprovementsScreen> createState() => _SiteImprovementsScreenState();
}

class _SiteImprovementsScreenState extends State<SiteImprovementsScreen>
    with SingleTickerProviderStateMixin {
  static const _collection = 'site_improvements';
  static const int _maxImages = 6;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _roles = UserRoleService();
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  late final TabController _tabs;
  final TextEditingController _textController = TextEditingController();

  bool _loadingAccess = true;
  bool _isAppAdmin = false;
  bool _isFullAdmin = false;

  final List<_PickedImage> _pickedImages = <_PickedImage>[];

  final Set<String> _selectedIds = <String>{};
  bool _selectAll = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadAccess();
  }

  Future<void> _loadAccess() async {
    try {
      final roles = await _roles.getCurrentUserRoles();
      final isAdmin = roles.contains('app admin');
      final isFull = await _roles.isFullAppAdmin();
      if (!mounted) return;
      setState(() {
        _isAppAdmin = isAdmin;
        _isFullAdmin = isFull;
        _loadingAccess = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAppAdmin = false;
        _isFullAdmin = false;
        _loadingAccess = false;
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _textController.dispose();
    super.dispose();
  }

  String _formatTs(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate().toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  List<String> _imageUrlsFromDoc(Map<String, dynamic> data) {
    final raw = data['imageUrls'];
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
  }

  Future<void> _pickFromGallery() async {
    try {
      final remaining = _maxImages - _pickedImages.length;
      if (remaining <= 0) return;

      final picked = await _picker.pickMultiImage();
      if (picked.isEmpty) return;

      final toTake = picked.take(remaining).toList();
      final newOnes = <_PickedImage>[];
      for (final f in toTake) {
        if (kIsWeb) {
          newOnes.add(_PickedImage(file: f, bytes: await f.readAsBytes()));
        } else {
          newOnes.add(_PickedImage(file: f));
        }
      }
      if (!mounted) return;
      setState(() => _pickedImages.addAll(newOnes));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick images: $e')),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final remaining = _maxImages - _pickedImages.length;
      if (remaining <= 0) return;

      final picked = await _picker.pickImage(source: ImageSource.camera);
      if (picked == null) return;

      final img = kIsWeb
          ? _PickedImage(file: picked, bytes: await picked.readAsBytes())
          : _PickedImage(file: picked);
      if (!mounted) return;
      setState(() => _pickedImages.add(img));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to take photo: $e')),
      );
    }
  }

  Future<void> _showImageViewer({
    required Widget child,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 600,
          height: 600,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _pickedImagesStrip() {
    if (_pickedImages.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(_pickedImages.length, (i) {
        final img = _pickedImages[i];
        final thumb = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 70,
            height: 70,
            child: kIsWeb
                ? Image.memory(img.bytes!, fit: BoxFit.cover)
                : Image.file(File(img.file.path), fit: BoxFit.cover),
          ),
        );

        return Stack(
          children: [
            InkWell(
              onTap: () => _showImageViewer(
                child: kIsWeb
                    ? Image.memory(img.bytes!, fit: BoxFit.contain)
                    : Image.file(File(img.file.path), fit: BoxFit.contain),
              ),
              child: thumb,
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                onPressed: _submitting
                    ? null
                    : () {
                        setState(() => _pickedImages.removeAt(i));
                      },
                icon: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _imageUrlsStrip(List<String> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: urls.map((url) {
        return InkWell(
          onTap: () => _showImageViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 70,
              height: 70,
              child: Image.network(url, fit: BoxFit.cover),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _guessContentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<String?> _uploadPickedImage({
    required String requestId,
    required _PickedImage img,
  }) async {
    final fileName = img.file.name.trim().isNotEmpty ? img.file.name : '${_uuid.v4()}.jpg';
    final key = _uuid.v4();
    final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
    final ref = _storage.ref().child('site_improvements/$requestId/$key.$ext');

    final meta = SettableMetadata(
      contentType: _guessContentType(fileName),
    );

    UploadTask task;
    if (kIsWeb) {
      final bytes = img.bytes ?? await img.file.readAsBytes();
      task = ref.putData(bytes, meta);
    } else {
      task = ref.putFile(File(img.file.path), meta);
    }

    final snap = await task;
    return await snap.ref.getDownloadURL();
  }

  Future<void> _submit() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final text = _textController.text.trim();
    if (text.isEmpty) return;
    if (text.length > 5000) return;

    setState(() => _submitting = true);
    try {
      final docRef = _firestore.collection(_collection).doc();

      final imageUrls = <String>[];
      for (final img in _pickedImages) {
        try {
          final url = await _uploadPickedImage(requestId: docRef.id, img: img);
          if (url != null && url.trim().isNotEmpty) imageUrls.add(url.trim());
        } catch (e) {
          // Keep going; we still want the text suggestion saved.
          print('[SiteImprovements] image upload failed: $e');
        }
      }

      final hadPickedImages = _pickedImages.isNotEmpty;

      await docRef.set({
        'text': text,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
        'createdByEmail': user.email ?? '',
        if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
      });
      _textController.clear();
      _pickedImages.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              imageUrls.isEmpty
                  ? (hadPickedImages ? 'Submitted. (Images failed to upload.)' : 'Submitted.')
                  : 'Submitted with ${imageUrls.length} image(s).',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Query<Map<String, dynamic>> _openQuery() {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true);
  }

  Query<Map<String, dynamic>> _archivedQuery() {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'archived')
        .orderBy('archivedAt', descending: true);
  }

  Query<Map<String, dynamic>> _myOpenQuery(String uid) {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'open')
        .where('createdBy', isEqualTo: uid)
        .orderBy('createdAt', descending: true);
  }

  String _buildCopyText(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final chunks = <String>[];
    for (final d in docs) {
      final data = d.data();
      final text = (data['text'] is String) ? (data['text'] as String).trim() : '';
      if (text.isEmpty) continue;
      final createdAt = data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : null;
      final by = (data['createdByEmail'] is String && (data['createdByEmail'] as String).trim().isNotEmpty)
          ? (data['createdByEmail'] as String).trim()
          : (data['createdBy'] is String ? (data['createdBy'] as String) : '');
      final header = [
        if (_formatTs(createdAt).isNotEmpty) _formatTs(createdAt),
        if (by.isNotEmpty) by,
        d.id,
      ].join(' • ');
      final imageUrls = _imageUrlsFromDoc(data);
      final imagesBlock = imageUrls.isEmpty ? '' : '\n\nImages:\n${imageUrls.map((u) => '- $u').join('\n')}';
      chunks.add('$header\n$text$imagesBlock');
    }
    return chunks.join('\n\n---\n\n');
  }

  Future<void> _copySelectedAndMaybeArchive(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> openDocs,
  ) async {
    if (!_isFullAdmin) return;
    if (_selectedIds.isEmpty) return;

    final selectedDocs = openDocs.where((d) => _selectedIds.contains(d.id)).toList();
    if (selectedDocs.isEmpty) return;

    final combined = _buildCopyText(selectedDocs);
    if (combined.trim().isEmpty) return;

    await Clipboard.setData(ClipboardData(text: combined));

    if (!mounted) return;
    final archive = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copied'),
        content: Text(
          'Copied ${selectedDocs.length} request(s) to clipboard.\n\n'
          'Add the copied request(s) to the archive?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (archive == true) {
      final uid = _auth.currentUser?.uid ?? '';
      final batch = _firestore.batch();
      for (final d in selectedDocs) {
        batch.update(d.reference, {
          'status': 'archived',
          'archivedAt': FieldValue.serverTimestamp(),
          'archivedBy': uid,
        });
      }
      await batch.commit();
    }

    if (!mounted) return;
    setState(() {
      _selectedIds.clear();
      _selectAll = false;
    });
  }

  Widget _headerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          'Submit website improvements in a command form:\n\n'
          'Ex1: Bug on the site every time ____ is clicked on the Y page. The error says _____.\n\n'
          'Ex2: The app needs to have a feature that does ______ specifically only for if a user is ______. '
          'Come up with a way to do _______ though that wouldn’t also do ________ because the goal of this feature would be to ______.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  Widget _submitTab() {
    final uid = _auth.currentUser?.uid;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _headerCard(),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _textController,
                  maxLength: 5000,
                  maxLines: 10,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    hintText: 'Site improvements… (plain text, up to 5000 characters)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Images (optional) — up to $_maxImages',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _submitting ? null : _pickFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Add'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _submitting ? null : _takePhoto,
                      tooltip: 'Take photo',
                      icon: const Icon(Icons.photo_camera_outlined),
                    ),
                  ],
                ),
                _pickedImagesStrip(),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (!_isAppAdmin || _submitting || _textController.text.trim().isEmpty)
                        ? null
                        : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Your open submissions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (uid == null)
          const Text('Please sign in.')
        else
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _myOpenQuery(uid).snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Text('No open requests yet.');
              }
              return Column(
                children: docs.map((d) {
                  final data = d.data();
                  final text = (data['text'] is String) ? data['text'] as String : '';
                  final createdAt = data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : null;
                  final imageUrls = _imageUrlsFromDoc(data);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatTs(createdAt),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(text),
                          if (imageUrls.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _imageUrlsStrip(imageUrls),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _reviewTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _openQuery().snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final openDocs = snap.data?.docs ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Open requests',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_isFullAdmin)
                  TextButton.icon(
                    onPressed: openDocs.isEmpty
                        ? null
                        : () {
                            setState(() {
                              _selectAll = !_selectAll;
                              _selectedIds
                                ..clear()
                                ..addAll(_selectAll ? openDocs.map((d) => d.id) : const Iterable.empty());
                            });
                          },
                    icon: const Icon(Icons.select_all),
                    label: Text(_selectAll ? 'Clear all' : 'Select all'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!_isFullAdmin)
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Only full app admins can select and copy requests.',
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (openDocs.isEmpty)
              const Text('No open requests.')
            else
              ...openDocs.map((d) {
                final data = d.data();
                final text = (data['text'] is String) ? data['text'] as String : '';
                final createdAt = data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : null;
                final by = (data['createdByEmail'] is String) ? data['createdByEmail'] as String : '';
                final imageUrls = _imageUrlsFromDoc(data);
                final checked = _selectedIds.contains(d.id);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (_isFullAdmin)
                              Checkbox(
                                value: checked,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selectedIds.add(d.id);
                                    } else {
                                      _selectedIds.remove(d.id);
                                      _selectAll = false;
                                    }
                                  });
                                },
                              ),
                            Expanded(
                              child: Text(
                                [
                                  _formatTs(createdAt),
                                  if (by.trim().isNotEmpty) by.trim(),
                                ].where((s) => s.trim().isNotEmpty).join(' • '),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SelectableText(text),
                        if (imageUrls.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _imageUrlsStrip(imageUrls),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (!_isFullAdmin || _selectedIds.isEmpty)
                    ? null
                    : () => _copySelectedAndMaybeArchive(openDocs),
                icon: const Icon(Icons.copy),
                label: Text(_selectedIds.isEmpty ? 'Copy selected' : 'Copy selected (${_selectedIds.length})'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _archiveTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _archivedQuery().snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No archived requests yet.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: docs.map((d) {
            final data = d.data();
            final text = (data['text'] is String) ? data['text'] as String : '';
            final archivedAt = data['archivedAt'] is Timestamp ? data['archivedAt'] as Timestamp : null;
            final by = (data['archivedBy'] is String) ? data['archivedBy'] as String : '';
            final imageUrls = _imageUrlsFromDoc(data);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        if (_formatTs(archivedAt).isNotEmpty) 'Archived ${_formatTs(archivedAt)}',
                        if (by.trim().isNotEmpty) by.trim(),
                      ].join(' • '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(text),
                    if (imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _imageUrlsStrip(imageUrls),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isAppAdmin) {
      return const Scaffold(
        body: Center(child: Text('Admin access required.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Site improvements'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Submit'),
            Tab(text: 'Review'),
            Tab(text: 'Archive'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _submitTab(),
          _reviewTab(),
          _archiveTab(),
        ],
      ),
    );
  }
}

