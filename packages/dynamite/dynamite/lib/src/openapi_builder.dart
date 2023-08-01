part of '../dynamite.dart';

class OpenAPIBuilder implements Builder {
  @override
  final buildExtensions = const {
    '.openapi.json': ['.openapi.dart'],
  };

  @override
  Future<void> build(final BuildStep buildStep) async {
    try {
      final inputId = buildStep.inputId;
      final outputId = inputId.changeExtension('.dart');

      final emitter = DartEmitter(
        orderDirectives: true,
        useNullSafetySyntax: true,
      );

      final spec = OpenAPI.fromJson(
        json.decode(
          await buildStep.readAsString(inputId),
        ) as Map<String, dynamic>,
      );
      final classPrefix = _toDartName(spec.info.title, uppercaseFirstCharacter: true);
      final variablePrefix = _toDartName(spec.info.title);
      final supportedVersions = ['3.0.3', '3.1.0'];
      if (!supportedVersions.contains(spec.version)) {
        throw Exception('Only OpenAPI ${supportedVersions.join(', ')} are supported');
      }

      var tags = <String?>[
        null,
        if (spec.paths != null) ...{
          for (final pathItem in spec.paths!.values) ...{
            for (final operation in pathItem.operations.values) ...{
              ...?operation.tags,
            },
          },
        },
      ];
      for (final tag in tags.toList()) {
        final tagPart = tag?.split('/').first;
        if (!tags.contains(tagPart)) {
          tags.add(tagPart);
        }
      }
      tags = tags
        ..sort(
          (final a, final b) => a == null
              ? -1
              : b == null
                  ? 1
                  : a.compareTo(b),
        );

      final hasAnySecurity = spec.components?.securitySchemes?.isNotEmpty ?? false;

      final state = State(classPrefix);
      final output = <String>[
        '// ignore_for_file: camel_case_types',
        '// ignore_for_file: public_member_api_docs',
        "import 'dart:convert';",
        "import 'dart:typed_data';",
        '',
        "import 'package:built_collection/built_collection.dart';",
        "import 'package:built_value/built_value.dart';",
        "import 'package:built_value/json_object.dart';",
        "import 'package:built_value/serializer.dart';",
        "import 'package:built_value/standard_json_plugin.dart';",
        "import 'package:dynamite_runtime/content_string.dart';",
        "import 'package:dynamite_runtime/http_client.dart';",
        "import 'package:universal_io/io.dart';",
        '',
        "export 'package:dynamite_runtime/http_client.dart';",
        '',
        "part '${p.basename(outputId.changeExtension('.g.dart').path)}';",
        '',
        Class(
          (final b) => b
            ..name = '${classPrefix}Response'
            ..types.addAll([
              refer('T'),
              refer('U'),
            ])
            ..extend = refer('DynamiteResponse<T, U>')
            ..constructors.add(
              Constructor(
                (final b) => b
                  ..requiredParameters.addAll(
                    ['data', 'headers'].map(
                      (final name) => Parameter(
                        (final b) => b
                          ..name = name
                          ..toSuper = true,
                      ),
                    ),
                  ),
              ),
            )
            ..methods.add(
              Method(
                (final b) => b
                  ..name = 'toString'
                  ..returns = refer('String')
                  ..annotations.add(refer('override'))
                  ..lambda = true
                  ..body = Code(
                    "'${classPrefix}Response(data: \$data, headers: \$headers)'",
                  ),
              ),
            ),
        ).accept(emitter).toString(),
        Class(
          (final b) => b
            ..name = '${classPrefix}ApiException'
            ..extend = refer('DynamiteApiException')
            ..constructors.add(
              Constructor(
                (final b) => b
                  ..requiredParameters.addAll(
                    ['statusCode', 'headers', 'body'].map(
                      (final name) => Parameter(
                        (final b) => b
                          ..name = name
                          ..toSuper = true,
                      ),
                    ),
                  ),
              ),
            )
            ..methods.addAll([
              Method(
                (final b) => b
                  ..name = 'fromResponse'
                  ..returns = refer('Future<${classPrefix}ApiException>')
                  ..static = true
                  ..modifier = MethodModifier.async
                  ..requiredParameters.add(
                    Parameter(
                      (final b) => b
                        ..name = 'response'
                        ..type = refer('HttpClientResponse'),
                    ),
                  )
                  ..body = Block.of([
                    const Code('final data = await response.bodyBytes;'),
                    const Code(''),
                    const Code('String body;'),
                    const Code('try {'),
                    const Code('body = utf8.decode(data);'),
                    const Code('} on FormatException {'),
                    const Code("body = 'binary';"),
                    const Code('}'),
                    const Code(''),
                    Code('return ${classPrefix}ApiException('),
                    const Code('response.statusCode,'),
                    const Code('response.responseHeaders,'),
                    const Code('body,'),
                    const Code(');'),
                  ]),
              ),
              Method(
                (final b) => b
                  ..name = 'toString'
                  ..returns = refer('String')
                  ..annotations.add(refer('override'))
                  ..lambda = true
                  ..body = Code(
                    "'${classPrefix}ApiException(statusCode: \$statusCode, headers: \$headers, body: \$body)'",
                  ),
              ),
            ]),
        ).accept(emitter).toString(),
      ];

      for (final tag in tags) {
        final isRootClient = tag == null;
        final paths = <String, PathItem>{};

        if (spec.paths != null) {
          for (final path in spec.paths!.keys) {
            final pathItem = spec.paths![path]!;
            for (final method in pathItem.operations.keys) {
              final operation = pathItem.operations[method]!;
              if ((tag != null && operation.tags != null && operation.tags!.contains(tag)) ||
                  (tag == null && (operation.tags == null || operation.tags!.isEmpty))) {
                if (paths[path] == null) {
                  paths[path] = PathItem(
                    description: pathItem.description,
                    parameters: pathItem.parameters,
                  );
                }
                paths[path] = paths[path]!.copyWithOperations({method: operation});
              }
            }
          }
        }

        output.add(
          Class(
            (final b) {
              if (isRootClient) {
                b
                  ..extend = refer('DynamiteClient')
                  ..constructors.addAll([
                    Constructor(
                      (final b) => b
                        ..requiredParameters.add(
                          Parameter(
                            (final b) => b
                              ..name = 'baseURL'
                              ..toSuper = true,
                          ),
                        )
                        ..optionalParameters.addAll([
                          Parameter(
                            (final b) => b
                              ..name = 'baseHeaders'
                              ..toSuper = true
                              ..named = true,
                          ),
                          Parameter(
                            (final b) => b
                              ..name = 'userAgent'
                              ..toSuper = true
                              ..named = true,
                          ),
                          Parameter(
                            (final b) => b
                              ..name = 'httpClient'
                              ..toSuper = true
                              ..named = true,
                          ),
                          Parameter(
                            (final b) => b
                              ..name = 'cookieJar'
                              ..toSuper = true
                              ..named = true,
                          ),
                          if (hasAnySecurity) ...[
                            Parameter(
                              (final b) => b
                                ..name = 'authentications'
                                ..toSuper = true
                                ..named = true,
                            ),
                          ],
                        ]),
                    ),
                    Constructor(
                      (final b) => b
                        ..name = 'fromClient'
                        ..requiredParameters.add(
                          Parameter(
                            (final b) => b
                              ..name = 'client'
                              ..type = refer('DynamiteClient'),
                          ),
                        )
                        ..initializers.add(
                          const Code('''
                            super(
                              client.baseURL,
                              baseHeaders: client.baseHeaders,
                              httpClient: client.httpClient,
                              cookieJar: client.cookieJar,
                              authentications: client.authentications,
                            )
                          '''),
                        ),
                    ),
                  ]);
              } else {
                b
                  ..fields.add(
                    Field(
                      (final b) => b
                        ..name = 'rootClient'
                        ..type = refer('${classPrefix}Client')
                        ..modifier = FieldModifier.final$,
                    ),
                  )
                  ..constructors.add(
                    Constructor(
                      (final b) => b.requiredParameters.add(
                        Parameter(
                          (final b) => b
                            ..name = 'rootClient'
                            ..toThis = true,
                        ),
                      ),
                    ),
                  );
              }
              final matchedTags = spec.tags?.where((final t) => t.name == tag).toList();
              b
                ..name = '$classPrefix${isRootClient ? 'Client' : _clientName(tag)}'
                ..docs.addAll(
                  _descriptionToDocs(
                    matchedTags != null && matchedTags.isNotEmpty ? matchedTags.single.description : null,
                  ),
                )
                ..methods.addAll(
                  [
                    for (final t in tags
                        .whereType<String>()
                        .where(
                          (final t) => (tag != null && (t.startsWith('$tag/'))) || (tag == null && !t.contains('/')),
                        )
                        .toList()) ...[
                      Method(
                        (final b) => b
                          ..name = _toDartName(tag == null ? t : t.substring('$tag/'.length))
                          ..lambda = true
                          ..type = MethodType.getter
                          ..returns = refer('$classPrefix${_clientName(t)}')
                          ..body = Code('$classPrefix${_clientName(t)}(${isRootClient ? 'this' : 'rootClient'})'),
                      ),
                    ],
                    for (final path in paths.keys) ...[
                      for (final httpMethod in paths[path]!.operations.keys) ...[
                        Method(
                          (final b) {
                            final operation = paths[path]!.operations[httpMethod]!;
                            final operationId = operation.operationId ?? _toDartName('$httpMethod-$path');
                            final pathParameters = <spec_parameter.Parameter>[
                              if (paths[path]!.parameters != null) ...paths[path]!.parameters!,
                            ];
                            final parameters = <spec_parameter.Parameter>[
                              ...pathParameters,
                              if (operation.parameters != null) ...operation.parameters!,
                            ]..sort(
                                (final a, final b) => sortRequiredElements(
                                  _isDartParameterRequired(
                                    a.required,
                                    a.schema?.default_,
                                  ),
                                  _isDartParameterRequired(
                                    b.required,
                                    b.schema?.default_,
                                  ),
                                ),
                              );
                            b
                              ..name = _toDartName(_filterMethodName(operationId, tag ?? ''))
                              ..modifier = MethodModifier.async
                              ..docs.addAll([
                                ..._descriptionToDocs(operation.summary),
                                if (operation.summary != null && operation.description != null) ...[
                                  '///',
                                ],
                                ..._descriptionToDocs(operation.description),
                              ]);
                            if (operation.deprecated ?? false) {
                              b.annotations.add(refer('Deprecated').call([refer("''")]));
                            }

                            final acceptHeader = (operation.responses?.values
                                        .map((final response) => response.content?.keys)
                                        .whereNotNull()
                                        .expand((final element) => element)
                                        .toSet() ??
                                    {})
                                .join(',');
                            final code = StringBuffer('''
                            var path = '$path';
                            final queryParameters = <String, dynamic>{};
                            final headers = <String, String>{${acceptHeader.isNotEmpty ? "'Accept': '$acceptHeader'," : ''}};
                            Uint8List? body;
                          ''');

                            final security = operation.security ?? spec.security ?? [];
                            final securityRequirements = security.where((final requirement) => requirement.isNotEmpty);
                            final isOptionalSecurity = securityRequirements.length != security.length;
                            for (final requirement in securityRequirements) {
                              final securityScheme = spec.components!.securitySchemes![requirement.keys.single]!;
                              code.write('''
                                if (${isRootClient ? '' : 'rootClient.'}authentications.where((final a) => a.type == '${securityScheme.type}' && a.scheme == '${securityScheme.scheme}').isNotEmpty) {
                                  headers.addAll(${isRootClient ? '' : 'rootClient.'}authentications.singleWhere((final a) => a.type == '${securityScheme.type}' && a.scheme == '${securityScheme.scheme}').headers);
                                }
                              ''');
                              if (securityRequirements.last != requirement) {
                                code.write('else');
                              }
                            }
                            if (securityRequirements.isNotEmpty && !isOptionalSecurity) {
                              code.write('''
                                else {
                                  throw Exception('Missing authentication for ${securityRequirements.map((final r) => r.keys.single).join(' or ')}'); // coverage:ignore-line
                                }
                              ''');
                            }

                            for (final parameter in parameters) {
                              final dartParameterNullable = _isDartParameterNullable(
                                parameter.required,
                                parameter.schema?.nullable,
                                parameter.schema?.default_,
                              );
                              final dartParameterRequired = _isDartParameterRequired(
                                parameter.required,
                                parameter.schema?.default_,
                              );

                              final result = resolveType(
                                spec,
                                variablePrefix,
                                state,
                                _toDartName(
                                  '$operationId-${parameter.name}',
                                  uppercaseFirstCharacter: true,
                                ),
                                parameter.schema!,
                                nullable: dartParameterNullable,
                              ).dartType;

                              if (result.name == 'String') {
                                if (parameter.schema?.pattern != null) {
                                  code.write('''
                                  if (!RegExp(r'${parameter.schema!.pattern!}').hasMatch(${_toDartName(parameter.name)})) {
                                    throw Exception('Invalid value "\$${_toDartName(parameter.name)}" for parameter "${_toDartName(parameter.name)}" with pattern "\${r'${parameter.schema!.pattern!}'}"'); // coverage:ignore-line
                                  }
                                  ''');
                                }
                                if (parameter.schema?.minLength != null) {
                                  code.write('''
                                  if (${_toDartName(parameter.name)}.length < ${parameter.schema!.minLength!}) {
                                    throw Exception('Parameter "${_toDartName(parameter.name)}" has to be at least ${parameter.schema!.minLength!} characters long'); // coverage:ignore-line
                                  }
                                  ''');
                                }
                                if (parameter.schema?.maxLength != null) {
                                  code.write('''
                                  if (${_toDartName(parameter.name)}.length > ${parameter.schema!.maxLength!}) {
                                    throw Exception('Parameter "${_toDartName(parameter.name)}" has to be at most ${parameter.schema!.maxLength!} characters long'); // coverage:ignore-line
                                  }
                                  ''');
                                }
                              }

                              final defaultValueCode = parameter.schema?.default_ != null
                                  ? _valueToEscapedValue(result, parameter.schema!.default_!.toString())
                                  : null;

                              b.optionalParameters.add(
                                Parameter(
                                  (final b) {
                                    b
                                      ..named = true
                                      ..name = _toDartName(parameter.name)
                                      ..required = dartParameterRequired;
                                    if (parameter.schema != null) {
                                      b.type = refer(result.nullableName);
                                    }
                                    if (defaultValueCode != null) {
                                      b.defaultTo = Code(defaultValueCode);
                                    }
                                  },
                                ),
                              );

                              if (dartParameterNullable) {
                                code.write('if (${_toDartName(parameter.name)} != null) {');
                              }
                              final value = result.encode(
                                _toDartName(parameter.name),
                                onlyChildren: result is TypeResultList && parameter.in_ == 'query',
                                // Objects inside the query always have to be interpreted in some way
                                mimeType: 'application/json',
                              );
                              if (defaultValueCode != null && parameter.in_ == 'query') {
                                code.write('if (${_toDartName(parameter.name)} != $defaultValueCode) {');
                              }
                              switch (parameter.in_) {
                                case 'path':
                                  code.write(
                                    "path = path.replaceAll('{${parameter.name}}', Uri.encodeQueryComponent($value));",
                                  );
                                  break;
                                case 'query':
                                  code.write(
                                    "queryParameters['${parameter.name}${result is TypeResultList ? '[]' : ''}'] = $value;",
                                  );
                                  break;
                                case 'header':
                                  code.write(
                                    "headers['${parameter.name}'] = $value;",
                                  );
                                  break;
                                default:
                                  throw Exception('Can not work with parameter in "${parameter.in_}"');
                              }
                              if (defaultValueCode != null && parameter.in_ == 'query') {
                                code.write('}');
                              }
                              if (dartParameterNullable) {
                                code.write('}');
                              }
                            }

                            if (operation.requestBody != null) {
                              if (operation.requestBody!.content!.length > 1) {
                                throw Exception('Can not work with multiple mime types right now');
                              }
                              for (final mimeType in operation.requestBody!.content!.keys) {
                                final mediaType = operation.requestBody!.content![mimeType]!;

                                code.write("headers['Content-Type'] = '$mimeType';");

                                final dartParameterNullable = _isDartParameterNullable(
                                  operation.requestBody!.required,
                                  mediaType.schema?.nullable,
                                  mediaType.schema?.default_,
                                );

                                final result = resolveType(
                                  spec,
                                  variablePrefix,
                                  state,
                                  _toDartName('$operationId-request-$mimeType', uppercaseFirstCharacter: true),
                                  mediaType.schema!,
                                  nullable: dartParameterNullable,
                                );
                                final parameterName = _toDartName(result.name.replaceFirst(classPrefix, ''));
                                switch (mimeType) {
                                  case 'application/json':
                                  case 'application/x-www-form-urlencoded':
                                    final dartParameterRequired = _isDartParameterRequired(
                                      operation.requestBody!.required,
                                      mediaType.schema?.default_,
                                    );
                                    b.optionalParameters.add(
                                      Parameter(
                                        (final b) => b
                                          ..name = parameterName
                                          ..type = refer(result.nullableName)
                                          ..named = true
                                          ..required = dartParameterRequired,
                                      ),
                                    );

                                    if (dartParameterNullable) {
                                      code.write('if ($parameterName != null) {');
                                    }
                                    code.write(
                                      'body = Uint8List.fromList(utf8.encode(${result.encode(parameterName, mimeType: mimeType)}));',
                                    );
                                    if (dartParameterNullable) {
                                      code.write('}');
                                    }
                                    break;
                                  default:
                                    throw Exception('Can not parse mime type "$mimeType"');
                                }
                              }
                            }

                            code.write(
                              '''
                            final response = await ${isRootClient ? '' : 'rootClient.'}doRequest(
                              '$httpMethod',
                              Uri(path: path, queryParameters: queryParameters.isNotEmpty ? queryParameters : null).toString(),
                              headers,
                              body,
                            );
                          ''',
                            );

                            if (operation.responses != null) {
                              if (operation.responses!.length > 1) {
                                throw Exception('Can not work with multiple status codes right now');
                              }
                              for (final statusCode in operation.responses!.keys) {
                                final response = operation.responses![statusCode]!;
                                code.write('if (response.statusCode == $statusCode) {');

                                String? headersType;
                                String? headersValue;
                                if (response.headers != null) {
                                  final identifier =
                                      '${tag != null ? _toDartName(tag, uppercaseFirstCharacter: true) : null}${_toDartName(operationId, uppercaseFirstCharacter: true)}Headers';
                                  final result = resolveObject(
                                    spec,
                                    variablePrefix,
                                    state,
                                    identifier,
                                    Schema(
                                      properties: response.headers!.map(
                                        (final headerName, final value) => MapEntry(
                                          headerName.toLowerCase(),
                                          value.schema!,
                                        ),
                                      ),
                                    ),
                                    isHeader: true,
                                  );
                                  headersType = result.name;
                                  headersValue = result.deserialize('response.responseHeaders');
                                }

                                String? dataType;
                                String? dataValue;
                                bool? dataNeedsAwait;
                                if (response.content != null) {
                                  if (response.content!.length > 1) {
                                    throw Exception('Can not work with multiple mime types right now');
                                  }
                                  for (final mimeType in response.content!.keys) {
                                    final mediaType = response.content![mimeType]!;

                                    final result = resolveType(
                                      spec,
                                      variablePrefix,
                                      state,
                                      _toDartName(
                                        '$operationId-response-$statusCode-$mimeType',
                                        uppercaseFirstCharacter: true,
                                      ),
                                      mediaType.schema!,
                                    );

                                    if (mimeType == '*/*' ||
                                        mimeType == 'application/octet-stream' ||
                                        mimeType.startsWith('image/')) {
                                      dataType = 'Uint8List';
                                      dataValue = 'response.bodyBytes';
                                      dataNeedsAwait = true;
                                    } else if (mimeType.startsWith('text/')) {
                                      dataType = 'String';
                                      dataValue = 'response.body';
                                      dataNeedsAwait = true;
                                    } else if (mimeType == 'application/json') {
                                      dataType = result.name;
                                      if (result.name == 'dynamic') {
                                        dataValue = '';
                                      } else if (result.name == 'String') {
                                        dataValue = 'response.body';
                                        dataNeedsAwait = true;
                                      } else if (result is TypeResultEnum || result is TypeResultBase) {
                                        dataValue = result.deserialize(result.decode('await response.body'));
                                        dataNeedsAwait = false;
                                      } else {
                                        dataValue = result.deserialize('await response.jsonBody');
                                        dataNeedsAwait = false;
                                      }
                                    } else {
                                      throw Exception('Can not parse mime type "$mimeType"');
                                    }
                                  }
                                }

                                if (headersType != null && dataType != null) {
                                  b.returns = refer('Future<${classPrefix}Response<$dataType, $headersType>>');
                                  code.write(
                                    'return ${classPrefix}Response<$dataType, $headersType>(${dataNeedsAwait ?? false ? 'await ' : ''}$dataValue, $headersValue,);',
                                  );
                                } else if (headersType != null) {
                                  b.returns = refer('Future<$headersType>');
                                  code.write('return $headersValue;');
                                } else if (dataType != null) {
                                  b.returns = refer('Future<$dataType>');
                                  code.write('return $dataValue;');
                                } else {
                                  b.returns = refer('Future');
                                  code.write('return;');
                                }

                                code.write('}');
                              }
                              code.write(
                                'throw await ${classPrefix}ApiException.fromResponse(response); // coverage:ignore-line\n',
                              );
                            } else {
                              b.returns = refer('Future');
                            }
                            b.body = Code(code.toString());
                          },
                        ),
                      ],
                    ],
                  ],
                );
            },
          ).accept(emitter).toString(),
        );
      }

      if (spec.components?.schemas != null) {
        for (final name in spec.components!.schemas!.keys) {
          final schema = spec.components!.schemas![name]!;

          final identifier = _toDartName(name, uppercaseFirstCharacter: true);
          if (schema.type == null && schema.ref == null && schema.ofs == null) {
            output.add('typedef $identifier = dynamic;');
          } else {
            final result = resolveType(
              spec,
              variablePrefix,
              state,
              identifier,
              schema,
            );
            if (result is TypeResultBase) {
              output.add('typedef $identifier = ${result.name};');
            }
          }
        }
      }

      output.addAll(state.output.map((final e) => e.accept(emitter).toString()));

      if (state.resolvedTypes.isNotEmpty) {
        output.addAll([
          'final Serializers _serializers = (Serializers().toBuilder()',
          ...state.resolvedTypes.map((final type) => type.serializers).expand((final element) => element).toSet(),
          ').build();',
          '',
          'Serializers get ${variablePrefix}Serializers => _serializers;',
          '',
          'final Serializers _jsonSerializers = (_serializers.toBuilder()..addPlugin(StandardJsonPlugin())..addPlugin(const ContentStringPlugin())).build();',
          '',
          '// coverage:ignore-start',
          'T deserialize$classPrefix<T>(final Object data) => _serializers.deserialize(data, specifiedType: FullType(T))! as T;',
          '',
          'Object? serialize$classPrefix<T>(final T data) => _serializers.serialize(data, specifiedType: FullType(T));',
          '// coverage:ignore-end',
        ]);
      }

      final formatter = DartFormatter(
        pageWidth: 120,
      );
      const coverageIgnoreStart = '  // coverage:ignore-start';
      const coverageIgnoreEnd = '  // coverage:ignore-end';
      final patterns = [
        RegExp(
          r'factory .*\.fromJson\(Map<String, dynamic> json\) => _\$.*FromJson\(json\);',
        ),
        RegExp(
          r'Map<String, dynamic> toJson\(\) => _\$.*ToJson\(this\);',
        ),
        RegExp(
          r'dynamic toJson\(\) => _data;',
        ),
      ];
      var outputString = output.join('\n');
      for (final pattern in patterns) {
        outputString = outputString.replaceAllMapped(
          pattern,
          (final match) => '$coverageIgnoreStart\n${match.group(0)}\n$coverageIgnoreEnd',
        );
      }
      await buildStep.writeAsString(
        outputId,
        formatter.format(outputString),
      );
    } catch (e, s) {
      print(s);

      rethrow;
    }
  }
}

