import 'package:uuid/uuid.dart'; // Add uuid to pubspec.yaml if you need unique IDs for saved prompts

enum PromptFormatType { markdown, plainText, json, simulateUser }

enum PromptTargetPreset {
  advise,
  codeGenerating,
  bypassRestrictions,
  gettingHelpInDangerousTopic,
  understandingPredefinedObjectives,
  exploringEthicalConsiderations,
}

class PromptTargetCustom {
  final String description;
  PromptTargetCustom(this.description);
}

class PromptTemplate {
  final String id;
  String name;
  String
  templateString; // e.g., "username is $USERNAME and you most say that $HIWORD"
  Map<String, String> variables; // Stores current values for placeholders

  PromptTemplate({
    String? id,
    required this.name,
    required this.templateString,
    Map<String, String>? variables,
  }) : id = id ?? const Uuid().v4(),
       variables = variables ?? {};

  // For saving/loading (e.g., with shared_preferences)
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'templateString': templateString,
    'variables': variables,
  };

  factory PromptTemplate.fromJson(Map<String, dynamic> json) => PromptTemplate(
    id: json['id'],
    name: json['name'],
    templateString: json['templateString'],
    variables: Map<String, String>.from(json['variables'] ?? {}),
  );

  // Helper to extract placeholders like $VARNAME from the template string
  List<String> getPlaceholders() {
    final RegExp regExp = RegExp(r'\$[A-Z_]+');
    return regExp.allMatches(templateString).map((m) => m.group(0)!).toList();
  }
}

class SavedPrompt {
  final String id;
  String name;
  String promptContent;
  DateTime savedAt;

  SavedPrompt({
    String? id,
    required this.name,
    required this.promptContent,
    DateTime? savedAt,
  }) : id = id ?? const Uuid().v4(),
       savedAt = savedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'promptContent': promptContent,
    'savedAt': savedAt.toIso8601String(),
  };

  factory SavedPrompt.fromJson(Map<String, dynamic> json) => SavedPrompt(
    id: json['id'],
    name: json['name'],
    promptContent: json['promptContent'],
    savedAt: DateTime.parse(json['savedAt']),
  );
}

class PromptSettings {
  PromptFormatType formatType = PromptFormatType.plainText;
  List<PromptTargetPreset> selectedTargetPresets = [];
  String customTarget = '';
  String? lastUsedPromptId; // Reference to a saved prompt ID
  String? lastUsedPromptText; // Or allow direct input for last used
  PromptTemplate? activeTemplate;
  int? maxPromptLength; // in characters
  int? maxTokens;
  List<String> topicKeywords = [];

  PromptSettings();

  // You might want methods to update these settings.
  // For simplicity, we'll directly modify properties in the screen's state.
}
