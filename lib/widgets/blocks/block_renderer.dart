import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import '../study/dsa_simulation_block.dart';
import 'arrange_blocks.dart';
import 'chem_blocks.dart';
import 'code_block.dart';
import 'common.dart';
import 'content_blocks.dart';
import 'custom_sim_block.dart';
import 'generic_blocks.dart';
import 'lab_blocks.dart';
import 'motion_block.dart';
import 'phenomenon_block.dart';
import 'question_blocks.dart';

/// Dung widget Flutter tuong ung voi loai khoi AI da chon.
class BlockRenderer extends StatelessWidget {
  const BlockRenderer({super.key, required this.block, required this.lesson, required this.onAnswered, this.onTutor});
  final Block block;
  final Lesson lesson;
  final OnAnswered onAnswered;
  final void Function(String chosen, String correct)? onTutor;

  @override
  Widget build(BuildContext context) {
    return switch (block.type) {
      BlockType.textSection => TextSectionBlock(block: block),
      BlockType.mcq => McqBlock(block: block, onAnswered: onAnswered, onTutor: onTutor),
      BlockType.trueFalse => TrueFalseBlock(block: block, onAnswered: onAnswered, onTutor: onTutor),
      BlockType.fillBlank => FillBlankBlock(block: block, onAnswered: onAnswered, onTutor: onTutor),
      BlockType.matching => MatchingBlock(block: block, onAnswered: onAnswered),
      BlockType.ordering => OrderingBlock(block: block, onAnswered: onAnswered),
      BlockType.formulaLab => block.lab == null ? const SizedBox.shrink() : FormulaLabBlock(block: block),
      BlockType.functionGraph => block.graph == null ? const SizedBox.shrink() : FunctionGraphBlock(block: block),
      BlockType.flashcards => FlashcardsBlock(block: block),
      BlockType.reactionLab => ReactionLabBlock(block: block),
      BlockType.chemFormula => ChemFormulaBlock(block: block),
      BlockType.motionSim => MotionSimBlock(block: block),
      BlockType.stepSolver => StepSolverBlock(block: block),
      BlockType.conceptMap => ConceptMapBlock(block: block),
      BlockType.imageCard => ImageCardBlock(block: block),
      BlockType.customSim => CustomSimBlock(block: block, lesson: lesson),
      BlockType.codeDemo => CodeDemoBlock(block: block),
      BlockType.dsaSim => DsaSimulationBlock(block: block),
      BlockType.phenomenonSim => PhenomenonBlock(block: block),
    };
  }
}
