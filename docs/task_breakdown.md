# Task Breakdown - Panel Plugin ABF & CNC Optimization

## Overview
Chi tiết phân rã công việc để xây dựng plugin hỗ trợ dựng nhanh, tích hợp ABF và tối ưu hóa quy trình sản xuất CNC.

---

## Milestone 1: Data Foundation & Core Refactoring
**Mục tiêu:** Đảm bảo mỗi tấm ván sinh ra đều mang đầy đủ "DNA" sản xuất, sạch về hình học và thống nhất về cấu trúc.

### Task 1.1: Chuẩn hóa Schema Attribute (ABF Standard)
- **Mô tả:** Định nghĩa lại `DynamicAttributes`, bổ sung các trường bắt buộc cho quy trình CNC và ABF.
- **Yêu cầu chi tiết:**
  - Bổ sung các trường: `material_code`, `edge_band_top/bottom/left/right`, `cnc_layer_id`, `drilling_pattern_id`, `barcode_uuid`.
  - Đảm bảo tương thích ngược với dữ liệu cũ.
  - Tạo utility helper để truy xuất và gán attribute an toàn.
- **Tiêu chí hoàn thành (DoD):**
  - [ ] Mọi panel mới sinh ra đều tự động gán đầy đủ attribute mặc định.
  - [ ] Có hàm utility `PanelMetadata.get(panel)` trả về object metadata chuẩn.
  - [ ] Unit test kiểm tra tính toàn vẹn của schema (không thiếu field, đúng kiểu dữ liệu).
  - [ ] Tài liệu hóa schema trong code (RDoc/YARD).

### Task 1.2: Làm sạch Hình học (Geometry Sanitization)
- **Mô tả:** Viết module `GeometryCleaner` để tối ưu hóa entity trước khi xuất DXF.
- **Yêu cầu chi tiết:**
  - Gộp các mặt phẳng đồng phẳng (coplanar faces).
  - Xóa cạnh dư (redundant edges) và vertex trùng lặp.
  - Đảm bảo pháp tuyến (normal) hướng ra ngoài thống nhất.
- **Tiêu chí hoàn thành (DoD):**
  - [ ] Panel xuất ra DXF không bị lỗi đường nét đứt hoặc thừa nét.
  - [ ] Số lượng entity giảm ít nhất 20% so với bản gốc (đo lường trên case thử nghiệm).
  - [ ] Có test case so sánh hình học trước/sau khi làm sạch.

### Task 1.3: Refactor Logic Sinh Tủ Base (Parametric Core)
- **Mô tả:** Tách biệt logic tính toán kích thước khỏi logic vẽ hình học.
- **Yêu cầu chi tiết:**
  - Áp dụng mẫu thiết kế Strategy hoặc Builder để tách lớp tính toán (Calculator) và lớp dựng hình (Builder).
  - Loại bỏ các phép tính cứng (hard-coded) trong phương thức vẽ.
- **Tiêu chí hoàn thành (DoD):**
  - [ ] Code dễ đọc, tuân thủ nguyên lý Single Responsibility.
  - [ ] Có thể thay đổi quy tắc lắp ráp (ví dụ: từ 4-way gap sang butt joint) mà không cần sửa logic vẽ.
  - [ ] Tốc độ sinh tủ hoàn chỉnh dưới 0.5s cho tủ tiêu chuẩn 3 khoang.

### Task 1.4: Đơn vị hóa Cấu trúc Tủ (Standardized Cabinet Structure)
- **Mô tả:** Xây dựng lớp `CabinetAssembly` để quản lý quan hệ cha-con và ngữ cảnh lắp ráp.
- **Yêu cầu chi tiết:**
  - Quản lý cây phân cấp: Cabinet -> Section -> Panel.
  - Lưu trữ thông tin mặt tiếp xúc (adjacency data) giữa các panel.
- **Tiêu chí hoàn thành (DoD):**
  - [ ] Có thể truy vấn nhanh danh sách panel con của một tủ.
  - [ ] Xác định chính xác mặt tiếp xúc giữa 2 tấm (dùng cho tính toán khoan lỗ sau này).
  - [ ] Hỗ trợ serialization/deserialization cấu trúc tủ sang JSON.

---

## Milestone 2: Auto-Drilling & Smart Joinery
**Mục tiêu:** Tự động sinh lỗ khoan và liên kết dựa trên quy tắc, giảm thao tác thủ công.

