import 'package:appwrite/appwrite.dart';

class AppwriteRealtimeService {
  AppwriteRealtimeService(this._realtime);

  final Realtime _realtime;

  RealtimeSubscription subscribe(
    String databaseId,
    String tableId,
  ) =>
      _realtime.subscribe([
        'tablesdb.$databaseId.tables.$tableId.rows',
      ]);

  Future<void> disconnect() => _realtime.disconnect();
}
