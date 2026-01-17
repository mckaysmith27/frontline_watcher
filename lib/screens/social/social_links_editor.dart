import 'package:flutter/material.dart';
import '../../services/social_service.dart';
import '../../models/social_link.dart';

class SocialLinksEditor extends StatefulWidget {
  final String userId;

  const SocialLinksEditor({super.key, required this.userId});

  @override
  State<SocialLinksEditor> createState() => _SocialLinksEditorState();
}

class _SocialLinksEditorState extends State<SocialLinksEditor> {
  final SocialService _socialService = SocialService();
  List<SocialLink> _links = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    setState(() => _isLoading = true);
    final links = await _socialService.getSocialLinks(widget.userId);
    setState(() {
      _links = links;
      _isLoading = false;
    });
  }

  Future<void> _saveLinks() async {
    await _socialService.saveSocialLinks(widget.userId, _links);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Links saved!')),
      );
    }
  }

  void _addLink() {
    setState(() {
      _links.add(SocialLink(platform: 'Facebook', url: ''));
    });
  }

  void _removeLink(int index) {
    setState(() {
      _links.removeAt(index);
    });
  }

  void _updateLink(int index, String platform, String url) {
    setState(() {
      _links[index] = SocialLink(platform: platform, url: url);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Social Links',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...List.generate(_links.length, (index) {
                              return _buildLinkEditor(index);
                            }),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _addLink,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Link'),
                            ),
                          ],
                        ),
                      ),
              ),
              Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _saveLinks,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text('Save Links'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLinkEditor(int index) {
    final link = _links[index];
    final urlController = TextEditingController(text: link.url);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: link.platform,
                  decoration: const InputDecoration(
                    labelText: 'Platform',
                    border: OutlineInputBorder(),
                  ),
                  items: SocialLink.platformTemplates.keys.map((platform) {
                    return DropdownMenuItem(
                      value: platform,
                      child: Text(platform),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      final template = SocialLink.platformTemplates[value] ?? '';
                      _updateLink(index, value, template);
                      urlController.text = template;
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeLink(index),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: urlController,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'https://...',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              _updateLink(index, link.platform, value);
            },
          ),
        ],
      ),
    );
  }
}

