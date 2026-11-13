# Skill và agent cho dự án Flutter

Đã cài ngày 13/11/2026, phạm vi dự án `Du an ma`.

## Đã cài

| Nguồn | Thành phần | Số lượng |
| --- | --- | ---: |
| [Flutter/Dart chính thức](https://github.com/flutter/agent-plugins) | Toàn bộ skill trong thư mục `skills/`: kiến trúc, UI, layout, HTTP, JSON, routing, localization, phân tích mã và kiểm thử | 25 skill |
| [Ponytail](https://github.com/DietrichGebert/ponytail) | `ponytail`, `ponytail-review`, `ponytail-audit`, `ponytail-debt`, `ponytail-gain`, `ponytail-help` | 6 skill |
| [Anthropic Skills](https://github.com/anthropics/skills) | `pdf`, `docx`, `pptx`, `xlsx`, `doc-coauthoring` | 5 skill |
| [Agency Agents](https://github.com/msitarzewski/agency-agents) | `rapid-prototyper` cho Claude Code | 1 agent |

Claude Code đọc skill ở `.claude/skills/` và agent ở `.claude/agents/`. Codex đọc bản tương thích ở `.agents/skills/`. Codex đã có agent Rapid Prototyper ở cấu hình người dùng; bản đó được giữ nguyên.

Các thư mục skill và agent dành cho Claude ở trên được lưu trong Git cùng dự án. Máy khác clone repo sẽ có sẵn chúng; vẫn cần cài Claude Code/Codex và môi trường Flutter riêng. Agent Rapid Prototyper ở cấu hình người dùng của Codex trên máy hiện tại không đi theo repo; bản agent trong `.claude/agents/` dành cho Claude Code.

## Cách dùng

Mở Claude Code hoặc Codex tại thư mục dự án. Skill mới có thể dùng từ lượt tiếp theo; nếu phiên đang mở chưa nhận ra, mở lại phiên tại đây.

Trong Claude Code:

```text
/ponytail
/ponytail-review
/ponytail-audit
/flutter-fix-layout-issues
```

Ví dụ yêu cầu dùng agent:

```text
Dùng agent rapid-prototyper để triển khai luồng nhập tài liệu theo CLAUDE.md.
Giữ Flutter/Dart, giao diện tiếng Việt và đầy đủ ba tính năng cốt lõi.
```

Trong Codex, gọi skill trực tiếp bằng `$ponytail`, `$ponytail-review` hoặc `$flutter-add-widget-test`. Các skill này được cài trực tiếp, không có namespace plugin.

## Phạm vi và kiểm chứng

- Ponytail được cài dưới dạng skill hướng dẫn. Gọi `/ponytail` để kích hoạt trong phiên; chưa cài lifecycle hooks, dashboard Band hoặc cơ chế tự kích hoạt khi mở phiên.
- Bộ Flutter/Dart ở đây là các skill; chưa cấu hình Dart MCP server từ plugin.
- Skill tài liệu hướng dẫn agent xử lý tệp. Thư viện Python, Node và công cụ hệ thống mà từng tác vụ cần chưa được cài thêm trong lần này.
- Agent Rapid Prototyper giữ nội dung nguồn, chuẩn hóa tên thành `rapid-prototyper` và thêm hướng dẫn ưu tiên `CLAUDE.md`, Flutter/Dart cùng phạm vi công việc của dự án.
- Đã kiểm tra metadata và đối chiếu SHA-256 của toàn bộ tệp trong 72 bản skill với nguồn tải về. Chưa chạy thử các lệnh bên trong phiên Claude Code/Codex mới.
- Commit nguồn và danh sách chi tiết: [ai-skills-installation.json](ai-skills-installation.json). Giấy phép nằm trong `skill-licenses/` và các thư mục skill tương ứng.

Các skill và agent này hỗ trợ quá trình phát triển; chúng không tự thêm chức năng xử lý PDF, tạo slide hay AI vào ứng dụng Android.
