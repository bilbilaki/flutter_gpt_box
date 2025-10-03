part of '../tool.dart';

final class TfHttpReq extends ToolFunc {
  static const instance = TfHttpReq._();

 const TfHttpReq._()
    : super(
        name: 'httpReq',
        parametersSchema: const {
          'type': 'object',
          'properties': {
            'method': {
              'type': 'string',
              'description':
                  'The HTTP method to use (e.g., "GET" for fetching data, "POST" for submitting). Defaults to "GET" if omitted. Confirm the method with the user if not obvious (e.g., for APIs requiring POST).',
            },
            'url': {
              'type': 'string',
              'description':
                  'The full URL endpoint (e.g., "https://api.github.com/users/octocat"). Required. Always verify and confirm the URL with the user before calling—use only trusted, public APIs or sites to avoid security risks.',
            },
            'headers': {
              'type': 'object',
              'description':
                  'Optional key-value object for HTTP headers (e.g., {"Authorization": "Bearer token", "Content-Type": "application/json"}). Use for authentication or custom needs; never include sensitive data without user consent. Defaults to empty.',
            },
            'body': {
              'type': 'string',
              'description':
                  'Optional request body as a string (e.g., JSON encoded as string: "{\"key\": \"value\"}"). Required for POST/PUT with data. For binary blobs, encode as base64 string. Inform the user if encoding is applied.',
            },
            'followRedirects': {
              'type': 'integer',
              'description':
                  'Optional maximum number of redirects to follow (e.g., 5). Defaults to a reasonable limit (e.g., 10); set lower only if the user specifies to prevent infinite loops.',
            },
            'truncateSize': {
              'type': 'integer',
              'description':
                  'Optional: Maximum size (in bytes) to truncate the response body if large (e.g., 10000 to save tokens). Use only if the user requests summarized or token-efficient responses (e.g., "Get a summary of the page"); otherwise, retrieve full content.',
            },
          },
          'required': ['url'],
        },
      );

  @override
  String get description => '''
Use this tool to make HTTP requests for web-based tasks when the user explicitly requests external data (e.g., "Search Wikipedia for AI history" or "Get the latest GitHub issues for this repo"). Do not call unsolicited—base URLs/methods on user input and known public APIs (e.g., api.github.com, en.wikipedia.org/w/api.php, api.stackexchange.com). Ideal for searching, fetching APIs, or downloading content without built-in tools.
The tool sends the request and returns the response as a string (headers, status, body). For JSON, it's a JSON string—parse it logically in your reasoning. For binaries/blobs, expect base64 encoding. Use returned data to inform the user directly.

**Usage Steps (One Request Per Call for Focus):**
1. **Simple GET Request (Default)**:
   - Provide 'url' (e.g., "https://api.github.com/repos/user/repo").
   - Optional: 'headers' for auth (e.g., GitHub token if user provides).
   - Response: Status, headers, and body string. Summarize for the user (e.g., "Here's the repo info: [key details]").
   - Example: User says "What's the weather?"—use a public API like openweathermap.org after confirming location.

2. **POST or Other Methods with Body**:
   - Set 'method' to "POST", add 'body' (JSON as string), and 'headers' if needed (e.g., for API submissions).
   - Confirm body/details with user (e.g., "Sending this JSON to the API—correct?").
   - Useful for user-initiated actions like creating GitHub issues.

3. **Advanced Options**:
   - 'followRedirects': Adjust for sites with redirects (rarely needed).
   - 'truncateSize': Set for long responses (e.g., full web pages)—offer full fetch if truncated (e.g., "Got a preview—want the complete response?").
   - For multi-part tasks (e.g., fetch then process): Call sequentially, using first response to inform the next (e.g., get user ID from API, then fetch profile).

4. **Handling Responses**:
   - Check status code (e.g., 200 OK, 404 Not Found). If errors, inform user and suggest fixes (e.g., "API unavailable—try another URL?").
   - Encoding: JSON is stringified; base64 for blobs—decode in reasoning if needed, but present raw to user unless specified.
   - Integration: Use results to answer queries (e.g., "From Wikipedia: [excerpt]") without further tools unless complex.

**Best Practices to Avoid Errors and Enhance Safety:**
- Always confirm: URLs, methods, and sensitive params (e.g., API keys) with the user—do not fabricate or assume.
- Trusted Sources Only: Stick to public APIs you know (e.g., GitHub, Wikipedia, Stack Overflow); warn about risks for unknown sites.
- Token Efficiency: Use 'truncateSize' proactively for large content; summarize responses to keep conversations concise.
- Multi-Requests: For chained ops (e.g., search then detail), use multiple calls—don't overload one request.
- Privacy/Security: Avoid sending user data in bodies without explicit consent; no private or authenticated requests unless user provides creds.
- Errors: If rate-limited or failed, suggest alternatives (e.g., "GitHub API hit limit—wait or use search?").

Focus on user-requested web access—respect limits and ethics.''';

  @override
  String get l10nName => l10n.toolHttpReqName;

  @override
  String? get l10nTip => l10n.httpToolTip;

  @override
  String help(_CallResp call, _Map args) {
    return l10n.toolHttpReqHelp(args['url'] as String? ?? '<?>');
  }

