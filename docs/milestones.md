# Roadmap: Panel Plugin - Tích hợp ABF & Tối ưu hóa CNC

## Mục tiêu tổng quát
Nâng cấp module **Xây dựng Tủ & Nội thất** hiện có để trở thành nền tảng dữ liệu chuẩn hóa cho quy trình sản xuất CNC, tích hợp sâu với hệ sinh thái ABF, bổ sung các thuật toán tối ưu vật liệu và chống lỗi gia công.

---

## Milestone 1: Chuẩn hóa Dữ liệu & Cấu trúc Tủ (Data Foundation)
**Mục tiêu:** Đảm bảo mọi tấm ván sinh ra từ tủ đều mang đầy đủ "DNA" sản xuất (ABF Compatible).
**Thời gian dự kiến:** 2 tuần

### Nhiệm vụ chi tiết:
- [ ] **Audit & Refactor Attribute Schema:**
    - Chuẩn hóa `panel_core` và `panel_cabinet` dictionaries.
    - Bổ sung các trường bắt buộc cho CNC: `edge_band_code` (mã cạnh dán), `drill_pattern_id` (mẫu khoan), `cnc_layer` (lớp xuất file), `grain_priority` (ưu hướng vân).
    - Đảm bảo tính kế thừa thuộc tính từ Cabinet xuống Panel con.
- [ ] **Cải tiến Logic sinh hình học (Geometry Engine):**
    - Tách biệt hoàn toàn phần tính toán kích thước (Logic) và phần vẽ hình học (Geometry).
    - Đảm bảo các tấm ván là "Clean Geometry" (không dư thừa điểm, mặt phẳng chuẩn) để dễ dàng export DXF.
    - Xử lý logic bo mép (fillet) ngay từ khâu sinh khối để đồng bộ với DAO cụ.
- [ ] **Đơn vị hóa cấu trúc tủ:**
    - Chuyển đổi các hard-code khoảng cách (gap) thành biến cấu hình toàn cục.
    - Hỗ trợ đa dạng loại tủ cơ bản: Base, Wall, Tall, Sink, Corner.

**Kết quả mong đợi:** Một chiếc tủ được dựng lên không chỉ là hình khối 3D mà là một tập hợp các đối tượng dữ liệu giàu thông tin, sẵn sàng cho các bước xử lý tiếp theo.

---

## Milestone 2: Tự động hóa Phụ kiện & Khoan cắt (Auto-Drilling & Joinery)
**Mục tiêu:** Tự động hóa việc tạo lỗ khoan và liên kết dựa trên quy tắc ABF, giảm 80% thao tác thủ công.
**Thời gian dự kiến:** 3 tuần

### Nhiệm vụ chi tiết:
- [ ] **Hệ thống Rule-based Drilling:**
    - Xây dựng database các mẫu khoan chuẩn (Euro hinge, Shelf pin, Ray trượt, Tay nắm).
    - Implement logic tự động khoét lỗ khi gắn phụ kiện vào tấm ván (dựa trên `dynamic_attributes`).
    - Hỗ trợ khoan xuyên tâm và khoan mặt (face drilling).
- [ ] **Nâng cấp Joinery Engine:**
    - Tích hợp tự động tạo mộng Lamello, Mộng gỗ, hoặc rãnh nhôm định hình tùy theo cấu hình tủ.
    - Kiểm tra va chạm (Clash Detection) giữa các lỗ khoan và đường cắt cạnh.
- [ ] **Giao diện cấu hình nhanh:**
    - Thêm tab "Hardware & Drilling" trong Cabinet Builder Panel.
    - Cho phép người dùng chọn loại phụ kiện và áp dụng hàng loạt cho cả tủ.

**Kết quả mong đợi:** Tủ sau khi dựng xong đã có sẵn các lỗ khoan chính xác đến từng milimet, sẵn sàng cho máy khoan CNC.

---

## Milestone 3: Validator & DFM (Design for Manufacturing)
**Mục tiêu:** Ngăn chặn sai sót trước khi xuất file, đảm bảo thiết kế có thể gia công được thực tế.
**Thời gian dự kiến:** 2 tuần

### Nhiệm vụ chi tiết:
- [ ] **Xây dựng DFM Validator Core:**
    - Kiểm tra độ dày ván tối thiểu cho từng loại dao.
    - Cảnh báo khoảng cách lỗ khoan quá gần cạnh (gây vỡ ván).
    - Phát hiện các góc chết không thể gia công được.
    - Kiểm tra hướng vân gỗ có phù hợp với phương án cắt không.
