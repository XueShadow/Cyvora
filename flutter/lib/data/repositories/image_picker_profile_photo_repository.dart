import '../../features/profile/models/profile_photo.dart';
import '../datasources/image_picker_profile_photo_data_source.dart';

class ImagePickerProfilePhotoRepository
    implements ProfilePhotoPickerRepository {
  const ImagePickerProfilePhotoRepository(this._dataSource);

  final ImagePickerProfilePhotoDataSource _dataSource;

  @override
  Future<ProfilePhoto?> pickProfilePhoto() => _dataSource.pickProfilePhoto();
}
