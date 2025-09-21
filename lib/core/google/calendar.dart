part of 'core.dart';

Future<void> addReminder() async {
final  client = await getClient();
  final calendarApi = calendar.CalendarApi(client);

  final event = calendar.Event(
    summary: "Test Reminder",
    start: calendar.EventDateTime(
      dateTime: DateTime.now().add(Duration(minutes: 10)),
    ),
    end: calendar.EventDateTime(
      dateTime: DateTime.now().add(Duration(minutes: 30)),
    ),
  );

  await calendarApi.events.insert(event, "primary");
}
