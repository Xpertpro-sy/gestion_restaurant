import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ProductImageStorage {
  static Future<Directory> _imagesDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(dir.path, 'product_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  static Future<String> saveForProduct(int productId, File source) async {
    final imagesDir = await _imagesDir();
    final ext = p.extension(source.path).isEmpty ? '.jpg' : p.extension(source.path);
    final filename = 'product_$productId$ext';
    final dest = File(p.join(imagesDir.path, filename));
    if (await dest.exists()) await dest.delete();
    await source.copy(dest.path);
    return filename;
  }

  static Future<File?> fileFor(String filename) async {
    if (filename.isEmpty) return null;
    final file = File(p.join((await _imagesDir()).path, filename));
    if (await file.exists()) return file;
    return null;
  }

  static String? contentTypeFor(String filename) {
    final ext = p.extension(filename).toLowerCase();
    return switch (ext) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.gif' => 'image/gif',
      _ => null,
    };
  }
}
