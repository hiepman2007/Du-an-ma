import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import '../rich_content.dart';
import '../sims/phenomenon_sim.dart';
import 'common.dart';

/// Khoi phenomenon_sim: canh mo phong dung san trong app, AI chi chon canh va thong so.
class PhenomenonBlock extends StatelessWidget {
  const PhenomenonBlock({super.key, required this.block, this.onAsk});
  final Block block;
  final ValueChanged<String>? onAsk;

  @override
  Widget build(BuildContext context) {
    final sim = simFromBlock(block, onAsk: onAsk);
    if (sim == null) return const SizedBox.shrink();
    return BlockCard(
      icon: Icons.science_outlined,
      label: 'Phòng thí nghiệm ảo · ${sim.scene.title}',
      title: block.title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (block.body?.isNotEmpty == true) ...[RichContent(block.body!), const SizedBox(height: 8)],
        sim,
        SourceNote(block: block),
      ]),
    );
  }
}