### Task 2.1: Engine tính toán vị trí khoan (Drilling Engine)
- **Mô tả:** Thuật toán tính tọa độ lỗ khoan dựa trên quy tắc khoảng cách mép và bước lỗ.
- **Yêu cầu chi tiết:**
  - Hỗ trợ lỗ mộng (dowel), lỗ vít (screw), lỗ bản lề (hinge cup).
  - Tính toán tự động dựa trên độ dày ván và vị trí ghép nối.
- **Tiêu chí hoàn thành (DoD):**
  - [ ] Sinh chính xác nhóm lỗ khoan cho mối nối tiêu chuẩn.
  - [ ] Cập nhật real-time vị trí lỗ khi thay đổi kích thước tủ.
  - [ ] Hỗ trợ cấu hình bán kính và độ sâu lỗ qua UI.

### Task 2.2: Tích hợp Thư viện Phụ kiện (Hardware Library)
- **Mô tả:** Database nội bộ chứa thông số khoét lỗ của các phụ kiện phổ biến.
- **Yêu cầu chi tiết:**
  - Lưu trữ thông số: Bản lề (Blum, Hafele...), Ray trượt, Tay nắm.
  - Cơ chế "Snap & Drill": Tự động khoét lỗ khi đặt phụ kiện vào mặt ván.
- **Tiêu chí hoàn thành (DoD):**
  - [ ] Tự động khoét lỗ chính xác theo catalog nhà sản xuất khi chọn phụ kiện.
  - [ ] Cảnh báo nếu vị trí đặt phụ kiện trùng với lỗ khoan có sẵn hoặc mép ván quá gần.

### Task 2.3: Tự động hóa Joinery (Mộng âm dương & Rãnh)
- **Mô tả:** Nâng cấp các công cụ tạo mộng và rãnh hoạt động tự động theo ngữ cảnh.
- **Yêu cầu chi tiết:**
  - Tích hợp `MortiseTenonTool` vào quy trình sinh tủ tự động.
  - Tự động tạo rãnh hậu (back panel groove) khi sinh khung tủ.
- **Tiêu chí hoàn thành (DoD):**
  - [ ] Khung tủ tự động tạo mộng ở 4 góc khi kích hoạt chế độ "Auto Joinery".
  - [ ] Rãnh hậu tự động sinh và điều chỉnh kích thước theo độ dày ván hậu.

### Task 2.4: Hệ thống Rule-based Validation (Luật liên kết)
- **Mô tả:** Định nghĩa và thực thi các luật liên kết để đảm bảo tính logic của kết cấu.
- **Yêu cầu chi tiết:**
  - Luật: "Ván dọc không được ngắn hơn 50mm", "Khoảng cách lỗ khoan tối thiểu từ mép là 3x đường kính mũi khoan".
  - Chạy kiểm tra ngầm mỗi khi người dùng thay đổi tham số.
- **Tiêu chí hoàn thành (DoD):**
  - [ ] Hệ thống hiển thị cảnh báo rõ ràng trong UI khi vi phạm luật.
  - [ ] Ngăn chặn sinh lỗ khoan vô lý (ví dụ: lỗ xuyên thủng ván).

---

## Milestone 3: DFM Validator (Design for Manufacturing)
**Mục tiêu:** Phát hiện lỗi thiết kế trước khi đưa xuống xưởng, giảm tỷ lệ phế phẩm.

### Task 3.1: Bộ kiểm tra Quy tắc Vật liệu (Material Rules)
- **Mô tả:** Kiểm tra tính khả thi của thiết kế đối với khổ ván thô thực tế.
- **Yêu cầu chi tiết:**
  - Cảnh báo nếu kích thước tấm > khổ ván chuẩn (1220x2440).
  - Kiểm tra hướng vân gỗ có phù hợp với thẩm mỹ và độ bền không.
- **Tiêu chí hoàn thành (DoD):**
  - [ ] Báo cáo lỗi rõ ràng trong UI nếu kích thước vượt ngưỡng.
  - [ ] Gợi ý phương án xẻ ván tối ưu nếu tấm quá lớn.

### Task 3.2: Kiểm tra Khả thi Dao cụ (Tooling Feasibility)
- **Mô tả:** Đảm bảo các chi tiết thiết kế có thể gia công được với bộ dao hiện có.
- **Yêu cầu chi tiết:**
  - Kiểm tra bán kính lượn góc (không nhỏ hơn bán kính dao nhỏ nhất).
  - Kiểm tra độ sâu rãnh (không quá 2/3 độ dày ván).