String _clientName(final String tag) => '${_toDartName(tag, uppercaseFirstCharacter: true)}Client';

String _toDartName(
  final String name, {
  final bool uppercaseFirstCharacter = false,
}) {
  var result = '';
  var upperCase = uppercaseFirstCharacter;
  var firstCharacter = !uppercaseFirstCharacter;
  for (final char in name.split('')) {
    if (_isNonAlphaNumericString(char)) {
      upperCase = true;
    } else {
      result += firstCharacter ? char.toLowerCase() : (upperCase ? char.toUpperCase() : char);
      upperCase = false;
      firstCharacter = false;
    }
  }

  if (_dartKeywords.contains(result) || RegExp(r'^[0-9]+$', multiLine: true).hasMatch(result)) {
    return '\$$result';
  }

  return result;
}

final _dartKeywords = [
  'assert',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'default',
  'do',
  'else',
  'enum',
  'extends',
  'false',
  'final',
  'finally',
  'for',
  'if',
  'in',
  'is',
  'new',
  'null',
  'rethrow',
  'return',
  'super',
  'switch',
  'this',
  'throw',
  'true',
  'try',
  'var',
  'void',
  'while',
  'with',
  'async',
  'hide',
  'on',
  'show',
  'sync',
  'abstract',
  'as',
  'covariant',
  'deferred',
  'dynamic',
  'export',
  'extension',
  'external',
  'factory',
  'function',
  'get',
  'implements',
  'import',
  'interface',
  'library',
  'mixin',
  'operator',
  'part',
  'set',
  'static',
  'typedef',
];

