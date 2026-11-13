import '../models/models.dart';

/// Khoa hoc mau (soan tay, khong do AI sinh) de xem giao dien khi chua co mang/API va lam du phong khi demo.
Course buildSampleCourse() {
  Map<String, dynamic> b(String type, Map<String, dynamic> extra) => {
        'type': type,
        'topic': '',
        'title': null,
        'body': null,
        'options': <String>[],
        'answer_index': null,
        'answer_bool': null,
        'answers': <String>[],
        'pairs': <Map>[],
        'items': <String>[],
        'cards': <Map>[],
        'lab': null,
        'graph': null,
        'explanation': null,
        'source_quote': null,
        'source_page': null,
        'source_url': null,
        ...extra,
      };

  final blocks = Block.parseList([
    b('text_section', {
      'topic': 'Định luật Ohm',
      'title': 'Định luật Ohm là gì?',
      'body': 'Cường độ dòng điện **I** chạy qua một đoạn mạch tỉ lệ thuận với hiệu điện thế **U** và tỉ lệ nghịch với điện trở **R**:\n\n'
          '- Công thức: **I = U / R**\n- Đơn vị: I (ampe, A), U (vôn, V), R (ôm, Ω)\n- Tăng U thì I tăng; tăng R thì I giảm.',
      'source_page': 1,
      'source_quote': 'I = U / R',
    }),
    b('formula_lab', {
      'topic': 'Định luật Ohm',
      'title': 'Phòng thí nghiệm điện học',
      'body': 'Kéo thanh trượt để thay đổi U và R, quan sát cường độ dòng điện.',
      'lab': {
        'formula': 'U/R',
        'result_label': 'Cường độ dòng điện I',
        'result_unit': 'A',
        'variables': [
          {'name': 'U', 'label': 'Hiệu điện thế U', 'unit': 'V', 'min': 0, 'max': 24, 'step': 1, 'default': 12},
          {'name': 'R', 'label': 'Điện trở R', 'unit': 'Ω', 'min': 1, 'max': 20, 'step': 1, 'default': 4},
        ],
      },
    }),
    b('mcq', {
      'topic': 'Định luật Ohm',
      'body': 'Một bóng đèn có điện trở 6 Ω mắc vào hiệu điện thế 12 V. Cường độ dòng điện qua đèn là bao nhiêu?',
      'options': ['0,5 A', '2 A', '6 A', '72 A'],
      'answer_index': 1,
      'explanation': 'I = U / R = 12 / 6 = 2 A.',
      'source_page': 1,
      'source_quote': 'I = U / R',
    }),
    b('true_false', {
      'topic': 'Quan hệ I – R',
      'body': 'Giữ nguyên hiệu điện thế, nếu điện trở tăng gấp đôi thì cường độ dòng điện cũng tăng gấp đôi.',
      'answer_bool': false,
      'explanation': 'I tỉ lệ nghịch với R: R tăng gấp đôi thì I giảm một nửa.',
    }),
    b('fill_blank', {
      'topic': 'Đơn vị đo',
      'body': 'Đơn vị của điện trở là ____.',
      'answers': ['ôm', 'ohm', 'Ω'],
      'explanation': 'Điện trở đo bằng ôm (Ω).',
    }),
    b('matching', {
      'topic': 'Đơn vị đo',
      'title': 'Ghép đại lượng với đơn vị',
      'pairs': [
        {'left': 'Hiệu điện thế', 'right': 'Vôn (V)'},
        {'left': 'Cường độ dòng điện', 'right': 'Ampe (A)'},
        {'left': 'Điện trở', 'right': 'Ôm (Ω)'},
      ],
    }),
    b('ordering', {
      'topic': 'Thí nghiệm',
      'title': 'Các bước đo điện trở bằng vôn kế và ampe kế',
      'items': ['Mắc mạch điện theo sơ đồ', 'Đóng khóa K', 'Đọc số chỉ vôn kế và ampe kế', 'Tính R = U / I'],
    }),
    b('function_graph', {
      'topic': 'Quan hệ I – U',
      'title': 'Đồ thị I theo U',
      'body': 'Với R cố định, đồ thị I theo U là một đường thẳng đi qua gốc tọa độ. Kéo R để xem độ dốc thay đổi.',
      'graph': {
        'expression': 'x/R',
        'x_min': 0,
        'x_max': 24,
        'params': [
          {'name': 'R', 'label': 'Điện trở R', 'unit': 'Ω', 'min': 1, 'max': 20, 'step': 1, 'default': 4},
        ],
      },
    }),
    b('flashcards', {
      'topic': 'Định luật Ohm',
      'title': 'Ôn nhanh',
      'cards': [
        {'front': 'Công thức định luật Ohm', 'back': 'I = U / R'},
        {'front': 'Tính U khi biết I và R', 'back': 'U = I × R'},
        {'front': 'I và R có quan hệ gì?', 'back': 'Tỉ lệ nghịch (khi U không đổi)'},
      ],
    }),
  ]);

  final chemBlocks = Block.parseList([
    b('reaction_lab', {
      'topic': 'Phản ứng trao đổi',
      'title': 'Trộn dung dịch, quan sát hiện tượng',
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
        'safety': 'Thí nghiệm thật cần kính bảo hộ, găng tay; không ngửi trực tiếp khí sinh ra.',
      },
    }),
    b('chem_formula', {'topic': 'Khối lượng mol', 'body': 'Khối lượng mol tính từ nguyên tử khối của từng nguyên tố.', 'chem': {'formula': 'CuSO4·5H2O', 'name': 'Đồng sunfat ngậm nước'}}),
    b('step_solver', {
      'topic': 'Tính theo phương trình',
      'title': 'Bài mẫu: tính khối lượng kết tủa',
      'body': 'Cho 16 g CuSO₄ tác dụng hết với dung dịch NaOH. Tính khối lượng kết tủa Cu(OH)₂.',
      'steps': [
        {'text': 'Số mol CuSO₄: n = m / M = 16 / 160', 'answer': '0,1'},
        {'text': 'Theo phương trình, n(Cu(OH)₂) = n(CuSO₄) = **0,1 mol**', 'answer': null},
        {'text': 'Khối lượng kết tủa: m = 0,1 × 98 = **9,8 g**', 'answer': '9,8'},
      ],
    }),
    b('concept_map', {
      'topic': 'Phân loại phản ứng',
      'title': 'Các loại phản ứng',
      'nodes': [
        {'id': 'pu', 'label': 'Phản ứng hóa học', 'detail': 'Quá trình biến đổi chất này thành chất khác.'},
        {'id': 'th', 'label': 'Trung hòa', 'detail': 'Axit + bazơ → muối + nước.'},
        {'id': 'kt', 'label': 'Tạo kết tủa', 'detail': 'Sản phẩm là chất không tan.'},
        {'id': 'kh', 'label': 'Tạo khí', 'detail': 'Sản phẩm có chất khí thoát ra.'},
        {'id': 'ox', 'label': 'Oxi hóa – khử', 'detail': 'Có sự thay đổi số oxi hóa.'},
      ],
      'edges': [
        {'from': 'pu', 'to': 'th', 'label': 'gồm'},
        {'from': 'pu', 'to': 'kt', 'label': 'gồm'},
        {'from': 'pu', 'to': 'kh', 'label': 'gồm'},
        {'from': 'pu', 'to': 'ox', 'label': 'gồm'},
      ],
    }),
  ]);

  final mathBlocks = Block.parseList([
    b('function_graph', {
      'topic': 'Hàm số bậc hai',
      'title': 'Parabol y = ax² + bx + c',
      'body': 'Bật Tiếp tuyến để xem đạo hàm, Diện tích để xem tích phân; kéo a, b, c để thấy đồ thị thay đổi.',
      'graph': {
        'expression': 'a*x^2+b*x+c',
        'extra_expressions': ['2*a*x+b'],
        'x_min': -5,
        'x_max': 5,
        'tools': ['tangent', 'roots', 'extrema'],
        'params': [
          {'name': 'a', 'label': 'a', 'unit': '', 'min': -3, 'max': 3, 'step': 0.5, 'default': 1},
          {'name': 'b', 'label': 'b', 'unit': '', 'min': -5, 'max': 5, 'step': 0.5, 'default': 0},
          {'name': 'c', 'label': 'c', 'unit': '', 'min': -5, 'max': 5, 'step': 0.5, 'default': -2},
        ],
      },
    }),
    b('motion_sim', {
      'topic': 'Chuyển động ném xiên',
      'title': 'Quỹ đạo parabol ngoài đời thực',
      'body': 'Vật ném xiên chuyển động theo quỹ đạo parabol. Chỉnh vận tốc và góc ném rồi bấm Chạy.',
      'motion': {
        'kind': 'projectile',
        'variables': [
          {'name': 'v0', 'label': 'Vận tốc ban đầu v₀', 'unit': 'm/s', 'min': 5, 'max': 40, 'step': 1, 'default': 20},
          {'name': 'angle', 'label': 'Góc ném', 'unit': '°', 'min': 5, 'max': 85, 'step': 1, 'default': 45},
          {'name': 'g', 'label': 'Gia tốc g', 'unit': 'm/s²', 'min': 1.6, 'max': 20, 'step': 0.1, 'default': 9.8},
        ],
      },
    }),
  ]);

  return Course(
    id: 'sample-ohm',
    title: 'Khóa mẫu: Lý · Hóa · Toán',
    goal: 'Xem thử các dạng bài tương tác',
    createdAt: DateTime.now(),
    text: 'Định luật Ohm: cường độ dòng điện I = U / R. Phản ứng trao đổi trong dung dịch tạo kết tủa, khí hoặc nước. Hàm số bậc hai y = ax² + bx + c có đồ thị là parabol.',
    lessons: [
      Lesson(id: 'l1', title: 'Định luật Ohm', objectives: ['Phát biểu định luật Ohm', 'Vận dụng I = U/R', 'Nhớ đơn vị đo'], minutes: 15, blocks: blocks),
      Lesson(id: 'l3', title: 'Phòng thí nghiệm: phản ứng trong dung dịch', objectives: ['Nhận biết hiện tượng phản ứng', 'Tính theo phương trình'], minutes: 20, blocks: chemBlocks),
      Lesson(id: 'l4', title: 'Hàm số bậc hai và chuyển động ném xiên', objectives: ['Khảo sát parabol', 'Liên hệ thực tế'], minutes: 20, blocks: mathBlocks),
    ],
  );
}
