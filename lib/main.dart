// lib/main.dart - Comprehensive Test UI

import 'dart:async';
import 'dart:convert';
import 'dart:ffi' hide Size;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide Size; // for TextInputFormatter
import 'package:provider/provider.dart';
import 'package:screengot/models/task.dart';
import 'package:screengot/services/image_capture_service.dart';
import 'package:window_manager/window_manager.dart';

import 'models/native_response.dart';
import 'services/screengot_service.dart';


FocusNode _keyboardFocusNode = FocusNode();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
    _keyboardFocusNode = FocusNode();

  runApp(const ScreenGotDemoApp());
}

class ScreenGotDemoApp extends StatelessWidget {
  const ScreenGotDemoApp({super.key});
  @override
  Widget build(BuildContext context) {
     return MultiProvider(
      providers: [
        // Make the service available globally
        ChangeNotifierProvider(create: (_) => ImageCaptureService()),
      ],
      child: 
     MaterialApp(
      title: 'ScreenGot Test Suite',
      theme: ThemeData(primarySwatch: Colors.blueGrey),
      home: const DemoHomePage(),
     ));
  }
}
class CaptureScreen extends StatelessWidget {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Interactive Screen Cropping')),
      body: Consumer<ImageCaptureService>(
        builder: (context, service, child) {
          return Column(
            children: [
              _buildControlPanel(context, service),
              Expanded(
                child: service.fullScreenshotData != null
                    ? _buildScreenshotView(context, service)
                    : Center(
                        child: Text(
                          service.status,
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
              ),
              if (service.croppedImage != null) _buildCroppedPreview(service,context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildControlPanel(BuildContext context, ImageCaptureService service) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: service.state == CroppingState.idle
                    ? service.captureFullScreen
                    : null,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Full Screen Picture'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: service.state != CroppingState.idle
                    ? service.reset
                    : null,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
              ),
              const SizedBox(width: 10),
              Text('State: ${service.state.name}'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Status: ${service.status}',
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
          if (service.croppedInfo != null)
            Text(
              'Cropped Info: ${service.croppedInfo}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          if (service.savedFilePath != null)
            Text(
              'Saved Path: ${service.savedFilePath}',
              style: const TextStyle(fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildScreenshotView(
    BuildContext context,
    ImageCaptureService service,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageWidget = Image.memory(
          service.fullScreenshotData!,
          fit: BoxFit.contain,
        );

        // Use a Key to reliably track the rendered size of the image widget.
        // We use the image hash as the key to force rebuild when image changes.
        // However, LayoutBuilder gives us the constraints, which is often enough.

        // Capture Pointer interactions over the image area
        return Listener(
          onPointerDown: (details) {
            if (service.state == CroppingState.selectingStart) {
              service.handlePointerDown(
                details.localPosition,
                constraints.maxWidth,
                constraints.maxHeight,
              );
            }
          },
          onPointerMove: (details) {
            if (service.state == CroppingState.selectingEnd) {
              service.handlePointerMove(
                details.localPosition,
                constraints.maxWidth,
                constraints.maxHeight,
              );
            }
          },
          onPointerUp: (details) {
            if (service.state == CroppingState.selectingEnd) {
              service.handlePointerUp(
                details.localPosition,
                constraints.maxWidth,
                constraints.maxHeight,
              );
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageWidget,
              if (service.selectionRectPixels != null)
                // We pass the selection rect (in native pixels) and native dimensions
                _buildSelectionOverlay(
                  context,
                  service,
                  constraints.maxWidth,
                  constraints.maxHeight,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectionOverlay(
    BuildContext context,
    ImageCaptureService service,
    double widgetW,
    double widgetH,
  ) {
    final selectionRectPixels = service.selectionRectPixels!;

    // Calculate scaling factors
    final scaleX = widgetW / service.capturedWidth;
    final scaleY = widgetH / service.capturedHeight;

    // Scale the native pixel rect down to the UI widget size
    final scaledRect = Rect.fromLTRB(
      selectionRectPixels.left * scaleX,
      selectionRectPixels.top * scaleY,
      selectionRectPixels.right * scaleX,
      selectionRectPixels.bottom * scaleY,
    );

    // Create the overlay view
    return CustomPaint(
      painter: SelectionPainter(scaledRect, service.state),
      child:
          Container(), // Dummy container to ensure custom paint area is fully visible
    );
  }

  Widget _buildCroppedPreview(ImageCaptureService service, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      height: 100,
      width: double.infinity,
      color: Theme.of(context).secondaryHeaderColor.withOpacity(0.1),
      child: Row(
        children: [
          const Text(
            'Cropped Result:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Image.memory(service.croppedImage!, fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}

class SelectionPainter extends CustomPainter {
  final Rect selection;
  final CroppingState state;

  SelectionPainter(this.selection, this.state);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw the semi-transparent overlay over the whole canvas
    final backgroundPaint = Paint()..color = Colors.black.withOpacity(0.2);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      backgroundPaint,
    );

    // 2. Erase the area where the selection is being made (using BlendMode.clear)
    // This allows the original image to show through the selection box.
    canvas.drawRect(selection, Paint()..blendMode = BlendMode.clear);

    // 3. Draw the border around the selection
    if (state == CroppingState.selectingEnd) {
      final borderPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRect(selection, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SelectionPainter oldDelegate) {
    return oldDelegate.selection != selection || oldDelegate.state != state;
  }
}
class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage>
    with SingleTickerProviderStateMixin {
  final svc = ScreenGotService();
  final List<String> _log = [];
  final List<NativeResponse> _events = [];
  Uint8List? _capturedImage;
  int? _lastTaskId;
  // ignore: unused_field
  int _tabIndex = 0;
  late TabController _tabController;

  bool _initialized = false;
  bool _hookRunning = false;
 int _x=0;
 int _y=0;
 String str='';
 List<Task> taskList = [];

  // Controllers for Mouse/Keyboard
  final TextEditingController _moveX = TextEditingController(text: '100');
  final TextEditingController _moveY = TextEditingController(text: '100');
  final TextEditingController _typeText = TextEditingController(
    text: 'Hello from Flutter!',
  );
  final TextEditingController _keyTapKey = TextEditingController(text: 'enter');
  final TextEditingController _keyTapMods = TextEditingController(text: 'ctrl');
  final TextEditingController _scrollX = TextEditingController(text: '0');
  final TextEditingController _scrollY = TextEditingController(text: '-20');

  // Controllers for Capture/CV
  final TextEditingController _captureX = TextEditingController(text: '100');
  final TextEditingController _captureY = TextEditingController(text: '100');
  final TextEditingController _captureW = TextEditingController(text: '200');
  final TextEditingController _captureH = TextEditingController(text: '150');
  final TextEditingController _tplPath = TextEditingController(text: 'tpl.png');
  final TextEditingController _targetPath = TextEditingController(
    text: 'screen.png',
  );
 final TextEditingController _textStr = TextEditingController(
  
  );
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _initBridge();
    
  }

  @override
  void dispose() {
    _tabController.dispose();
    svc.dispose();
    super.dispose();
  }

  Future<void> _initBridge() async {
    try {
      await svc.init(libPath: 'native/linux/screengot.so');
      _appendLog('Bridge initialized');
      svc.events.listen(_handleEvent);
      setState(() => _initialized = true);
    } catch (e) {
      _appendLog('Bridge init error: $e');
    }
  }

  void _handleEvent(NativeResponse r) {
    // Only display hook events in the Events tab/log
    if (r.op == null || r.op!.isEmpty) {
      // Unsolicited messages (like hook events or log prints)
      setState(() {
        _events.insert(0, r);
        _appendLog('EVENT: ${r.data ?? r.error ?? ''}');
      });
    }
  }

  void _appendLog(String s) {
    setState(
      () => _log.insert(
        0,
        '[${DateTime.now().toIso8601String().substring(11, 23)}] $s',
      ),
    );
  }
  void recordTask(Function action, {int? x, int? y}) {
  setState(() {
    taskList.add(
      Task(
        order: taskList.length + 1,
        action: action,
        taskX: x,
        taskY: y,
        finalResult: FinalResult(
          tasktrigger: TaskTrigger.runbyhand,
          taskprerule: TaskPreRule.none,
          taskpostrule: TaskPostRule.none,
          parentConfirmType: ParentConfirmType.none,
          resultType: ResultType.none,
        ),
      ),
    );
  });
}

 

  Widget _buildTaskList() {
  return ReorderableListView(
    onReorder: (oldIndex, newIndex) {
      setState(() {
        if (newIndex > oldIndex) newIndex--;
        final task = taskList.removeAt(oldIndex);
        taskList.insert(newIndex, task);
      });
    },
    children: [
      for (final task in taskList)
        ListTile(
          key: ValueKey(task.order),
          title: Text('Task ${task.order} → ${task.action.runtimeType}'),
          subtitle: Text('(${task.taskX}, ${task.taskY})'),
          trailing: Icon(Icons.drag_handle),
        ),
    ],
  );
}
  Future<NativeResponse?> _safeCall(
  Future<NativeResponse> Function() action,
  String opName,
) async {
  _appendLog('CALL: $opName');
  try {
    final r = await action();
    _appendLog(
      'RESULT ($opName): Success=${r.success} Data=${r.data} Error=${r.error}',
    );
    
    if (opName == "GetLocation") {
      _parseCoordinatesFromResponse(r);
    }
    
    return r;
  } catch (e) {
    _appendLog('ERROR ($opName): $e');
    return null;
  }
}

void _parseCoordinatesFromResponse(NativeResponse r) {
  try {
    if (r.data is Map) {
      // If data is already a Map, extract x and y directly
      final Map<String, dynamic> data = Map<String, dynamic>.from(r.data as Map);
      _x = data['x']?.toInt() ?? data['dx']?.toInt() ?? 0;
              _x!=0?_moveX.text="$_x":"0";

      _y = data['y']?.toInt() ?? data['dy']?.toInt() ?? 0;
              _y!=0?_moveY.text="$_y":"0";
setState(() {
  
});
    } else if (r.data is String) {
      // If data is a string, try to parse coordinates from common log formats
      final String logData = r.data as String;
      
      // Pattern 1: "move to (x, y)" or "moved to (x, y)"
      final movePattern = RegExp(r'[Mm]ove(?:d)?\s+to\s*[\(\[{]?\s*(\d+)\s*[, ]\s*(\d+)[\)\]}]?');
      final moveMatch = movePattern.firstMatch(logData);
      if (moveMatch != null) {
        _x = int.tryParse(moveMatch.group(1)!) ?? 0;
                _x!=0?_moveX.text="$_x":"0";

        _y = int.tryParse(moveMatch.group(2)!) ?? 0;
                _y!=0?_moveY.text="$_y":"0";
setState(() {
  
});
        return;
      }
      
      // Pattern 2: "coordinates: x=123, y=456"
      final coordPattern = RegExp(r'[Xx]\s*[:=]?\s*(\d+).*?[Yy]\s*[:=]?\s*(\d+)');
      final coordMatch = coordPattern.firstMatch(logData);
      if (coordMatch != null) {
        _x = int.tryParse(coordMatch.group(1)!) ?? 0;
        _x!=0?_moveX.text="$_x":"0";
        _y = int.tryParse(coordMatch.group(2)!) ?? 0;
        _y!=0?_moveY.text="$_y":"0";
  setState(() {
    
  });
        return;
      }
      
      // Pattern 3: JSON-like format {"x": 123, "y": 456}
      final jsonPattern = RegExp(r'[{"\'"\']?\s*[:=]\s*(\d+).*?[{"']?y[}"\']?\s*[:=]\s*(\d+)');
      final jsonMatch = jsonPattern.firstMatch(logData);
      if (jsonMatch != null) {
        _x = int.tryParse(jsonMatch.group(1)!) ?? 0;
                _x!=0?_moveX.text="$_x":"0";

        _y = int.tryParse(jsonMatch.group(2)!) ?? 0;
                _y!=0?_moveY.text="$_y":"0";

setState(() {
  
});
        return;
      }
      
      // Pattern 4: Simple number pair "123, 456"
      final simplePattern = RegExp(r'(\d+)\s*[, ]\s*(\d+)');
      final simpleMatch = simplePattern.firstMatch(logData);
      if (simpleMatch != null) {
        _x = int.tryParse(simpleMatch.group(1)!) ?? 0;
                _x!=0?_moveX.text="$_x":"0";

        _y = int.tryParse(simpleMatch.group(2)!) ?? 0;
                _y!=0?_moveY.text="$_y":"0";

setState(() {
  
});
        return;
      }
      
      // If no pattern matches, set default values
      _x = 0;
      _y = 0;
    
    }
    _appendLog('Parsed coordinates: x=$_x, y=$_y');
  } catch (e) {
    _appendLog('ERROR parsing coordinates: $e');
    _x = 0;
    _y = 0;
  }
}
  // --- BUILD TABS ---
Future<void> runTasks() async {
  for (int loop = 0; loop < (taskList.first.loopCount); loop++) {
    for (final task in taskList) {
      for (int i = 0; i < task.repeatPerTask; i++) {
        await Future.delayed(Duration(seconds: task.delaySeconds.toInt()));
        if (task.action != null) await task.action();

      }
    }
  }
}

// Add this FocusNode to your state class



Widget _buildMouseTab() {
  return RawKeyboardListener(
    focusNode: _keyboardFocusNode,
    autofocus: true,
    onKey: (RawKeyEvent event) async{
      if (event is RawKeyDownEvent) {
        // Check if 'G' key is pressed (both lowercase and uppercase)
        if (event.logicalKey == LogicalKeyboardKey.keyG) {
          _triggerGetLocation();
        }
      if (event.logicalKey == LogicalKeyboardKey.keyM)
  recordTask(() async => _triggerMove(), x:_x, y:_y);
if (event.logicalKey == LogicalKeyboardKey.keyD)
  recordTask(() async => _triggerDragMove(), x:_x, y:_y);
if (event.logicalKey == LogicalKeyboardKey.keyS&& event.logicalKey==LogicalKeyboardKey.alt)
  recordTask(() async => _triggerSetStr(), x:_x, y:_y);
  if (event.logicalKey == LogicalKeyboardKey.keyS)
  recordTask(() async => _triggerSmoothMove(), x:_x, y:_y);
    if (event.logicalKey == LogicalKeyboardKey.keyC)
  recordTask(() async => _triggerLeftClick(), x:_x, y:_y);
    if (event.logicalKey == LogicalKeyboardKey.keyV)
  recordTask(() async => _triggerRightClick(), x:_x, y:_y);
    }},



  
    child: SingleChildScrollView(
      padding:  EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            'Mouse Movement & Location',
            style: TextStyle(fontSize: 16),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _moveX,
                  decoration: const InputDecoration(labelText: 'X'),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _moveY,
                  decoration: const InputDecoration(labelText: 'Y'),
                ),
              ),
              ElevatedButton(
                onPressed: _initialized
                    ? () => _safeCall(
                          () => svc.move(
                            int.tryParse(_moveX.text) ?? 0,
                            int.tryParse(_moveY.text) ?? 0,
                          ),
                          'Move',
                        )
                    : null,
                child: const Text('Move'),
              ),
              ElevatedButton(
                onPressed: _initialized
                    ? () => _safeCall(() => svc.getLocation(), 'GetLocation')
                    : null,
                child: const Text('GetLocation'),
              ),
            ],
          ),
          Row(
            children: [
              ElevatedButton(
                onPressed: _initialized
                    ? () =>
                          _safeCall(() => svc.moveSmooth(_x, _y), 'MoveSmooth')
                    : null,
                child: const Text('MoveSmooth (50,50)'),
              ),
              ElevatedButton(
                onPressed: _initialized
                    ? () => _safeCall(
                          () => svc.dragSmoothTo(_x, _y),
                          'DragSmooth ($_x,$_y)',
                        )
                    : null,
                child: const Text('DragSmooth'),
              ),
            ],
          ),
          const Divider(),
          const Text('Mouse Scroll', style: TextStyle(fontSize: 16)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _scrollX,
                  decoration: const InputDecoration(labelText: 'Scroll X'),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _scrollY,
                  decoration: const InputDecoration(labelText: 'Scroll Y'),
                ),
              ),
              ElevatedButton(
                onPressed: _initialized
                    ? () => _safeCall(
                          () => svc.scroll(
                            int.tryParse(_scrollX.text) ?? 0,
                            int.tryParse(_scrollY.text) ?? 0,
                          ),
                          'Scroll',
                        )
                    : null,
                child: const Text('Scroll'),
              ),
              ElevatedButton(
                onPressed: _initialized
                    ? () => _safeCall(
                          () => svc.scrollSmooth(20, 20),
                          'ScrollSmooth',
                        )
                    : null,
                child: const Text('ScrollSmooth'),
              ),
            ],
          ),
          const Divider(),
          const Text('Mouse Clicks', style: TextStyle(fontSize: 16)),
          Row(
            children: [
              ElevatedButton(
                onPressed: _initialized
                    ? () => _safeCall(() => svc.click('left'), 'Click Left')
                    : null,
                child: const Text('Click Left'),
              ),
              ElevatedButton(
                onPressed: _initialized
                    ? () => _safeCall(() => svc.click('right'), 'Click Right')
                    : null,
                child: const Text('Click Right'),
              ),
              ElevatedButton(
                onPressed: _initialized
                    ? () => _safeCall(
                          () => svc.click('left', dbl: true),
                          'Double Click Left',
                        )
                    : null,
                child: const Text('Dbl Click Left'),
              ),
            ],
          ),
                 TextField(
                  controller: _textStr,
                  decoration: const InputDecoration(
                    labelText: 'Str',
                  ),
                ),
              
 
          // Add a hint about the keyboard shortcut
          const SizedBox(height: 20),

          const Text(
            '''Tip: Press the "G" key to quickly get location
                    if (event.logicalKey == LogicalKeyboardKey.keyG) {
          _triggerGetLocation();
        }
      if (event.logicalKey == LogicalKeyboardKey.keyM)
  recordTask(() async => _triggerMove(), x:_x, y:_y);
if (event.logicalKey == LogicalKeyboardKey.keyD)
  recordTask(() async => _triggerDragMove(), x:_x, y:_y);
if (event.logicalKey == LogicalKeyboardKey.keyS&& event.logicalKey==LogicalKeyboardKey.alt)
  recordTask(() async => _triggerSetStr(), x:_x, y:_y);
  if (event.logicalKey == LogicalKeyboardKey.keyS)
  recordTask(() async => _triggerSmoothMove(), x:_x, y:_y);
    if (event.logicalKey == LogicalKeyboardKey.keyC)
  recordTask(() async => _triggerLeftClick(), x:_x, y:_y);
    if (event.logicalKey == LogicalKeyboardKey.keyV)
  recordTask(() async => _triggerRightClick(), x:_x, y:_y);
            ''',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ],

      ),
    ),
  );
}

// Helper method to trigger get location
 _triggerGetLocation() {
  if (_initialized) {
    _safeCall(() => svc.getLocation(), 'GetLocation');
  }
}
 Future<void>_triggerMove()async {
  if (_initialized) {
   await _safeCall(() => svc.move(
                            _x,
                            _y,
                          ),
                          'Move',
                        );
  }
}
Future<void> _triggerDragMove() async {
  if (_initialized) {
    // First perform the drag, then after it completes, perform the click
    await _safeCall(() => svc.dragSmoothTo(_x, _y), 'DragSmooth');
    await _safeCall(() => svc.click('left'), 'Click Left');
  }
}
Future<void>  _triggerSmoothMove() async {
  if (_initialized) {
    // First perform the drag, then after it completes, perform the click
    await _safeCall(() => svc.moveSmooth(_x, _y), 'MoveSmooth');
   // await _safeCall(() => svc.click('left'), 'Click Left');
  }
}

 Future<void> _triggerLeftClick() async {
  if (_initialized) {
    // First perform the drag, then after it completes, perform the click
  //  await _safeCall(() => svc.dragSmoothTo(_x, _y), 'DragSmooth');
    await _safeCall(() => svc.click('left'), 'Click Left');
  }
}
 Future<void> _triggerRightClick() async {
  if (_initialized) {
    // First perform the drag, then after it completes, perform the click
   // await _safeCall(() => svc.dragSmoothTo(_x, _y), 'DragSmooth');
    await _safeCall(() => svc.click('Right'), 'Click Right');
  }
}
 Future<void> _triggerTypeStr(sstr) async {
  if (_initialized) {
    // First perform the drag, then after it completes, perform the click
    await _safeCall(() => svc.typeStr(sstr), 'TypeStr'); }
}

 Future<void> _triggerSetStr() async {
  if (_initialized) {
    // First perform the drag, then after it completes, perform the click
   str = _textStr.text;
   _textStr.clear();
   final fut= _triggerTypeStr(str);
   setState(() {
     str='';
   });
   return fut;
   }}

  Widget _buildKeyboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Typing & Text', style: TextStyle(fontSize: 16)),
          TextField(
            controller: _typeText,
            decoration: const InputDecoration(labelText: 'Text to type'),
          ),
          ElevatedButton(
            onPressed: _initialized
                ? () => _safeCall(() => svc.typeStr(_typeText.text), 'TypeStr')
                : null,
            child: const Text('TypeStr'),
          ),
          ElevatedButton(
            onPressed: _initialized
                ? () =>
                      _safeCall(() => svc.writeAll(_typeText.text), 'WriteAll')
                : null,
            child: const Text('WriteAll (Clipboard)'),
          ),
          ElevatedButton(
            onPressed: _initialized
                ? () => _safeCall(() => svc.readAll(), 'ReadAll')
                : null,
            child: const Text('ReadAll (Clipboard)'),
          ),
          const Divider(),
          const Text('Key Taps', style: TextStyle(fontSize: 16)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keyTapKey,
                  decoration: const InputDecoration(
                    labelText: 'Key (e.g., "enter")',
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _keyTapMods,
                  decoration: const InputDecoration(
                    labelText: 'Mods (e.g., "ctrl,shift")',
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _initialized
                    ? () => _safeCall(
                        () =>
                            svc.keyTap(_keyTapKey.text, mods: _keyTapMods.text),
                        'KeyTap',
                      )
                    : null,
                child: const Text('KeyTap'),
              ),
            ],
          ),
          const Text('Key Toggles (Up/Down)', style: TextStyle(fontSize: 16)),
          Row(
            children: [
              ElevatedButton(
                onPressed: _initialized
                    ? () => _safeCall(
                        () => svc.keyToggle('shift', direction: 'down'),
                        'Toggle Shift Down',
                      )
                    : null,
                child: const Text('Shift Down'),
              ),
              ElevatedButton(
                onPressed: _initialized
                    ? () => _safeCall(
                        () => svc.keyToggle('shift', direction: 'up'),
                        'Toggle Shift Up',
                      )
                    : null,
                child: const Text('Shift Up'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScreenCaptureTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Capture Region', style: TextStyle(fontSize: 16)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _captureX,
                  decoration: const InputDecoration(labelText: 'X'),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _captureY,
                  decoration: const InputDecoration(labelText: 'Y'),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _captureW,
                  decoration: const InputDecoration(labelText: 'W'),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _captureH,
                  decoration: const InputDecoration(labelText: 'H'),
                ),
              ),
            ],
          ),
          Row(
            children: [
              ElevatedButton(
                onPressed: _initialized ? _doCaptureAndShow : null,
                child: const Text('Capture Base64 & Show'),
              ),
              ElevatedButton(
                onPressed: _initialized
                    ? () =>
                          _safeCall(() => svc.getScreenSize(), 'GetScreenSize')
                    : null,
                child: const Text('GetScreenSize'),
              ),
              ElevatedButton(
                onPressed: _initialized
                    ? () => _safeCall(() => svc.displaysNum(), 'DisplaysNum')
                    : null,
                child: const Text('DisplaysNum'),
              ),
            ],
          ),
          const Divider(),
          _buildImagePreview(),
        ],
      ),
    );
  }

  Future<void> _doCaptureAndShow() async {
    final x = int.tryParse(_captureX.text) ?? 0;
    final y = int.tryParse(_captureY.text) ?? 0;
    final w = int.tryParse(_captureW.text) ?? 200;
    final h = int.tryParse(_captureH.text) ?? 150;
    try {
      final r = await _safeCall(
        () => svc.captureScreenBase64(x, y, w, h),
        'CaptureScreenBase64',
      );
      if (r?.success == true) {
        final data = r!.data as Map?;
        final b64 = data?['base64_png'];
        if (b64 is String) {
          setState(() {
            _capturedImage = base64Decode(b64);
          });
          _appendLog('Captured image: ${_capturedImage!.lengthInBytes} bytes');
        }
      }
    } catch (e) {
      _appendLog('Capture error: $e');
    }
  }
Widget _buildScreenCaptureclassTab() {
    return CaptureScreen();
  }

  Widget _buildFindingCVTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Image Finding (GCV & Bitmap)',
            style: TextStyle(fontSize: 16),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tplPath,
                  decoration: const InputDecoration(labelText: 'Template Path'),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _targetPath,
                  decoration: const InputDecoration(
                    labelText: 'Target/Screen Path',
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              ElevatedButton(
                onPressed: _initialized
                    ? () => _safeCall(
                        () =>
                            svc.gcvFindImgFile(_tplPath.text, _targetPath.text),
                        'GcvFindImgFile',
                      )
                    : null,
                child: const Text('Find Image File'),
              ),
              ElevatedButton(
                onPressed: _initialized
                    ? () => _safeCall(
                        () => svc.gcvFindAllImgFile(
                          _tplPath.text,
                          _targetPath.text,
                        ),
                        'GcvFindAllImgFile',
                      )
                    : null,
                child: const Text('Find All Image File'),
              ),
            ],
          ),
          const Divider(),
          const Text('Bitmap Find & Move', style: TextStyle(fontSize: 16)),
          Row(
            children: [
              ElevatedButton(
                onPressed: _initialized
                    ? () => _safeCall(
                        () => svc.bitmapOpenFind(_tplPath.text),
                        'BitmapOpenFind',
                      )
                    : null,
                child: const Text('Bitmap Find'),
              ),
              ElevatedButton(
                onPressed: _initialized
                    ? () => _safeCall(
                        () => svc.moveToFoundFromFile(_tplPath.text),
                        'MoveToFoundFromFile',
                      )
                    : null,
                child: const Text('Move to Found Bitmap'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHooksEventsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Global Hooks & Events', style: TextStyle(fontSize: 16)),
          Row(
            children: [
              ElevatedButton(
                onPressed: _initialized ? _hookStartStop : null,
                child: Text(
                  _hookRunning ? 'Stop Hook Listener' : 'Start Hook Listener',
                ),
              ),
              ElevatedButton(
                onPressed: _initialized ? _registerHotkey : null,
                child: const Text('Register Hotkey: Ctrl+Alt+Z'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Received Events:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _events.length,
              reverse: false,
              itemBuilder: (context, i) {
                final e = _events[i];
                return Text(
                  '${e.op ?? '<Unsolicited>'} | ${e.data ?? e.error ?? ''}',
                  style: TextStyle(fontSize: 12),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _hookStartStop() async {
    if (!_hookRunning) {
      final r = await _safeCall(() => svc.hookStart(), 'HookStart');
      if (r?.success == true) setState(() => _hookRunning = true);
    } else {
      svc.hookStop();
      _appendLog('HookStop called (may take a moment for thread shutdown)');
      setState(() => _hookRunning = false);
    }
  }

  Future<void> _registerHotkey() async {
    await _safeCall(
      () => svc.hookRegisterCombo('ctrl,alt', 'z'),
      'HookRegisterCombo',
    );
    _appendLog('Try pressing CTRL+ALT+Z to trigger a registered event.');
  }

  Widget _buildImagePreview() {
    if (_capturedImage == null) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('No image captured')),
      );
    }
    return SizedBox(
      height: 180,
      child: Image.memory(_capturedImage!, fit: BoxFit.contain),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ScreenGot Test Suite'),
        actions: [ElevatedButton(
  onPressed: () async {
    await runTasks();
    taskList=[];
    setState(() {
      
    });
  },
  child: const Text("Run Task List"),
),
],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Mouse'),
            Tab(text: "TaskList",),
            Tab(text: 'Keyboard'),
            Tab(text: 'Capture'),
            Tab(text: 'Capturenew'),
            Tab(text: 'Find/CV'),
            Tab(text: 'Hooks/Log'),
          ],
          onTap: (index) => setState(() => _tabIndex = index),
        ),
      ),
      body: Row(
        children: [
          // Left Side: Test Controls
          Expanded(
            flex: 2,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMouseTab(),
                                    _buildTaskList()
,
                _buildKeyboardTab(),
                _buildScreenCaptureTab(),
                _buildScreenCaptureclassTab(),
                _buildFindingCVTab(),
                _buildHooksEventsTab(),

              ],
            ),
          ),
          // Right Side: Global Log
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'System Log',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Status: ${_initialized ? 'READY' : 'Loading'} | Task ID: ${_lastTaskId ?? 'None'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _initialized ? Colors.green : Colors.red,
                    ),
                  ),
                  const Divider(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _log.length,
                      reverse: true, // Show newest entries at the top
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          _log[i],
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
