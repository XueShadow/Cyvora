import 'package:appwrite/appwrite.dart';

class AppwriteFunctionService {
  AppwriteFunctionService(this._functions);

  final Functions _functions;

  Future<dynamic> execute({
    required String functionId,
    Map<String, dynamic>? data,
  }) =>
      _functions.createExecution(
        functionId: functionId,
        body: data == null ? null : data,
      );
}
