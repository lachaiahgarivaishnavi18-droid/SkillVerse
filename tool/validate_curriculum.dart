import 'dart:io';

import 'package:learning_app/data/app_content.dart';
import 'package:learning_app/data/course_discovery.dart';
import 'package:learning_app/data/course_models.dart';
import 'package:learning_app/data/interview_roles.dart';
import 'package:learning_app/data/lesson_guides.dart';
import 'package:learning_app/data/project_briefs.dart';

void main() {
  final report = validateCurriculum();
  stdout.writeln(report.summary);
  for (final issue in report.errors) {
    stderr.writeln(issue);
  }
  stdout.writeln('${report.errors.length} invalid records or references.');
  if (report.errors.isNotEmpty) exitCode = 1;
}

({String summary, List<String> errors}) validateCurriculum() {
  final errors = <String>{};
  final courseIds = <String>{};
  final lessons = <String, String>{};
  final quizIds = <String, String>{};
  final interviewIds = <String, String>{};
  const levels = {'Beginner', 'Intermediate', 'Advanced'};
  var moduleCount = 0;

  void unique(String id, String origin, Map<String, String> seen) {
    if (id.trim().isEmpty) {
      errors.add('$origin: missing ID');
    } else if (seen.containsKey(id)) {
      errors.add('$origin: duplicate ID $id (already in ${seen[id]})');
    } else {
      seen[id] = origin;
    }
  }

  void checkFields(String id, Map<String, String> fields) {
    for (final entry in fields.entries) {
      if (entry.value.trim().isEmpty) errors.add('$id: empty ${entry.key}');
    }
  }

  void checkQuiz(QuizQuestion question, String origin) {
    unique(question.id, origin, quizIds);
    checkFields(question.id, {
      'subject': question.subject,
      'prompt': question.prompt,
      'topic': question.topic,
      'explanation': question.explanation,
    });
    if (question.options.length < 2 ||
        question.options.any((option) => option.trim().isEmpty) ||
        question.options.map((option) => option.trim()).toSet().length !=
            question.options.length) {
      errors.add(
        '${question.id}: expected at least two distinct non-empty options',
      );
    }
    if (question.answerIndex < 0 ||
        question.answerIndex >= question.options.length) {
      errors.add(
        '${question.id}: answer index ${question.answerIndex} is out of range',
      );
    }
    if (!levels.contains(question.difficultyLabel)) {
      errors.add('${question.id}: unknown difficulty ${question.difficulty}');
    }
  }

  for (final course in courses) {
    if (course.id.trim().isEmpty || !courseIds.add(course.id)) {
      errors.add(
        '${course.title}: missing or duplicate course ID ${course.id}',
      );
    }
    checkFields(course.id, {
      'title': course.title,
      'description': course.description,
    });
    if (course.allLessons.isEmpty) errors.add('${course.id}: no lessons');
    for (final lesson in course.allLessons) {
      unique(lesson.id, course.id, lessons);
      final guide = guideForLesson(lesson);
      checkFields(lesson.id, {
        'title': lesson.title,
        'summary': lesson.summary,
        'example': guide.example ?? lesson.example,
        'learning objective': guide.objective,
        'exercise': guide.practice,
        'solution': guide.solution,
        'common mistake': guide.mistake,
      });
      if (lesson.topics.isEmpty ||
          lesson.topics.any((topic) => topic.trim().isEmpty)) {
        errors.add('${lesson.id}: missing or blank topic');
      }
      if (guide.hints.isEmpty ||
          guide.hints.any((hint) => hint.trim().isEmpty)) {
        errors.add('${lesson.id}: missing or blank hints');
      }
      final resources = <String>{};
      for (final resource in guide.resources) {
        if (!resources.add(resource.filename)) {
          errors.add('${lesson.id}: duplicate resource ${resource.filename}');
        }
        if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_.-]*$')
            .hasMatch(resource.filename)) {
          errors.add(
            '${lesson.id}: invalid resource filename ${resource.filename}',
          );
        }
        checkFields('${lesson.id}/${resource.filename}', {
          'resource content': resource.text,
          'resource description': resource.description,
        });
      }
    }
    final moduleTitles = <String>{};
    final courseLessonIds = course.allLessons
        .map((lesson) => lesson.id)
        .toSet();
    final assignedLessons = <String>{};
    for (final module in course.learningModules) {
      moduleCount++;
      final label = '${course.id}/${module.title}';
      if (module.title.trim().isEmpty || !moduleTitles.add(module.title)) {
        errors.add('$label: missing or duplicate module title');
      }
      if (module.lessons.isEmpty) errors.add('$label: module is empty');
      for (final lesson in module.lessons) {
        if (!courseLessonIds.contains(lesson.id) ||
            !assignedLessons.add(lesson.id)) {
          errors.add(
            '$label: missing or repeated lesson reference ${lesson.id}',
          );
        }
      }
      for (final (bank, questions) in [
        ('practice', module.questions),
        ('module quiz', module.moduleQuizQuestions),
        ('final assessment', module.assessmentQuestions),
      ]) {
        for (final question in questions) {
          checkQuiz(question, '$label/$bank');
        }
      }
    }
    for (final id in courseLessonIds.difference(assignedLessons)) {
      errors.add('${course.id}: $id is missing from module navigation');
    }
    if (projectBriefFor(course) case final brief?) {
      for (final lesson in brief.relatedLessons) {
        if (!courseLessonIds.contains(lesson.id)) {
          errors.add(
            '${course.id}: invalid project lesson reference ${lesson.id}',
          );
        }
      }
    }
  }
  for (final course in courses) {
    for (final id in prerequisiteLessonIds(course)) {
      if (!lessons.containsKey(id)) {
        errors.add('${course.id}: unknown prerequisite $id');
      }
    }
  }
  for (final id in lessonGuideReferenceIds.difference(lessons.keys.toSet())) {
    errors.add('Lesson content override references unknown lesson $id');
  }
  for (final question in quizQuestions) {
    checkQuiz(question, 'subject quiz/${question.subject}');
  }

  void checkInterview(InterviewQuestion question, String origin) {
    unique(question.id, origin, interviewIds);
    checkFields(question.id, {
      'prompt': question.question,
      'reference answer': question.answer,
      'explanation': question.explanation,
      'topic': question.topic,
      'category': question.category,
    });
    if (!levels.contains(question.difficulty)) {
      errors.add(
        '${question.id}: unknown interview difficulty ${question.difficulty}',
      );
    }
  }

  for (final question in interviewQuestions) {
    checkInterview(question, 'interview bank/${question.category}');
  }
  // Role sets refer to questions already registered in the main bank.
  final bankById = {
    for (final question in interviewQuestions) question.id: question,
  };
  final roleIds = <String, String>{};
  for (final entry in roleInterviewQuestions) {
    final question = entry.question;
    unique(question.id, 'interview role/${entry.role.name}', roleIds);
    if (!identical(bankById[question.id], question)) {
      errors.add(
        '${entry.role.name}: unknown or conflicting interview reference ${question.id}',
      );
    }
  }
  return (
    summary:
        'Validated ${courseIds.length} courses, $moduleCount modules, ${lessons.length} lessons, ${quizIds.length} quiz questions, and ${interviewIds.length} interview questions.',
    errors: errors.toList()..sort(),
  );
}
