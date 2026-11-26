import 'package:appwrite/appwrite.dart';

import '../../core/constants/appwrite_config.dart';

class AppwriteInitializer {
  const AppwriteInitializer._();

  static Client? initialize() {
    if (appwriteEndpoint.isEmpty || appwriteProjectId.isEmpty) {
      return null;
    }

    return Client()
      ..setEndpoint(appwriteEndpoint)
      ..setProject(appwriteProjectId);
  }
}

class AppwriteClientProvider {
  const AppwriteClientProvider(this.client);

  final Client client;

  Account get account => Account(client);
  TablesDB get tablesDb => TablesDB(client);
  Storage get storage => Storage(client);
  Functions get functions => Functions(client);
  Realtime get realtime => Realtime(client);
}
