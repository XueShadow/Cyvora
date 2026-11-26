import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';

class AppwriteStorageService {
  AppwriteStorageService(this._storage);

  final Storage _storage;

  Future<Uint8List> download({
    required String bucketId,
    required String fileId,
  }) async {
    final result = await _storage.getFileDownload(
      bucketId: bucketId,
      fileId: fileId,
    );
    return result;
  }

  Future<void> deleteFile({
    required String bucketId,
    required String fileId,
  }) =>
      _storage.deleteFile(bucketId: bucketId, fileId: fileId);
}
