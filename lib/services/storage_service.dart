import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  StorageService(this.client, {required this.bucketName});

  final SupabaseClient client;
  final String bucketName;

  Future<void> uploadSelectedFile({
    required String userId,
    required PlatformFile selectedFile,
  }) async {
    final bytes = selectedFile.bytes;
    if (bytes == null) {
      throw StateError('The selected file has no bytes.');
    }

    final sanitizedFileName = selectedFile.name.replaceAll(' ', '_');
    final filePath =
        '$userId/${DateTime.now().millisecondsSinceEpoch}_$sanitizedFileName';

    await client.storage
        .from(bucketName)
        .uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeFromName(sanitizedFileName),
          ),
        );
  }

  Future<List<FileObject>> listUserFiles(String userId) async {
    final files = await client.storage.from(bucketName).list(path: userId);
    files.sort((a, b) {
      final aCreated = a.createdAt ?? '';
      final bCreated = b.createdAt ?? '';
      return bCreated.compareTo(aCreated);
    });
    return files;
  }

  Future<String> createSignedUrl(String userId, String fileName) {
    return client.storage
        .from(bucketName)
        .createSignedUrl('$userId/$fileName', 600);
  }

  Future<void> uploadSelectedFileToFolder({
    required String folder,
    required PlatformFile selectedFile,
  }) async {
    final bytes = selectedFile.bytes;
    if (bytes == null) {
      throw StateError('The selected file has no bytes.');
    }

    final sanitizedFolder = folder.trim().replaceAll(' ', '_');
    if (sanitizedFolder.isEmpty) {
      throw StateError('Folder cannot be empty.');
    }

    final sanitizedFileName = selectedFile.name.replaceAll(' ', '_');
    final filePath =
        '$sanitizedFolder/${DateTime.now().millisecondsSinceEpoch}_$sanitizedFileName';

    await client.storage
        .from(bucketName)
        .uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeFromName(sanitizedFileName),
          ),
        );
  }

  Future<List<FileObject>> listFolderFiles(String folder) async {
    final sanitizedFolder = folder.trim().replaceAll(' ', '_');
    final files = await client.storage
        .from(bucketName)
        .list(path: sanitizedFolder);
    files.sort((a, b) {
      final aCreated = a.createdAt ?? '';
      final bCreated = b.createdAt ?? '';
      return bCreated.compareTo(aCreated);
    });
    return files;
  }

  Future<String> createSignedUrlForPath(String path) {
    return client.storage.from(bucketName).createSignedUrl(path, 600);
  }

  bool isImage(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  String _contentTypeFromName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }
    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }
    return 'application/octet-stream';
  }
}
