// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $AuthorsTable extends Authors with TableInfo<$AuthorsTable, Author> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuthorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _accountNameMeta = const VerificationMeta(
    'accountName',
  );
  @override
  late final GeneratedColumn<String> accountName = GeneratedColumn<String>(
    'account_name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 256,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 0,
      maxTextLength: 1000,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<int> role = GeneratedColumn<int>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isActivatedMeta = const VerificationMeta(
    'isActivated',
  );
  @override
  late final GeneratedColumn<bool> isActivated = GeneratedColumn<bool>(
    'is_activated',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_activated" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountName,
    description,
    role,
    isActivated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'authors';
  @override
  VerificationContext validateIntegrity(
    Insertable<Author> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_name')) {
      context.handle(
        _accountNameMeta,
        accountName.isAcceptableOrUnknown(
          data['account_name']!,
          _accountNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_accountNameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('is_activated')) {
      context.handle(
        _isActivatedMeta,
        isActivated.isAcceptableOrUnknown(
          data['is_activated']!,
          _isActivatedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {accountName},
  ];
  @override
  Author map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Author(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      accountName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}role'],
      )!,
      isActivated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_activated'],
      )!,
    );
  }

  @override
  $AuthorsTable createAlias(String alias) {
    return $AuthorsTable(attachedDatabase, alias);
  }
}

class Author extends DataClass implements Insertable<Author> {
  final int id;
  final String accountName;
  final String? description;
  final int role;
  final bool isActivated;
  const Author({
    required this.id,
    required this.accountName,
    this.description,
    required this.role,
    required this.isActivated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_name'] = Variable<String>(accountName);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['role'] = Variable<int>(role);
    map['is_activated'] = Variable<bool>(isActivated);
    return map;
  }

  AuthorsCompanion toCompanion(bool nullToAbsent) {
    return AuthorsCompanion(
      id: Value(id),
      accountName: Value(accountName),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      role: Value(role),
      isActivated: Value(isActivated),
    );
  }

  factory Author.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Author(
      id: serializer.fromJson<int>(json['id']),
      accountName: serializer.fromJson<String>(json['accountName']),
      description: serializer.fromJson<String?>(json['description']),
      role: serializer.fromJson<int>(json['role']),
      isActivated: serializer.fromJson<bool>(json['isActivated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountName': serializer.toJson<String>(accountName),
      'description': serializer.toJson<String?>(description),
      'role': serializer.toJson<int>(role),
      'isActivated': serializer.toJson<bool>(isActivated),
    };
  }

  Author copyWith({
    int? id,
    String? accountName,
    Value<String?> description = const Value.absent(),
    int? role,
    bool? isActivated,
  }) => Author(
    id: id ?? this.id,
    accountName: accountName ?? this.accountName,
    description: description.present ? description.value : this.description,
    role: role ?? this.role,
    isActivated: isActivated ?? this.isActivated,
  );
  Author copyWithCompanion(AuthorsCompanion data) {
    return Author(
      id: data.id.present ? data.id.value : this.id,
      accountName: data.accountName.present
          ? data.accountName.value
          : this.accountName,
      description: data.description.present
          ? data.description.value
          : this.description,
      role: data.role.present ? data.role.value : this.role,
      isActivated: data.isActivated.present
          ? data.isActivated.value
          : this.isActivated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Author(')
          ..write('id: $id, ')
          ..write('accountName: $accountName, ')
          ..write('description: $description, ')
          ..write('role: $role, ')
          ..write('isActivated: $isActivated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, accountName, description, role, isActivated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Author &&
          other.id == this.id &&
          other.accountName == this.accountName &&
          other.description == this.description &&
          other.role == this.role &&
          other.isActivated == this.isActivated);
}

class AuthorsCompanion extends UpdateCompanion<Author> {
  final Value<int> id;
  final Value<String> accountName;
  final Value<String?> description;
  final Value<int> role;
  final Value<bool> isActivated;
  const AuthorsCompanion({
    this.id = const Value.absent(),
    this.accountName = const Value.absent(),
    this.description = const Value.absent(),
    this.role = const Value.absent(),
    this.isActivated = const Value.absent(),
  });
  AuthorsCompanion.insert({
    this.id = const Value.absent(),
    required String accountName,
    this.description = const Value.absent(),
    this.role = const Value.absent(),
    this.isActivated = const Value.absent(),
  }) : accountName = Value(accountName);
  static Insertable<Author> custom({
    Expression<int>? id,
    Expression<String>? accountName,
    Expression<String>? description,
    Expression<int>? role,
    Expression<bool>? isActivated,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountName != null) 'account_name': accountName,
      if (description != null) 'description': description,
      if (role != null) 'role': role,
      if (isActivated != null) 'is_activated': isActivated,
    });
  }

  AuthorsCompanion copyWith({
    Value<int>? id,
    Value<String>? accountName,
    Value<String?>? description,
    Value<int>? role,
    Value<bool>? isActivated,
  }) {
    return AuthorsCompanion(
      id: id ?? this.id,
      accountName: accountName ?? this.accountName,
      description: description ?? this.description,
      role: role ?? this.role,
      isActivated: isActivated ?? this.isActivated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountName.present) {
      map['account_name'] = Variable<String>(accountName.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (role.present) {
      map['role'] = Variable<int>(role.value);
    }
    if (isActivated.present) {
      map['is_activated'] = Variable<bool>(isActivated.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuthorsCompanion(')
          ..write('id: $id, ')
          ..write('accountName: $accountName, ')
          ..write('description: $description, ')
          ..write('role: $role, ')
          ..write('isActivated: $isActivated')
          ..write(')'))
        .toString();
  }
}

class $NoteCatalogsTable extends NoteCatalogs
    with TableInfo<$NoteCatalogsTable, NoteCatalog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteCatalogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schemaMeta = const VerificationMeta('schema');
  @override
  late final GeneratedColumn<String> schema = GeneratedColumn<String>(
    'schema',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _renderMeta = const VerificationMeta('render');
  @override
  late final GeneratedColumn<String> render = GeneratedColumn<String>(
    'render',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatTypeMeta = const VerificationMeta(
    'formatType',
  );
  @override
  late final GeneratedColumn<int> formatType = GeneratedColumn<int>(
    'format_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 0,
      maxTextLength: 1000,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    schema,
    render,
    formatType,
    isDefault,
    description,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_catalogs';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteCatalog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('schema')) {
      context.handle(
        _schemaMeta,
        schema.isAcceptableOrUnknown(data['schema']!, _schemaMeta),
      );
    } else if (isInserting) {
      context.missing(_schemaMeta);
    }
    if (data.containsKey('render')) {
      context.handle(
        _renderMeta,
        render.isAcceptableOrUnknown(data['render']!, _renderMeta),
      );
    }
    if (data.containsKey('format_type')) {
      context.handle(
        _formatTypeMeta,
        formatType.isAcceptableOrUnknown(data['format_type']!, _formatTypeMeta),
      );
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {name},
  ];
  @override
  NoteCatalog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteCatalog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      schema: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schema'],
      )!,
      render: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}render'],
      ),
      formatType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}format_type'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
    );
  }

  @override
  $NoteCatalogsTable createAlias(String alias) {
    return $NoteCatalogsTable(attachedDatabase, alias);
  }
}

class NoteCatalog extends DataClass implements Insertable<NoteCatalog> {
  final int id;
  final String name;
  final String schema;
  final String? render;
  final int formatType;
  final bool isDefault;
  final String? description;
  const NoteCatalog({
    required this.id,
    required this.name,
    required this.schema,
    this.render,
    required this.formatType,
    required this.isDefault,
    this.description,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['schema'] = Variable<String>(schema);
    if (!nullToAbsent || render != null) {
      map['render'] = Variable<String>(render);
    }
    map['format_type'] = Variable<int>(formatType);
    map['is_default'] = Variable<bool>(isDefault);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    return map;
  }

  NoteCatalogsCompanion toCompanion(bool nullToAbsent) {
    return NoteCatalogsCompanion(
      id: Value(id),
      name: Value(name),
      schema: Value(schema),
      render: render == null && nullToAbsent
          ? const Value.absent()
          : Value(render),
      formatType: Value(formatType),
      isDefault: Value(isDefault),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
    );
  }

  factory NoteCatalog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteCatalog(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      schema: serializer.fromJson<String>(json['schema']),
      render: serializer.fromJson<String?>(json['render']),
      formatType: serializer.fromJson<int>(json['formatType']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      description: serializer.fromJson<String?>(json['description']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'schema': serializer.toJson<String>(schema),
      'render': serializer.toJson<String?>(render),
      'formatType': serializer.toJson<int>(formatType),
      'isDefault': serializer.toJson<bool>(isDefault),
      'description': serializer.toJson<String?>(description),
    };
  }

  NoteCatalog copyWith({
    int? id,
    String? name,
    String? schema,
    Value<String?> render = const Value.absent(),
    int? formatType,
    bool? isDefault,
    Value<String?> description = const Value.absent(),
  }) => NoteCatalog(
    id: id ?? this.id,
    name: name ?? this.name,
    schema: schema ?? this.schema,
    render: render.present ? render.value : this.render,
    formatType: formatType ?? this.formatType,
    isDefault: isDefault ?? this.isDefault,
    description: description.present ? description.value : this.description,
  );
  NoteCatalog copyWithCompanion(NoteCatalogsCompanion data) {
    return NoteCatalog(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      schema: data.schema.present ? data.schema.value : this.schema,
      render: data.render.present ? data.render.value : this.render,
      formatType: data.formatType.present
          ? data.formatType.value
          : this.formatType,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      description: data.description.present
          ? data.description.value
          : this.description,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteCatalog(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('schema: $schema, ')
          ..write('render: $render, ')
          ..write('formatType: $formatType, ')
          ..write('isDefault: $isDefault, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, schema, render, formatType, isDefault, description);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteCatalog &&
          other.id == this.id &&
          other.name == this.name &&
          other.schema == this.schema &&
          other.render == this.render &&
          other.formatType == this.formatType &&
          other.isDefault == this.isDefault &&
          other.description == this.description);
}

class NoteCatalogsCompanion extends UpdateCompanion<NoteCatalog> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> schema;
  final Value<String?> render;
  final Value<int> formatType;
  final Value<bool> isDefault;
  final Value<String?> description;
  const NoteCatalogsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.schema = const Value.absent(),
    this.render = const Value.absent(),
    this.formatType = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.description = const Value.absent(),
  });
  NoteCatalogsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String schema,
    this.render = const Value.absent(),
    this.formatType = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.description = const Value.absent(),
  }) : name = Value(name),
       schema = Value(schema);
  static Insertable<NoteCatalog> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? schema,
    Expression<String>? render,
    Expression<int>? formatType,
    Expression<bool>? isDefault,
    Expression<String>? description,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (schema != null) 'schema': schema,
      if (render != null) 'render': render,
      if (formatType != null) 'format_type': formatType,
      if (isDefault != null) 'is_default': isDefault,
      if (description != null) 'description': description,
    });
  }

  NoteCatalogsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? schema,
    Value<String?>? render,
    Value<int>? formatType,
    Value<bool>? isDefault,
    Value<String?>? description,
  }) {
    return NoteCatalogsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      schema: schema ?? this.schema,
      render: render ?? this.render,
      formatType: formatType ?? this.formatType,
      isDefault: isDefault ?? this.isDefault,
      description: description ?? this.description,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (schema.present) {
      map['schema'] = Variable<String>(schema.value);
    }
    if (render.present) {
      map['render'] = Variable<String>(render.value);
    }
    if (formatType.present) {
      map['format_type'] = Variable<int>(formatType.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteCatalogsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('schema: $schema, ')
          ..write('render: $render, ')
          ..write('formatType: $formatType, ')
          ..write('isDefault: $isDefault, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }
}

class $NotesTable extends Notes with TableInfo<$NotesTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: generateUuid,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 1000,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorIdMeta = const VerificationMeta(
    'authorId',
  );
  @override
  late final GeneratedColumn<int> authorId = GeneratedColumn<int>(
    'author_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES authors (id)',
    ),
  );
  static const VerificationMeta _catalogIdMeta = const VerificationMeta(
    'catalogId',
  );
  @override
  late final GeneratedColumn<int> catalogId = GeneratedColumn<int>(
    'catalog_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES note_catalogs (id)',
    ),
  );
  static const VerificationMeta _parentNoteIdMeta = const VerificationMeta(
    'parentNoteId',
  );
  @override
  late final GeneratedColumn<int> parentNoteId = GeneratedColumn<int>(
    'parent_note_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notes (id)',
    ),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<Uint8List> version = GeneratedColumn<Uint8List>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createDateMeta = const VerificationMeta(
    'createDate',
  );
  @override
  late final GeneratedColumn<DateTime> createDate = GeneratedColumn<DateTime>(
    'create_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _lastModifiedDateMeta = const VerificationMeta(
    'lastModifiedDate',
  );
  @override
  late final GeneratedColumn<DateTime> lastModifiedDate =
      GeneratedColumn<DateTime>(
        'last_modified_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 0,
      maxTextLength: 1000,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attachmentsMeta = const VerificationMeta(
    'attachments',
  );
  @override
  late final GeneratedColumn<String> attachments = GeneratedColumn<String>(
    'attachments',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    subject,
    content,
    authorId,
    catalogId,
    parentNoteId,
    deletedAt,
    version,
    createDate,
    lastModifiedDate,
    description,
    attachments,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Note> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('author_id')) {
      context.handle(
        _authorIdMeta,
        authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_authorIdMeta);
    }
    if (data.containsKey('catalog_id')) {
      context.handle(
        _catalogIdMeta,
        catalogId.isAcceptableOrUnknown(data['catalog_id']!, _catalogIdMeta),
      );
    }
    if (data.containsKey('parent_note_id')) {
      context.handle(
        _parentNoteIdMeta,
        parentNoteId.isAcceptableOrUnknown(
          data['parent_note_id']!,
          _parentNoteIdMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('create_date')) {
      context.handle(
        _createDateMeta,
        createDate.isAcceptableOrUnknown(data['create_date']!, _createDateMeta),
      );
    }
    if (data.containsKey('last_modified_date')) {
      context.handle(
        _lastModifiedDateMeta,
        lastModifiedDate.isAcceptableOrUnknown(
          data['last_modified_date']!,
          _lastModifiedDateMeta,
        ),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('attachments')) {
      context.handle(
        _attachmentsMeta,
        attachments.isAcceptableOrUnknown(
          data['attachments']!,
          _attachmentsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      ),
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
      authorId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}author_id'],
      )!,
      catalogId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}catalog_id'],
      ),
      parentNoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_note_id'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}version'],
      ),
      createDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}create_date'],
      )!,
      lastModifiedDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_modified_date'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      attachments: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachments'],
      ),
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  final int id;
  final String? uuid;
  final String subject;
  final String? content;
  final int authorId;
  final int? catalogId;
  final int? parentNoteId;
  final DateTime? deletedAt;
  final Uint8List? version;
  final DateTime createDate;
  final DateTime? lastModifiedDate;
  final String? description;
  final String? attachments;
  const Note({
    required this.id,
    this.uuid,
    required this.subject,
    this.content,
    required this.authorId,
    this.catalogId,
    this.parentNoteId,
    this.deletedAt,
    this.version,
    required this.createDate,
    this.lastModifiedDate,
    this.description,
    this.attachments,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || uuid != null) {
      map['uuid'] = Variable<String>(uuid);
    }
    map['subject'] = Variable<String>(subject);
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    map['author_id'] = Variable<int>(authorId);
    if (!nullToAbsent || catalogId != null) {
      map['catalog_id'] = Variable<int>(catalogId);
    }
    if (!nullToAbsent || parentNoteId != null) {
      map['parent_note_id'] = Variable<int>(parentNoteId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<Uint8List>(version);
    }
    map['create_date'] = Variable<DateTime>(createDate);
    if (!nullToAbsent || lastModifiedDate != null) {
      map['last_modified_date'] = Variable<DateTime>(lastModifiedDate);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || attachments != null) {
      map['attachments'] = Variable<String>(attachments);
    }
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      uuid: uuid == null && nullToAbsent ? const Value.absent() : Value(uuid),
      subject: Value(subject),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      authorId: Value(authorId),
      catalogId: catalogId == null && nullToAbsent
          ? const Value.absent()
          : Value(catalogId),
      parentNoteId: parentNoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentNoteId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      createDate: Value(createDate),
      lastModifiedDate: lastModifiedDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModifiedDate),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      attachments: attachments == null && nullToAbsent
          ? const Value.absent()
          : Value(attachments),
    );
  }

  factory Note.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String?>(json['uuid']),
      subject: serializer.fromJson<String>(json['subject']),
      content: serializer.fromJson<String?>(json['content']),
      authorId: serializer.fromJson<int>(json['authorId']),
      catalogId: serializer.fromJson<int?>(json['catalogId']),
      parentNoteId: serializer.fromJson<int?>(json['parentNoteId']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      version: serializer.fromJson<Uint8List?>(json['version']),
      createDate: serializer.fromJson<DateTime>(json['createDate']),
      lastModifiedDate: serializer.fromJson<DateTime?>(
        json['lastModifiedDate'],
      ),
      description: serializer.fromJson<String?>(json['description']),
      attachments: serializer.fromJson<String?>(json['attachments']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String?>(uuid),
      'subject': serializer.toJson<String>(subject),
      'content': serializer.toJson<String?>(content),
      'authorId': serializer.toJson<int>(authorId),
      'catalogId': serializer.toJson<int?>(catalogId),
      'parentNoteId': serializer.toJson<int?>(parentNoteId),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'version': serializer.toJson<Uint8List?>(version),
      'createDate': serializer.toJson<DateTime>(createDate),
      'lastModifiedDate': serializer.toJson<DateTime?>(lastModifiedDate),
      'description': serializer.toJson<String?>(description),
      'attachments': serializer.toJson<String?>(attachments),
    };
  }

  Note copyWith({
    int? id,
    Value<String?> uuid = const Value.absent(),
    String? subject,
    Value<String?> content = const Value.absent(),
    int? authorId,
    Value<int?> catalogId = const Value.absent(),
    Value<int?> parentNoteId = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<Uint8List?> version = const Value.absent(),
    DateTime? createDate,
    Value<DateTime?> lastModifiedDate = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> attachments = const Value.absent(),
  }) => Note(
    id: id ?? this.id,
    uuid: uuid.present ? uuid.value : this.uuid,
    subject: subject ?? this.subject,
    content: content.present ? content.value : this.content,
    authorId: authorId ?? this.authorId,
    catalogId: catalogId.present ? catalogId.value : this.catalogId,
    parentNoteId: parentNoteId.present ? parentNoteId.value : this.parentNoteId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    version: version.present ? version.value : this.version,
    createDate: createDate ?? this.createDate,
    lastModifiedDate: lastModifiedDate.present
        ? lastModifiedDate.value
        : this.lastModifiedDate,
    description: description.present ? description.value : this.description,
    attachments: attachments.present ? attachments.value : this.attachments,
  );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      subject: data.subject.present ? data.subject.value : this.subject,
      content: data.content.present ? data.content.value : this.content,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
      catalogId: data.catalogId.present ? data.catalogId.value : this.catalogId,
      parentNoteId: data.parentNoteId.present
          ? data.parentNoteId.value
          : this.parentNoteId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      version: data.version.present ? data.version.value : this.version,
      createDate: data.createDate.present
          ? data.createDate.value
          : this.createDate,
      lastModifiedDate: data.lastModifiedDate.present
          ? data.lastModifiedDate.value
          : this.lastModifiedDate,
      description: data.description.present
          ? data.description.value
          : this.description,
      attachments: data.attachments.present
          ? data.attachments.value
          : this.attachments,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('subject: $subject, ')
          ..write('content: $content, ')
          ..write('authorId: $authorId, ')
          ..write('catalogId: $catalogId, ')
          ..write('parentNoteId: $parentNoteId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('version: $version, ')
          ..write('createDate: $createDate, ')
          ..write('lastModifiedDate: $lastModifiedDate, ')
          ..write('description: $description, ')
          ..write('attachments: $attachments')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    subject,
    content,
    authorId,
    catalogId,
    parentNoteId,
    deletedAt,
    $driftBlobEquality.hash(version),
    createDate,
    lastModifiedDate,
    description,
    attachments,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.subject == this.subject &&
          other.content == this.content &&
          other.authorId == this.authorId &&
          other.catalogId == this.catalogId &&
          other.parentNoteId == this.parentNoteId &&
          other.deletedAt == this.deletedAt &&
          $driftBlobEquality.equals(other.version, this.version) &&
          other.createDate == this.createDate &&
          other.lastModifiedDate == this.lastModifiedDate &&
          other.description == this.description &&
          other.attachments == this.attachments);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<int> id;
  final Value<String?> uuid;
  final Value<String> subject;
  final Value<String?> content;
  final Value<int> authorId;
  final Value<int?> catalogId;
  final Value<int?> parentNoteId;
  final Value<DateTime?> deletedAt;
  final Value<Uint8List?> version;
  final Value<DateTime> createDate;
  final Value<DateTime?> lastModifiedDate;
  final Value<String?> description;
  final Value<String?> attachments;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.subject = const Value.absent(),
    this.content = const Value.absent(),
    this.authorId = const Value.absent(),
    this.catalogId = const Value.absent(),
    this.parentNoteId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.createDate = const Value.absent(),
    this.lastModifiedDate = const Value.absent(),
    this.description = const Value.absent(),
    this.attachments = const Value.absent(),
  });
  NotesCompanion.insert({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    required String subject,
    this.content = const Value.absent(),
    required int authorId,
    this.catalogId = const Value.absent(),
    this.parentNoteId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.createDate = const Value.absent(),
    this.lastModifiedDate = const Value.absent(),
    this.description = const Value.absent(),
    this.attachments = const Value.absent(),
  }) : subject = Value(subject),
       authorId = Value(authorId);
  static Insertable<Note> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? subject,
    Expression<String>? content,
    Expression<int>? authorId,
    Expression<int>? catalogId,
    Expression<int>? parentNoteId,
    Expression<DateTime>? deletedAt,
    Expression<Uint8List>? version,
    Expression<DateTime>? createDate,
    Expression<DateTime>? lastModifiedDate,
    Expression<String>? description,
    Expression<String>? attachments,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (subject != null) 'subject': subject,
      if (content != null) 'content': content,
      if (authorId != null) 'author_id': authorId,
      if (catalogId != null) 'catalog_id': catalogId,
      if (parentNoteId != null) 'parent_note_id': parentNoteId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (version != null) 'version': version,
      if (createDate != null) 'create_date': createDate,
      if (lastModifiedDate != null) 'last_modified_date': lastModifiedDate,
      if (description != null) 'description': description,
      if (attachments != null) 'attachments': attachments,
    });
  }

  NotesCompanion copyWith({
    Value<int>? id,
    Value<String?>? uuid,
    Value<String>? subject,
    Value<String?>? content,
    Value<int>? authorId,
    Value<int?>? catalogId,
    Value<int?>? parentNoteId,
    Value<DateTime?>? deletedAt,
    Value<Uint8List?>? version,
    Value<DateTime>? createDate,
    Value<DateTime?>? lastModifiedDate,
    Value<String?>? description,
    Value<String?>? attachments,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      subject: subject ?? this.subject,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      catalogId: catalogId ?? this.catalogId,
      parentNoteId: parentNoteId ?? this.parentNoteId,
      deletedAt: deletedAt ?? this.deletedAt,
      version: version ?? this.version,
      createDate: createDate ?? this.createDate,
      lastModifiedDate: lastModifiedDate ?? this.lastModifiedDate,
      description: description ?? this.description,
      attachments: attachments ?? this.attachments,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<int>(authorId.value);
    }
    if (catalogId.present) {
      map['catalog_id'] = Variable<int>(catalogId.value);
    }
    if (parentNoteId.present) {
      map['parent_note_id'] = Variable<int>(parentNoteId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<Uint8List>(version.value);
    }
    if (createDate.present) {
      map['create_date'] = Variable<DateTime>(createDate.value);
    }
    if (lastModifiedDate.present) {
      map['last_modified_date'] = Variable<DateTime>(lastModifiedDate.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (attachments.present) {
      map['attachments'] = Variable<String>(attachments.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('subject: $subject, ')
          ..write('content: $content, ')
          ..write('authorId: $authorId, ')
          ..write('catalogId: $catalogId, ')
          ..write('parentNoteId: $parentNoteId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('version: $version, ')
          ..write('createDate: $createDate, ')
          ..write('lastModifiedDate: $lastModifiedDate, ')
          ..write('description: $description, ')
          ..write('attachments: $attachments')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 0,
      maxTextLength: 1000,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActivatedMeta = const VerificationMeta(
    'isActivated',
  );
  @override
  late final GeneratedColumn<bool> isActivated = GeneratedColumn<bool>(
    'is_activated',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_activated" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _lastModifiedMeta = const VerificationMeta(
    'lastModified',
  );
  @override
  late final GeneratedColumn<DateTime> lastModified = GeneratedColumn<DateTime>(
    'last_modified',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    isActivated,
    lastModified,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('is_activated')) {
      context.handle(
        _isActivatedMeta,
        isActivated.isAcceptableOrUnknown(
          data['is_activated']!,
          _isActivatedMeta,
        ),
      );
    }
    if (data.containsKey('last_modified')) {
      context.handle(
        _lastModifiedMeta,
        lastModified.isAcceptableOrUnknown(
          data['last_modified']!,
          _lastModifiedMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {name},
  ];
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      isActivated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_activated'],
      )!,
      lastModified: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_modified'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final int id;
  final String name;
  final String? description;
  final bool isActivated;
  final DateTime lastModified;
  final DateTime? deletedAt;
  const Tag({
    required this.id,
    required this.name,
    this.description,
    required this.isActivated,
    required this.lastModified,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_activated'] = Variable<bool>(isActivated);
    map['last_modified'] = Variable<DateTime>(lastModified);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isActivated: Value(isActivated),
      lastModified: Value(lastModified),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      isActivated: serializer.fromJson<bool>(json['isActivated']),
      lastModified: serializer.fromJson<DateTime>(json['lastModified']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'isActivated': serializer.toJson<bool>(isActivated),
      'lastModified': serializer.toJson<DateTime>(lastModified),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Tag copyWith({
    int? id,
    String? name,
    Value<String?> description = const Value.absent(),
    bool? isActivated,
    DateTime? lastModified,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Tag(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    isActivated: isActivated ?? this.isActivated,
    lastModified: lastModified ?? this.lastModified,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      isActivated: data.isActivated.present
          ? data.isActivated.value
          : this.isActivated,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('isActivated: $isActivated, ')
          ..write('lastModified: $lastModified, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, description, isActivated, lastModified, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.isActivated == this.isActivated &&
          other.lastModified == this.lastModified &&
          other.deletedAt == this.deletedAt);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<bool> isActivated;
  final Value<DateTime> lastModified;
  final Value<DateTime?> deletedAt;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.isActivated = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  TagsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    this.isActivated = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Tag> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<bool>? isActivated,
    Expression<DateTime>? lastModified,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (isActivated != null) 'is_activated': isActivated,
      if (lastModified != null) 'last_modified': lastModified,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  TagsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<bool>? isActivated,
    Value<DateTime>? lastModified,
    Value<DateTime?>? deletedAt,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActivated: isActivated ?? this.isActivated,
      lastModified: lastModified ?? this.lastModified,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isActivated.present) {
      map['is_activated'] = Variable<bool>(isActivated.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<DateTime>(lastModified.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('isActivated: $isActivated, ')
          ..write('lastModified: $lastModified, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $NoteTagRefsTable extends NoteTagRefs
    with TableInfo<$NoteTagRefsTable, NoteTagRef> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteTagRefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<int> noteId = GeneratedColumn<int>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notes (id)',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<int> tagId = GeneratedColumn<int>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [noteId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_tag_refs';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteTagRef> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {noteId, tagId};
  @override
  NoteTagRef map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteTagRef(
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}note_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $NoteTagRefsTable createAlias(String alias) {
    return $NoteTagRefsTable(attachedDatabase, alias);
  }
}

class NoteTagRef extends DataClass implements Insertable<NoteTagRef> {
  final int noteId;
  final int tagId;
  const NoteTagRef({required this.noteId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['note_id'] = Variable<int>(noteId);
    map['tag_id'] = Variable<int>(tagId);
    return map;
  }

  NoteTagRefsCompanion toCompanion(bool nullToAbsent) {
    return NoteTagRefsCompanion(noteId: Value(noteId), tagId: Value(tagId));
  }

  factory NoteTagRef.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteTagRef(
      noteId: serializer.fromJson<int>(json['noteId']),
      tagId: serializer.fromJson<int>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'noteId': serializer.toJson<int>(noteId),
      'tagId': serializer.toJson<int>(tagId),
    };
  }

  NoteTagRef copyWith({int? noteId, int? tagId}) =>
      NoteTagRef(noteId: noteId ?? this.noteId, tagId: tagId ?? this.tagId);
  NoteTagRef copyWithCompanion(NoteTagRefsCompanion data) {
    return NoteTagRef(
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteTagRef(')
          ..write('noteId: $noteId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(noteId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteTagRef &&
          other.noteId == this.noteId &&
          other.tagId == this.tagId);
}

class NoteTagRefsCompanion extends UpdateCompanion<NoteTagRef> {
  final Value<int> noteId;
  final Value<int> tagId;
  final Value<int> rowid;
  const NoteTagRefsCompanion({
    this.noteId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteTagRefsCompanion.insert({
    required int noteId,
    required int tagId,
    this.rowid = const Value.absent(),
  }) : noteId = Value(noteId),
       tagId = Value(tagId);
  static Insertable<NoteTagRef> custom({
    Expression<int>? noteId,
    Expression<int>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (noteId != null) 'note_id': noteId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteTagRefsCompanion copyWith({
    Value<int>? noteId,
    Value<int>? tagId,
    Value<int>? rowid,
  }) {
    return NoteTagRefsCompanion(
      noteId: noteId ?? this.noteId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (noteId.present) {
      map['note_id'] = Variable<int>(noteId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<int>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteTagRefsCompanion(')
          ..write('noteId: $noteId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$HmmDatabase extends GeneratedDatabase {
  _$HmmDatabase(QueryExecutor e) : super(e);
  $HmmDatabaseManager get managers => $HmmDatabaseManager(this);
  late final $AuthorsTable authors = $AuthorsTable(this);
  late final $NoteCatalogsTable noteCatalogs = $NoteCatalogsTable(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $NoteTagRefsTable noteTagRefs = $NoteTagRefsTable(this);
  late final Index idxNotesLastModified = Index(
    'idx_notes_last_modified',
    'CREATE INDEX idx_notes_last_modified ON notes (last_modified_date)',
  );
  late final Index idxNotesCatalog = Index(
    'idx_notes_catalog',
    'CREATE INDEX idx_notes_catalog ON notes (catalog_id)',
  );
  late final Index idxNotesParent = Index(
    'idx_notes_parent',
    'CREATE INDEX idx_notes_parent ON notes (parent_note_id)',
  );
  late final Index idxNotesUuid = Index(
    'idx_notes_uuid',
    'CREATE UNIQUE INDEX idx_notes_uuid ON notes (uuid)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    authors,
    noteCatalogs,
    notes,
    tags,
    noteTagRefs,
    idxNotesLastModified,
    idxNotesCatalog,
    idxNotesParent,
    idxNotesUuid,
  ];
}

typedef $$AuthorsTableCreateCompanionBuilder =
    AuthorsCompanion Function({
      Value<int> id,
      required String accountName,
      Value<String?> description,
      Value<int> role,
      Value<bool> isActivated,
    });
typedef $$AuthorsTableUpdateCompanionBuilder =
    AuthorsCompanion Function({
      Value<int> id,
      Value<String> accountName,
      Value<String?> description,
      Value<int> role,
      Value<bool> isActivated,
    });

final class $$AuthorsTableReferences
    extends BaseReferences<_$HmmDatabase, $AuthorsTable, Author> {
  $$AuthorsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$NotesTable, List<Note>> _notesRefsTable(
    _$HmmDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.notes,
    aliasName: $_aliasNameGenerator(db.authors.id, db.notes.authorId),
  );

  $$NotesTableProcessedTableManager get notesRefs {
    final manager = $$NotesTableTableManager(
      $_db,
      $_db.notes,
    ).filter((f) => f.authorId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_notesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AuthorsTableFilterComposer
    extends Composer<_$HmmDatabase, $AuthorsTable> {
  $$AuthorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountName => $composableBuilder(
    column: $table.accountName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActivated => $composableBuilder(
    column: $table.isActivated,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> notesRefs(
    Expression<bool> Function($$NotesTableFilterComposer f) f,
  ) {
    final $$NotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.authorId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableFilterComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AuthorsTableOrderingComposer
    extends Composer<_$HmmDatabase, $AuthorsTable> {
  $$AuthorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountName => $composableBuilder(
    column: $table.accountName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActivated => $composableBuilder(
    column: $table.isActivated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AuthorsTableAnnotationComposer
    extends Composer<_$HmmDatabase, $AuthorsTable> {
  $$AuthorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accountName => $composableBuilder(
    column: $table.accountName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<bool> get isActivated => $composableBuilder(
    column: $table.isActivated,
    builder: (column) => column,
  );

  Expression<T> notesRefs<T extends Object>(
    Expression<T> Function($$NotesTableAnnotationComposer a) f,
  ) {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.authorId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableAnnotationComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AuthorsTableTableManager
    extends
        RootTableManager<
          _$HmmDatabase,
          $AuthorsTable,
          Author,
          $$AuthorsTableFilterComposer,
          $$AuthorsTableOrderingComposer,
          $$AuthorsTableAnnotationComposer,
          $$AuthorsTableCreateCompanionBuilder,
          $$AuthorsTableUpdateCompanionBuilder,
          (Author, $$AuthorsTableReferences),
          Author,
          PrefetchHooks Function({bool notesRefs})
        > {
  $$AuthorsTableTableManager(_$HmmDatabase db, $AuthorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuthorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuthorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuthorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> accountName = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> role = const Value.absent(),
                Value<bool> isActivated = const Value.absent(),
              }) => AuthorsCompanion(
                id: id,
                accountName: accountName,
                description: description,
                role: role,
                isActivated: isActivated,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String accountName,
                Value<String?> description = const Value.absent(),
                Value<int> role = const Value.absent(),
                Value<bool> isActivated = const Value.absent(),
              }) => AuthorsCompanion.insert(
                id: id,
                accountName: accountName,
                description: description,
                role: role,
                isActivated: isActivated,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AuthorsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({notesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (notesRefs) db.notes],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (notesRefs)
                    await $_getPrefetchedData<Author, $AuthorsTable, Note>(
                      currentTable: table,
                      referencedTable: $$AuthorsTableReferences._notesRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$AuthorsTableReferences(db, table, p0).notesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.authorId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$AuthorsTableProcessedTableManager =
    ProcessedTableManager<
      _$HmmDatabase,
      $AuthorsTable,
      Author,
      $$AuthorsTableFilterComposer,
      $$AuthorsTableOrderingComposer,
      $$AuthorsTableAnnotationComposer,
      $$AuthorsTableCreateCompanionBuilder,
      $$AuthorsTableUpdateCompanionBuilder,
      (Author, $$AuthorsTableReferences),
      Author,
      PrefetchHooks Function({bool notesRefs})
    >;
typedef $$NoteCatalogsTableCreateCompanionBuilder =
    NoteCatalogsCompanion Function({
      Value<int> id,
      required String name,
      required String schema,
      Value<String?> render,
      Value<int> formatType,
      Value<bool> isDefault,
      Value<String?> description,
    });
typedef $$NoteCatalogsTableUpdateCompanionBuilder =
    NoteCatalogsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> schema,
      Value<String?> render,
      Value<int> formatType,
      Value<bool> isDefault,
      Value<String?> description,
    });

final class $$NoteCatalogsTableReferences
    extends BaseReferences<_$HmmDatabase, $NoteCatalogsTable, NoteCatalog> {
  $$NoteCatalogsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$NotesTable, List<Note>> _notesRefsTable(
    _$HmmDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.notes,
    aliasName: $_aliasNameGenerator(db.noteCatalogs.id, db.notes.catalogId),
  );

  $$NotesTableProcessedTableManager get notesRefs {
    final manager = $$NotesTableTableManager(
      $_db,
      $_db.notes,
    ).filter((f) => f.catalogId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_notesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NoteCatalogsTableFilterComposer
    extends Composer<_$HmmDatabase, $NoteCatalogsTable> {
  $$NoteCatalogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schema => $composableBuilder(
    column: $table.schema,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get render => $composableBuilder(
    column: $table.render,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get formatType => $composableBuilder(
    column: $table.formatType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> notesRefs(
    Expression<bool> Function($$NotesTableFilterComposer f) f,
  ) {
    final $$NotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.catalogId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableFilterComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NoteCatalogsTableOrderingComposer
    extends Composer<_$HmmDatabase, $NoteCatalogsTable> {
  $$NoteCatalogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schema => $composableBuilder(
    column: $table.schema,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get render => $composableBuilder(
    column: $table.render,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get formatType => $composableBuilder(
    column: $table.formatType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NoteCatalogsTableAnnotationComposer
    extends Composer<_$HmmDatabase, $NoteCatalogsTable> {
  $$NoteCatalogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get schema =>
      $composableBuilder(column: $table.schema, builder: (column) => column);

  GeneratedColumn<String> get render =>
      $composableBuilder(column: $table.render, builder: (column) => column);

  GeneratedColumn<int> get formatType => $composableBuilder(
    column: $table.formatType,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  Expression<T> notesRefs<T extends Object>(
    Expression<T> Function($$NotesTableAnnotationComposer a) f,
  ) {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.catalogId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableAnnotationComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NoteCatalogsTableTableManager
    extends
        RootTableManager<
          _$HmmDatabase,
          $NoteCatalogsTable,
          NoteCatalog,
          $$NoteCatalogsTableFilterComposer,
          $$NoteCatalogsTableOrderingComposer,
          $$NoteCatalogsTableAnnotationComposer,
          $$NoteCatalogsTableCreateCompanionBuilder,
          $$NoteCatalogsTableUpdateCompanionBuilder,
          (NoteCatalog, $$NoteCatalogsTableReferences),
          NoteCatalog,
          PrefetchHooks Function({bool notesRefs})
        > {
  $$NoteCatalogsTableTableManager(_$HmmDatabase db, $NoteCatalogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteCatalogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteCatalogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteCatalogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> schema = const Value.absent(),
                Value<String?> render = const Value.absent(),
                Value<int> formatType = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<String?> description = const Value.absent(),
              }) => NoteCatalogsCompanion(
                id: id,
                name: name,
                schema: schema,
                render: render,
                formatType: formatType,
                isDefault: isDefault,
                description: description,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String schema,
                Value<String?> render = const Value.absent(),
                Value<int> formatType = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<String?> description = const Value.absent(),
              }) => NoteCatalogsCompanion.insert(
                id: id,
                name: name,
                schema: schema,
                render: render,
                formatType: formatType,
                isDefault: isDefault,
                description: description,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$NoteCatalogsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({notesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (notesRefs) db.notes],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (notesRefs)
                    await $_getPrefetchedData<
                      NoteCatalog,
                      $NoteCatalogsTable,
                      Note
                    >(
                      currentTable: table,
                      referencedTable: $$NoteCatalogsTableReferences
                          ._notesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$NoteCatalogsTableReferences(
                            db,
                            table,
                            p0,
                          ).notesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.catalogId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$NoteCatalogsTableProcessedTableManager =
    ProcessedTableManager<
      _$HmmDatabase,
      $NoteCatalogsTable,
      NoteCatalog,
      $$NoteCatalogsTableFilterComposer,
      $$NoteCatalogsTableOrderingComposer,
      $$NoteCatalogsTableAnnotationComposer,
      $$NoteCatalogsTableCreateCompanionBuilder,
      $$NoteCatalogsTableUpdateCompanionBuilder,
      (NoteCatalog, $$NoteCatalogsTableReferences),
      NoteCatalog,
      PrefetchHooks Function({bool notesRefs})
    >;
typedef $$NotesTableCreateCompanionBuilder =
    NotesCompanion Function({
      Value<int> id,
      Value<String?> uuid,
      required String subject,
      Value<String?> content,
      required int authorId,
      Value<int?> catalogId,
      Value<int?> parentNoteId,
      Value<DateTime?> deletedAt,
      Value<Uint8List?> version,
      Value<DateTime> createDate,
      Value<DateTime?> lastModifiedDate,
      Value<String?> description,
      Value<String?> attachments,
    });
typedef $$NotesTableUpdateCompanionBuilder =
    NotesCompanion Function({
      Value<int> id,
      Value<String?> uuid,
      Value<String> subject,
      Value<String?> content,
      Value<int> authorId,
      Value<int?> catalogId,
      Value<int?> parentNoteId,
      Value<DateTime?> deletedAt,
      Value<Uint8List?> version,
      Value<DateTime> createDate,
      Value<DateTime?> lastModifiedDate,
      Value<String?> description,
      Value<String?> attachments,
    });

final class $$NotesTableReferences
    extends BaseReferences<_$HmmDatabase, $NotesTable, Note> {
  $$NotesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AuthorsTable _authorIdTable(_$HmmDatabase db) => db.authors
      .createAlias($_aliasNameGenerator(db.notes.authorId, db.authors.id));

  $$AuthorsTableProcessedTableManager get authorId {
    final $_column = $_itemColumn<int>('author_id')!;

    final manager = $$AuthorsTableTableManager(
      $_db,
      $_db.authors,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_authorIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $NoteCatalogsTable _catalogIdTable(_$HmmDatabase db) =>
      db.noteCatalogs.createAlias(
        $_aliasNameGenerator(db.notes.catalogId, db.noteCatalogs.id),
      );

  $$NoteCatalogsTableProcessedTableManager? get catalogId {
    final $_column = $_itemColumn<int>('catalog_id');
    if ($_column == null) return null;
    final manager = $$NoteCatalogsTableTableManager(
      $_db,
      $_db.noteCatalogs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_catalogIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $NotesTable _parentNoteIdTable(_$HmmDatabase db) => db.notes
      .createAlias($_aliasNameGenerator(db.notes.parentNoteId, db.notes.id));

  $$NotesTableProcessedTableManager? get parentNoteId {
    final $_column = $_itemColumn<int>('parent_note_id');
    if ($_column == null) return null;
    final manager = $$NotesTableTableManager(
      $_db,
      $_db.notes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentNoteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$NoteTagRefsTable, List<NoteTagRef>>
  _noteTagRefsRefsTable(_$HmmDatabase db) => MultiTypedResultKey.fromTable(
    db.noteTagRefs,
    aliasName: $_aliasNameGenerator(db.notes.id, db.noteTagRefs.noteId),
  );

  $$NoteTagRefsTableProcessedTableManager get noteTagRefsRefs {
    final manager = $$NoteTagRefsTableTableManager(
      $_db,
      $_db.noteTagRefs,
    ).filter((f) => f.noteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_noteTagRefsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NotesTableFilterComposer extends Composer<_$HmmDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createDate => $composableBuilder(
    column: $table.createDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastModifiedDate => $composableBuilder(
    column: $table.lastModifiedDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => ColumnFilters(column),
  );

  $$AuthorsTableFilterComposer get authorId {
    final $$AuthorsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.authorId,
      referencedTable: $db.authors,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuthorsTableFilterComposer(
            $db: $db,
            $table: $db.authors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NoteCatalogsTableFilterComposer get catalogId {
    final $$NoteCatalogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.catalogId,
      referencedTable: $db.noteCatalogs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteCatalogsTableFilterComposer(
            $db: $db,
            $table: $db.noteCatalogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NotesTableFilterComposer get parentNoteId {
    final $$NotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentNoteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableFilterComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> noteTagRefsRefs(
    Expression<bool> Function($$NoteTagRefsTableFilterComposer f) f,
  ) {
    final $$NoteTagRefsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTagRefs,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTagRefsTableFilterComposer(
            $db: $db,
            $table: $db.noteTagRefs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NotesTableOrderingComposer
    extends Composer<_$HmmDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createDate => $composableBuilder(
    column: $table.createDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastModifiedDate => $composableBuilder(
    column: $table.lastModifiedDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => ColumnOrderings(column),
  );

  $$AuthorsTableOrderingComposer get authorId {
    final $$AuthorsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.authorId,
      referencedTable: $db.authors,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuthorsTableOrderingComposer(
            $db: $db,
            $table: $db.authors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NoteCatalogsTableOrderingComposer get catalogId {
    final $$NoteCatalogsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.catalogId,
      referencedTable: $db.noteCatalogs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteCatalogsTableOrderingComposer(
            $db: $db,
            $table: $db.noteCatalogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NotesTableOrderingComposer get parentNoteId {
    final $$NotesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentNoteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableOrderingComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotesTableAnnotationComposer
    extends Composer<_$HmmDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<Uint8List> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createDate => $composableBuilder(
    column: $table.createDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastModifiedDate => $composableBuilder(
    column: $table.lastModifiedDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => column,
  );

  $$AuthorsTableAnnotationComposer get authorId {
    final $$AuthorsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.authorId,
      referencedTable: $db.authors,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuthorsTableAnnotationComposer(
            $db: $db,
            $table: $db.authors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NoteCatalogsTableAnnotationComposer get catalogId {
    final $$NoteCatalogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.catalogId,
      referencedTable: $db.noteCatalogs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteCatalogsTableAnnotationComposer(
            $db: $db,
            $table: $db.noteCatalogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NotesTableAnnotationComposer get parentNoteId {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentNoteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableAnnotationComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> noteTagRefsRefs<T extends Object>(
    Expression<T> Function($$NoteTagRefsTableAnnotationComposer a) f,
  ) {
    final $$NoteTagRefsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTagRefs,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTagRefsTableAnnotationComposer(
            $db: $db,
            $table: $db.noteTagRefs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$HmmDatabase,
          $NotesTable,
          Note,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (Note, $$NotesTableReferences),
          Note,
          PrefetchHooks Function({
            bool authorId,
            bool catalogId,
            bool parentNoteId,
            bool noteTagRefsRefs,
          })
        > {
  $$NotesTableTableManager(_$HmmDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> uuid = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<int> authorId = const Value.absent(),
                Value<int?> catalogId = const Value.absent(),
                Value<int?> parentNoteId = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<Uint8List?> version = const Value.absent(),
                Value<DateTime> createDate = const Value.absent(),
                Value<DateTime?> lastModifiedDate = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> attachments = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                uuid: uuid,
                subject: subject,
                content: content,
                authorId: authorId,
                catalogId: catalogId,
                parentNoteId: parentNoteId,
                deletedAt: deletedAt,
                version: version,
                createDate: createDate,
                lastModifiedDate: lastModifiedDate,
                description: description,
                attachments: attachments,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> uuid = const Value.absent(),
                required String subject,
                Value<String?> content = const Value.absent(),
                required int authorId,
                Value<int?> catalogId = const Value.absent(),
                Value<int?> parentNoteId = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<Uint8List?> version = const Value.absent(),
                Value<DateTime> createDate = const Value.absent(),
                Value<DateTime?> lastModifiedDate = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> attachments = const Value.absent(),
              }) => NotesCompanion.insert(
                id: id,
                uuid: uuid,
                subject: subject,
                content: content,
                authorId: authorId,
                catalogId: catalogId,
                parentNoteId: parentNoteId,
                deletedAt: deletedAt,
                version: version,
                createDate: createDate,
                lastModifiedDate: lastModifiedDate,
                description: description,
                attachments: attachments,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$NotesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                authorId = false,
                catalogId = false,
                parentNoteId = false,
                noteTagRefsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (noteTagRefsRefs) db.noteTagRefs,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (authorId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.authorId,
                                    referencedTable: $$NotesTableReferences
                                        ._authorIdTable(db),
                                    referencedColumn: $$NotesTableReferences
                                        ._authorIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (catalogId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.catalogId,
                                    referencedTable: $$NotesTableReferences
                                        ._catalogIdTable(db),
                                    referencedColumn: $$NotesTableReferences
                                        ._catalogIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (parentNoteId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.parentNoteId,
                                    referencedTable: $$NotesTableReferences
                                        ._parentNoteIdTable(db),
                                    referencedColumn: $$NotesTableReferences
                                        ._parentNoteIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (noteTagRefsRefs)
                        await $_getPrefetchedData<
                          Note,
                          $NotesTable,
                          NoteTagRef
                        >(
                          currentTable: table,
                          referencedTable: $$NotesTableReferences
                              ._noteTagRefsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NotesTableReferences(
                                db,
                                table,
                                p0,
                              ).noteTagRefsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.noteId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$HmmDatabase,
      $NotesTable,
      Note,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (Note, $$NotesTableReferences),
      Note,
      PrefetchHooks Function({
        bool authorId,
        bool catalogId,
        bool parentNoteId,
        bool noteTagRefsRefs,
      })
    >;
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> description,
      Value<bool> isActivated,
      Value<DateTime> lastModified,
      Value<DateTime?> deletedAt,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> description,
      Value<bool> isActivated,
      Value<DateTime> lastModified,
      Value<DateTime?> deletedAt,
    });

final class $$TagsTableReferences
    extends BaseReferences<_$HmmDatabase, $TagsTable, Tag> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$NoteTagRefsTable, List<NoteTagRef>>
  _noteTagRefsRefsTable(_$HmmDatabase db) => MultiTypedResultKey.fromTable(
    db.noteTagRefs,
    aliasName: $_aliasNameGenerator(db.tags.id, db.noteTagRefs.tagId),
  );

  $$NoteTagRefsTableProcessedTableManager get noteTagRefsRefs {
    final manager = $$NoteTagRefsTableTableManager(
      $_db,
      $_db.noteTagRefs,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_noteTagRefsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagsTableFilterComposer extends Composer<_$HmmDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActivated => $composableBuilder(
    column: $table.isActivated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> noteTagRefsRefs(
    Expression<bool> Function($$NoteTagRefsTableFilterComposer f) f,
  ) {
    final $$NoteTagRefsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTagRefs,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTagRefsTableFilterComposer(
            $db: $db,
            $table: $db.noteTagRefs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableOrderingComposer extends Composer<_$HmmDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActivated => $composableBuilder(
    column: $table.isActivated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$HmmDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActivated => $composableBuilder(
    column: $table.isActivated,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> noteTagRefsRefs<T extends Object>(
    Expression<T> Function($$NoteTagRefsTableAnnotationComposer a) f,
  ) {
    final $$NoteTagRefsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTagRefs,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTagRefsTableAnnotationComposer(
            $db: $db,
            $table: $db.noteTagRefs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$HmmDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, $$TagsTableReferences),
          Tag,
          PrefetchHooks Function({bool noteTagRefsRefs})
        > {
  $$TagsTableTableManager(_$HmmDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> isActivated = const Value.absent(),
                Value<DateTime> lastModified = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                name: name,
                description: description,
                isActivated: isActivated,
                lastModified: lastModified,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> description = const Value.absent(),
                Value<bool> isActivated = const Value.absent(),
                Value<DateTime> lastModified = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                name: name,
                description: description,
                isActivated: isActivated,
                lastModified: lastModified,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TagsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({noteTagRefsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (noteTagRefsRefs) db.noteTagRefs],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (noteTagRefsRefs)
                    await $_getPrefetchedData<Tag, $TagsTable, NoteTagRef>(
                      currentTable: table,
                      referencedTable: $$TagsTableReferences
                          ._noteTagRefsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TagsTableReferences(db, table, p0).noteTagRefsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$HmmDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, $$TagsTableReferences),
      Tag,
      PrefetchHooks Function({bool noteTagRefsRefs})
    >;
typedef $$NoteTagRefsTableCreateCompanionBuilder =
    NoteTagRefsCompanion Function({
      required int noteId,
      required int tagId,
      Value<int> rowid,
    });
typedef $$NoteTagRefsTableUpdateCompanionBuilder =
    NoteTagRefsCompanion Function({
      Value<int> noteId,
      Value<int> tagId,
      Value<int> rowid,
    });

final class $$NoteTagRefsTableReferences
    extends BaseReferences<_$HmmDatabase, $NoteTagRefsTable, NoteTagRef> {
  $$NoteTagRefsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NotesTable _noteIdTable(_$HmmDatabase db) => db.notes.createAlias(
    $_aliasNameGenerator(db.noteTagRefs.noteId, db.notes.id),
  );

  $$NotesTableProcessedTableManager get noteId {
    final $_column = $_itemColumn<int>('note_id')!;

    final manager = $$NotesTableTableManager(
      $_db,
      $_db.notes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagsTable _tagIdTable(_$HmmDatabase db) => db.tags.createAlias(
    $_aliasNameGenerator(db.noteTagRefs.tagId, db.tags.id),
  );

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<int>('tag_id')!;

    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NoteTagRefsTableFilterComposer
    extends Composer<_$HmmDatabase, $NoteTagRefsTable> {
  $$NoteTagRefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$NotesTableFilterComposer get noteId {
    final $$NotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableFilterComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteTagRefsTableOrderingComposer
    extends Composer<_$HmmDatabase, $NoteTagRefsTable> {
  $$NoteTagRefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$NotesTableOrderingComposer get noteId {
    final $$NotesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableOrderingComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteTagRefsTableAnnotationComposer
    extends Composer<_$HmmDatabase, $NoteTagRefsTable> {
  $$NoteTagRefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$NotesTableAnnotationComposer get noteId {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableAnnotationComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteTagRefsTableTableManager
    extends
        RootTableManager<
          _$HmmDatabase,
          $NoteTagRefsTable,
          NoteTagRef,
          $$NoteTagRefsTableFilterComposer,
          $$NoteTagRefsTableOrderingComposer,
          $$NoteTagRefsTableAnnotationComposer,
          $$NoteTagRefsTableCreateCompanionBuilder,
          $$NoteTagRefsTableUpdateCompanionBuilder,
          (NoteTagRef, $$NoteTagRefsTableReferences),
          NoteTagRef,
          PrefetchHooks Function({bool noteId, bool tagId})
        > {
  $$NoteTagRefsTableTableManager(_$HmmDatabase db, $NoteTagRefsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteTagRefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteTagRefsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteTagRefsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> noteId = const Value.absent(),
                Value<int> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteTagRefsCompanion(
                noteId: noteId,
                tagId: tagId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int noteId,
                required int tagId,
                Value<int> rowid = const Value.absent(),
              }) => NoteTagRefsCompanion.insert(
                noteId: noteId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$NoteTagRefsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({noteId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (noteId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.noteId,
                                referencedTable: $$NoteTagRefsTableReferences
                                    ._noteIdTable(db),
                                referencedColumn: $$NoteTagRefsTableReferences
                                    ._noteIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable: $$NoteTagRefsTableReferences
                                    ._tagIdTable(db),
                                referencedColumn: $$NoteTagRefsTableReferences
                                    ._tagIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$NoteTagRefsTableProcessedTableManager =
    ProcessedTableManager<
      _$HmmDatabase,
      $NoteTagRefsTable,
      NoteTagRef,
      $$NoteTagRefsTableFilterComposer,
      $$NoteTagRefsTableOrderingComposer,
      $$NoteTagRefsTableAnnotationComposer,
      $$NoteTagRefsTableCreateCompanionBuilder,
      $$NoteTagRefsTableUpdateCompanionBuilder,
      (NoteTagRef, $$NoteTagRefsTableReferences),
      NoteTagRef,
      PrefetchHooks Function({bool noteId, bool tagId})
    >;

class $HmmDatabaseManager {
  final _$HmmDatabase _db;
  $HmmDatabaseManager(this._db);
  $$AuthorsTableTableManager get authors =>
      $$AuthorsTableTableManager(_db, _db.authors);
  $$NoteCatalogsTableTableManager get noteCatalogs =>
      $$NoteCatalogsTableTableManager(_db, _db.noteCatalogs);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$NoteTagRefsTableTableManager get noteTagRefs =>
      $$NoteTagRefsTableTableManager(_db, _db.noteTagRefs);
}