- **Tiêu chí hoàn thành (DoD):**
  - [ ] Liệt kê chi tiết lỗi "Không thể gia công" kèm tên dao cần dùng.
  - [ ] Gợi ý sửa đổi thông số (ví dụ: "Tăng bán kính góc lên 3mm").

### Task 3.3: Kiểm tra xung đột (Collision Detection)
- **Mô tả:** Quét toàn bộ tủ để phát hiện các xung đột hình học.
- **Yêu cầu chi tiết:**
  - Phát hiện lỗ khoan trùng nhau hoặc chồng lấn.
  - Phát hiện vết cắt chạm vào phụ kiện hoặc liên kết.
- **Tiêu chí hoàn thành (DoD):**
  - [ ] Highlight đỏ các vùng xung đột trực tiếp trong mô hình 3D SketchUp.
  - [ ] Báo cáo chi tiết danh sách xung đột kèm tọa độ.

### Task 3.4: Báo cáo DFM tổng hợp
- **Mô tả:** Tổng hợp tất cả cảnh báo thành một báo cáo duy nhất, dễ đọc.
- **Yêu cầu chi tiết:**
  - Phân loại mức độ: Error (phải sửa), Warning (nên sửa), Info (gợi ý).
  - Khóa chức năng xuất CNC nếu còn lỗi Error.
- **Tiêu chí hoàn thành (DoD):**
  - [ ] Nút "Export CNC" bị vô hiệu hóa nếu tồn tại lỗi nghiêm trọng.
  - [ ] Xuất được file PDF/Text báo cáo DFM để gửi khách hàng/xưởng.

---

## Milestone 4: Nesting & Anti-Fly Optimization
**Mục tiêu:** Tiết kiệm vật liệu và đảm bảo an toàn khi cắt CNC, chống hiện tượng "bay ván".

### Task 4.1: Thuật toán Nesting 2D (Cơ bản)
- **Mô tả:** Implement thuật toán xếp hình 2D để sắp xếp các tấm ván vào khổ gỗ lớn nhất.
- **Yêu cầu chi tiết:**
  - Hỗ trợ xoay tấm 90 độ (nếu cho phép hướng vân).
  - Tính toán khe hở dao cắt (kerf width) giữa các tấm.
- **Tiêu chí hoàn thành (DoD):**
  - [ ] Sắp xếp panel vào tấm ván với tỷ lệ lấp đầy > 80% (trung bình các case test).
  - [ ] Hiển thị mô phỏng sơ đồ cắt (cutting diagram) trong SketchUp.

### Task 4.2: Chiến lược Anti-Fly Tabs (Tabs giữ ván)
- **Mô tả:** Tự động thêm các điểm giữ (tabs/micro-joints) tại các cạnh dễ bị xê dịch khi cắt xong.
- **Yêu cầu chi tiết:**
  - Tính toán vị trí tabs dựa trên kích thước tấm và lực hút chân không.
  - Đảm bảo tabs không nằm vào vị trí cần dán cạnh hoặc khoan lỗ.
- **Tiêu chí hoàn thành (DoD):**
  - [ ] Đường cắt DXF có các đoạn ngắt (tabs) chính xác theo cấu hình (kích thước, số lượng).
  - [ ] Không có panel nào trong mô phỏng bị coi là "bay" (mất liên kết với tấm nền trước khi cắt xong).

### Task 4.3: Tối ưu thứ tự cắt (Cutting Order Optimization)
- **Mô tả:** Sắp xếp lại thứ tự cắt để giảm thời gian di chuyển đầu dao và tăng độ ổn định.
- **Yêu cầu chi tiết:**
  - Cắt các lỗ bên trong (internal cuts) trước, sau đó đến biên dạng ngoài.
  - Tối ưu đường đi (toolpath) ngắn nhất giữa các điểm cắt.
- **Tiêu chí hoàn thành (DoD):**
  - [ ] File xuất có thứ tự layer/entity đúng chuẩn: Lỗ khoan -> Rãnh -> Cắt viền.
  - [ ] Giảm 10-15% thời gian gia công ước tính so với cách xuất ngẫu nhiên.

