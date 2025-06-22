import 'package:flutter/material.dart';

import '../services/firebase_service.dart';

class EditCategoryDialog extends StatefulWidget {
  final Map<String, dynamic> category;
  final VoidCallback onCategoryUpdated;

  const EditCategoryDialog({
    super.key,
    required this.category,
    required this.onCategoryUpdated,
  });

  @override
  State<EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends State<EditCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  final _firebaseService = FirebaseService();

  late String _selectedIcon;
  late Color _selectedColor;
  bool _isLoading = false;

  final List<String> _availableIcons = [
    'category',
    'info',
    'sports_soccer',
    'mosque',
    'movie',
    'computer',
    'psychology',
    'science',
    'library_books',
    'school',
    'business',
    'music_note',
    'palette',
    'restaurant',
    'travel_explore',
  ];

  final List<Color> _availableColors = [
    Colors.deepPurple,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.pink,
    Colors.teal,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
    Colors.brown,
    Colors.deepOrange,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.category['name'] ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.category['description'] ?? '',
    );
    _selectedIcon = widget.category['icon'] ?? 'category';
    _selectedColor = Color(widget.category['color'] ?? 0xFF9C27B0);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعديل الفئة'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // اسم الفئة
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الفئة *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال اسم الفئة';
                  }
                  if (value.trim().length < 2) {
                    return 'يجب أن يكون اسم الفئة على الأقل حرفين';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // وصف الفئة
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'وصف الفئة (اختياري)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // اختيار الأيقونة
              const Text(
                'اختر الأيقونة:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _availableIcons.map((iconName) {
                      final isSelected = _selectedIcon == iconName;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedIcon = iconName),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? _selectedColor.withOpacity(0.2)
                                    : Colors.grey.shade100,
                            border: Border.all(
                              color:
                                  isSelected
                                      ? _selectedColor
                                      : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getIconData(iconName),
                            color:
                                isSelected
                                    ? _selectedColor
                                    : Colors.grey.shade600,
                          ),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 16),

              // اختيار اللون
              const Text(
                'اختر اللون:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _availableColors.map((color) {
                      final isSelected = _selectedColor == color;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = color),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  isSelected
                                      ? Colors.black
                                      : Colors.grey.shade300,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 16),

              // معاينة الفئة
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _selectedColor.withOpacity(0.2),
                      child: Icon(
                        _getIconData(_selectedIcon),
                        color: _selectedColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameController.text.isEmpty
                                ? 'اسم الفئة'
                                : _nameController.text,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (_descriptionController.text.isNotEmpty)
                            Text(
                              _descriptionController.text,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateCategory,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child:
              _isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('تحديث'),
        ),
      ],
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'info':
        return Icons.info;
      case 'sports_soccer':
        return Icons.sports_soccer;
      case 'mosque':
        return Icons.mosque;
      case 'movie':
        return Icons.movie;
      case 'computer':
        return Icons.computer;
      case 'psychology':
        return Icons.psychology;
      case 'science':
        return Icons.science;
      case 'library_books':
        return Icons.library_books;
      case 'school':
        return Icons.school;
      case 'business':
        return Icons.business;
      case 'music_note':
        return Icons.music_note;
      case 'palette':
        return Icons.palette;
      case 'restaurant':
        return Icons.restaurant;
      case 'travel_explore':
        return Icons.travel_explore;
      case 'category':
        return Icons.category;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> _updateCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final success = await _firebaseService.updateCustomCategory(
        widget.category['id'],
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        icon: _selectedIcon,
        color: _selectedColor,
      );

      if (success) {
        widget.onCategoryUpdated();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم تحديث الفئة بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ فشل في تحديث الفئة'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ في تحديث الفئة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
