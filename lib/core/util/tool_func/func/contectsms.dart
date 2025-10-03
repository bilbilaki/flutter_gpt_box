part of '../tool.dart';

final smsSender = SmsSender();

final class TfSMSSender extends ToolFunc {
  static const instance = TfSMSSender._();
  const TfSMSSender._()
  : super(
  name: 'smssender',
  parametersSchema: const {
    'type': 'object',
    'properties': {
      'contact': {
        'type': 'string',
        'description':
            'The recipient\'s contact name . Obtain the contact details directly from the user before invoking this tool. Use only one contact per call. but you can performing multi tool call',
      },
      'message': {
        'type': 'string',
        'description':
            'The exact message content to send via SMS, as specified or requested by the user. Keep it concise to respect SMS limits.',
      },
      'simslot2': {
        'type': 'boolean',
        'description':
            'Optional: Set to true to send from SIM slot 2; defaults to SIM slot 1 if false or omitted.',
      },
    },
    'required': ['contact', 'message'],
  },
);

@override
String get description => '''
Use this tool to send an SMS message to a specified contact when the user explicitly requests it (e.g., "Send a text to John saying I'm running late").
- First, confirm and extract the recipient's contact details and message content from the user's input.
- Do not assume or fabricate any contact info—always get it from the user.
- This tool handles one SMS at a time; for multiple, invoke it sequentially.
''';
  @override
  String get l10nName => "smssender";

  @override
  Future<_Ret?> run(_CallResp call, _Map args, OnToolLog log) async {
    // Normalize inputs to avoid null returns anywhere
    final contact = (args['contact'] as String?)?.trim() ?? '';
    final message = (args['message'] as String?)?.trim() ?? '';
    final isSim2 = args['simslot2'] as bool?;
  
    // Validate inputs
    if (contact.isEmpty || message.isEmpty) {
      log('''Failed to Sending message check Input Message: -> $message
  Also may this Problem is with Contact check this too: -> $contact ''');
      return [ChatContent.text("failed to sending sms message: invalid contact or message")];
    }
  
    bool hasPermission = await smsSender.checkSmsPermission();
  
    // Request permission if needed
    if (!hasPermission) {
      hasPermission = await smsSender.requestSmsPermission();
      if (!hasPermission) {
        return [
          ChatContent.text(
            "failed to sending sms message. SMS permission is denied",
          ),
        ];
      }
    }
  
    // Resolve contact number (function now returns empty string instead of null when not found)
    final finalNumber = await findContactNumber(contact);
    if (finalNumber.isEmpty) {
      return [
        ChatContent.text(
          "failed to sending sms message. couldn't find a phone number for the provided contact",
        ),
      ];
    }
  
    log('''Sending SMS with this Message: -> $message
  to this Contact: -> $contact
  Resolved number: -> $finalNumber''');
  
    try {
      final bool success = (await smsSender.sendSms(
            phoneNumber: finalNumber,
            message: message,
            simSlot: isSim2 == true ? 1 : 0, // Optional: specify SIM slot (0 or 1)
          )) ==
          true;
  
      return success
          ? [ChatContent.text("successfully sms sending to target done")]
          : [
              ChatContent.text(
                "failed to sending sms message; may be an issue with the phone, provider, or SIM balance",
              ),
            ];
    } catch (e, st) {
      log(
        'All task completed up to sending but SMS failing at send step. Error: $e\n$st',
      );
      return [
        ChatContent.text(
          "failed to sending sms message; please check SIM, network or provider status",
        ),
      ];
    }
  }
}

Future<String> findContactNumber(String query) async {
  final q = query.trim();
  if (q.isEmpty) return '';

  // Request permission; if denied return empty string (no nulls)
  final bool permissionGranted = await FlutterContacts.requestPermission();
  if (!permissionGranted) return '';

  final List<Contact> contacts = await FlutterContacts.getContacts(
    withProperties: true,
  );

  final String qLower = q.toLowerCase();
  final bool isEmail = q.contains('@');
  final String qDigits = q.replaceAll(RegExp(r'\D'), '');
  final bool isPhone = !isEmail && qDigits.isNotEmpty;

  String tryReturnFirstPhone(Contact c) {
    if (c.phones.isNotEmpty) {
      return (c.phones.first.number).trim();
    }
    return '';
  }

  for (final c in contacts) {
    // 1) Email search
    if (isEmail) {
      for (final e in c.emails) {
        final addr = (e.address).toLowerCase();
        if (addr == qLower || addr.contains(qLower)) {
          final found = tryReturnFirstPhone(c);
          if (found.isNotEmpty) return found;
          break;
        }
      }
      continue;
    }

    // 2) Direct phone match
    if (isPhone) {
      for (final p in c.phones) {
        final phoneDigits = (p.number).replaceAll(RegExp(r'\D'), '');
        if (phoneDigits.isEmpty) continue;
        if (phoneDigits.contains(qDigits) ||
            qDigits.contains(phoneDigits) ||
            phoneDigits.endsWith(qDigits)) {
          return (p.number).trim();
        }
      }
      continue;
    }

    // 3) Name/display search (safe null handling)
    final display = (c.displayName).toLowerCase();
    final first = (c.name.first).toLowerCase();
    final last = (c.name.last).toLowerCase();
    final full = ('$first ${last}'.trim()).toLowerCase();

    if (display.contains(qLower) ||
        first == qLower ||
        last == qLower ||
        full.contains(qLower) ||
        full == qLower) {
      final found = tryReturnFirstPhone(c);
      if (found.isNotEmpty) return found;
    }
  }

  // Return empty string when nothing found (never null)
  return 'contact not found , tell to user or recheck and if need adjust contact name like Case Sensetive or symbols , if you find maybe with a little adjust can find contact retry using tool too finding that but just 2 more time , if failed tell user that';
}
