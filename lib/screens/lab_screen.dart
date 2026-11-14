import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import '../theme.dart';
import '../widgets/blocks/chem_blocks.dart';
import '../widgets/blocks/motion_block.dart';
import '../widgets/sims/phenomenon_sim.dart';
import '../widgets/sims/sim_catalog.dart';
import '../widgets/sims/sim_core.dart';
import 'tutor_chat_screen.dart';

/// Hai thi nghiem dung khoi da co (tron hoa chat, nem xien) de day du danh muc trong Phong thi nghiem.
final _extraLabs = <(String, String, String, IconData, Block)>[
  ('Trộn hóa chất', 'Hóa học', 'Cho chất vào cốc, quan sát kết tủa, sủi bọt, đổi màu.', Icons.biotech, Block.tryParse({
    'type': 'reaction_lab', 'topic': 'Phản ứng trao đổi', 'title': 'Trộn dung dịch, quan sát hiện tượng',
    'reaction': {
      'setup': 'Cốc thủy tinh 100 ml, các dung dịch loãng.',
      'reagents': [
        {'id': 'hcl', 'name': 'Axit clohiđric', 'formula': 'HCl', 'color': '#f2f6fa', 'state': 'solution'},
        {'id': 'naoh', 'name': 'Natri hiđroxit', 'formula': 'NaOH', 'color': '#f2f6fa', 'state': 'solution'},
        {'id': 'cuso4', 'name': 'Đồng(II) sunfat', 'formula': 'CuSO4', 'color': '#3b8fd9', 'state': 'solution'},
        {'id': 'bacl2', 'name': 'Bari clorua', 'formula': 'BaCl2', 'color': '#f2f6fa', 'state': 'solution'},
        {'id': 'h2so4', 'name': 'Axit sunfuric', 'formula': 'H2SO4', 'color': '#f2f6fa', 'state': 'solution'},
        {'id': 'zn', 'name': 'Kẽm viên', 'formula': 'Zn', 'color': '#9ea7b0', 'state': 'solid'},
      ],
      'reactions': [
        {'reagents': ['hcl', 'naoh'], 'equation': 'HCl + NaOH → NaCl + H2O', 'observation': 'Không màu, cốc ấm lên', 'color': '#f2f6fa', 'gas': false, 'precipitate': false, 'precipitate_color': null, 'heat': 'exo', 'min_temp': null, 'explanation': 'Phản ứng trung hòa: axit + bazơ tạo muối và nước, tỏa nhiệt.'},
        {'reagents': ['cuso4', 'naoh'], 'equation': 'CuSO4 + 2NaOH → Cu(OH)2↓ + Na2SO4', 'observation': 'Xuất hiện kết tủa xanh lơ', 'color': '#cfe3f5', 'gas': false, 'precipitate': true, 'precipitate_color': '#4aa3df', 'heat': 'none', 'min_temp': null, 'explanation': 'Ion Cu²⁺ kết hợp OH⁻ tạo Cu(OH)₂ không tan.'},
        {'reagents': ['bacl2', 'h2so4'], 'equation': 'BaCl2 + H2SO4 → BaSO4↓ + 2HCl', 'observation': 'Kết tủa trắng', 'color': '#f2f6fa', 'gas': false, 'precipitate': true, 'precipitate_color': '#ffffff', 'heat': 'none', 'min_temp': null, 'explanation': 'BaSO₄ không tan trong nước và axit, dùng để nhận biết gốc sunfat.'},
        {'reagents': ['zn', 'hcl'], 'equation': 'Zn + 2HCl → ZnCl2 + H2↑', 'observation': 'Kẽm tan dần, sủi bọt khí', 'color': '#f2f6fa', 'gas': true, 'precipitate': false, 'precipitate_color': null, 'heat': 'exo', 'min_temp': null, 'explanation': 'Kim loại đứng trước H đẩy hiđro ra khỏi axit.'},
      ],
      'no_reaction_text': 'Không có hiện tượng: hai chất này không phản ứng với nhau.',
      'safety': 'Thí nghiệm thật cần kính bảo hộ, găng tay.',
    },
  })!),
  ('Ném xiên', 'Vật lý', 'Chỉnh vận tốc và góc ném, xem quỹ đạo parabol.', Icons.sports_baseball, Block.tryParse({
    'type': 'motion_sim', 'topic': 'Chuyển động ném xiên',
    'motion': {'kind': 'projectile', 'variables': [
      {'name': 'v0', 'label': 'Vận tốc ban đầu', 'unit': 'm/s', 'min': 5, 'max': 40, 'step': 1, 'default': 20},
      {'name': 'angle', 'label': 'Góc ném', 'unit': '°', 'min': 5, 'max': 85, 'step': 1, 'default': 45},
      {'name': 'g', 'label': 'Gia tốc trọng trường', 'unit': 'm/s²', 'min': 1, 'max': 20, 'step': 0.1, 'default': 9.8},
    ]},
  })!),
];

/// Phong thi nghiem ao: danh muc mo phong dung san, mo duoc ngay ca khi khong co mang.
class LabScreen extends StatelessWidget {
  const LabScreen({super.key, this.courseId, this.embedded = false});
  final String? courseId;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final subjects = {...simCatalog.values.map((s) => s.subject), ..._extraLabs.map((e) => e.$2)};
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (!embedded) ...[
          const Text('Chọn một thí nghiệm, kéo thanh trượt và bấm Chạy để quan sát hiện tượng. Chạy ngay trên máy, không cần mạng.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
        ],
        for (final subject in subjects) ...[
          Padding(padding: const EdgeInsets.only(top: 8, bottom: 8), child: Eyebrow(subject)),
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: [
              for (final s in simCatalog.values.where((s) => s.subject == subject))
                LabTile(icon: s.icon, title: s.title, summary: s.summary, onTap: () => openSim(context, s, courseId: courseId)),
              for (final e in _extraLabs.where((e) => e.$2 == subject))
                LabTile(icon: e.$4, title: e.$1, summary: e.$3, onTap: () => _openBlock(context, e.$1, e.$5)),
            ],
          ),
        ],
      ],
    );
    if (embedded) return list;
    return Scaffold(appBar: AppBar(title: const Text('Phòng thí nghiệm')), body: SafeArea(child: list));
  }

  void _openBlock(BuildContext context, String title, Block block) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => Scaffold(
                appBar: AppBar(title: Text(title)),
                body: SafeArea(
                  child: ListView(padding: const EdgeInsets.all(12), children: [
                    block.type == BlockType.reactionLab ? ReactionLabBlock(block: block) : MotionSimBlock(block: block),
                  ]),
                ),
              )));
}

void openSim(BuildContext context, SimScene scene, {String? courseId}) => Navigator.push(
    context,
    MaterialPageRoute(
        builder: (_) => Scaffold(
              appBar: AppBar(title: Text(scene.title)),
              body: SafeArea(
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
                  Text(scene.summary, style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 12),
                  PhenomenonSim(
                    scene: scene,
                    onAsk: courseId == null
                        ? null
                        : (q) => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => TutorChatScreen(courseId: courseId, initialQuestion: q))),
                  ),
                ]),
              ),
            )));

class LabTile extends StatelessWidget {
  const LabTile({super.key, required this.icon, required this.title, required this.summary, required this.onTap});
  final IconData icon;
  final String title, summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 4),
              Expanded(
                child: Text(summary, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ),
            ]),
          ),
        ),
      );
}
