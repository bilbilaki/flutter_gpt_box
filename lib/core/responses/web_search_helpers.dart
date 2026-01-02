 part of 'package:gpt_box/view/page/home/home.dart';


class WebSearchApi {
  final ResponsesService _svc;
  WebSearchApi(this._svc);

  Future<String> quickSearch({
    required String query,
    String model = 'gpt-5',
  }) async {
    final req = ResponsesRequest(
      model: model,
      input: query,
      tools: [WebSearchTool()],
      toolChoice: 'auto', previousResponseId: null,
    );
    final res = await _svc.create(req);
    return res.outputText;
  }

  Future<DeepResponse> searchWithFilters({
    required String query,
    String model = 'gpt-5',
    List<String>? allowedDomains,
    bool includeSources = true,
    WebSearchUserLocation? userLocation,
  }) async {
    final tool = WebSearchTool(
      filters: allowedDomains != null
          ? WebSearchFilters(allowedDomains: allowedDomains)
          : null,
      userLocation: userLocation,
    );
    final req = ResponsesRequest(
      model: model,
      input: query,
      tools: [tool],
      toolChoice: 'auto',
      include: includeSources ? ['web_search_call.action.sources'] : null, previousResponseId: null,
    );
    return await _svc.create(req);
  }

  // Legacy preview with context size
  Future<DeepResponse> previewWithContext({
    required String query,
    String model = 'gpt-4.1',
    String contextSize = 'low', // low | medium | high
  }) async {
    final req = ResponsesRequest(
      model: model,
      input: query,
      tools: [WebSearchPreviewTool(searchContextSize: contextSize)],
      toolChoice: 'auto', previousResponseId: null,
    );
    return await _svc.create(req);
  }
}
