# Backend AI (Node, không phụ thuộc thư viện)

Giữ API key, ép đầu ra JSON theo schema, kiểm tra khối trước khi trả về app.

## Nhà cung cấp AI
Đặt `AI_PROVIDER=gemini` hoặc `AI_PROVIDER=openai` trong `.env`, app không phải sửa gì.

| | Gemini | OpenAI |
|---|---|---|
| API | Interactions API (`/v1beta/interactions`) | Responses API |
| Key | `GEMINI_API_KEY` (aistudio.google.com) | `OPENAI_API_KEY` |
| Model mặc định | `gemini-3.5-flash-lite` | `gpt-6-luna` |
| File tải lên | Gemini Files API, **giữ 48 giờ** (khóa học cũ hơn 48 giờ sẽ không sinh thêm bài được) | OpenAI Files, giữ đến khi xóa |
| Tìm nguồn web | `google_search` (link có thể là link chuyển hướng của Google; server lấy tên miền thật từ tiêu đề) | `web_search` |
| Lưu ý | Gói miễn phí giới hạn số lần gọi/phút; dữ liệu gói miễn phí có thể được Google dùng để cải thiện sản phẩm | Dùng credits BTC cấp |

Code: `lib/ai.js` (chọn nhà cung cấp, model, ghi chi phí), `lib/providers/gemini.js`, `lib/providers/openai.js`.

## Chạy cục bộ
```bash
cp .env.example .env   # điền AI_PROVIDER, GEMINI_API_KEY (hoặc OPENAI_API_KEY) và APP_TOKEN
npm run dev            # http://localhost:8787
npm test
```
Thử nhanh:
```bash
curl -H "X-App-Token: <APP_TOKEN>" http://localhost:8787/api/health
```

## Triển khai Vercel
1. Tạo tài khoản Vercel, cài CLI: `npm i -g vercel`.
2. Trong thư mục `server/`: `vercel` rồi `vercel --prod`.
3. Đặt biến môi trường trong Project Settings: `AI_PROVIDER`, `GEMINI_API_KEY` hoặc `OPENAI_API_KEY`, `APP_TOKEN`, và tùy chọn `MODEL_OUTLINE`, `MODEL_LESSON`, `MODEL_SMALL`.
4. Build app với `--dart-define=API_BASE_URL=https://<tên>.vercel.app`.

Giới hạn: body tối đa ~4.5MB (PDF ≤ 4MB), mỗi request tối đa 60 giây (`vercel.json`).

## Endpoint
| Endpoint | Việc |
|---|---|
| `POST /api/upload` | PDF/ảnh → Files API của nhà cung cấp → `fileId` |
| `POST /api/course/outline` | Lên lộ trình khóa học |
| `POST /api/lesson` | Sinh bài học = chuỗi khối widget |
| `POST /api/exercises` | Bộ đề luyện: thêm N câu theo độ khó easy/medium/hard, không trùng câu đã có |
| `POST /api/ask` | Gia sư hỏi đáp: câu trả lời là 1–4 khối (chữ + LaTeX, ảnh, đồ thị/mô phỏng, giải từng bước, code demo) |
| `POST /api/simulation` | Mô phỏng tùy biến: HTML tự chứa, đã chặn tài nguyên ngoài + CSP |
| `POST /api/interactive` | Thêm khối tương tác cho một khái niệm |
| `POST /api/explain` | Gia sư: gợi ý, giải thích, gốc lỗi |
| `POST /api/sources/search` | Tìm nguồn web (chỉ giữ URL từ công cụ tìm kiếm), gắn nhãn tin cậy |
| `GET /api/health`, `GET /api/usage` | Kiểm tra, chi phí token thực tế |
