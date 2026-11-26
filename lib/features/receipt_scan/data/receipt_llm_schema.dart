import '../../../core/llm/contract/contract.dart';

/// Prompt for AI-provider receipt extraction. Ported from the server's
/// AnthropicReceiptExtractionProvider, minus the tool-use wording.
const receiptLlmPrompt =
    'Extract this vehicle service receipt. Fill only '
    'fields present on the receipt; leave anything absent null. Classify '
    'each line item\'s type as "Labour", "Part", or "Fee". Use ISO '
    'yyyy-MM-dd for the date. For every line item, read its quantity from '
    'the receipt\'s quantity column. That column is not always headed '
    '"Qty" — it may be labelled Shp, Ship, or Shipped (or shown as '
    '"x2"); use whichever column holds the per-item count. Set unitCost '
    'to the per-unit price, not the line total. Cross-check with the line '
    'amount: quantity multiplied by unitCost should equal the line\'s '
    'total amount, so when an amount is a whole multiple of the unit '
    'price, use that multiple as the quantity. Use 1 only when no '
    'quantity is shown and the amount equals the unit price. Also set '
    'amount to the line\'s printed total for that item.';

/// Structured-output schema mirroring the server's `BuildSchema()`. Strict
/// compatible (OpenAI): every property is required, optional values are
/// nullable, and objects forbid additional properties.
const receiptLlmSchema = LlmJsonSchema(
  name: 'record_service_receipt',
  schema: {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'shopName': {
        'type': ['string', 'null'],
      },
      'date': {
        'type': ['string', 'null'],
        'description': 'ISO date yyyy-MM-dd',
      },
      'odometer': {
        'type': ['integer', 'null'],
        'description': 'Odometer / mileage reading',
      },
      'tax': {
        'type': ['number', 'null'],
      },
      'total': {
        'type': ['number', 'null'],
      },
      'currency': {
        'type': ['string', 'null'],
        'description': 'ISO 4217 code, e.g. CAD',
      },
      'lineItems': {
        'type': 'array',
        'items': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'type': {
              'type': 'string',
              'enum': ['Labour', 'Part', 'Fee'],
            },
            'name': {'type': 'string'},
            'quantity': {
              'type': 'integer',
              'description':
                  'Per-item count from the quantity column (may be headed '
                  'Qty, Shp, Ship or Shipped); equals line amount / unit '
                  'price. 1 if none shown',
            },
            'unitCost': {
              'type': ['number', 'null'],
              'description': 'Per-unit price (not the line total)',
            },
            'amount': {
              'type': ['number', 'null'],
              'description': 'Line total for this item (unit price x quantity)',
            },
          },
          'required': ['type', 'name', 'quantity', 'unitCost', 'amount'],
        },
      },
    },
    'required': [
      'shopName',
      'date',
      'odometer',
      'tax',
      'total',
      'currency',
      'lineItems',
    ],
  },
);
