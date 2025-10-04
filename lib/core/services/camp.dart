import 'dart:convert';
import 'package:gpt_box/data/res/openai.dart';
import 'package:gpt_box/core/services/screengot_service.dart';
import 'dart:io';
import 'package:openai_core/openai_core.dart';

// Define a tool by extending FunctionToolHandler.
class CompUseTool extends FunctionToolHandler {
  CompUseTool()
    : super(
        metadata: FunctionTool(
          name: 'get_current_temperature',
          description: 'Returns the current temperature in Celsius for a city.',
          strict: true,
          parameters: {
            "type": "computer_use_preview",
            "display_width": 1920,
            "display_height": 1080,
            "environment": "linux",
          }
        ),
      );
      
        @override
        Future<String> execute(ResponsesSessionController controller, Map<String, dynamic> arguments) async {
          // Map the incoming computer action to native ScreenGotService calls
          final action = ComputerAction.fromJson(arguments);

          final svc = ScreenGotService();
          // Ensure native bridge is initialized (noop if already init)
          await svc.init();

          try {
            if (action is ComputerActionMove) {
              await svc.move(action.x, action.y);
              return jsonEncode({'ok': true, 'did': 'move', 'x': action.x, 'y': action.y});
            }

            if (action is ComputerActionClick) {
              // Move to the target then click the specified button
              await svc.move(action.x, action.y);
              await svc.click(action.button, dbl: false);
              return jsonEncode({
                'ok': true,
                'did': 'click',
                'x': action.x,
                'y': action.y,
                'button': action.button,
              });
            }

            if (action is ComputerActionDoubleClick) {
              await svc.move(action.x, action.y);
              await svc.click('left', dbl: true);
              return jsonEncode({'ok': true, 'did': 'double_click', 'x': action.x, 'y': action.y});
            }

            if (action is ComputerActionScroll) {
              // Move the pointer near intended area then scroll
              await svc.move(action.x, action.y);
              await svc.scroll(action.scrollX, action.scrollY);
              return jsonEncode({
                'ok': true,
                'did': 'scroll',
                'x': action.x,
                'y': action.y,
                'scroll_x': action.scrollX,
                'scroll_y': action.scrollY,
              });
            }

            if (action is ComputerActionType) {
              await svc.typeStr(action.text);
              return jsonEncode({'ok': true, 'did': 'type', 'text': action.text});
            }

            if (action is ComputerActionKeyPress) {
              // If multiple keys provided, treat all but last as modifiers
              if (action.keys.isEmpty) {
                return jsonEncode({'ok': false, 'error': 'no_keys'});
              }
              if (action.keys.length == 1) {
                await svc.keyTap(action.keys.first);
              } else {
                final key = action.keys.last;
                final mods = action.keys.take(action.keys.length - 1).join(',');
                await svc.keyTap(key, mods: mods);
              }
              return jsonEncode({'ok': true, 'did': 'keypress', 'keys': action.keys});
            }

            if (action is ComputerActionDrag) {
              if (action.path.isEmpty) {
                return jsonEncode({'ok': false, 'error': 'empty_drag_path'});
              }
              // Press, move along path, then release
              await svc.move(action.path.first.x, action.path.first.y);
              await svc.toggle('left', 'down');
              for (final p in action.path.skip(1)) {
                await svc.move(p.x, p.y);
              }
              await svc.toggle('left', 'up');
              return jsonEncode({
                'ok': true,
                'did': 'drag',
                'points': action.path.map((p) => p.toJson()).toList(),
              });
            }

            if (action is ComputerActionScreenshot) {
              // Save a full-screen capture to a temp file, return data URL
              final dir = await Directory.systemTemp.createTemp('gptbox_ss_');
              final filePath = '${dir.path}/screen.png';
              await svc.saveCaptureFull(filePath);
              final bytes = await File(filePath).readAsBytes();
              final b64 = base64Encode(bytes);
              // Best-effort cleanup
              try { await File(filePath).delete(); } catch (_) {}
              try { await dir.delete(); } catch (_) {}
              return jsonEncode({
                'ok': true,
                'did': 'screenshot',
                'image': 'data:image/png;base64,$b64',
              });
            }

            if (action is ComputerActionWait) {
              // Small delay to allow UI settling
              await svc.milliSleep(300);
              return jsonEncode({'ok': true, 'did': 'wait', 'ms': 300});
            }

            // Fallback for unrecognized/other actions
            return jsonEncode({'ok': false, 'error': 'unsupported_action', 'action': action.toJson()});
          } catch (e) {
            return jsonEncode({'ok': false, 'error': e.toString()});
          }
        }


}

/// Base-class for every computer-action payload.
abstract class ComputerAction {
  const ComputerAction();

  /// `"click"`, `"double_click"`, …
  String get type;

  Map<String, dynamic> toJson();

  /* ––– dynamic factory ––– */
  static ComputerAction fromJson(Map<String, dynamic> j) {
    switch (j['type']) {
      case 'click':
        return ComputerActionClick(x: j['x'], y: j['y'], button: j['button']);
      case 'double_click':
        return ComputerActionDoubleClick(x: j['x'], y: j['y']);
      case 'drag':
        return ComputerActionDrag(
          path: (j['path'] as List)
              .cast<Map<String, dynamic>>()
              .map((p) => Point(x: p['x'], y: p['y']))
              .toList(),
        );
      case 'keypress':
        return ComputerActionKeyPress(keys: List<String>.from(j['keys']));
      case 'move':
        return ComputerActionMove(x: j['x'], y: j['y']);
      case 'screenshot':
        return const ComputerActionScreenshot();
      case 'scroll':
        return ComputerActionScroll(
          x: j['x'],
          y: j['y'],
          scrollX: j['scroll_x'],
          scrollY: j['scroll_y'],
        );
      case 'type':
        return ComputerActionType(text: j['text']);
      case 'wait':
        return const ComputerActionWait();
      default:
        return OtherComputerAction(j);
    }
  }
}