bool _isNonAlphaNumericString(final String input) => !RegExp(r'^[a-zA-Z0-9]$').hasMatch(input);

String _toFieldName(final String dartName, final String type) => dartName == type ? '\$$dartName' : dartName;

bool _isDartParameterNullable(
  final bool? required,
  final bool? nullable,
  final dynamic default_,
) =>
    (!(required ?? false) && default_ == null) || (nullable ?? false);

bool _isDartParameterRequired(
  final bool? required,
  final dynamic default_,
) =>
    (required ?? false) && default_ == null;

String _valueToEscapedValue(final TypeResult result, final dynamic value) {
  if (result is TypeResultBase && result.name == 'String') {
    return "'$value'";
  }
  if (result is TypeResultList) {
    return 'const $value';
  }
  if (result is TypeResultEnum) {
    return '${result.name}.${_toDartName(value.toString())}';
  }
  return value.toString();
}

String _toCamelCase(final String name) {
  var result = '';
  var upperCase = false;
  var firstCharacter = true;
  for (final char in name.split('')) {
    if (char == '_') {
      upperCase = true;
    } else if (char == r'$') {
      result += r'$';
    } else {
      result += firstCharacter ? char.toLowerCase() : (upperCase ? char.toUpperCase() : char);
      upperCase = false;
      firstCharacter = false;
    }
  }
  return result;
}

