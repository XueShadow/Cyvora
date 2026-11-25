import 'dart:typed_data';

class ProfilePhoto {
  const ProfilePhoto({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

abstract interface class ProfilePhotoPickerRepository {
  Future<ProfilePhoto?> pickProfilePhoto();
}

class ProfilePhotoException implements Exception {
  const ProfilePhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}
