import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import 'canvas_screen.dart';
import 'quiz_builder_screen.dart';
import 'quiz_player_screen.dart';
import 'study_artifact_screen.dart';
import 'study_goal_sheet.dart';

/// Cac thao tac dung chung giua cac trang cua so hoc tap (lap lo trinh, tao/mo noi dung Studio).
/// Loi duoc bao bang SnackBar; tra ve false neu that bai.
class StudyActions {
  StudyActions._();

  static String topicFrom(String input) => input.trim().replaceFirst(RegExp(
        r'^(?:hãy\s+)?(?:tìm(?:\s+nguồn|\s+tài liệu)?(?:\s+cho\s+(?:tôi|mình))?\s+và\s+)?(?:lên|lập|tạo)\s+(?:lộ trình|khóa học)(?:\s+học)?(?:\s+cho\s+(?:tôi|mình))?(?:\s+(?:về|cho))?(?:\s+môn)?\s*',
        caseSensitive: false), '').trim();

  static bool wantsPlan(Course course, String question) =>
      course.lessons.isEmpty && RegExp(r'lộ trình|tạo khóa học|lập kế hoạch học', caseSensitive: false).hasMatch(question);

  static Future<bool> _guard(BuildContext context, Future<void> Function() run) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await run();
      return true;
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Chưa thực hiện được. Hãy kiểm tra kết nối rồi thử lại.')));
    }
    return false;
  }

  /// Hoi muc tieu (chu de, ngay thi, so phut/ngay) roi lap lo trinh. [edit] = chi dieu chinh lich.
  static Future<bool> plan(BuildContext context, Course course, {String? topic, bool edit = false}) async {
    final state = context.read<AppState>();
    final brief = await showStudyGoal(context,
        topic: topic ?? course.brief?.topic ?? (course.title == 'Sổ học tập mới' ? '' : course.title),
        previous: topic == null ? course.brief : null,
        edit: edit);
    if (brief == null || !context.mounted) return false;
    return _guard(context, () => edit ? state.updateSchedule(course, brief) : state.planCourse(course, brief));
  }

  static Future<bool> continuePlan(BuildContext context, Course course) async {
    final brief = course.brief;
    if (brief == null) return plan(context, course);
    return _guard(context, () => context.read<AppState>().planCourse(course, brief));
  }

  static void open(BuildContext context, Course course, StudyArtifact artifact) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => artifact.kind.isQuiz
              ? QuizPlayerScreen(courseId: course.id, artifactId: artifact.id)
              : artifact.kind == StudyArtifactKind.canvas
                  ? CanvasScreen(courseId: course.id, artifactId: artifact.id)
                  : StudyArtifactScreen(courseId: course.id, artifactId: artifact.id)));

  /// Tao (hoac mo ban da co neu nguon khong doi) noi dung Studio: tom tat, flashcards, quiz nhanh...
  static Future<void> create(BuildContext context, Course course, StudyArtifactKind kind, {bool regenerate = false}) async {
    if (course.enabledSources.isEmpty && !course.isSample) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hãy thêm hoặc bật ít nhất một tài liệu trước.')));
      return;
    }
    if (course.isSample && !regenerate) {
      final sample = course.artifacts.where((a) => a.kind == kind).lastOrNull;
      if (sample != null) return open(context, course, sample);
    }
    StudyArtifact? item;
    final ok = await _guard(context, () async {
      item = await context.read<AppState>().createArtifact(course, kind, regenerate: regenerate);
    });
    if (ok && item != null && context.mounted) open(context, course, item!);
  }

  static void quizBuilder(BuildContext context, Course course, {String? lessonId}) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => QuizBuilderScreen(courseId: course.id, lessonId: lessonId)));

  static void canvas(BuildContext context, Course course, {String? lessonId, String? prompt}) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => CanvasScreen(courseId: course.id, lessonId: lessonId, initialPrompt: prompt)));
}