List<String> _descriptionToDocs(final String? description) => [
      if (description != null && description.isNotEmpty) ...[
        for (final line in description.split('\n')) ...[
          '/// $line',
        ],
      ],
    ];

String _filterMethodName(final String operationId, final String tag) {
  final expandedTag = tag.split('/').toList();
  final parts = operationId.split('-');
  final output = <String>[];
  for (var i = 0; i < parts.length; i++) {
    if (expandedTag.length <= i || expandedTag[i] != parts[i]) {
      output.add(parts[i]);
    }
  }
  return output.join('-');
}

class State {
  State(this.prefix);

  final String prefix;
  final output = <Spec>[];
  final resolvedTypes = <TypeResult>{};
}

TypeResult resolveObject(
  final OpenAPI spec,
  final String variablePrefix,
  final State state,
  final String identifier,
  final Schema schema, {
  final bool nullable = false,
  final bool isHeader = false,
}) {
  final result = TypeResultObject(
    '${state.prefix}$identifier',
    nullable: nullable,
  );
  if (state.resolvedTypes.add(result)) {
    state.output.add(
      Class(
        (final b) {
          b
            ..name = '${state.prefix}$identifier'
            ..docs.addAll(_descriptionToDocs(schema.description))
            ..abstract = true
            ..implements.add(
              refer(
                'Built<${state.prefix}$identifier, ${state.prefix}${identifier}Builder>',
              ),
            )
            ..constructors.addAll([
              Constructor(
                (final b) => b
                  ..name = '_'
                  ..constant = true,
              ),
              Constructor(
                (final b) => b
                  ..factory = true
                  ..lambda = true
                  ..optionalParameters.add(
                    Parameter(
                      (final b) => b
                        ..name = 'b'
                        ..type = refer('void Function(${state.prefix}${identifier}Builder)?'),
                    ),
                  )
                  ..redirect = refer('_\$${state.prefix}$identifier'),
              ),
              Constructor(
                (final b) => b
                  ..factory = true
                  ..name = 'fromJson'
                  ..lambda = true
                  ..requiredParameters.add(
                    Parameter(
                      (final b) => b
                        ..name = 'json'
                        ..type = refer('Map<String, dynamic>'),
                    ),
                  )
                  ..body = const Code('_jsonSerializers.deserializeWith(serializer, json)!'),
              ),
            ])
            ..methods.addAll([
              Method(
                (final b) => b
                  ..name = 'toJson'
                  ..returns = refer('Map<String, dynamic>')
                  ..lambda = true
                  ..body = const Code('_jsonSerializers.serializeWith(serializer, this)! as Map<String, dynamic>'),
              ),
              for (final propertyName in schema.properties!.keys) ...[
                Method(
                  (final b) {
                    final propertySchema = schema.properties![propertyName]!;
                    final result = resolveType(
                      spec,
                      variablePrefix,
                      state,
                      '${identifier}_${_toDartName(propertyName, uppercaseFirstCharacter: true)}',
                      propertySchema,
                      nullable: _isDartParameterNullable(
                        schema.required?.contains(propertyName),
                        propertySchema.nullable,
                        propertySchema.default_,
                      ),
                    );

                    b
                      ..name = _toDartName(propertyName)
                      ..returns = refer(result.nullableName)
                      ..type = MethodType.getter
                      ..docs.addAll(_descriptionToDocs(propertySchema.description));

                    if (_toDartName(propertyName) != propertyName) {
                      b.annotations.add(
                        refer('BuiltValueField').call([], {
                          'wireName': literalString(propertyName),
                        }),
                      );
                    }
                  },
                ),
              ],
              Method((final b) {
                b
                  ..name = 'serializer'
                  ..returns = refer('Serializer<${state.prefix}$identifier>')
                  ..lambda = true
                  ..static = true
                  ..body = Code(
                    isHeader
                        ? '_\$${state.prefix}${identifier}Serializer()'
                        : "_\$${_toCamelCase('${state.prefix}$identifier')}Serializer",
                  )
                  ..type = MethodType.getter;
                if (isHeader) {
                  b.annotations.add(refer('BuiltValueSerializer').call([], {'custom': refer('true')}));
                }
              }),
            ]);

          final defaults = <String>[];
          for (final propertyName in schema.properties!.keys) {
            final propertySchema = schema.properties![propertyName]!;
            if (propertySchema.default_ != null) {
              final value = propertySchema.default_!.toString();
              final result = resolveType(
                spec,
                variablePrefix,
                state,
                propertySchema.type!,
                propertySchema,
              );
              defaults.add('..${_toDartName(propertyName)} = ${_valueToEscapedValue(result, value)}');
            }
          }
          if (defaults.isNotEmpty) {
            b.methods.add(
              Method(
                (final b) => b
                  ..name = '_defaults'
                  ..returns = refer('void')
                  ..static = true
                  ..lambda = true
                  ..annotations.add(
                    refer('BuiltValueHook').call(
                      [],
                      {
                        'initializeBuilder': refer('true'),
                      },
                    ),
                  )
                  ..requiredParameters.add(
                    Parameter(
                      (final b) => b
                        ..name = 'b'
                        ..type = refer('${state.prefix}${identifier}Builder'),
                    ),
                  )
                  ..body = Code(
                    <String?>[
                      'b',
                      ...defaults,
                    ].join(),
                  ),
              ),
            );
          }
        },
      ),
    );
    if (isHeader) {
      state.output.add(
        Class(
          (final b) => b
            ..name = '_\$${state.prefix}${identifier}Serializer'
            ..implements.add(refer('StructuredSerializer<${state.prefix}$identifier>'))
            ..fields.addAll([
              Field(
                (final b) => b
                  ..name = 'types'
                  ..modifier = FieldModifier.final$
                  ..type = refer('Iterable<Type>')
                  ..annotations.add(refer('override'))
                  ..assignment = Code('const [${state.prefix}$identifier, _\$${state.prefix}$identifier]'),
              ),
              Field(
                (final b) => b
                  ..name = 'wireName'
                  ..modifier = FieldModifier.final$
                  ..type = refer('String')
                  ..annotations.add(refer('override'))
                  ..assignment = Code("r'${state.prefix}$identifier'"),
              )
            ])
            ..methods.addAll([
              Method((final b) {
                b
                  ..name = 'serialize'
                  ..returns = refer('Iterable<Object?>')
                  ..annotations.add(refer('override'))
                  ..requiredParameters.addAll([
                    Parameter(
                      (final b) => b
                        ..name = 'serializers'
                        ..type = refer('Serializers'),
                    ),
                    Parameter(
                      (final b) => b
                        ..name = 'object'
                        ..type = refer('${state.prefix}$identifier'),
                    ),
                  ])
                  ..optionalParameters.add(
                    Parameter(
                      (final b) => b
                        ..name = 'specifiedType'
                        ..type = refer('FullType')
                        ..named = true
                        ..defaultTo = const Code('FullType.unspecified'),
                    ),
                  )
                  ..body = const Code('throw UnimplementedError();');
              }),
              Method((final b) {
                b
                  ..name = 'deserialize'
                  ..returns = refer('${state.prefix}$identifier')
                  ..annotations.add(refer('override'))
                  ..requiredParameters.addAll([
                    Parameter(
                      (final b) => b
                        ..name = 'serializers'
                        ..type = refer('Serializers'),
                    ),
                    Parameter(
                      (final b) => b
                        ..name = 'serialized'
                        ..type = refer('Iterable<Object?>'),
                    ),
                  ])
                  ..optionalParameters.add(
                    Parameter(
                      (final b) => b
                        ..name = 'specifiedType'
                        ..type = refer('FullType')
                        ..named = true
                        ..defaultTo = const Code('FullType.unspecified'),
                    ),
                  );
                List<Code> deserializeProperty(final String propertyName) {
                  final propertySchema = schema.properties![propertyName]!;
                  final result = resolveType(
                    spec,
                    variablePrefix,
                    state,
                    '${identifier}_${_toDartName(propertyName, uppercaseFirstCharacter: true)}',
                    propertySchema,
                    nullable: _isDartParameterNullable(
                      schema.required?.contains(propertyName),
                      propertySchema.nullable,
                      propertySchema.default_,
                    ),
                  );

                  return [
                    Code("case '$propertyName':"),
                    if (result.className != 'String') ...[
                      if (result is TypeResultBase || result is TypeResultEnum) ...[
                        Code(
                          'result.${_toDartName(propertyName)} = ${result.deserialize(result.decode('value!'))};',
                        ),
                      ] else ...[
                        Code(
                          'result.${_toDartName(propertyName)}.replace(${result.deserialize(result.decode('value!'))});',
                        ),
                      ],
                    ] else ...[
                      Code(
                        'result.${_toDartName(propertyName)} = value!;',
                      ),
                    ],
                    const Code('break;'),
                  ];
                }

                b.body = Block.of([
                  Code('final result = new ${state.prefix}${identifier}Builder();'),
                  const Code(''),
                  const Code('final iterator = serialized.iterator;'),
                  const Code('while (iterator.moveNext()) {'),
                  const Code('final key = iterator.current! as String;'),
                  const Code('iterator.moveNext();'),
                  const Code('final value = iterator.current! as String;'),
                  const Code('switch (key) {'),
                  for (final propertyName in schema.properties!.keys) ...[
                    ...deserializeProperty(propertyName),
                  ],
                  const Code('}'),
                  const Code('}'),
                  const Code(''),
                  const Code('return result.build();'),
                ]);
              }),
            ]),
        ),
      );
    }
  }
  return result;
}