- [ ] **Hệ thống cảnh báo trực quan:**
    - Highlight các vùng lỗi trên mô hình 3D bằng màu đỏ/cam.
    - Hiển thị danh sách lỗi chi tiết kèm giải pháp đề xuất trong UI.
- [ ] **Kiểm tra tính hợp lệ của ABF Data:**
    - Đảm bảo không có panel nào thiếu mã vật liệu hoặc mã cạnh dán.

**Kết quả mong đợi:** Người dùng nhận được báo cáo "Pass/Fail" trước khi nhấn nút Export, giảm thiểu phế phẩm do lỗi thiết kế.

---

## Milestone 4: Tối ưu hóa Nesting & Chống bay ván (Nesting & Anti-Fly)
**Mục tiêu:** Tiết kiệm vật liệu và đảm bảo an toàn khi chạy máy CNC.
**Thời gian dự kiến:** 3 tuần

### Nhiệm vụ chi tiết:
- [ ] **Thuật toán Nesting nội bộ (hoặc tích hợp API):**
    - Sắp xếp các tấm ván từ nhiều tủ vào một khổ giấy tiêu chuẩn (1220x2440, 1830x2440...).
    - Tính toán tỷ lệ sử dụng ván (% Utilization).
    - Hỗ trợ xoay tấm ván tự động để tối ưu diện tích (có tính đến hướng vân cố định).
- [ ] **Chiến lược Anti-Fly Tabs (Tai giữ ván):**
    - Tự động thêm các "Tabs" (điểm nối nhỏ) tại các vị trí chiến lược trên đường cắt ngoài cùng.
    - Tính toán số lượng và kích thước Tab dựa trên độ dày ván và loại dao.
    - Đảm bảo Tab không vướng vào vị trí cần dán cạnh hoặc lắp ráp.
- [ ] **Tối ưu đường chạy dao (Toolpath Optimization):**
    - Sắp xếp thứ tự cắt để giảm thời gian di chuyển trống của đầu dao.
    - Phân nhóm các chi tiết cùng vật liệu/độ dày.

**Kết quả mong đợi:** File xuất ra giúp tiết kiệm 5-10% nguyên liệu và ngăn chặn hiện tượng tấm ván bị xê dịch/hỏng khi cắt xong.

---

## Milestone 5: Xuất file CNC & Báo cáo sản xuất (CAM Export & Reporting)
**Mục tiêu:** Hoàn thiện quy trình "One-click to Production".
**Thời gian dự kiến:** 2 tuần

### Nhiệm vụ chi tiết:
- [ ] **Nâng cấp Export DXF/CAM:**
    - Xuất file phân lớp màu chuẩn (Cut, Drill, Mill, Score).
    - Nhúng thông tin G-code cơ bản hoặc header file cho máy CNC cụ thể (Homag, Biesse, SCM...).
    - Định dạng file đầu ra tương thích hoàn toàn với phần mềm điều khiển máy.
- [ ] **Hệ thống Labeling (Mã vạch/QR):**
    - Tự động sinh nhãn dán cho từng tấm ván chứa: Mã tủ, Vị trí, Kích thước, Mã cạnh dán.
    - In nhãn trực tiếp từ SketchUp hoặc xuất file PDF riêng.
- [ ] **Báo cáo BOM & Cutlist nâng cao:**
    - Xuất Excel/PDF chi tiết: Tổng diện tích ván, tổng chiều dài cạnh dán, danh sách phụ kiện.
    - Dự toán chi phí nguyên vật liệu sơ bộ.

**Kết quả mong đợi:** Quy trình khép kín từ Thiết kế -> Duyệt lỗi -> Tối ưu -> Xuất file máy -> In nhãn -> Sản xuất.

---

## Phụ lục: Công nghệ & Thư viện đề xuất
- **Nesting Algorithm:** Sử dụng thư viện Ruby `bin_packing` hoặc viết thuật toán Greedy/Genetic Algorithm đơn giản.
- **DXF Library:** Cập nhật `lib/export/dxf_writer.rb` để hỗ trợ entity mới (Spline, Arc chính xác).
- **Database:** Sử dụng SQLite nhúng hoặc JSON files để lưu cấu hình dao, mẫu khoan.
- **UI Framework:** Tiếp tục sử dụng HTML/JS hiện tại, bổ sung Chart.js cho biểu đồ nesting.
