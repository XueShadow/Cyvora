import 'package:image_picker/image_picker.dart';

import '../../features/profile/models/profile_photo.dart';

class ImagePickerProfilePhotoDataSource {
  ImagePickerProfilePhotoDataSource({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<ProfilePhoto?> pickProfilePhoto() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image == null) return null;

    final contentType =
        image.mimeType ??
        switch (image.name.split('.').last.toLowerCase()) {
          'jpg' || 'jpeg' => 'image/jpeg',
          'png' => 'image/png',
          'webp' => 'image/webp',
          _ => null,
        };
    if (contentType == null ||
        !const {
          'image/jpeg',
          'image/png',
          'image/webp',
        }.contains(contentType)) {
      throw const ProfilePhotoException('Choose a JPEG, PNG, or WebP photo.');
    }

    final bytes = await image.readAsBytes();
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const ProfilePhotoException('Choose a photo smaller than 5 MB.');
    }
    return ProfilePhoto(bytes: bytes, contentType: contentType);
  }
}
