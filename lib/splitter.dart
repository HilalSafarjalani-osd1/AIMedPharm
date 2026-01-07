import 'dart:io';

void main() async {
  // 1. حدد مكان الملف الأصلي
  final originalFile = File('assets/models/model.bin');
  
  if (!originalFile.existsSync()) {
    print('❌ Error: File not found at assets/models/model.bin');
    return;
  }

  print('🔪 Splitting model.bin (Size: ${originalFile.lengthSync()} bytes)...');

  // 2. اقرأ الملف واقسمه
  final bytes = await originalFile.readAsBytes();
  // نقسمه إلى جزأين (حوالي 700 ميجا لكل جزء لتكون آمنة)
  final partSize = (bytes.length / 2).ceil(); 

  // كتابة الجزء الأول
  final file1 = File('assets/models/model_part1.bin');
  await file1.writeAsBytes(bytes.sublist(0, partSize));
  print('✅ Created: model_part1.bin');

  // كتابة الجزء الثاني
  final file2 = File('assets/models/model_part2.bin');
  await file2.writeAsBytes(bytes.sublist(partSize));
  print('✅ Created: model_part2.bin');

  print('🎉 Done! You can now delete the original model.bin from assets folder.');
}