  @override
  Future<_Ret?> run(_CallResp call, _Map args, OnToolLog log) async {
    final method = args['method'] as String? ?? 'GET';
    final url = args['url'] as String;
    final headers = (args['headers'] as Map? ?? {}).cast<String, dynamic>();
    final body = args['body'] as String?;
    //final forSearch = args['forSearch'] as bool? ?? false;
    final truncateSize = args['truncateSize'] as int?;
    final followRedirects = args['followRedirects'] as int?;

    if (url.startsWith(ApiUrls.base) && headers['Authorization'] == null) {
      headers['Authorization'] = UserApi.tokenProp.get();
    }

    log('Http $method -> $url');
    final resp = await myDio.request(
      url,
      options: Options(
        method: method,
        headers: headers,
        maxRedirects: followRedirects,
        validateStatus: (_) => true,
      ),
      data: body,
    );

    const mimesBin = [
      'application/octet-stream',
      'image/',
      'video/',
      'audio/',
    ];

    const mimesString = [
      'text/',
      'application/json',
      'application/xml',
      'application/javascript',
      'application/x-www-form-urlencoded',
    ];

    final contentType = resp.headers['content-type']?.join(';');

    String tryConvertStr(raw) {
      try {
        return raw.toString();
      } catch (e) {
        return '';
      }
    }

    log('Http $method -> ${resp.statusCode} ${resp.statusMessage}');
    var respBody = switch ((contentType, resp.data)) {
      (_, final String raw) => raw,
      (final typ, final List<int> raw) when mimesString.contains(typ) =>
        await compute(utf8.decode, raw),
      (final String typ, final List<int> raw)
          when mimesBin.any((e) => typ.startsWith(e)) =>
        await compute(base64.encode, raw),
      (_, final List<int> raw) => await compute(utf8.decode, raw),
      _ => tryConvertStr(resp.data),
    };

    // if (forSearch) {
    //   final urlMap = await compute(_filterHtmlUrls, respBody);
    //   if (urlMap.isNotEmpty) {
    //     respBody = '';

    //     final idxes = <int>{};
    //     for (;idxes.length < 10;) {
    //       final idx = Random().nextInt(urlMap.length);
    //       if (idxes.contains(idx)) continue;
    //       idxes.add(idx);
    //     }

    //     final futures = List.generate(idxes.length, (idx) async {
    //       final entry = urlMap.entries.elementAt(idx);
    //       final url = entry.value;
    //       log('Http $method -> $url');
    //       try {
    //         final resp = await myDio.get(
    //           entry.value,
    //           options: Options(
    //             maxRedirects: followRedirects,
    //             headers: headers,
    //             validateStatus: (_) => true,
    //             responseType: ResponseType.plain,
    //           ),
    //         );

    //         final data = resp.data;
    //         if (data is! String) return null;
    //         final html = await compute(_filterRespBody, data);
    //         return html;
    //       } catch (e, s) {
    //         Loggers.app.warning(e, null, s);
    //         log('Http $method -> ${libL10n.error}: $e');
    //       }
    //     });

    //     final res = await Future.wait(futures);
    //     for (final html in res) {
    //       if (html != null) {
    //         respBody += html;
    //       }
    //     }
    //   }
    // }

    if (truncateSize != null && respBody.length > truncateSize) {
      respBody = respBody.substring(0, truncateSize);
    }

    await Future.delayed(Durations.short3);
    log('Http $method -> ${libL10n.success}');
    await Future.delayed(Durations.short3);

    return [ChatContent.text(respBody)];
  }
}

/// Only return the content insides body tag as a <title: url> map.
// Map<String, String> _filterHtmlUrls(String html) {
//   // Remove the first line of <!DOCTYPE html>
//   if (html.startsWith('<!')) {
//     html = html.substring(html.indexOf('>') + 1);
//   }
//   final doc = html_parser.parse(html);
//   final aInBody = doc.querySelectorAll('body a');
//   final map = <String, String>{};
//   // Find all <a> tag with href.
//   for (final a in aInBody) {
//     var href = a.attributes['href'];
//     if (href == null) continue;
//     final title = a.text.trim();
//     if (title.isEmpty) continue;
//     if (!href.startsWith('http')) {
//       // `//duckduckgo.com/l/?uddg=https%3A%2F%2Fwww.sportingnews.com%2Fus%2Folympics%2Fnews`
//       if (href.startsWith('//duckduckgo.com')) {
//         href = Uri.decodeFull(href.replaceFirst('//duckduckgo.com/l/?uddg=', ''));
//       }
//       // `/url?q=` is the query string for google search result.
//       else if (href.startsWith('/url?q=')) {
//         final uri = Uri.parse(href);
//         href = uri.queryParameters['q'] ?? href;
//       }
//     }
//     map[title] = href;
//   }
//   return map;
// }

// /// Return all text content insides body tag.
// String _filterRespBody(String raw) {
//   try {
//     final doc = html_parser.parse(raw);
//     final body = doc.querySelector('body');
//     final text = body?.text;
//     if (text == null || text.isEmpty) return raw;

//     final lines = text.split('\n');
//     final rmIdxs = <int>[];
//     for (var i = 0; i < lines.length; i++) {
//       final line = lines[i];
//       if (line.trim().isEmpty) {
//         rmIdxs.add(i);
//       }
//     }

//     for (var i = rmIdxs.length - 1; i >= 0; i--) {
//       lines.removeAt(rmIdxs[i]);
//     }

//     return lines.join('\n');
//   } catch (_) {
//     // May not html?
//     return raw;
//   }
// }
