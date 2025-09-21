import 'dart:convert';

/// Represents basic pricing information for a model.
class PriceInfo {
  final double input;
  final double output;
  final double inputCache;

  const PriceInfo({
    required this.input,
    required this.output,
    required this.inputCache,
  });
}

// Exact model pricing. Update these as needed.
final Map<String, PriceInfo> _exact = {
  // Previously: 0.00006 (now applied to all three for backward parity)
  'gpt-4-32k': PriceInfo(input: 0.00006, output: 0.00006, inputCache: 0.00006),
  // Previously: 0.00003
  'gpt-4': PriceInfo(input: 0.00003, output: 0.00003, inputCache: 0.00003),
};

/// Pattern-based fallbacks (by convention):
/// - gpt-4-* -> 0.00001
/// - gpt-3.5* -> 0.000001
PriceInfo? _patternPricing(String model) {
  if (model.startsWith('gpt-4-')) {
    return PriceInfo(input: 0.00001, output: 0.00001, inputCache: 0.00001);
  }
  if (model.startsWith('gpt-3.5')) {
    return PriceInfo(input: 0.000001, output: 0.000001, inputCache: 0.000001);
  }
  return null;
}

/// Returns the complete pricing info for a model, or null if unknown.
PriceInfo? getPrices(String model) {
  final exact = _exact[model];
  if (exact != null) return exact;
  return _patternPricing(model);
}

/// Convenience: input (prompt) price-per-1K-tokens for [model].
double? getInputPrice(String model) => getPrices(model)?.input;

/// Convenience: output (completion) price-per-1K-tokens for [model].
double? getOutputPrice(String model) => getPrices(model)?.output;

/// Convenience: cached input price-per-1K-tokens for [model].
double? getInputCachePrice(String model) => getPrices(model)?.inputCache;

/// Data structure to hold model pricing information parsed from JSON.
class ModelPricingInfo {
  final String id;
  final String object;
  final String? objectType; // e.g., 'model'
  final String ownedBy;
  final double? inputPrice;
  final double? cachedInputPrice;
  final double? outputPrice;
  final double? inputCostPerSecond; // For audio models
  final double? outputCostPerSecond; // For audio models
  final double? inputCostPerQuery; // For rerank models (single double value)
  final Map<String, dynamic>? searchContextCostPerQuery; // For models with detailed search costs (map)
  final double? outputCostPerImage; // For image generation models
  final double? imageInput; // For vision models
  final double? imageOutput; // For vision models

  ModelPricingInfo({
    required this.id,
    required this.object,
    this.objectType,
    required this.ownedBy,
    this.inputPrice,
    this.cachedInputPrice,
    this.outputPrice,
    this.inputCostPerSecond,
    this.outputCostPerSecond,
    this.inputCostPerQuery,
    this.searchContextCostPerQuery,
    this.outputCostPerImage,
    this.imageInput,
    this.imageOutput,
  });

  factory ModelPricingInfo.fromJson(Map<String, dynamic> json) {
    final pricing = json['pricing'] as Map<String, dynamic>?;
    final searchContextPricing = pricing?['search_context_cost_per_query'];
    
    Map<String, dynamic>? parsedSearchContextPricing;
    double? parsedInputCostPerQuery;

    // Handle 'search_context_cost_per_query' which can be either a map or a number
    if (searchContextPricing is Map<String, dynamic>) {
      parsedSearchContextPricing = searchContextPricing;
    } else if (searchContextPricing is num) {
      parsedInputCostPerQuery = searchContextPricing.toDouble();
    }


    return ModelPricingInfo(
      id: json['id'] as String,
      object: json['object'] as String,
      objectType: json['objectType'] as String?,
      ownedBy: json['owned_by'] as String,
      inputPrice: (pricing?['input'] as num?)?.toDouble(),
      cachedInputPrice: (pricing?['cached_input'] as num?)?.toDouble() ??
          (pricing?['cached_input_above_32K'] as num?)?.toDouble() ??
          (pricing?['cached_input_above_128K'] as num?)?.toDouble() ??
          (pricing?['cached_input_above_256K'] as num?)?.toDouble(),
      outputPrice: (pricing?['output'] as num?)?.toDouble() ??
          (pricing?['output_above_32K'] as num?)?.toDouble() ??
          (pricing?['output_above_128K'] as num?)?.toDouble() ??
          (pricing?['output_above_256K'] as num?)?.toDouble(),
      inputCostPerSecond: (pricing?['input_cost_per_second'] as num?)?.toDouble() ??
          (pricing?['audio_input'] as num?)?.toDouble(),
      outputCostPerSecond: (pricing?['output_cost_per_second'] as num?)?.toDouble() ??
          (pricing?['audio_output'] as num?)?.toDouble(),
      inputCostPerQuery: (pricing?['input_cost_per_query'] as num?)?.toDouble() ?? parsedInputCostPerQuery,
      searchContextCostPerQuery: parsedSearchContextPricing,
      outputCostPerImage: (pricing?['output_cost_per_image'] as num?)?.toDouble(),
      imageInput: (pricing?['image_input'] as num?)?.toDouble(),
      imageOutput: (pricing?['image_output'] as num?)?.toDouble(),
    );
  }
}

