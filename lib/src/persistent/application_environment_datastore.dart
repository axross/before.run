import 'dart:async' show Future;
import 'package:meta/meta.dart';
import 'package:postgresql/postgresql.dart' show PostgresqlException;
import 'package:postgresql/pool.dart' show Pool;
import '../entity/application.dart';
import '../entity/application_environment.dart';
import '../entity/user.dart';
import './src/deserialize.dart';
import './src/resource_exception.dart';

class ApplicationEnvironmentDatastore {
  final Pool _postgresConnectionPool;

  Future<List<ApplicationEnvironment>> getAllEnvironments({@required Application application}) async {
    final connection = await _postgresConnectionPool.connect();

    try {
      final rows = await connection.query('select application_environments.id as id, application_id, application_environments.name as name, application_environments.created_at as created_at from application_environments inner join applications on applications.id = application_environments.application_id where application_environments.application_id = @applicationId;', {
        'applicationId': application.id,
      }).toList();

      return rows.map((row) => deserializeToApplicationEnvironment(row)).toList();
    } finally {
      connection.close();
    }
  }

  Future<ApplicationEnvironment> getEnvironment({@required int id, @required Application application, @required User requester}) async {
    final connection = await _postgresConnectionPool.connect();

    try {
      final rows = await connection.query('select application_environments.id as id, application_id, application_environments.name as name, application_environments.created_at as created_at from application_environments inner join applications on applications.id = application_environments.application_id where application_environments.id = @id and application_environments.application_id = @applicationId limit 1;', {
        'id': id,
        'applicationId': application.id,
      }).toList();

      if (rows.isEmpty) {
        throw new ApplicationEnvironmentNotFoundException(applicationId: application.id, id: id);
      }

      return deserializeToApplicationEnvironment(rows.first);
    } finally {
      connection.close();
    }
  }

  Future<ApplicationEnvironment> createEnvironment({@required String name, @required Application application, @required User requester}) async {
    final connection = await _postgresConnectionPool.connect();

    try {
      final row = await connection.query('insert into application_environments (application_id, name, created_at) values (@applicationId, @name, @now) returning id, application_id, name, created_at;', {
        'applicationId': application.id,
        'name': name,
        'now': new DateTime.now(),
      }).single;

      return deserializeToApplicationEnvironment(row);
    } on PostgresqlException catch (err) {
      if (err.toString().contains('duplicate key value violates unique constraint')) {
        throw new ApplicationEnvironmentConflictException(applicationId: application.id, name: name);
      }

      rethrow;
    } finally {
      connection.close();
    }
  }
  
  ApplicationEnvironmentDatastore({@required Pool postgresConnectionPool}):
    _postgresConnectionPool = postgresConnectionPool;
}
