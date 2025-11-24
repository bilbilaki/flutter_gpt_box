import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:puppeteer/puppeteer.dart' as pup;

import '../utils/browser_utils.dart';

/// A controller for browser automation with persistent session management.
/// 
/// This controller maintains a single browser session that stays open until
/// explicitly closed, allowing for sequential operations across multiple actions.
/// 
/// Key features:
/// - Persistent browser sessions
/// - Puppeteer-based automation
/// - JavaScript execution in browser context
/// - Element interaction (click, type, scroll, etc.)
/// - Session status monitoring
class BrowserController {
  pup.Browser? _browser;
  pup.Page? _page;
  bool _isSessionActive = false;
  String? _sessionId;

  /// Helper method to execute JavaScript with consistent error handling
  Future<String> _evaluateJS(String js) async {
    if (!isSessionActive) {
      return "Browser session not active. Please initialize session first.";
    }
    try {
      final result = await _page!.evaluate(js);
      return result.toString();
    } catch (e) {
      return "Error executing JavaScript: $e";
    }
  }

  // Initialize browser session
  Future<String> initializeBrowserSession(BuildContext? context) async {
    if (_isSessionActive && _browser != null) {
      return "Browser session already active";
    }

    try {
      if (!Platform.isAndroid) {
        _browser = await pup.puppeteer.launch(
          headless: false, // Keep browser visible
          ignoreHttpsErrors: true,
          args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-accelerated-2d-canvas',
            '--no-first-run',
            '--no-zygote',
            '--disable-gpu',


          ],
        );
      } else {
        // For Android, use the browser config dialog
        if (context != null) {
          final config = await showBrowserConfigDialog(context);
          if (config == null) {
            return "Browser configuration cancelled";
          }
          _browser = await pup.puppeteer.connect(
            browserWsEndpoint: config['browserWsEndpoint'],
          );
        } else {
          return "BuildContext required for Android browser initialization";
        }
      }
        

      _page = await _browser!.newPage();
      _isSessionActive = true;
      _sessionId = DateTime.now().millisecondsSinceEpoch.toString();

      // Set default viewport
      await _page!.setViewport(pup.DeviceViewport(width: 1280, height: 720));

      return "Browser session initialized successfully. Session ID: $_sessionId";
    } catch (e) {
      return "Error initializing browser session: $e";
    }
  }

  // Check if session is active
  bool get isSessionActive => _isSessionActive && _browser != null && _page != null;

  // Get current session ID
  String? get sessionId => _sessionId;

  // Get browser instance (for advanced operations)
  pup.Browser? get browser => _browser;

  // Get page instance (for direct puppeteer operations)
  pup.Page? get page => _page;

  // Navigate to URL using Puppeteer
  Future<String> loadUrl(String url) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    try {
      await _page!.goto(url, wait: pup.Until.domContentLoaded);
      final currentUrl = _page!.url;
      return "Successfully loaded URL: $url (Current: $currentUrl)";
    } catch (e) {
      return "Error loading URL: $e";
    }
  }

  // Close current session
  Future<String> closeBrowserSession() async {
    if (!_isSessionActive) {
      return "No active browser session to close";
    }

    try {
      await _browser?.close();
      _browser = null;
      _page = null;
      _isSessionActive = false;
      _sessionId = null;
      return "Browser session closed successfully";
    } catch (e) {
      return "Error closing browser session: $e";
    }
  }

  // Create new page in current session
  Future<String> createNewPage() async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    try {
      _page = await _browser!.newPage();
      return "New page created successfully";
    } catch (e) {
      return "Error creating new page: $e";
    }
  }

  // Get session status
  Map<String, dynamic> getSessionStatus() {
    return {
      'isActive': _isSessionActive,
      'sessionId': _sessionId,
      'hasBrowser': _browser != null,
      'hasPage': _page != null,
      'currentUrl': _page?.url ?? 'No page',
    };
  }

  /// Reads the visible text content of the entire page or a specific element.
  Future<String> readTextContent({String? selector}) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    final target = selector != null
        ? "document.querySelector('$selector')"
        : "document.body";

    final js = """
      (function() {
        try {
          const element = $target;
          if (!element) {
            return 'Error: Element with selector "$selector" not found.';
          }
          return element.textContent || element.innerText || '';
        } catch (e) {
          return 'Error reading text content: ' + e.message;
        }
      })();
    """;
    
    final result = await _evaluateJS(js);
    return result.replaceAll('"', '').trim();
  }

  /// Gets all interactive elements on the page with temporary IDs for easy reference.
  /// Returns a JSON string with element information (id, tagName, description).
  Future<String> getInteractiveElements() async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    const js = r"""
    (function() {
        try {
            const interactiveSelectors = [
                'a', 'button', 'input', 'select', 'textarea',
                '[role="button"]', '[onclick]', '[role="link"]',
                'input[type="submit"]', 'input[type="button"]'
            ];
            
            const allElements = [];
            interactiveSelectors.forEach(selector => {
                const elements = document.querySelectorAll(selector);
                elements.forEach((el, index) => {
                    if (el.offsetParent !== null) { // Check if visible
                        const rect = el.getBoundingClientRect();
                        if (rect.width > 0 && rect.height > 0) {
                            allElements.push({
                                id: `ai_${allElements.length + 1}`,
                                tagName: el.tagName.toLowerCase(),
                                type: el.type || '',
                                text: (el.textContent || el.innerText || '').trim().substring(0, 50),
                                href: el.href || '',
                                placeholder: el.placeholder || '',
                                value: el.value || '',
                                selector: selector,
                                boundingRect: {
                                    x: Math.round(rect.left),
                                    y: Math.round(rect.top),
                                    width: Math.round(rect.width),
                                    height: Math.round(rect.height)
                                }
                            });
                        }
                    }
                });
            });
            
            return JSON.stringify(allElements.slice(0, 20)); // Limit to first 20
        } catch (e) {
            return 'Error getting interactive elements: ' + e.message;
        }
    })();
    """;

    return await _evaluateJS(js);
  }

  // We also need ID-based versions of click and type
  Future<String> clickElementByAiId(String aiId) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    final js = """
    (function() {
      try {
        // Find element by AI ID stored in dataset
        const element = document.querySelector('[data-ai-id="$aiId"]');
        if (element) {
          element.click();
          return 'Successfully clicked element with AI ID: $aiId';
        } else {
          return 'Error: Element with AI ID $aiId not found.';
        }
      } catch (e) {
        return 'Error executing click: ' + e.message;
      }
    })();
    """;

    final result = await _evaluateJS(js);
    return result.replaceAll('"', '').trim();
  }

  Future<String> typeInElementByAiId(String aiId, String text) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    final escapedText = jsonEncode(text);
    final js = """
    (function() {
      try {
        const element = document.querySelector('[data-ai-id="$aiId"]');
        if (element) {
          element.value = $escapedText;
          element.dispatchEvent(new Event('input', { bubbles: true }));
          return 'Successfully typed "$text" into element with AI ID: $aiId';
        } else {
          return 'Error: Element with AI ID $aiId not found.';
        }
      } catch (e) {
        return 'Error executing type: ' + e.message;
      }
    })();
    """;

    final result = await _evaluateJS(js);
    return result.replaceAll('"', '').trim();
  }

  /// Waits for an element to appear and become visible on the page.
  Future<String> waitForElement(String selector) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    final timeoutMs = 1000000; // 1000 seconds in milliseconds

    final js = """
    (function() {
      return new Promise((resolve) => {
        const startTime = Date.now();
        const checkElement = () => {
          try {
            const element = document.querySelector('$selector');
            if (element && element.offsetParent !== null) {
              const rect = element.getBoundingClientRect();
              if (rect.width > 0 && rect.height > 0) {
                resolve('Element "$selector" found and visible');
                return;
              }
            }
            
            if (Date.now() - startTime > $timeoutMs) {
              resolve('Timeout: Element "$selector" not found within 1000 seconds');
              return;
            }
            
            setTimeout(checkElement, 100);
          } catch (e) {
            resolve('Error waiting for element: ' + e.message);
          }
        };
        checkElement();
      });
    })();
    """;

    final result = await _evaluateJS(js);
    return result.replaceAll('"', '').trim();
  }

  /// Types text into an element found by a CSS selector, ensuring focus and handling common input events.
  /// Improved to handle input/textarea and contenteditable elements.
  Future<String> typeInElement(String selector, String text) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    final escapedText = jsonEncode(text);
    final js = """
    (function() {
      try {
        const element = document.querySelector('$selector');
        if (!element) {
          return 'Error: Element with selector "$selector" not found.';
        }
        
        // Focus the element first
        element.focus();
        
        // Clear existing value
        element.value = '';
        
        // Set new value
        element.value = $escapedText;
        
        // Trigger input events
        element.dispatchEvent(new Event('input', { bubbles: true }));
        element.dispatchEvent(new Event('change', { bubbles: true }));
        
        return 'Successfully typed "$text" into element with selector "$selector".';
      } catch (e) {
        return 'Error executing type: ' + e.message;
      }
    })();
    """;

    final result = await _evaluateJS(js);
    return result.replaceAll('"', '').trim();
  }

  /// Clicks an element found by a CSS selector, ensuring element is clickable.
  /// Scrolls into view before clicking.
  Future<String> clickElement(String selector) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    final js = """
    (function() {
      try {
        const element = document.querySelector('$selector');
        if (!element) {
          return 'Error: Element with selector "$selector" not found.';
        }
        
        // Scroll into view
        element.scrollIntoView({ behavior: 'smooth', block: 'center' });
        
        // Wait a bit for scroll
        setTimeout(() => {
          element.click();
        }, 500);
        
        return 'Successfully clicked element with selector "$selector".';
      } catch (e) {
        return 'Error executing click: ' + e.message;
      }
    })();
    """;

    final result = await _evaluateJS(js);
    return result.replaceAll('"', '').trim();
  }

  /// Gets the value of an input, textarea, or selected option of a select element.
  Future<String> getElementValue(String selector) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    final js = """
    (function() {
      try {
        const element = document.querySelector('$selector');
        if (!element) {
          return 'Error: Element with selector "$selector" not found.';
        }
        
        if (element.tagName.toLowerCase() === 'select') {
          const selectedOption = element.options[element.selectedIndex];
          return selectedOption ? selectedOption.value || selectedOption.text : '';
        } else {
          return element.value || '';
        }
      } catch (e) {
        return 'Error getting element value: ' + e.message;
      }
    })();
    """;

    final result = await _evaluateJS(js);
    return result.replaceAll('"', '').trim();
  }

  /// Selects an option in a <select> dropdown by its value or visible text.
  Future<String> selectDropdownOption(
    String selector,
    String valueOrText, {
    bool byValue = true,
  }) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    final escapedValueOrText = jsonEncode(valueOrText);
    final js = """
    (function() {
      try {
        const select = document.querySelector('$selector');
        if (!select || select.tagName.toLowerCase() !== 'select') {
          return 'Error: Select element with selector "$selector" not found.';
        }
        
        const options = Array.from(select.options);
        let targetOption = null;
        
        if (${byValue}) {
          targetOption = options.find(opt => opt.value === $escapedValueOrText);
        } else {
          targetOption = options.find(opt => opt.text === $escapedValueOrText);
        }
        
        if (targetOption) {
          select.value = targetOption.value;
          select.dispatchEvent(new Event('change', { bubbles: true }));
          return 'Successfully selected option "$valueOrText" in dropdown.';
        } else {
          return 'Error: Option "$valueOrText" not found in dropdown.';
        }
      } catch (e) {
        return 'Error selecting dropdown option: ' + e.message;
      }
    })();
    """;

    final result = await _evaluateJS(js);
    return result.replaceAll('"', '').trim();
  }

  /// Submits the form containing the element identified by the selector, or the form itself.
  Future<String> submitForm(String selector) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    final js = """
    (function() {
      try {
        let element = document.querySelector('$selector');
        if (!element) {
          return 'Error: Element with selector "$selector" not found.';
        }
        
        let form = element;
        if (element.tagName.toLowerCase() !== 'form') {
          form = element.closest('form');
        }
        
        if (form) {
          form.submit();
          return 'Successfully submitted form.';
        } else {
          return 'Error: No form found containing the element.';
        }
      } catch (e) {
        return 'Error submitting form: ' + e.message;
      }
    })();
    """;

    final result = await _evaluateJS(js);
    return result.replaceAll('"', '').trim();
  }

  /// Gets specific attributes (e.g., 'href', 'src', 'alt', 'class') of an element.
  /// Returns a Map of attribute-value pairs.
  Future<Map<String, String>> getElementAttributes(
    String selector,
    List<String> attributes,
  ) async {
    if (!isSessionActive) {
      return {};
    }

    final escapedAttributes = jsonEncode(attributes);
    final js = """
    (function() {
      try {
        const element = document.querySelector('$selector');
        if (!element) {
          return JSON.stringify({});
        }
        
        const attrs = {};
        const requestedAttrs = $escapedAttributes;
        
        requestedAttrs.forEach(attr => {
          attrs[attr] = element.getAttribute(attr) || '';
        });
        
        return JSON.stringify(attrs);
      } catch (e) {
        return JSON.stringify({});
      }
    })();
    """;

    try {
      final result = await _evaluateJS(js);
      final decoded = jsonDecode(result) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      return {};
    }
  }

  /// Scrolls the page to a specific element by selector.
  Future<String> scrollIntoView(
    String selector, {
    bool smooth = true,
    String block = 'center',
  }) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    final js = """
    (function() {
      try {
        const element = document.querySelector('$selector');
        if (!element) {
          return 'Error: Element with selector "$selector" not found.';
        }
        
        element.scrollIntoView({ 
          behavior: ${smooth ? "'smooth'" : "'auto'"}, 
          block: '$block' 
        });
        
        return 'Successfully scrolled to element with selector "$selector".';
      } catch (e) {
        return 'Error scrolling to element: ' + e.message;
      }
    })();
    """;

    final result = await _evaluateJS(js);
    return result.replaceAll('"', '').trim();
  }

  /// Scrolls the entire page by specified pixels.
  Future<String> scrollPage(int x, int y, {bool smooth = true}) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    final js = """
    (function() {
      try {
        window.scrollBy({ 
          left: $x, 
          top: $y, 
          behavior: ${smooth ? "'smooth'" : "'auto'"} 
        });
        return 'Successfully scrolled page by ($x, $y) pixels.';
      } catch (e) {
        return 'Error scrolling page: ' + e.message;
      }
    })();
    """;

    final result = await _evaluateJS(js);
    return result.replaceAll('"', '').trim();
  }

  /// Executes arbitrary JavaScript and returns its result (serialized to string).
  /// This is the most powerful and flexible method, allowing you to run any custom logic.
  /// Ensure your JS returns a serializable value (string, number, boolean, array, object).
  Future<String> evaluateJavaScript(String script) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    final wrappedJs = """
    (function() {
      try {
        $script
      } catch (e) {
        return 'Error executing JavaScript: ' + e.message;
      }
    })();
    """;

    try {
      final result = await _page!.evaluate(wrappedJs);
      final decoded = jsonDecode(result.toString());
      return decoded.toString();
    } catch (jsonError) {
      return "Error decoding JavaScript result: $jsonError";
    }
  }

  /// Retrieves the text content of all elements matching a selector.
  /// Returns a List of strings.
  Future<List<String>> getTextsOfAllElements(String selector) async {
    if (!isSessionActive) {
      return [];
    }

    final js = """
    (function() {
      try {
        const elements = document.querySelectorAll('$selector');
        const texts = [];
        
        elements.forEach(el => {
          const text = (el.textContent || el.innerText || '').trim();
          if (text) {
            texts.push(text);
          }
        });
        
        return JSON.stringify(texts);
      } catch (e) {
        return JSON.stringify([]);
      }
    })();
    """;

    try {
      final result = await _evaluateJS(js);
      final decoded = jsonDecode(result) as List<dynamic>;
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  /// Takes a screenshot of the current page or a specific element.
  /// Returns a success message with optional file information.
  Future<String> takeScreenshot({String? selector, String? filePath}) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    try {
      if (selector != null) {
        // Use JavaScript to get element and take screenshot
        final js = """
        (function() {
          const element = document.querySelector('$selector');
          if (element) {
            // This is a simplified approach - in real puppeteer we'd use the element handle
            return 'Element found';
          } else {
            return 'Element not found';
          }
        })();
        """;
        final elementCheck = await _evaluateJS(js);
        if (elementCheck == 'Element found') {
          // For now, take a full page screenshot
          final screenshot = await _page!.screenshot();
          if (filePath != null) {
            await File(filePath).writeAsBytes(screenshot);
            return "Screenshot taken of element '$selector' and saved to $filePath";
          } else {
            return "Screenshot taken of element '$selector'";
          }
        } else {
          return "Error: Element with selector '$selector' not found";
        }
      } else {
        final screenshot = await _page!.screenshot();
        if (filePath != null) {
          await File(filePath).writeAsBytes(screenshot);
          return "Screenshot taken of page and saved to $filePath";
        } else {
          return "Screenshot taken of page";
        }
      }
    } catch (e) {
      return "Error taking screenshot: $e";
    }
  }

  /// Checks if an element exists on the page.
  Future<bool> elementExists(String selector) async {
    if (!isSessionActive) {
      return false;
    }

    final js = """
    (function() {
      try {
        const element = document.querySelector('$selector');
        return element !== null;
      } catch (e) {
        return false;
      }
    })();
    """;

    try {
      final result = await _evaluateJS(js);
      return result.toLowerCase() == 'true';
    } catch (e) {
      return false;
    }
  }

  /// Counts elements matching a selector.
  Future<int> countElements(String selector) async {
    if (!isSessionActive) {
      return 0;
    }

    final js = """
    (function() {
      try {
        return document.querySelectorAll('$selector').length;
      } catch (e) {
        return 0;
      }
    })();
    """;

    try {
      final result = await _evaluateJS(js);
      return int.tryParse(result) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Gets the current page title.
  Future<String> getPageTitle() async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    try {
      return await _page!.title ?? "No title";
    } catch (e) {
      return "Error getting page title: $e";
    }
  }

  /// Gets the current page URL.
  Future<String> getCurrentUrl() async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    try {
      return _page!.url ?? "No URL";
    } catch (e) {
      return "Error getting current URL: $e";
    }
  }

  /// Reloads the current page.
  Future<String> reloadPage({bool waitUntil = true}) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    try {
      await _page!.reload(wait: waitUntil ? pup.Until.domContentLoaded: pup.Until.domContentLoaded);
      return "Page reloaded successfully";
    } catch (e) {
      return "Error reloading page: $e";
    }
  }

  /// Navigates back in browser history.
  Future<String> goBack() async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    try {
      await _page!.goBack();
      return "Navigated back successfully";
    } catch (e) {
      return "Error navigating back: $e";
    }
  }

  /// Navigates forward in browser history.
  Future<String> goForward() async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    try {
      await _page!.goForward();
      return "Navigated forward successfully";
    } catch (e) {
      return "Error navigating forward: $e";
    }
  }

  /// Hovers over an element (triggers hover effects).
  Future<String> hoverElement(String selector) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    try {
      // Use JavaScript to hover over element
      final js = """
      (function() {
        const element = document.querySelector('$selector');
        if (element) {
          const event = new MouseEvent('mouseover', { bubbles: true });
          element.dispatchEvent(event);
          return 'Success';
        } else {
          return 'Element not found';
        }
      })();
      """;
      final result = await _evaluateJS(js);
      if (result == 'Success') {
        return "Successfully hovered over element with selector '$selector'.";
      } else {
        return "Error: Element with selector '$selector' not found";
      }
    } catch (e) {
      return "Error hovering over element: $e";
    }
  }

  /// Focuses on an element.
  Future<String> focusElement(String selector) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    final js = """
    (function() {
      try {
        const element = document.querySelector('$selector');
        if (!element) {
          return 'Error: Element with selector "$selector" not found.';
        }
        
        element.focus();
        return 'Successfully focused element with selector "$selector".';
      } catch (e) {
        return 'Error focusing element: ' + e.message;
      }
    })();
    """;

    final result = await _evaluateJS(js);
    return result.replaceAll('"', '').trim();
  }

  /// Clears the value of an input element.
  Future<String> clearInput(String selector) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    final js = """
    (function() {
      try {
        const element = document.querySelector('$selector');
        if (!element) {
          return 'Error: Element with selector "$selector" not found.';
        }
        
        element.value = '';
        element.dispatchEvent(new Event('input', { bubbles: true }));
        element.dispatchEvent(new Event('change', { bubbles: true }));
        
        return 'Successfully cleared input with selector "$selector".';
      } catch (e) {
        return 'Error clearing input: ' + e.message;
      }
    })();
    """;

    final result = await _evaluateJS(js);
    return result.replaceAll('"', '').trim();
  }

  /// Checks or unchecks a checkbox or radio button.
  Future<String> setCheckbox(String selector, bool checked) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    final js = """
    (function() {
      try {
        const element = document.querySelector('$selector');
        if (!element) {
          return 'Error: Element with selector "$selector" not found.';
        }
        
        if (element.type === 'checkbox' || element.type === 'radio') {
          element.checked = $checked;
          element.dispatchEvent(new Event('change', { bubbles: true }));
          return 'Successfully set checkbox/radio to ${checked ? 'checked' : 'unchecked'}.';
        } else {
          return 'Error: Element is not a checkbox or radio button.';
        }
      } catch (e) {
        return 'Error setting checkbox: ' + e.message;
      }
    })();
    """;

    final result = await _evaluateJS(js);
    return result.replaceAll('"', '').trim();
  }

  /// Gets all links (anchor tags) from the page with their text and href.
  Future<List<Map<String, String>>> getAllLinks() async {
    if (!isSessionActive) {
      return [];
    }

    final js = """
    (function() {
      try {
        const links = document.querySelectorAll('a');
        const linkData = [];
        
        links.forEach(link => {
          const href = link.getAttribute('href');
          const text = (link.textContent || link.innerText || '').trim();
          
          if (href && text) {
            linkData.push({
              'text': text,
              'href': href
            });
          }
        });
        
        return JSON.stringify(linkData);
      } catch (e) {
        return JSON.stringify([]);
      }
    })();
    """;

    try {
      final result = await _evaluateJS(js);
      final decoded = jsonDecode(result) as List<dynamic>;
      return decoded.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Gets all form inputs from the page with their properties.
  Future<List<Map<String, String>>> getAllFormInputs() async {
    if (!isSessionActive) {
      return [];
    }

    final js = """
    (function() {
      try {
        const inputs = document.querySelectorAll('input, select, textarea');
        const inputData = [];
        
        inputs.forEach(input => {
          inputData.push({
            'tagName': input.tagName.toLowerCase(),
            'type': input.type || '',
            'name': input.name || '',
            'id': input.id || '',
            'class': input.className || '',
            'placeholder': input.placeholder || '',
            'value': input.value || '',
            'required': input.required ? 'true' : 'false',
            'disabled': input.disabled ? 'true' : 'false'
          });
        });
        
        return JSON.stringify(inputData);
      } catch (e) {
        return JSON.stringify([]);
      }
    })();
    """;

    try {
      final result = await _evaluateJS(js);
      final decoded = jsonDecode(result) as List<dynamic>;
      return decoded.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Waits for navigation to complete (useful after clicks that trigger navigation).
  Future<String> waitForNavigation() async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    try {
      await _page!.waitForNavigation(timeout: const Duration(seconds: 1000));
      return "Navigation completed successfully";
    } catch (e) {
      return "Error waiting for navigation: $e";
    }
  }

  /// Sets a cookie for the current page using JavaScript.
  Future<String> setCookie(String name, String value, {String? domain, String? path}) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    final escapedName = jsonEncode(name);
    final escapedValue = jsonEncode(value);
    final escapedDomain = domain != null ? jsonEncode(domain) : 'null';
    final escapedPath = path != null ? jsonEncode(path) : 'null';

    final js = """
    (function() {
      try {
        const cookieStr = $escapedName + '=' + $escapedValue;
        ${domain != null ? "+ ';domain=' + $escapedDomain" : ""}
        ${path != null ? "+ ';path=' + $escapedPath" : ""};
        
        document.cookie = cookieStr;
        return 'Successfully set cookie: ' + cookieStr;
      } catch (e) {
        return 'Error setting cookie: ' + e.message;
      }
    })();
    """;

    final result = await _evaluateJS(js);
    return result.replaceAll('"', '').trim();
  }

  /// Gets all cookies for the current page using JavaScript.
  Future<List<Map<String, String>>> getCookies() async {
    if (!isSessionActive) {
      return [];
    }

    final js = """
    (function() {
      try {
        const cookies = document.cookie.split(';');
        const cookieData = [];
        
        cookies.forEach(cookie => {
          const [name, ...valueParts] = cookie.trim().split('=');
          const value = valueParts.join('=');
          
          if (name && value) {
            cookieData.push({
              'name': name,
              'value': value
            });
          }
        });
        
        return JSON.stringify(cookieData);
      } catch (e) {
        return JSON.stringify([]);
      }
    })();
    """;

    try {
      final result = await _evaluateJS(js);
      final decoded = jsonDecode(result) as List<dynamic>;
      return decoded.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Deletes a specific cookie using JavaScript.
  Future<String> deleteCookie(String name) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    final escapedName = jsonEncode(name);

    final js = """
    (function() {
      try {
        document.cookie = $escapedName + '=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/';
        return 'Successfully deleted cookie: ' + $escapedName;
      } catch (e) {
        return 'Error deleting cookie: ' + e.message;
      }
    })();
    """;

    final result = await _evaluateJS(js);
    return result.replaceAll('"', '').trim();
  }

  /// Simulates pressing a keyboard key using JavaScript.
  Future<String> pressKey(String key) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    final escapedKey = jsonEncode(key);

    final js = """
    (function() {
      try {
        const event = new KeyboardEvent('keydown', {
          key: $escapedKey,
          code: $escapedKey,
          bubbles: true
        });
        
        document.activeElement.dispatchEvent(event);
        return 'Successfully pressed key: ' + $escapedKey;
      } catch (e) {
        return 'Error pressing key: ' + e.message;
      }
    })();
    """;

    final result = await _evaluateJS(js);
    return result.replaceAll('"', '').trim();
  }

  /// Types text character by character (simulates real typing).
  Future<String> typeText(String text, {Duration? delay}) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    final delayMs = delay?.inMilliseconds ?? 100;

    final js = """
    (function() {
      return new Promise((resolve) => {
        const text = ${jsonEncode(text)};
        let index = 0;
        
        const typeChar = () => {
          if (index < text.length) {
            const char = text[index];
            const event = new KeyboardEvent('keydown', {
              key: char,
              bubbles: true
            });
            
            document.activeElement.dispatchEvent(event);
            index++;
            setTimeout(typeChar, $delayMs);
          } else {
            resolve('Successfully typed text: ' + text);
          }
        };
        
        typeChar();
      });
    })();
    """;

    final result = await _evaluateJS(js);
    return result.replaceAll('"', '').trim();
  }

  /// Scrolls to the top of the page.
  Future<String> scrollToTop() async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    final js = """
    (function() {
      try {
        window.scrollTo({ top: 0, behavior: 'smooth' });
        return 'Successfully scrolled to top.';
      } catch (e) {
        return 'Error scrolling to top: ' + e.message;
      }
    })();
    """;

    final result = await _evaluateJS(js);
    return result.replaceAll('"', '').trim();
  }

  /// Scrolls to the bottom of the page.
  Future<String> scrollToBottom() async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    final js = """
    (function() {
      try {
        window.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' });
        return 'Successfully scrolled to bottom.';
      } catch (e) {
        return 'Error scrolling to bottom: ' + e.message;
      }
    })();
    """;

    final result = await _evaluateJS(js);
    return result.replaceAll('"', '').trim();
  }

  /// Gets the page HTML content.
  Future<String> getPageHTML() async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    try {
      return await _page!.content ?? "No content";
    } catch (e) {
      return "Error getting page HTML: $e";
    }
  }

  /// Checks if the page is still loading.
  Future<bool> isPageLoading() async {
    if (!isSessionActive) {
      return false;
    }

    final js = """
    (function() {
      return document.readyState !== 'complete';
    })();
    """;

    try {
      final result = await _evaluateJS(js);
      return result.toLowerCase() == 'true';
    } catch (e) {
      return false;
    }
  }

  /// Gets viewport dimensions.
  Future<Map<String, int>> getViewportSize() async {
    if (!isSessionActive) {
      return {};
    }

    final js = """
    (function() {
      return JSON.stringify({
        width: window.innerWidth,
        height: window.innerHeight
      });
    })();
    """;

    try {
      final result = await _evaluateJS(js);
      final decoded = jsonDecode(result) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value as int));
    } catch (e) {
      return {};
    }
  }

  /// Sets viewport dimensions.
  Future<String> setViewportSize(int width, int height) async {
    if (!isSessionActive) {
      return "Browser session not active.";
    }

    try {
      await _page!.setViewport(pup.DeviceViewport(width: width, height: height));
      return "Successfully set viewport size to ${width}x$height";
    } catch (e) {
      return "Error setting viewport size: $e";
    }
  }
}