class OtherComputerAction extends ComputerAction {
  OtherComputerAction(this.json);

  Map<String, dynamic> json;

  @override
  String get type => 'click';

  @override
  Map<String, dynamic> toJson() => json;
}

class Point {
  const Point({required this.x, required this.y});
  final int x;
  final int y;

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}

class ComputerActionClick extends ComputerAction {
  const ComputerActionClick({
    required this.x,
    required this.y,
    required this.button,
  });
  final int x, y;
  final String button; // left, right, wheel, back, forward

  @override
  String get type => 'click';

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'x': x,
    'y': y,
    'button': button,
  };
}

class ComputerActionDoubleClick extends ComputerAction {
  const ComputerActionDoubleClick({required this.x, required this.y});
  final int x, y;

  @override
  String get type => 'double_click';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'x': x, 'y': y};
}

class ComputerActionDrag extends ComputerAction {
  const ComputerActionDrag({required this.path});
  final List<Point> path;

  @override
  String get type => 'drag';
  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'path': path.map((p) => p.toJson()).toList(),
  };
}

class ComputerActionKeyPress extends ComputerAction {
  const ComputerActionKeyPress({required this.keys});
  final List<String> keys;

  @override
  String get type => 'keypress';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'keys': keys};
}

class ComputerActionMove extends ComputerAction {
  const ComputerActionMove({required this.x, required this.y});
  final int x, y;

  @override
  String get type => 'move';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'x': x, 'y': y};
}

class ComputerActionScreenshot extends ComputerAction {
  const ComputerActionScreenshot();
  @override
  String get type => 'screenshot';
  @override
  Map<String, dynamic> toJson() => {'type': type};
}

class ComputerActionScroll extends ComputerAction {
  const ComputerActionScroll({
    required this.x,
    required this.y,
    required this.scrollX,
    required this.scrollY,
  });
  final int x, y;
  final int scrollX, scrollY;

  @override
  String get type => 'scroll';
  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'x': x,
    'y': y,
    'scroll_x': scrollX,
    'scroll_y': scrollY,
  };
}

class ComputerActionType extends ComputerAction {
  const ComputerActionType({required this.text});
  final String text;

  @override
  String get type => 'type';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'text': text};
}

class ComputerActionWait extends ComputerAction {
  const ComputerActionWait();
  @override
  String get type => 'wait';
  @override
  Map<String, dynamic> toJson() => {'type': type};
}

class ComputerCall extends ResponseItem {
  const ComputerCall({
    required this.id,
    required this.callId,
    required this.action,
    required this.pendingSafetyChecks,
    this.status,
  }) : super('computer_call');

  final String id;
  final String callId;
  final ComputerAction action;
  final List<ComputerSafetyCheck> pendingSafetyChecks;
  final ComputerResultStatus? status; // in_progress | completed | incomplete

  ComputerCallOutput output(
    ComputerScreenshotOutput output, {
    List<ComputerSafetyCheck>? acknowledgedSafetyChecks,
    ComputerResultStatus? status,
    String? id,
  }) {
    return ComputerCallOutput(
      callId: callId,
      output: output,
      status: status,
      id: id,
      acknowledgedSafetyChecks: acknowledgedSafetyChecks,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'computer_call',
    'id': id,
    'call_id': callId,
    'action': action.toJson(),
    'pending_safety_checks': pendingSafetyChecks
        .map((c) => c.toJson())
        .toList(),
    if (status != null) 'status': status!.toJson(),
  };
}

class ComputerCallOutput extends ResponseItem {
  const ComputerCallOutput({
    required this.callId,
    required this.output,
    this.acknowledgedSafetyChecks,
    this.id,
    this.status,
  }) : super('computer_call_output');

  final String callId;
  final ComputerScreenshotOutput output;
  final List<ComputerSafetyCheck>? acknowledgedSafetyChecks;
  final String? id;
  final ComputerResultStatus? status;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'computer_call_output',
    'call_id': callId,
    'output': output.toJson(),
    if (acknowledgedSafetyChecks != null)
      'acknowledged_safety_checks': acknowledgedSafetyChecks!
          .map((e) => e.toJson())
          .toList(),
    if (id != null) 'id': id,
    if (status != null) 'status': status!.toJson(),
  };
}


Future<Response> startCompUse(String msg, String imgbs64) async {
  final client = OpenAIClient(
    apiKey: Cfg.current.key,baseUrl:  Cfg.current.url
  );

  final session = ResponsesSessionController(
    client: client,
    model: ChatModel.computerUsePreview,
    stream: false, // set true to receive SSE events
    store: false, // set true to use previousResponseId on the server
    tools: [CompUseTool()],
    input:  Input.fromJson({
      "role": "user",
      "content": [
        {"type": "input_text", "text": "$msg"},
        {
          "type": "input_image",
          "image_url":
              "$imgbs64",
        },
      ],
    }),
  );

  // Runs one or more turns automatically until outputText is present.
  final response = await session.nextResponse();
  print(response.outputText);
    client.close();

return response;
}
