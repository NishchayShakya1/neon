// ignore_for_file: avoid_positional_boolean_parameters

import 'package:dynamite/src/helpers/dart_helpers.dart';
import 'package:dynamite/src/models/parameter.dart';
import 'package:dynamite/src/models/schema.dart';

String filterMethodName(final String operationId, final String tag) {
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

String clientName(final String tag) => '${toDartName(tag, uppercaseFirstCharacter: true)}Client';

bool isDartParameterNullable(
  final bool? required,
  final Schema? schema,
) =>
    (!(required ?? false) && schema?.default_ == null) || (schema?.nullable ?? false);

bool isRequired(
  final bool? required,
  final dynamic default_,
) =>
    (required ?? false) && default_ == null;

int sortRequiredParameters(final Parameter a, final Parameter b) {
  if (a.isDartRequired != b.isDartRequired) {
    if (a.isDartRequired && !b.isDartRequired) {
      return -1;
    } else {
      return 1;
    }
  }

  return 0;
}
