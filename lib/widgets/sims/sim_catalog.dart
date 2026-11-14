import 'package:material_ui/material_ui.dart';

import 'chem_sims.dart';
import 'optics_sims.dart';
import 'physics_sims.dart';
import 'sim_core.dart';

/// Danh muc canh mo phong hien tuong. Ten canh va ten bien khop SIM_SCENES o server/lib/schemas.js.
final simCatalog = <String, SimScene>{
  for (final s in [
    SimScene(
      id: 'circuit',
      title: 'Mạch điện và định luật Ohm',
      subject: 'Vật lý',
      icon: Icons.electrical_services,
      summary: 'Nối tiếp hay song song: đèn nào sáng hơn, dòng điện chia ra sao.',
      vars: [
        simVar('U', 'Hiệu điện thế nguồn', 'V', 1, 24, 6, 0.5),
        simVar('R1', 'Điện trở R₁', 'Ω', 1, 100, 10, 1),
        simVar('R2', 'Điện trở R₂', 'Ω', 1, 100, 20, 1),
      ],
      options: const [('series', 'Nối tiếp'), ('parallel', 'Song song')],
      challenges: const [
        'Mắc nối tiếp, tăng R₂: đèn R₁ sáng hơn hay tối đi?',
        'Chuyển sang song song: cường độ mạch chính thay đổi thế nào?',
      ],
      model: const CircuitModel(),
    ),
    SimScene(
      id: 'refraction',
      title: 'Khúc xạ và phản xạ toàn phần',
      subject: 'Vật lý',
      icon: Icons.flare,
      summary: 'Tia sáng đổi hướng khi qua mặt phân cách hai môi trường.',
      vars: [
        simVar('n1', 'Chiết suất môi trường tới n₁', '', 1, 2.5, 1.5, 0.01),
        simVar('n2', 'Chiết suất môi trường khúc xạ n₂', '', 1, 2.5, 1.0, 0.01),
        simVar('angle', 'Góc tới', '°', 0, 89, 30, 1),
      ],
      challenges: const [
        'Từ thủy tinh ra không khí: tăng góc tới đến khi tia khúc xạ biến mất.',
        'Đổi n₂ lớn hơn n₁: tia khúc xạ lệch gần hay xa pháp tuyến?',
      ],
      model: const RefractionModel(),
    ),
    SimScene(
      id: 'lens',
      title: 'Thấu kính tạo ảnh',
      subject: 'Vật lý',
      icon: Icons.center_focus_strong,
      summary: 'Dời vật quanh tiêu điểm, xem ảnh thật/ảo, lớn/nhỏ.',
      vars: [
        simVar('f', 'Tiêu cự', 'cm', 5, 30, 10, 0.5),
        simVar('d', 'Khoảng cách vật', 'cm', 2, 60, 25, 0.5),
      ],
      options: const [('converging', 'Hội tụ'), ('diverging', 'Phân kỳ')],
      challenges: const [
        'Thấu kính hội tụ: đặt vật trong khoảng tiêu cự (d < f), ảnh có gì khác?',
        'Thấu kính phân kỳ: thử mọi vị trí, ảnh có bao giờ là ảnh thật không?',
      ],
      model: const LensModel(),
    ),
    SimScene(
      id: 'spring',
      title: 'Con lắc lò xo',
      subject: 'Vật lý',
      icon: Icons.waves,
      summary: 'Dao động điều hòa và đồ thị li độ theo thời gian.',
      vars: [
        simVar('k', 'Độ cứng lò xo', 'N/m', 5, 200, 40, 1),
        simVar('m', 'Khối lượng vật', 'kg', 0.1, 5, 1, 0.1),
        simVar('A', 'Biên độ', 'cm', 1, 10, 6, 0.5),
      ],
      challenges: const ['Tăng khối lượng gấp 4: chu kỳ tăng bao nhiêu lần?', 'Biên độ có làm đổi chu kỳ không?'],
      model: const SpringModel(),
    ),
    SimScene(
      id: 'wave',
      title: 'Sóng cơ và giao thoa',
      subject: 'Vật lý',
      icon: Icons.graphic_eq,
      summary: 'Sóng trên dây hoặc hai nguồn kết hợp tạo vân giao thoa.',
      vars: [
        simVar('f', 'Tần số', 'Hz', 0.5, 5, 1, 0.1),
        simVar('wavelength', 'Bước sóng', 'cm', 1, 6, 3, 0.1),
        simVar('d', 'Khoảng cách hai nguồn', 'cm', 2, 12, 6, 0.5),
      ],
      options: const [('single', 'Sóng trên dây'), ('interference', 'Giao thoa')],
      challenges: const [
        'Sóng trên dây: hạt màu đỏ có chạy theo sóng không hay chỉ lên xuống?',
        'Giao thoa: giảm bước sóng, số vân sáng nhiều lên hay ít đi?',
      ],
      model: const WaveModel(),
    ),
    SimScene(
      id: 'gas',
      title: 'Chất khí: áp suất, thể tích, nhiệt độ',
      subject: 'Vật lý',
      icon: Icons.bubble_chart,
      summary: 'Các phân tử va vào thành bình tạo áp suất.',
      vars: [
        simVar('T', 'Nhiệt độ', 'K', 100, 600, 300, 5),
        simVar('V', 'Thể tích', 'lít', 1, 10, 5, 0.5),
        simVar('N', 'Số phân tử', 'hạt', 10, 80, 40, 1),
      ],
      challenges: const ['Giữ T, giảm V còn một nửa: áp suất thay đổi thế nào?', 'Tăng T: phân tử chuyển động ra sao?'],
      model: const GasModel(),
    ),
    SimScene(
      id: 'electric_field',
      title: 'Điện trường và lực Cu-lông',
      subject: 'Vật lý',
      icon: Icons.bolt,
      summary: 'Đường sức điện quanh hai điện tích.',
      vars: [
        simVar('q1', 'Điện tích q₁', 'µC', -5, 5, 3, 0.5),
        simVar('q2', 'Điện tích q₂', 'µC', -5, 5, -3, 0.5),
        simVar('d', 'Khoảng cách', 'cm', 2, 8, 5, 0.5),
      ],
      challenges: const ['Cho hai điện tích cùng dấu: đường sức trông thế nào?', 'Giảm khoảng cách một nửa: lực tăng mấy lần?'],
      model: const FieldModel(),
    ),
    SimScene(
      id: 'buoyancy',
      title: 'Lực đẩy Ác-si-mét',
      subject: 'Vật lý',
      icon: Icons.sailing,
      summary: 'Vật nổi, lơ lửng hay chìm tùy khối lượng riêng.',
      vars: [
        simVar('rho_liquid', 'Khối lượng riêng chất lỏng', 'kg/m³', 700, 1500, 1000, 10),
        simVar('rho_object', 'Khối lượng riêng vật', 'kg/m³', 100, 3000, 600, 10),
        simVar('V', 'Thể tích vật', 'cm³', 50, 500, 200, 10),
      ],
      challenges: const ['Tìm khối lượng riêng để vật lơ lửng trong nước.', 'Thả cùng vật vào nước muối (1200): phần chìm thay đổi ra sao?'],
      model: const BuoyancyModel(),
    ),
    SimScene(
      id: 'titration',
      title: 'Chuẩn độ axit – bazơ',
      subject: 'Hóa học',
      icon: Icons.science,
      summary: 'Nhỏ NaOH vào HCl, xem pH và chất chỉ thị đổi màu.',
      vars: [
        simVar('Ca', 'Nồng độ HCl', 'M', 0.05, 1, 0.1, 0.05),
        simVar('Cb', 'Nồng độ NaOH', 'M', 0.05, 1, 0.1, 0.05),
        simVar('Va', 'Thể tích HCl', 'mL', 5, 50, 20, 1),
        simVar('Vb', 'Lượng NaOH đã nhỏ', '%', 0, 100, 0, 1),
      ],
      options: const [('phenolphthalein', 'Phenolphtalein'), ('methyl_orange', 'Metyl da cam'), ('litmus', 'Quỳ tím')],
      challenges: const ['Bấm Chạy để nhỏ giọt: pH nhảy vọt ở đâu?', 'Đổi chất chỉ thị: màu chuyển ở pH nào?'],
      model: const TitrationModel(),
    ),
    SimScene(
      id: 'states',
      title: 'Chuyển thể rắn – lỏng – khí',
      subject: 'Hóa học',
      icon: Icons.thermostat,
      summary: 'Các hạt chuyển động thế nào khi đun nóng.',
      vars: [simVar('T', 'Nhiệt độ', '°C', -150, 200, 25, 1)],
      options: const [('water', 'Nước'), ('ethanol', 'Etanol')],
      challenges: const ['Hạ nhiệt độ dưới 0 °C: các hạt sắp xếp ra sao?', 'Etanol sôi ở nhiệt độ thấp hay cao hơn nước?'],
      model: const StatesModel(),
    ),
  ])
    s.id: s,
};
