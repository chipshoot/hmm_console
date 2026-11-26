import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/llm/json_schema_validator.dart';

void main() {
  test('nullable type accepts null', () {
    expect(
      validateJsonSchema(null, {
        'type': ['string', 'null'],
      }),
      isEmpty,
    );
  });

  test('wrong type reported', () {
    expect(validateJsonSchema(1, {'type': 'string'}), [': type']);
  });

  test('integer rejects fractions, number accepts ints', () {
    expect(validateJsonSchema(1.5, {'type': 'integer'}), isNotEmpty);
    expect(validateJsonSchema(2, {'type': 'number'}), isEmpty);
  });

  test('missing required reported', () {
    expect(
      validateJsonSchema({}, {
        'type': 'object',
        'required': ['lineItems'],
        'properties': {
          'lineItems': {'type': 'array'},
        },
      }),
      ['lineItems: required'],
    );
  });

  test('enum and nested items', () {
    final errors = validateJsonSchema(
      {
        'lineItems': [
          {'type': 'Oil'},
        ],
      },
      {
        'type': 'object',
        'properties': {
          'lineItems': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'type': {
                  'enum': ['Labour', 'Part', 'Fee'],
                },
              },
            },
          },
        },
      },
    );
    expect(errors, contains('lineItems[0].type: enum'));
  });

  test('additionalProperties false rejects extras', () {
    expect(
      validateJsonSchema(
        {'x': 1},
        {'type': 'object', 'additionalProperties': false},
      ),
      ['x: not allowed'],
    );
  });

  test('valid value gives no errors', () {
    expect(
      validateJsonSchema(
        {'a': 'b'},
        {
          'type': 'object',
          'required': ['a'],
          'properties': {
            'a': {'type': 'string'},
          },
        },
      ),
      isEmpty,
    );
  });
}
