class Task {
  final int order;
  final Function action;
  int runIndex;
  int? taskX;
  int? taskY;
  String? taskStr;
  double delaySeconds;
  int repeatPerTask;
  int loopCount;
  FinalResult finalResult;

  Task({
    required this.order,
    required this.action,
    this.taskX,
    this.taskY,
    this.taskStr,
    this.delaySeconds = 0.5,
    this.runIndex = 1,
    this.repeatPerTask = 1,
    this.loopCount = 1,
    required this.finalResult,
  });
}

enum TaskTrigger { runbyhand, apicall, listentoevent, timetrigger, askai, none }

enum TaskPreRule {
  iflasttasksuccessful,
  iflasttaskfailed,
  iflasttaskresultis,
  iflasttaskresultnot,
  iflasttaskresultunknow,
  ifextratriggerrun,
  none,
}

enum TaskPostRule {
  ifresultequel,
  ifresultnotequel,
  ifresultcontains,
  ifresultnotcontains,
  ifresultstartedwith,
  ifresultnostartedwith,
  ifresultendwith,
  ifresultnotendwith,
  ifevent,
  ifnotevent,
  ifrunindexdone,
  ifparentconfirm,
  none,
}

enum ResultType { success, failed, none }

enum ParentConfirmType { parentpass, parentdeny, none }

class FinalResult {
  TaskTrigger tasktrigger = TaskTrigger.none;
  TaskPreRule taskprerule = TaskPreRule.none;
  TaskPostRule taskpostrule = TaskPostRule.none;
  ParentConfirmType parentConfirmType = ParentConfirmType.none;
  ResultType resultType = ResultType.none;
  FinalResult({
    required this.parentConfirmType,
    required this.resultType,
    required this.taskpostrule,
    required this.taskprerule,
    required this.tasktrigger,
  });
}