TypeResult resolveType(
  final OpenAPI spec,
  final String variablePrefix,
  final State state,
  final String identifier,
  final Schema schema, {
  final bool ignoreEnum = false,
  final bool nullable = false,
}) {
  TypeResult? result;
  if (schema.ref == null && schema.ofs == null && schema.type == null) {
    return TypeResultBase(
      'JsonObject',
      nullable: nullable,
    );
  }
  if (schema.ref != null) {
    final name = schema.ref!.split('/').last;
    result = resolveType(
      spec,
      variablePrefix,
      state,
      name,
      spec.components!.schemas![name]!,
      nullable: nullable,
    );
  } else if (schema.ofs != null) {
    result = TypeResultObject(
      '${state.prefix}$identifier',
      nullable: nullable,
    );
    if (state.resolvedTypes.add(result)) {
      final results = schema.ofs!
          .map(
            (final s) => resolveType(
              spec,
              variablePrefix,
              state,
              '$identifier${schema.ofs!.indexOf(s)}',
              s,
              nullable: !(schema.allOf?.contains(s) ?? false),
            ),
          )
          .toList();

      final fields = <String, String>{};
      for (final result in results) {
        final dartName = _toDartName(result.name.replaceFirst(state.prefix, ''));
        fields[result.name] = _toFieldName(dartName, result.name.replaceFirst(state.prefix, ''));
      }

      state.output.addAll([
        Class(
          (final b) {
            b
              ..name = '${state.prefix}$identifier'
              ..abstract = true
              ..implements.add(
                refer(
                  'Built<${state.prefix}$identifier, ${state.prefix}${identifier}Builder>',
                ),
              )
              ..constructors.addAll([
                Constructor(
                  (final b) => b
                    ..name = '_'
                    ..constant = true,
                ),
                Constructor(
                  (final b) => b
                    ..factory = true
                    ..lambda = true
                    ..optionalParameters.add(
                      Parameter(
                        (final b) => b
                          ..name = 'b'
                          ..type = refer('void Function(${state.prefix}${identifier}Builder)?'),
                      ),
                    )
                    ..redirect = refer('_\$${state.prefix}$identifier'),
                ),
              ])
              ..methods.addAll([
                Method(
                  (final b) {
                    b
                      ..name = 'data'
                      ..returns = refer('JsonObject')
                      ..type = MethodType.getter;
                  },
                ),
                for (final result in results) ...[
                  Method(
                    (final b) {
                      final s = schema.ofs![results.indexOf(result)];
                      b
                        ..name = fields[result.name]
                        ..returns = refer(result.nullableName)
                        ..type = MethodType.getter
                        ..docs.addAll(_descriptionToDocs(s.description));
                    },
                  ),
                ],
                Method(
                  (final b) => b
                    ..static = true
                    ..name = 'fromJson'
                    ..lambda = true
                    ..returns = refer('${state.prefix}$identifier')
                    ..requiredParameters.add(
                      Parameter(
                        (final b) => b
                          ..name = 'json'
                          ..type = refer('Object'),
                      ),
                    )
                    ..body = const Code('_jsonSerializers.deserializeWith(serializer, json)!'),
                ),
                Method(
                  (final b) => b
                    ..name = 'toJson'
                    ..returns = refer('Map<String, dynamic>')
                    ..lambda = true
                    ..body = const Code('_jsonSerializers.serializeWith(serializer, this)! as Map<String, dynamic>'),
                ),
                Method(
                  (final b) => b
                    ..name = 'serializer'
                    ..returns = refer('Serializer<${state.prefix}$identifier>')
                    ..lambda = true
                    ..static = true
                    ..annotations.add(refer('BuiltValueSerializer').call([], {'custom': refer('true')}))
                    ..body = Code('_\$${state.prefix}${identifier}Serializer()')
                    ..type = MethodType.getter,
                ),
              ]);
          },
        ),
        Class(
          (final b) => b
            ..name = '_\$${state.prefix}${identifier}Serializer'
            ..implements.add(refer('PrimitiveSerializer<${state.prefix}$identifier>'))
            ..fields.addAll([
              Field(
                (final b) => b
                  ..name = 'types'
                  ..modifier = FieldModifier.final$
                  ..type = refer('Iterable<Type>')
                  ..annotations.add(refer('override'))
                  ..assignment = Code('const [${state.prefix}$identifier, _\$${state.prefix}$identifier]'),
              ),
              Field(
                (final b) => b
                  ..name = 'wireName'
                  ..modifier = FieldModifier.final$
                  ..type = refer('String')
                  ..annotations.add(refer('override'))
                  ..assignment = Code("r'${state.prefix}$identifier'"),
              )
            ])
            ..methods.addAll([
              Method((final b) {
                b
                  ..name = 'serialize'
                  ..returns = refer('Object')
                  ..annotations.add(refer('override'))
                  ..requiredParameters.addAll([
                    Parameter(
                      (final b) => b
                        ..name = 'serializers'
                        ..type = refer('Serializers'),
                    ),
                    Parameter(
                      (final b) => b
                        ..name = 'object'
                        ..type = refer('${state.prefix}$identifier'),
                    ),
                  ])
                  ..optionalParameters.add(
                    Parameter(
                      (final b) => b
                        ..name = 'specifiedType'
                        ..type = refer('FullType')
                        ..named = true
                        ..defaultTo = const Code('FullType.unspecified'),
                    ),
                  )
                  ..body = const Code('return object.data.value;');
              }),
              Method((final b) {
                b
                  ..name = 'deserialize'
                  ..returns = refer('${state.prefix}$identifier')
                  ..annotations.add(refer('override'))
                  ..requiredParameters.addAll([
                    Parameter(
                      (final b) => b
                        ..name = 'serializers'
                        ..type = refer('Serializers'),
                    ),
                    Parameter(
                      (final b) => b
                        ..name = 'data'
                        ..type = refer('Object'),
                    ),
                  ])
                  ..optionalParameters.add(
                    Parameter(
                      (final b) => b
                        ..name = 'specifiedType'
                        ..type = refer('FullType')
                        ..named = true
                        ..defaultTo = const Code('FullType.unspecified'),
                    ),
                  )
                  ..body = Code(
                    <String>[
                      'final result = new ${state.prefix}${identifier}Builder()',
                      '..data = JsonObject(data);',
                      if (schema.allOf != null) ...[
                        for (final result in results) ...[
                          if (result is TypeResultBase || result is TypeResultEnum) ...[
                            'result.${fields[result.name]!} = ${result.deserialize('data')};',
                          ] else ...[
                            'result.${fields[result.name]!}.replace(${result.deserialize('data')});',
                          ],
                        ],
                      ] else ...[
                        if (schema.discriminator != null) ...[
                          'if (data is! Iterable) {',
                          r"throw StateError('Expected an Iterable but got ${data.runtimeType}');",
                          '}',
                          '',
                          'String? discriminator;',
                          '',
                          'final iterator = data.iterator;',
                          'while (iterator.moveNext()) {',
                          'final key = iterator.current! as String;',
                          'iterator.moveNext();',
                          'final Object? value = iterator.current;',
                          "if (key == '${schema.discriminator!.propertyName}') {",
                          'discriminator = value! as String;',
                          'break;',
                          '}',
                          '}',
                        ],
                        for (final result in results) ...[
                          if (schema.discriminator != null) ...[
                            "if (discriminator == '${result.name.replaceFirst(state.prefix, '')}'",
                            if (schema.discriminator!.mapping != null && schema.discriminator!.mapping!.isNotEmpty) ...[
                              for (final key in schema.discriminator!.mapping!.entries
                                  .where(
                                    (final entry) =>
                                        entry.value.endsWith('/${result.name.replaceFirst(state.prefix, '')}'),
                                  )
                                  .map((final entry) => entry.key)) ...[
                                " ||  discriminator == '$key'",
                              ],
                              ') {',
                            ],
                          ],
                          'try {',
                          if (result is TypeResultBase || result is TypeResultEnum) ...[
                            'result._${fields[result.name]!} = ${result.deserialize('data')};',
                          ] else ...[
                            'result._${fields[result.name]!} = ${result.deserialize('data')}.toBuilder();',
                          ],
                          '} catch (_) {',
                          if (schema.discriminator != null) ...[
                            'rethrow;',
                          ],
                          '}',
                          if (schema.discriminator != null) ...[
                            '}',
                          ],
                        ],
                        if (schema.oneOf != null) ...[
                          "assert([${fields.values.map((final e) => 'result._$e').join(',')}].where((final x) => x != null).length >= 1, 'Need oneOf for \${result._data}');",
                        ],
                        if (schema.anyOf != null) ...[
                          "assert([${fields.values.map((final e) => 'result._$e').join(',')}].where((final x) => x != null).length >= 1, 'Need anyOf for \${result._data}');",
                        ],
                      ],
                      'return result.build();',
                    ].join(),
                  );
              }),
            ]),
        ),
      ]);
    }
  } else if (schema.isContentString) {
    final subResult = resolveType(
      spec,
      variablePrefix,
      state,
      identifier,
      schema.contentSchema!,
    );

    result = TypeResultObject(
      'ContentString',
      generics: [subResult],
      nullable: nullable,
    );
  } else {
    switch (schema.type) {
      case 'boolean':
        result = TypeResultBase(
          'bool',
          nullable: nullable,
        );
        break;
      case 'integer':
        result = TypeResultBase(
          'int',
          nullable: nullable,
        );
        break;
      case 'number':
        result = TypeResultBase(
          'num',
          nullable: nullable,
        );
        break;
      case 'string':
        switch (schema.format) {
          case 'binary':
            result = TypeResultBase(
              'Uint8List',
              nullable: nullable,
            );
            break;
        }

        result = TypeResultBase(
          'String',
          nullable: nullable,
        );
        break;
      case 'array':
        if (schema.items != null) {
          final subResult = resolveType(
            spec,
            variablePrefix,
            state,
            identifier,
            schema.items!,
          );
          result = TypeResultList(
            'BuiltList',
            subResult,
            nullable: nullable,
          );
        } else {
          result = TypeResultList(
            'BuiltList',
            TypeResultBase('JsonObject'),
            nullable: nullable,
          );
        }
        break;
      case 'object':
        if (schema.properties == null) {
          if (schema.additionalProperties != null) {
            if (schema.additionalProperties is EmptySchema) {
              result = TypeResultMap(
                'BuiltMap',
                TypeResultBase('JsonObject'),
                nullable: nullable,
              );
            } else {
              final subResult = resolveType(
                spec,
                variablePrefix,
                state,
                identifier,
                schema.additionalProperties!,
              );
              result = TypeResultMap(
                'BuiltMap',
                subResult,
                nullable: nullable,
              );
            }
            break;
          }
          result = TypeResultBase(
            'JsonObject',
            nullable: nullable,
          );
          break;
        }
        if (schema.properties!.isEmpty) {
          result = TypeResultMap(
            'BuiltMap',
            TypeResultBase('JsonObject'),
            nullable: nullable,
          );
          break;
        }

        result = resolveObject(
          spec,
          variablePrefix,
          state,
          identifier,
          schema,
          nullable: nullable,
        );
        break;
    }
  }

  if (result != null) {
    if (!ignoreEnum && schema.enum_ != null) {
      if (state.resolvedTypes.add(TypeResultEnum('${state.prefix}$identifier', result))) {
        state.output.add(
          Class(
            (final b) => b
              ..name = '${state.prefix}$identifier'
              ..extend = refer('EnumClass')
              ..constructors.add(
                Constructor(
                  (final b) => b
                    ..name = '_'
                    ..constant = true
                    ..requiredParameters.add(
                      Parameter(
                        (final b) => b
                          ..name = 'name'
                          ..toSuper = true,
                      ),
                    ),
                ),
              )
              ..fields.addAll(
                schema.enum_!.map(
                  (final value) => Field(
                    (final b) {
                      final result = resolveType(
                        spec,
                        variablePrefix,
                        state,
                        '$identifier${_toDartName(value.toString(), uppercaseFirstCharacter: true)}',
                        schema,
                        ignoreEnum: true,
                      );
                      b
                        ..name = _toDartName(value.toString())
                        ..static = true
                        ..modifier = FieldModifier.constant
                        ..type = refer('${state.prefix}$identifier')
                        ..assignment = Code(
                          '_\$${_toCamelCase('${state.prefix}$identifier')}${_toDartName(value.toString(), uppercaseFirstCharacter: true)}',
                        );

                      if (_toDartName(value.toString()) != value.toString()) {
                        if (result.name != 'String' && result.name != 'int') {
                          throw Exception(
                            'Sorry enum values are a bit broken. '
                            'See https://github.com/google/json_serializable.dart/issues/616. '
                            'Please remove the enum values on ${state.prefix}$identifier.',
                          );
                        }
                        b.annotations.add(
                          refer('BuiltValueEnumConst').call([], {
                            'wireName': refer(_valueToEscapedValue(result, value.toString())),
                          }),
                        );
                      }
                    },
                  ),
                ),
              )
              ..methods.addAll([
                Method(
                  (final b) => b
                    ..name = 'values'
                    ..returns = refer('BuiltSet<${state.prefix}$identifier>')
                    ..lambda = true
                    ..static = true
                    ..body = Code('_\$${_toCamelCase('${state.prefix}$identifier')}Values')
                    ..type = MethodType.getter,
                ),
                Method(
                  (final b) => b
                    ..name = 'valueOf'
                    ..returns = refer('${state.prefix}$identifier')
                    ..lambda = true
                    ..static = true
                    ..requiredParameters.add(
                      Parameter(
                        (final b) => b
                          ..name = 'name'
                          ..type = refer(result!.name),
                      ),
                    )
                    ..body = Code('_\$valueOf${state.prefix}$identifier(name)'),
                ),
                Method(
                  (final b) => b
                    ..name = 'serializer'
                    ..returns = refer('Serializer<${state.prefix}$identifier>')
                    ..lambda = true
                    ..static = true
                    ..body = Code("_\$${_toCamelCase('${state.prefix}$identifier')}Serializer")
                    ..type = MethodType.getter,
                ),
              ]),
          ),
        );
      }
      result = TypeResultEnum(
        '${state.prefix}$identifier',
        result,
        nullable: nullable,
      );
    }

    state.resolvedTypes.add(result);
    return result;
  }

  throw Exception('Can not convert OpenAPI type "${schema.toJson()}" to a Dart type');
}

// ignore: avoid_positional_boolean_parameters
int sortRequiredElements(final bool a, final bool b) {
  if (a != b) {
    if (a && !b) {
      return -1;
    } else {
      return 1;
    }
  }

  return 0;
}
