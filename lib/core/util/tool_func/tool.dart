import 'dart:async';
import 'dart:convert';
import 'dart:io'; // For Platform.isAndroid
import 'package:android_package_installer/android_package_installer.dart'; // For APK installation

import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:gpt_box/core/services/download_manager_service.dart';
import 'package:gpt_box/core/services/file_index.dart';
import 'package:gpt_box/core/services/pdf_opration.dart';
import 'package:gpt_box/core/util/utils.dart';
// import 'package:flutter_js/extensions/fetch.dart';
// import 'package:flutter_js/flutter_js.dart';

import 'package:gpt_box/data/model/chat/history/history.dart';
import 'package:gpt_box/data/model/download.dart';
import 'package:gpt_box/data/res/build_data.dart';
import 'package:gpt_box/data/res/l10n.dart';
import 'package:gpt_box/data/store/all.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:native_zip/native_zip.dart';
import 'package:sms_sender_background/sms_sender.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';
import '../../../env.dart';
part 'type.dart';
part 'func/iface.dart';
part 'func/http.dart';
part 'func/terminal.dart';
part 'func/memory.dart';
part 'func/history.dart';
part 'mcp.dart';
part 'internal_mcp_server.dart';
part 'func/urlluancher.dart';
part 'func/contectsms.dart';
part 'func/download.dart';
part 'func/ziptool.dart';
part 'func/filemanager.dart';
part 'func/pdftool.dart';
part 'func/webbuilder.dart';
part 'func/python_project_builder.dart';
part 'func/go_project_builder.dart';
part 'func/type_script_builder.dart';

abstract final class OpenAIFuncCalls {
  static const internalTools = [
    TfMemory.instance,
    TfHistory.instance,
    // TfJs.instance,
    TfTerminal.instance,
    TfHttpReq.instance,
    TfUrlLuancher.instance,
    TfSMSSender.instance,
    TfDownloader.instance,
    TfFileManager.instance,
    TfPdfManager.instance,
    TfZipManager.instance,
    TfWebBuilder.instance,
    TfPythonProjectBuilder.instance,
    TfGoProjectBuilder.instance,
  ];

  static Future<Set<ChatCompletionTool>> get tools async {
    if (!Stores.mcp.enabled.get()) return {};

    try {
      // All tools are now handled through MCP protocol
      return McpTools.tools;
    } catch (e, s) {
      Loggers.app.warning('Load MCP tools failed', e, s);
      return {};
    }
  }

  static Future<_Ret?> handle(
    _CallResp resp,
    ToolConfirm askConfirm,
    OnToolLog onToolLog,
  ) async {
    switch (resp.type) {
      case ChatCompletionMessageToolCallType.function:
        final targetName = resp.function.name;

        // Resolve function id mapping to server/tool name
        final mapping = McpTools._functionNameMap[targetName];
        if (mapping != null && mapping.key == InternalMcpServer.serverName) {
          final toolName = mapping.value;
          final func = internalTools.firstWhereOrNull(
            (e) => e.name == toolName,
          );
          if (func != null) {
            final args = await _parseMap(resp.function.arguments);
            if (!await askConfirm(func, func.help(resp, args))) return null;
          }
        }

        // All tools are now handled through MCP protocol
        return await McpTools.handle(resp, onToolLog);
    }
  }
}
