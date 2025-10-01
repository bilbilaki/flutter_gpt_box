// lib/main.dart - Comprehensive Test UI

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for TextInputFormatter

import 'models/native_response.dart';
import 'services/screengot_service.dart';

void main() {
  runApp(const ScreenGotDemoApp());
}

class ScreenGotDemoApp extends StatelessWidget {
  const ScreenGotDemoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScreenGot Test Suite',
      theme: ThemeData(primarySwatch: Colors.blueGrey),
      home: const DemoHomePage(),
    );
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
      return r;
    } catch (e) {
      _appendLog('ERROR ($opName): $e');
      return null;
    }
  }

  // --- BUILD TABS ---

  Widget _buildMouseTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
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
                          _safeCall(() => svc.moveSmooth(50, 50), 'MoveSmooth')
                    : null,
                child: const Text('MoveSmooth (50,50)'),
              ),
              ElevatedButton(
                onPressed: _initialized
                    ? () => _safeCall(
                        () => svc.dragSmoothTo(50, 50),
                        'DragSmooth (50,50)',
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
        ],
      ),
    );
  }

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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Mouse'),
            Tab(text: 'Keyboard'),
            Tab(text: 'Capture'),
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
                _buildKeyboardTab(),
                _buildScreenCaptureTab(),
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