List<ModelPricingInfo> parseModelPricing(String jsonData) {
  final data = Map<String, dynamic>.from(
    json.decode(jsonData) as Map<String, dynamic>,
  );
  final List<dynamic> models = data['data'] as List<dynamic>;
  return models.map((json) => ModelPricingInfo.fromJson(json as Map<String, dynamic>)).toList();
}

/// The raw JSON data provided.
const String _modelPricingJsonData = r'''

''';

// Function to demonstrate parsing and accessing the data
void main() {
  // Parse the model pricing data from the JSON string
  List<ModelPricingInfo> parsedModels = parseModelPricing(_modelPricingJsonData);

  print('--- Imported Model Pricing Information ---');
  print('Total models imported: ${parsedModels.length}\n');


  // Example 1: Accessing specific models and their detailed pricing
  final gpt4oMini = parsedModels.firstWhere((m) => m.id == 'gpt-4o-mini');
  print('Model: ${gpt4oMini.id} (Owned by: ${gpt4oMini.ownedBy})');
  print('  Input Price: ${gpt4oMini.inputPrice ?? 'N/A'}');
  print('  Output Price: ${gpt4oMini.outputPrice ?? 'N/A'}');
  print('  Cached Input Price: ${gpt4oMini.cachedInputPrice ?? 'N/A'}');
  print('  Search Context Pricing (Low): ${gpt4oMini.searchContextCostPerQuery?['search_context_size_low'] ?? 'N/A'}\n');


  final claudeOpus = parsedModels.firstWhere((m) => m.id == 'anthropic.claude-3-opus-20240229-v1:0');
  print('Model: ${claudeOpus.id} (Owned by: ${claudeOpus.ownedBy})');
  print('  Input Price: ${claudeOpus.inputPrice ?? 'N/A'}');
  print('  Output Price: ${claudeOpus.outputPrice ?? 'N/A'}');
  print('  Cached Input Price: ${claudeOpus.cachedInputPrice ?? 'N/A'}\n');

  final whisper1 = parsedModels.firstWhere((m) => m.id == 'whisper-1');
  print('Model: ${whisper1.id} (Owned by: ${whisper1.ownedBy})');
  print('  Input Cost Per Second: ${whisper1.inputCostPerSecond ?? 'N/A'}\n');

  final cohereRerank = parsedModels.firstWhere((m) => m.id == 'cohere.rerank-v3-5:0');
  print('Model: ${cohereRerank.id} (Owned by: ${cohereRerank.ownedBy})');
  print('  Input Cost Per Query: ${cohereRerank.inputCostPerQuery ?? 'N/A'}\n');


  // Example 2: Loop through a few models to show a general overview
  print('--- Sample of All Models and Their Prices ---');
  for (int i = 0; i < (parsedModels.length > 5 ? 5 : parsedModels.length); i++) {
    final model = parsedModels[i];
    print('  ID: ${model.id}');
    print('    Owned By: ${model.ownedBy}');
    print('    Input: ${model.inputPrice ?? 'N/A'}');
    print('    Output: ${model.outputPrice ?? 'N/A'}');
    print('    Cached Input: ${model.cachedInputPrice ?? 'N/A'}');
    if (model.inputCostPerSecond != null) {
      print('    Input Cost/Sec: ${model.inputCostPerSecond}');
    }
    if (model.inputCostPerQuery != null) {
      print('    Input Cost/Query: ${model.inputCostPerQuery}');
    }
    if (model.searchContextCostPerQuery != null) {
      print('    Search Context Costs: ${model.searchContextCostPerQuery}');
    }
    print('');
  }

  // Demonstration of existing PriceInfo functions (still functional for predefined models)
  print('--- Existing PriceInfo Lookup ---');
  final gpt4Prices = getPrices('gpt-4');
  if (gpt4Prices != null) {
    print('Traditional gpt-4 pricing:');
    print('  Input: ${gpt4Prices.input}');
    print('  Output: ${gpt4Prices.output}');
    print('  Cached Input: ${gpt4Prices.inputCache}');
  }
}