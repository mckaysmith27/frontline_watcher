import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/social_service.dart';
import '../../services/user_role_service.dart';

class PostComposer extends StatefulWidget {
  final String? initialTag;
  
  const PostComposer({super.key, this.initialTag});

  @override
  State<PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends State<PostComposer> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _imageUrls = [];
  final ImagePicker _picker = ImagePicker();
  bool _isPosting = false;
  String? _selectedCategoryTag; // happy, funny, random-thought, heart-warming, sad
  
  // Category tags with emojis
  static const Map<String, String> categoryTags = {
    'happy': '😊',
    'funny': '😂',
    'random-thought': '🤔',
    'heart-warming': '😄',
    'sad': '😢',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialTag != null) {
      _selectedCategoryTag = widget.initialTag;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // Check if user has access to community feature
    final roleService = UserRoleService();
    final hasCommunityAccess = await roleService.hasFeatureAccess('community');
    
    if (!hasCommunityAccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This feature is not available for your role.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      // In production, upload to Firebase Storage
      setState(() {
        _imageUrls.add(image.path); // Temporary - would be URL after upload
      });
    }
  }

  Future<void> _post() async {
    if (_controller.text.trim().isEmpty && _imageUrls.isEmpty) return;

    setState(() => _isPosting = true);

    try {
      final socialService = SocialService();
      await socialService.createPost(
        content: _controller.text.trim(),
        imageUrls: _imageUrls,
        categoryTag: _selectedCategoryTag,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
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
                      'Create Post',
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
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show selected tag if one is selected
                      if (_selectedCategoryTag != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${categoryTags[_selectedCategoryTag]} ${_selectedCategoryTag!.replaceAll('-', ' ')}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCategoryTag = null;
                                  });
                                },
                                child: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      TextField(
                        controller: _controller,
                        maxLines: null,
                        decoration: const InputDecoration(
                          hintText: 'What\'s on your mind?',
                          border: InputBorder.none,
                        ),
                      ),
                      if (_imageUrls.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          children: _imageUrls.map((url) {
                            // Check if it's a local file path or a network URL
                            final isLocalFile = !url.startsWith('http://') && 
                                               !url.startsWith('https://');
                            
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: isLocalFile
                                      ? Image.file(
                                          File(url),
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: 100,
                                              height: 100,
                                              color: Colors.grey[300],
                                              child: const Icon(Icons.error),
                                            );
                                          },
                                        )
                                      : Image.network(
                                          url,
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: 100,
                                              height: 100,
                                              color: Colors.grey[300],
                                              child: const Icon(Icons.error),
                                            );
                                          },
                                        ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _imageUrls.remove(url);
                                      });
                                    },
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Divider(),
              // Category tag selection buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // ALL button
                      _buildCategoryButton('ALL', null, isSelected: _selectedCategoryTag == null),
                      const SizedBox(width: 8),
                      // Category buttons
                      ...categoryTags.entries.map((entry) {
                        final tag = entry.key;
                        final emoji = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildCategoryButton(
                            '$emoji ${tag.replaceAll('-', ' ')}',
                            tag,
                            isSelected: _selectedCategoryTag == tag,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image),
                      onPressed: _pickImage,
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _isPosting ? null : _post,
                      child: _isPosting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Post'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryButton(String label, String? tag, {required bool isSelected}) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCategoryTag = selected ? tag : null;
        });
      },
    );
  }
}


