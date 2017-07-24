import 'dart:async' show Future;
import 'package:meta/meta.dart';
import 'package:postgresql/postgresql.dart' show Row;
import 'package:postgresql/pool.dart' show Pool;
import '../entity/application.dart';
import '../entity/user.dart';

Application _assembleApplication(Row row) => new Application(id: row.id, name: row.name);

class ApplicationNotFoundException implements Exception {
  final User owner;
  final String name;

  String toString() => 'An application (owner: "${owner.name}", name: "$name") is not found.';

  ApplicationNotFoundException({@required this.owner, @required this.name});
}

class ApplicationRepository {
  final Pool _postgresConnectionPool;

  Future<Application> getApplication({@required String name, @required User owner}) async {
    final connection = await _postgresConnectionPool.connect();
    final rows = await connection.query('select id, name, owner_id, created_at from applications where name = @name and owner_id = @userId limit 1;').toList();

    connection.close();

    if (rows.length != 1) {
      throw new ApplicationNotFoundException(owner: owner, name: name);
    }

    return _assembleApplication(rows[0]);
  }

  Future<Application> createApplication({@required String name, @required User owner}) async {
    final connection = await _postgresConnectionPool.connect();
    final row = await connection.query('insert into applications (name, owner_id, created_at) values (@name, @userId, @now) returning id, name, owner_id, created_at;', {
      'name': name,
      'userId': owner.id,
      'now': new DateTime.now(),
    }).single;

    connection.close();

    return _assembleApplication(row);
  }
  
  ApplicationRepository({@required postgresConnectionPool}):
    _postgresConnectionPool = postgresConnectionPool;
}
