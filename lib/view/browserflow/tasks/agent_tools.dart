// agent_tools.dart

import 'package:openai_dart/openai_dart.dart';
import 'browser_controller.dart';

/// This class organizes all browser automation tools into categories
/// and provides the routing mechanism for the dual-agent system:
/// - Brain 1 (Router): Selects the appropriate tool category
/// - Brain 2 (Specialist): Executes specific tools within that category
class AgentTools {
  final BrowserController browser;

  // Constructor
  AgentTools({required this.browser});

  // === 1. THE ROUTER (BRAIN 1) ===
  /// The router tool that selects which category of tools to use
  static const ChatCompletionTool toolSelector = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'select_tool_category',
      description:
          'Select a category of browser automation tools to use based on the user task.',
      parameters: {
        'type': 'object',
        'properties': {
          'category': {
            'type': 'string',
            'description': 'The category of tools to use.',
            'enum': [
              'browserSessionTools',
              'navigationTools',
              'elementInteractionTools',
              'elementInspectionTools',
              'formTools',
              'scrollingTools',
              'waitingTools',
              'screenshotTools',
              'advancedTools',
            ],
          },
          'task_information': {
            'type': 'string',
            'description': 'The specific sub-task for the specialist agent.',
          },
        },
        'required': ['category', 'task_information'],
      },
    ),
  );

  // === 2. THE SPECIALISTS (BRAIN 2) ===

  // -- Specialist 1: Browser Session Tools --
  List<ChatCompletionTool> get browserSessionTools => [
    initializeBrowserSessionTool,
    closeBrowserSessionTool,
    createNewPageTool,
    getSessionStatusTool,
  ];

  Map<String, Function> get browserSessionToolMap => {
    'initialize_browser_session': (Map<String, dynamic> args) async {
      // Note: BuildContext should be passed from the calling widget
      return await browser.initializeBrowserSession(null);
    },
    'close_browser_session': (Map<String, dynamic> args) async =>
        await browser.closeBrowserSession(),
    'create_new_page': (Map<String, dynamic> args) async =>
        await browser.createNewPage(),
    'get_session_status': (Map<String, dynamic> args) =>
        browser.getSessionStatus(),
  };

  // -- Specialist 2: Navigation Tools --
  List<ChatCompletionTool> get navigationTools => [
    loadUrlTool,
    reloadPageTool,
    goBackTool,
    goForwardTool,
    getCurrentUrlTool,
    getPageTitleTool,
  ];

  Map<String, Function> get navigationToolMap => {
    'load_url': (Map<String, dynamic> args) async =>
        await browser.loadUrl(args['url']),
    'reload_page': (Map<String, dynamic> args) async =>
        await browser.reloadPage(waitUntil: args['wait_until'] ?? true),
    'go_back': (Map<String, dynamic> args) async => await browser.goBack(),
    'go_forward': (Map<String, dynamic> args) async =>
        await browser.goForward(),
    'get_current_url': (Map<String, dynamic> args) async =>
        await browser.getCurrentUrl(),
    'get_page_title': (Map<String, dynamic> args) async =>
        await browser.getPageTitle(),
  };

  // -- Specialist 3: Element Interaction Tools --
  List<ChatCompletionTool> get elementInteractionTools => [
    clickElementTool,
    typeInElementTool,
    hoverElementTool,
    focusElementTool,
    clearInputTool,
    setCheckboxTool,
    pressKeyTool,
    typeTextTool,
  ];

  Map<String, Function> get elementInteractionToolMap => {
    'click_element': (Map<String, dynamic> args) async =>
        await browser.clickElement(args['selector']),
    'type_in_element': (Map<String, dynamic> args) async =>
        await browser.typeInElement(args['selector'], args['text']),
    'hover_element': (Map<String, dynamic> args) async =>
        await browser.hoverElement(args['selector']),
    'focus_element': (Map<String, dynamic> args) async =>
        await browser.focusElement(args['selector']),
    'clear_input': (Map<String, dynamic> args) async =>
        await browser.clearInput(args['selector']),
    'set_checkbox': (Map<String, dynamic> args) async =>
        await browser.setCheckbox(args['selector'], args['checked']),
    'press_key': (Map<String, dynamic> args) async =>
        await browser.pressKey(args['key']),
    'type_text': (Map<String, dynamic> args) async {
      final delayMs = args['delay_ms'] as int?;
      final delay = delayMs != null ? Duration(milliseconds: delayMs) : null;
      return await browser.typeText(args['text'], delay: delay);
    },
  };

  // -- Specialist 4: Element Inspection Tools --
  List<ChatCompletionTool> get elementInspectionTools => [
    readTextContentTool,
    getElementValueTool,
    getElementAttributesTool,
    elementExistsTool,
    countElementsTool,
    getInteractiveElementsTool,
    getTextsOfAllElementsTool,
    getAllLinksTool,
    getAllFormInputsTool,
  ];

  Map<String, Function> get elementInspectionToolMap => {
    'read_text_content': (Map<String, dynamic> args) async =>
        await browser.readTextContent(selector: args['selector']),
    'get_element_value': (Map<String, dynamic> args) async =>
        await browser.getElementValue(args['selector']),
    'get_element_attributes': (Map<String, dynamic> args) async =>
        await browser.getElementAttributes(
          args['selector'],
          List<String>.from(args['attributes']),
        ),
    'element_exists': (Map<String, dynamic> args) async =>
        await browser.elementExists(args['selector']),
    'count_elements': (Map<String, dynamic> args) async =>
        await browser.countElements(args['selector']),
    'get_interactive_elements': (Map<String, dynamic> args) async =>
        await browser.getInteractiveElements(),
    'get_texts_of_all_elements': (Map<String, dynamic> args) async =>
        await browser.getTextsOfAllElements(args['selector']),
    'get_all_links': (Map<String, dynamic> args) async =>
        await browser.getAllLinks(),
    'get_all_form_inputs': (Map<String, dynamic> args) async =>
        await browser.getAllFormInputs(),
  };

  // -- Specialist 5: Form Tools --
  List<ChatCompletionTool> get formTools => [
    selectDropdownOptionTool,
    submitFormTool,
  ];

  Map<String, Function> get formToolMap => {
    'select_dropdown_option': (Map<String, dynamic> args) async =>
        await browser.selectDropdownOption(
          args['selector'],
          args['value_or_text'],
          byValue: args['by_value'] ?? true,
        ),
    'submit_form': (Map<String, dynamic> args) async =>
        await browser.submitForm(args['selector']),
  };

  // -- Specialist 6: Scrolling Tools --
  List<ChatCompletionTool> get scrollingTools => [
    scrollIntoViewTool,
    scrollPageTool,
    scrollToTopTool,
    scrollToBottomTool,
  ];

  Map<String, Function> get scrollingToolMap => {
    'scroll_into_view': (Map<String, dynamic> args) async =>
        await browser.scrollIntoView(
          args['selector'],
          smooth: args['smooth'] ?? true,
          block: args['block'] ?? 'center',
        ),
    'scroll_page': (Map<String, dynamic> args) async =>
        await browser.scrollPage(
          args['x'] ?? 0,
          args['y'] ?? 0,
          smooth: args['smooth'] ?? true,
        ),
    'scroll_to_top': (Map<String, dynamic> args) async =>
        await browser.scrollToTop(),
    'scroll_to_bottom': (Map<String, dynamic> args) async =>
        await browser.scrollToBottom(),
  };

  // -- Specialist 7: Waiting Tools --
  List<ChatCompletionTool> get waitingTools => [
    waitForElementTool,
    waitForNavigationTool,
    isPageLoadingTool,
  ];

  Map<String, Function> get waitingToolMap => {
    'wait_for_element': (Map<String, dynamic> args) async {
      return await browser.waitForElement(args['selector']);
    },
    'wait_for_navigation': (Map<String, dynamic> args) async {
      return await browser.waitForNavigation();
    },
    'is_page_loading': (Map<String, dynamic> args) async =>
        await browser.isPageLoading(),
  };

  // -- Specialist 8: Screenshot Tools --
  List<ChatCompletionTool> get screenshotTools => [takeScreenshotTool];

  Map<String, Function> get screenshotToolMap => {
    'take_screenshot': (Map<String, dynamic> args) async =>
        await browser.takeScreenshot(
          selector: args['selector'],
          filePath: args['file_path'],
        ),
  };

  // -- Specialist 9: Advanced Tools --
  List<ChatCompletionTool> get advancedTools => [
    evaluateJavaScriptTool,
    getPageHTMLTool,
    getViewportSizeTool,
    setViewportSizeTool,
    setCookieTool,
    getCookiesTool,
    deleteCookieTool,
  ];

  Map<String, Function> get advancedToolMap => {
    'evaluate_javascript': (Map<String, dynamic> args) async =>
        await browser.evaluateJavaScript(args['script']),
    'get_page_html': (Map<String, dynamic> args) async =>
        await browser.getPageHTML(),
    'get_viewport_size': (Map<String, dynamic> args) async =>
        await browser.getViewportSize(),
    'set_viewport_size': (Map<String, dynamic> args) async =>
        await browser.setViewportSize(args['width'], args['height']),
    'set_cookie': (Map<String, dynamic> args) async => await browser.setCookie(
      args['name'],
      args['value'],
      domain: args['domain'],
      path: args['path'],
    ),
    'get_cookies': (Map<String, dynamic> args) async =>
        await browser.getCookies(),
    'delete_cookie': (Map<String, dynamic> args) async =>
        await browser.deleteCookie(args['name']),
  };

  // === 3. MAPS TO CONNECT ROUTER TO SPECIALISTS ===
  /// Returns the tool list for a given category
  Map<String, List<ChatCompletionTool>> getSpecialistToolList() {
    return {
      'browserSessionTools': browserSessionTools,
      'navigationTools': navigationTools,
      'elementInteractionTools': elementInteractionTools,
      'elementInspectionTools': elementInspectionTools,
      'formTools': formTools,
      'scrollingTools': scrollingTools,
      'waitingTools': waitingTools,
      'screenshotTools': screenshotTools,
      'advancedTools': advancedTools,
    };
  }

  /// Returns the function map for a given category
  Map<String, Map<String, Function>> getSpecialistFunctionMap() {
    return {
      'browserSessionTools': browserSessionToolMap,
      'navigationTools': navigationToolMap,
      'elementInteractionTools': elementInteractionToolMap,
      'elementInspectionTools': elementInspectionToolMap,
      'formTools': formToolMap,
      'scrollingTools': scrollingToolMap,
      'waitingTools': waitingToolMap,
      'screenshotTools': screenshotToolMap,
      'advancedTools': advancedToolMap,
    };
  }

  // === 4. ALL TOOL SCHEMAS ===

  // -- Browser Session Tools --
  static const initializeBrowserSessionTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'initialize_browser_session',
      description:
          'Initialize a new browser session. Must be called before any other browser operations.',
      parameters: {'type': 'object', 'properties': {}},
    ),
  );

  static const closeBrowserSessionTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'close_browser_session',
      description: 'Close the current browser session and free resources.',
      parameters: {'type': 'object', 'properties': {}},
    ),
  );

  static const createNewPageTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'create_new_page',
      description: 'Create a new page/tab in the current browser session.',
      parameters: {'type': 'object', 'properties': {}},
    ),
  );

  static const getSessionStatusTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'get_session_status',
      description: 'Get the current status of the browser session.',
      parameters: {'type': 'object', 'properties': {}},
    ),
  );

  // -- Navigation Tools --
  static const loadUrlTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'load_url',
      description: 'Navigate to a specific URL in the browser.',
      parameters: {
        'type': 'object',
        'properties': {
          'url': {
            'type': 'string',
            'description':
                'The URL to navigate to (must include http:// or https://).',
          },
        },
        'required': ['url'],
      },
    ),
  );

  static const reloadPageTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'reload_page',
      description: 'Reload the current page.',
      parameters: {
        'type': 'object',
        'properties': {
          'wait_until': {
            'type': 'boolean',
            'description':
                'Whether to wait until the page is fully loaded. Default: true.',
          },
        },
      },
    ),
  );

  static const goBackTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'go_back',
      description: 'Navigate back in browser history.',
      parameters: {'type': 'object', 'properties': {}},
    ),
  );

  static const goForwardTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'go_forward',
      description: 'Navigate forward in browser history.',
      parameters: {'type': 'object', 'properties': {}},
    ),
  );

  static const getCurrentUrlTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'get_current_url',
      description: 'Get the current page URL.',
      parameters: {'type': 'object', 'properties': {}},
    ),
  );

  static const getPageTitleTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'get_page_title',
      description: 'Get the title of the current page.',
      parameters: {'type': 'object', 'properties': {}},
    ),
  );

  // -- Element Interaction Tools --
  static const clickElementTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'click_element',
      description: 'Click an element on the page using a CSS selector.',
      parameters: {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description':
                'CSS selector for the element to click (e.g., "#submit-button", ".login-btn").',
          },
        },
        'required': ['selector'],
      },
    ),
  );

  static const typeInElementTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'type_in_element',
      description:
          'Type text into an input field or textarea using a CSS selector.',
      parameters: {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description':
                'CSS selector for the input element (e.g., "#email", "input[name=\'username\']").',
          },
          'text': {
            'type': 'string',
            'description': 'The text to type into the element.',
          },
        },
        'required': ['selector', 'text'],
      },
    ),
  );

  static const hoverElementTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'hover_element',
      description: 'Hover over an element to trigger hover effects.',
      parameters: {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description': 'CSS selector for the element to hover over.',
          },
        },
        'required': ['selector'],
      },
    ),
  );

  static const focusElementTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'focus_element',
      description: 'Focus on a specific element.',
      parameters: {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description': 'CSS selector for the element to focus.',
          },
        },
        'required': ['selector'],
      },
    ),
  );

  static const clearInputTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'clear_input',
      description: 'Clear the value of an input field.',
      parameters: {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description': 'CSS selector for the input element to clear.',
          },
        },
        'required': ['selector'],
      },
    ),
  );

  static const setCheckboxTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'set_checkbox',
      description: 'Check or uncheck a checkbox or radio button.',
      parameters: {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description': 'CSS selector for the checkbox or radio button.',
          },
          'checked': {
            'type': 'boolean',
            'description':
                'Whether to check (true) or uncheck (false) the element.',
          },
        },
        'required': ['selector', 'checked'],
      },
    ),
  );

  static const pressKeyTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'press_key',
      description:
          'Simulate pressing a keyboard key (e.g., "Enter", "Tab", "Escape").',
      parameters: {
        'type': 'object',
        'properties': {
          'key': {
            'type': 'string',
            'description':
                'The key to press (e.g., "Enter", "Tab", "Escape", "ArrowDown").',
          },
        },
        'required': ['key'],
      },
    ),
  );

  static const typeTextTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'type_text',
      description:
          'Type text character by character with realistic delays (simulates human typing).',
      parameters: {
        'type': 'object',
        'properties': {
          'text': {'type': 'string', 'description': 'The text to type.'},
          'delay_ms': {
            'type': 'integer',
            'description':
                'Delay in milliseconds between each character. Default: 100ms.',
          },
        },
        'required': ['text'],
      },
    ),
  );

  // -- Element Inspection Tools --
  static const readTextContentTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'read_text_content',
      description:
          'Read the visible text content of the page or a specific element.',
      parameters: {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description':
                'Optional CSS selector for a specific element. If omitted, reads the entire page body.',
          },
        },
      },
    ),
  );

  static const getElementValueTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'get_element_value',
      description:
          'Get the value of an input, textarea, or selected option in a select element.',
      parameters: {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description': 'CSS selector for the element.',
          },
        },
        'required': ['selector'],
      },
    ),
  );

  static const getElementAttributesTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'get_element_attributes',
      description:
          'Get specific attributes of an element (e.g., href, src, alt, class).',
      parameters: {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description': 'CSS selector for the element.',
          },
          'attributes': {
            'type': 'array',
            'description':
                'List of attribute names to retrieve (e.g., ["href", "class", "id"]).',
            'items': {'type': 'string'},
          },
        },
        'required': ['selector', 'attributes'],
      },
    ),
  );

  static const elementExistsTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'element_exists',
      description: 'Check if an element exists on the page.',
      parameters: {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description': 'CSS selector for the element.',
          },
        },
        'required': ['selector'],
      },
    ),
  );

  static const countElementsTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'count_elements',
      description: 'Count how many elements match a CSS selector.',
      parameters: {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description': 'CSS selector for the elements to count.',
          },
        },
        'required': ['selector'],
      },
    ),
  );

  static const getInteractiveElementsTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'get_interactive_elements',
      description:
          'Get all interactive elements (buttons, links, inputs) on the page with their properties.',
      parameters: {'type': 'object', 'properties': {}},
    ),
  );

  static const getTextsOfAllElementsTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'get_texts_of_all_elements',
      description: 'Get the text content of all elements matching a selector.',
      parameters: {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description': 'CSS selector for the elements.',
          },
        },
        'required': ['selector'],
      },
    ),
  );

  static const getAllLinksTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'get_all_links',
      description:
          'Get all links (anchor tags) on the page with their text and href attributes.',
      parameters: {'type': 'object', 'properties': {}},
    ),
  );

  static const getAllFormInputsTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'get_all_form_inputs',
      description:
          'Get all form inputs (input, select, textarea) with their properties.',
      parameters: {'type': 'object', 'properties': {}},
    ),
  );

  // -- Form Tools --
  static const selectDropdownOptionTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'select_dropdown_option',
      description:
          'Select an option in a dropdown (select element) by value or visible text.',
      parameters: {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description': 'CSS selector for the select element.',
          },
          'value_or_text': {
            'type': 'string',
            'description': 'The value or text of the option to select.',
          },
          'by_value': {
            'type': 'boolean',
            'description':
                'Whether to select by value (true) or by visible text (false). Default: true.',
          },
        },
        'required': ['selector', 'value_or_text'],
      },
    ),
  );

  static const submitFormTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'submit_form',
      description:
          'Submit a form containing the specified element, or submit a form element directly.',
      parameters: {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description':
                'CSS selector for the form or an element within the form.',
          },
        },
        'required': ['selector'],
      },
    ),
  );

  // -- Scrolling Tools --
  static const scrollIntoViewTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'scroll_into_view',
      description: 'Scroll to a specific element on the page.',
      parameters: {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description': 'CSS selector for the element to scroll to.',
          },
          'smooth': {
            'type': 'boolean',
            'description': 'Whether to use smooth scrolling. Default: true.',
          },
          'block': {
            'type': 'string',
            'description':
                'Vertical alignment (start, center, end, nearest). Default: center.',
          },
        },
        'required': ['selector'],
      },
    ),
  );

  static const scrollPageTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'scroll_page',
      description: 'Scroll the page by specified pixels.',
      parameters: {
        'type': 'object',
        'properties': {
          'x': {
            'type': 'integer',
            'description':
                'Horizontal pixels to scroll (positive = right, negative = left).',
          },
          'y': {
            'type': 'integer',
            'description':
                'Vertical pixels to scroll (positive = down, negative = up).',
          },
          'smooth': {
            'type': 'boolean',
            'description': 'Whether to use smooth scrolling. Default: true.',
          },
        },
        'required': ['y'],
      },
    ),
  );

  static const scrollToTopTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'scroll_to_top',
      description: 'Scroll to the top of the page.',
      parameters: {'type': 'object', 'properties': {}},
    ),
  );

  static const scrollToBottomTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'scroll_to_bottom',
      description: 'Scroll to the bottom of the page.',
      parameters: {'type': 'object', 'properties': {}},
    ),
  );

  // -- Waiting Tools --
  static const waitForElementTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'wait_for_element',
      description:
          'Wait for an element to appear and become visible on the page. Timeout is 1000 seconds.',
      parameters: {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description': 'CSS selector for the element to wait for.',
          },
        },
        'required': ['selector'],
      },
    ),
  );

  static const waitForNavigationTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'wait_for_navigation',
      description:
          'Wait for page navigation to complete (useful after clicking links or submitting forms). Timeout is 1000 seconds.',
      parameters: {'type': 'object', 'properties': {}},
    ),
  );

  static const isPageLoadingTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'is_page_loading',
      description: 'Check if the page is currently loading.',
      parameters: {'type': 'object', 'properties': {}},
    ),
  );

  // -- Screenshot Tools --
  static const takeScreenshotTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'take_screenshot',
      description:
          'Take a screenshot of the current page or a specific element.',
      parameters: {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description':
                'Optional CSS selector for a specific element. If omitted, captures the full page.',
          },
          'file_path': {
            'type': 'string',
            'description': 'Optional file path to save the screenshot.',
          },
        },
      },
    ),
  );

  // -- Advanced Tools --
  static const evaluateJavaScriptTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'evaluate_javascript',
      description:
          'Execute arbitrary JavaScript code in the browser context and get the result.',
      parameters: {
        'type': 'object',
        'properties': {
          'script': {
            'type': 'string',
            'description':
                'The JavaScript code to execute. Must return a serializable value.',
          },
        },
        'required': ['script'],
      },
    ),
  );

  static const getPageHTMLTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'get_page_html',
      description: 'Get the complete HTML source code of the current page.',
      parameters: {'type': 'object', 'properties': {}},
    ),
  );

  static const getViewportSizeTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'get_viewport_size',
      description: 'Get the current viewport dimensions (width and height).',
      parameters: {'type': 'object', 'properties': {}},
    ),
  );

  static const setViewportSizeTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'set_viewport_size',
      description:
          'Set the viewport dimensions (useful for responsive testing).',
      parameters: {
        'type': 'object',
        'properties': {
          'width': {
            'type': 'integer',
            'description': 'Viewport width in pixels.',
          },
          'height': {
            'type': 'integer',
            'description': 'Viewport height in pixels.',
          },
        },
        'required': ['width', 'height'],
      },
    ),
  );

  static const setCookieTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'set_cookie',
      description: 'Set a cookie for the current page.',
      parameters: {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': 'Cookie name.'},
          'value': {'type': 'string', 'description': 'Cookie value.'},
          'domain': {
            'type': 'string',
            'description': 'Optional cookie domain.',
          },
          'path': {'type': 'string', 'description': 'Optional cookie path.'},
        },
        'required': ['name', 'value'],
      },
    ),
  );

  static const getCookiesTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'get_cookies',
      description: 'Get all cookies for the current page.',
      parameters: {'type': 'object', 'properties': {}},
    ),
  );

  static const deleteCookieTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: 'delete_cookie',
      description: 'Delete a specific cookie.',
      parameters: {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Name of the cookie to delete.',
          },
        },
        'required': ['name'],
      },
    ),
  );
}
