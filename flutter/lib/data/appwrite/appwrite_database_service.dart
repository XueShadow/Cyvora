import 'package:appwrite/appwrite.dart';

import '../../core/constants/appwrite_config.dart';

class AppwriteDatabaseService {
  AppwriteDatabaseService(this._tablesDb);

  final TablesDB _tablesDb;

  Future<Map<String, dynamic>> listRows({
    required String tableId,
    List<String>? queries,
  }) async {
    if (appwriteDatabaseId.isEmpty) {
      throw StateError('APPWRITE_DATABASE_ID is not configured.');
    }
    final result = await _tablesDb.listRows(
      databaseId: appwriteDatabaseId,
      tableId: tableId,
      queries: queries,
    );
    return {'rows': result.rows, 'total': result.total};
  }

  Future<Map<String, dynamic>> getRow({
    required String tableId,
    required String rowId,
  }) async {
    if (appwriteDatabaseId.isEmpty) {
      throw StateError('APPWRITE_DATABASE_ID is not configured.');
    }
    final row = await _tablesDb.getRow(
      databaseId: appwriteDatabaseId,
      tableId: tableId,
      rowId: rowId,
    );
    return row.data;
  }
}
