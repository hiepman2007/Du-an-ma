import 'package:flutter/foundation.dart' show kIsWeb;

/// Wikimedia chan yeu cau tai anh khong ghi ro ung dung (User-Agent mac dinh co the bi 403),
/// nen anh mang tren dien thoai gui kem ten ung dung theo chinh sach cua Wikimedia.
/// Tren web trinh duyet tu dat User-Agent (khong duoc ghi de), nen khong gui header.
final Map<String, String>? imageHeaders = kIsWeb ? null : const {'User-Agent': 'HocThongMinh/1.0 (Flutter; education app)'};