### Task 4.4: Tích hợp tham số máy CNC cụ thể
- **Mô tả:** Cho phép cấu hình các tham số đặc thù của máy CNC đang sử dụng.
- **Yêu cầu chi tiết:**
  - Nhập thông số: Tốc độ chạy dao, tốc độ quay trục, đường kính dao, lực hút bàn.
  - Lưu profile cho từng máy (Machine Profile).
- **Tiêu chí hoàn thành (DoD):**
  - [ ] File xuất DXF/G-code chứa các thông số phù hợp ngay với máy thực tế.
  - [ ] Người dùng có thể lưu và chuyển đổi giữa các profile máy khác nhau.

---

## Milestone 5: CAM Export & Reporting
**Mục tiêu:** Hoàn tất quy trình từ thiết kế đến máy móc và quản lý kho, đóng vòng lặp sản xuất.

### Task 5.1: Export DXF/CAM phân lớp (Layered Export)
- **Mô tả:** Xuất file DXF với hệ thống layer màu sắc và tên gọi chuẩn hóa cho máy CNC.
- **Yêu cầu chi tiết:**
  - Phân lớp: CUT_OUT (đỏ), DRILLING (xanh), GROOVE (vàng), TEXT (trắng).
  - Đảm bảo tỷ lệ 1:1 chính xác tuyệt đối.
- **Tiêu chí hoàn thành (DoD):**
  - [ ] Mở file DXF trên phần mềm điều khiển máy (VD: AlphaCam, ArtCAM) thấy đúng các lớp.
  - [ ] Kích thước đo trên file DXF trùng khớp 100% với thiết kế SketchUp.

### Task 5.2: Sinh mã vạch/QR Code cho từng tấm
- **Mô tả:** Tạo mã QR chứa thông tin định danh và quy cách tấm ván, khắc laser lên mặt sau.
- **Yêu cầu chi tiết:**
  - Mã hóa thông tin: ID tấm, Kích thước, Vật liệu, Cạnh dán, Vị trí lắp ráp.
  - Tự động vẽ vector mã QR vào mặt sau của tấm trong bản xuất DXF.
- **Tiêu chí hoàn thành (DoD):**
  - [ ] Máy quét mã vạch cầm tay đọc được thông tin từ tấm ván in thử.
  - [ ] Mã QR hiển thị đúng và không bị biến dạng khi xuất DXF.

### Task 5.3: Báo cáo BOM & Cutlist nâng cao
- **Mô tả:** Xuất báo cáo chi tiết vật tư và danh sách cắt phục vụ sản xuất và kế toán.
- **Yêu cầu chi tiết:**
  - Nhóm các tấm cùng vật liệu, cùng độ dày.
  - Tính toán tổng diện tích bề mặt, chu vi cạnh dán.
  - Xuất định dạng Excel (.xlsx) và PDF.
- **Tiêu chí hoàn thành (DoD):**
  - [ ] File báo cáo đầy đủ cột: Mã tấm, Kích thước, Vật liệu, Diện tích, Cạnh dán (L/T/R/B).
  - [ ] Báo cáo nhóm tấm theo từng tấm gỗ thô (Sheet) để giao cho thợ cắt.

### Task 5.4: Pipeline tự động hóa (One-Click Production)
- **Mô tả:** Tạo nút lệnh "Sản xuất" chạy tuần tự toàn bộ quy trình từ kiểm tra đến xuất file.
- **Yêu cầu chi tiết:**
  - Tuần tự: DFM Check -> Nesting -> Thêm Tabs -> Xuất DXF -> Xuất BOM.
  - Xử lý lỗi gracefully: Nếu bước 1 lỗi thì dừng và báo cáo, không chạy tiếp.
- **Tiêu chí hoàn thành (DoD):**
  - [ ] Quy trình từ thiết kế đến khi có file gửi máy mất dưới 1 phút cho tủ trung bình.
  - [ ] Hệ thống thông báo tiến độ từng bước và tóm tắt kết quả cuối cùng.

---

## Ghi chú triển khai
- **Ngôn ngữ:** Ruby (SketchUp API), HTML/JS (UI Dialog).
- **Thư viện ngoài:** Có thể cân nhắc dùng thư viện Ruby cho QR Code (`rqrcode` nếu môi trường cho phép) hoặc tự sinh vector đơn giản.
- **Ưu tiên:** Tập trung hoàn thành Milestone 1 và 2 trước để có dữ liệu sạch, sau đó mới tối ưu Nesting và Export.
