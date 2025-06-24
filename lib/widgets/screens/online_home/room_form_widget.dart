import 'package:flutter/material.dart';

class RoomFormWidget extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController roomCodeController;
  final bool isLoading;
  final bool isCreatingRoom;
  final VoidCallback onCreateRoom;
  final VoidCallback onJoinRoom;
  final VoidCallback? onToggleMode;
  final VoidCallback? onShowAvailableRooms;
  final bool showAvailableRooms;
  final bool isLoadingRooms;
  final bool isLoggedIn;
  final bool isNameReadOnly;

  const RoomFormWidget({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.roomCodeController,
    required this.isLoading,
    required this.isCreatingRoom,
    required this.onCreateRoom,
    required this.onJoinRoom,
    this.onToggleMode,
    this.onShowAvailableRooms,
    this.showAvailableRooms = false,
    this.isLoadingRooms = false,
    this.isLoggedIn = false,
    this.isNameReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.1),
            spreadRadius: 3,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // أيقونة الألعاب الأونلاين
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                Icons.games,
                size: 48,
                color: Colors.deepPurple.shade600,
              ),
            ),
            const SizedBox(height: 24),

            // عنوان النموذج
            Text(
              'ألعاب متعددة اللاعبين',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'العب مع أصدقائك أونلاين',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // أزرار تبديل الوضع
            Container(
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap:
                          onToggleMode != null && !isCreatingRoom
                              ? onToggleMode
                              : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color:
                              isCreatingRoom
                                  ? Colors.deepPurple.shade600
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'إنشاء غرفة',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                isCreatingRoom
                                    ? Colors.white
                                    : Colors.deepPurple.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap:
                          onToggleMode != null && isCreatingRoom
                              ? onToggleMode
                              : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color:
                              !isCreatingRoom
                                  ? Colors.deepPurple.shade600
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'انضمام لغرفة',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                !isCreatingRoom
                                    ? Colors.white
                                    : Colors.deepPurple.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // حقل اسم اللاعب
            TextFormField(
              controller: nameController,
              readOnly: isNameReadOnly,
              decoration: InputDecoration(
                labelText: 'اسم اللاعب',
                hintText: isLoggedIn ? 'اسم المستخدم المسجل' : 'أدخل اسمك',
                prefixIcon: Icon(
                  Icons.person,
                  color: Colors.deepPurple.shade600,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.deepPurple.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color:
                        isNameReadOnly
                            ? Colors.grey.shade400
                            : Colors.deepPurple.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color:
                        isNameReadOnly
                            ? Colors.grey.shade400
                            : Colors.deepPurple.shade600,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor:
                    isNameReadOnly
                        ? Colors.grey.shade100
                        : Colors.deepPurple.shade50,
              ),
              style: TextStyle(
                color: isNameReadOnly ? Colors.grey.shade700 : Colors.black,
                fontWeight:
                    isNameReadOnly ? FontWeight.w600 : FontWeight.normal,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال اسم اللاعب';
                }
                if (value.trim().length < 2) {
                  return 'اسم اللاعب يجب أن يكون حرفين على الأقل';
                }
                if (value.trim().length > 20) {
                  return 'اسم اللاعب لا يمكن أن يزيد عن 20 حرف';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // حقل كود الغرفة (فقط للانضمام)
            Visibility(
              visible: !isCreatingRoom,
              child: Column(
                children: [
                  TextFormField(
                    controller: roomCodeController,
                    decoration: InputDecoration(
                      labelText: 'كود الغرفة',
                      hintText: 'أدخل كود الغرفة',
                      prefixIcon: Icon(
                        Icons.vpn_key,
                        color: Colors.deepPurple.shade600,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: Colors.deepPurple.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: Colors.deepPurple.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: Colors.deepPurple.shade600,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.deepPurple.shade50,
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (!isCreatingRoom &&
                          (value == null || value.trim().isEmpty)) {
                        return 'يرجى إدخال كود الغرفة';
                      }
                      if (!isCreatingRoom && value!.trim().length != 6) {
                        return 'كود الغرفة يجب أن يكون 6 أحرف';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // أزرار العمل
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed:
                    isLoading
                        ? null
                        : (isCreatingRoom ? onCreateRoom : onJoinRoom),
                icon:
                    isLoading
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : Icon(
                          isCreatingRoom
                              ? Icons.add_circle_outline
                              : Icons.login,
                        ),
                label: Text(
                  isLoading
                      ? (isCreatingRoom
                          ? 'جاري الإنشاء...'
                          : 'جاري الانضمام...')
                      : (isCreatingRoom ? 'إنشاء غرفة جديدة' : 'انضمام للغرفة'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isCreatingRoom
                          ? Colors.deepPurple.shade600
                          : Colors.green.shade600,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shadowColor: (isCreatingRoom
                          ? Colors.deepPurple
                          : Colors.green)
                      .withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),

            // زر عرض الغرف المتاحة
            if (onShowAvailableRooms != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: isLoadingRooms ? null : onShowAvailableRooms,
                  icon:
                      isLoadingRooms
                          ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Icon(
                            showAvailableRooms
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                  label: Text(
                    showAvailableRooms
                        ? 'إخفاء الغرف المتاحة'
                        : 'عرض الغرف المتاحة',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shadowColor: Colors.orange.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
