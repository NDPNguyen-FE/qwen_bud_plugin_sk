# frozen_string_literal: true

module PanelCore
  # Module định nghĩa chuẩn hóa Schema thuộc tính cho ABF Integration
  # Mục đích: Đảm bảo mọi panel sinh ra đều mang đúng "DNA" để ABF Engine nhận diện
  # và xử lý tự động (khoan, dán cạnh, xuất CNC).
  module ABF
    # --- PREFIXES ---
    # Sử dụng prefix để tránh xung đột với các plugin khác hoặc attribute mặc định của SketchUp
    PREFIX = 'pp_abf_'.freeze
    
    # --- CORE IDENTIFIERS (Định danh cốt lõi) ---
    # Các trường này giúp ABF biết tấm ván này là gì, thuộc nhóm nào
    ATTRIBUTE_KEYS = {
      # Mã định danh duy nhất cho từng tấm ván (dùng cho Barcode/QR)
      panel_uuid: "#{PREFIX}uuid",
      
      # Loại tấm ván trong cấu trúc tủ (Side, Top, Bottom, Shelf, Door, Back, etc.)
      # Giá trị ví dụ: :side, :top, :bottom, :shelf, :door, :back, :drawer_front
      panel_role: "#{PREFIX}role",
      
      # Mã vật liệu thô (liên kết với thư viện vật liệu ABF)
      # Ví dụ: "MDF_18_WHITE", "WOOD_OAK_25"
      material_code: "#{PREFIX}material_code",
      
      # Độ dày thực tế của ván (mm) - Dùng để verify với material_code
      thickness_mm: "#{PREFIX}thickness_mm",
      
      # Hướng vân gỗ (0, 90, 180, 270 độ) - Quan trọng cho nesting và thẩm mỹ
      grain_direction: "#{PREFIX}grain_dir",
    }.freeze

    # --- EDGE BANDING DATA (Dữ liệu dán cạnh) ---
    # ABF cần biết cạnh nào cần dán, mã cạnh là gì để tính toán kích thước thành phẩm
    EDGE_KEYS = {
      # Cạnh trên (Top) - Tương ứng với trục Y+ trong local coordinates
      edge_top: "#{PREFIX}edge_top",       # Boolean: Có dán không?
      edge_top_code: "#{PREFIX}edge_top_code", # String: Mã vật liệu cạnh (ví dụ: "PVC_1MM_WHITE")
      
      # Cạnh dưới (Bottom) - Trục Y-
      edge_bottom: "#{PREFIX}edge_bottom",
      edge_bottom_code: "#{PREFIX}edge_bottom_code",
      
      # Cạnh trái (Left) - Trục X-
      edge_left: "#{PREFIX}edge_left",
      edge_left_code: "#{PREFIX}edge_left_code",
      
      # Cạnh phải (Right) - Trục X+
      edge_right: "#{PREFIX}edge_right",
      edge_right_code: "#{PREFIX}edge_right_code",
    }.freeze

    # --- CNC & DRILLING DATA (Dữ liệu gia công) ---
    # Các trường này điều khiển hành vi của máy CNC thông qua ABF
    PROCESSING_KEYS = {
      # ID của mẫu khoan lỗ (Drilling Pattern) được định nghĩa trong thư viện ABF
      # Plugin chỉ cần gán ID, ABF sẽ tự sinh tọa độ lỗ dựa trên Rule
      drilling_pattern_id: "#{PREFIX}drill_pattern_id",
      
      # ID của cấu hình dao cụ/layer trên máy CNC
      # Ví dụ: "CUT_OUTLINE", "GROOVE_3MM", "DRILL_5MM"
      cnc_layer_id: "#{PREFIX}cnc_layer_id",
      
      # Trạng thái kiểm tra DFM (Design for Manufacturing)
      # :ok, :warning, :error
      dfm_status: "#{PREFIX}dfm_status",
      
      # Ghi chú lỗi DFM nếu có (để hiển thị UI)
      dfm_message: "#{PREFIX}dfm_message",
    }.freeze

    # --- CABINET METADATA (Metadata cho cabinet container) ---
    # Các trường dành riêng cho Group chứa toàn bộ tủ
    CABINET_KEYS = {
      cabinet_id: "#{PREFIX}cabinet_id",
      cabinet_name: "#{PREFIX}cabinet_name",
      cabinet_type: "#{PREFIX}cabinet_type", # :base, :wall, :tall
      width_mm: "#{PREFIX}width_mm",
      height_mm: "#{PREFIX}height_mm",
      depth_mm: "#{PREFIX}depth_mm",
      thickness_mm: "#{PREFIX}thickness_mm",
      back_thickness_mm: "#{PREFIX}back_thickness_mm",
      style: "#{PREFIX}style",
      has_back: "#{PREFIX}has_back",
      has_top: "#{PREFIX}has_top",
      num_doors: "#{PREFIX}num_doors",
      door_gap_top: "#{PREFIX}door_gap_top",
      door_gap_bot: "#{PREFIX}door_gap_bot",
      door_gap_l: "#{PREFIX}door_gap_l",
      door_gap_r: "#{PREFIX}door_gap_r",
      toe_kick_height: "#{PREFIX}toe_kick_height",
      toe_kick_depth: "#{PREFIX}toe_kick_depth",
      floor_raise: "#{PREFIX}floor_raise",
      back_groove_depth: "#{PREFIX}back_groove_depth",
      back_groove_offset: "#{PREFIX}back_groove_offset",
      created_at: "#{PREFIX}created_at",
      is_parametric: "#{PREFIX}is_parametric",
    }.freeze

    # --- HELPER METHODS ---
    
    # Trả về toàn bộ keys cần thiết để khởi tạo một panel chuẩn
    def self.all_keys
      ATTRIBUTE_KEYS.values + EDGE_KEYS.values + PROCESSING_KEYS.values
    end

    # Trả về toàn bộ keys cho cabinet metadata
    def self.all_cabinet_keys
      CABINET_KEYS.values
    end

    # Kiểm tra xem một entity đã có đầy đủ attribute chưa
    def self.validate_panel_attributes(entity)
      return { valid: false, missing: ['No attribute dictionary'] } unless entity.attribute_dictionary
      
      missing_keys = []
      all_keys.each do |key|
        missing_keys << key unless entity.attribute_dictionary.key?(key)
      end
      
      if missing_keys.empty?
        { valid: true, missing: [] }
      else
        { valid: false, missing: missing_keys }
      end
    end

    # Khởi tạo attribute dictionary mặc định cho một panel mới
    # @param entity [Sketchup::ComponentInstance or Sketchup::Group]
    # @param role [Symbol] Vai trò của tấm ván
    # @param material_code [String] Mã vật liệu
    # @param thickness [Numeric] Độ dày
    def self.initialize_panel_attributes(entity, role:, material_code:, thickness:)
      dict = entity.attribute_dictionary('PanelCore', true)
      
      # Core Identifiers
      dict[ATTRIBUTE_KEYS[:panel_uuid]] = generate_uuid
      dict[ATTRIBUTE_KEYS[:panel_role]] = role.to_s
      dict[ATTRIBUTE_KEYS[:material_code]] = material_code
      dict[ATTRIBUTE_KEYS[:thickness_mm]] = thickness
      dict[ATTRIBUTE_KEYS[:grain_direction]] = 0 # Default 0 degrees

      # Edge Banding Defaults (Mặc định chưa dán cạnh, người dùng hoặc rule sẽ cập nhật sau)
      EDGE_KEYS.each do |key, attr_name|
        if key.to_s.include?('code')
          dict[attr_name] = '' # Empty string for code
        else
          dict[attr_name] = false # Boolean false for enable/disable
        end
      end

      # Processing Defaults
      dict[PROCESSING_KEYS[:drilling_pattern_id]] = 'DEFAULT_CABINET' # Default pattern
      dict[PROCESSING_KEYS[:cnc_layer_id]] = 'PANEL_CUTOUT'
      dict[PROCESSING_KEYS[:dfm_status]] = 'pending'
      dict[PROCESSING_KEYS[:dfm_message]] = ''

      dict
    end

    # Khởi tạo attribute dictionary cho cabinet container
    # @param entity [Sketchup::Group] Group chứa toàn bộ tủ
    # @param config [Hash] Cấu hình tủ
    def self.initialize_cabinet_attributes(entity, config:)
      dict = entity.attribute_dictionary('PanelCore', true)
      
      CABINET_KEYS.each do |key, attr_name|
        value = config[key]
        dict[attr_name] = value unless value.nil?
      end
      
      # Set defaults if not provided
      dict[CABINET_KEYS[:cabinet_id]] ||= generate_cabinet_id
      dict[CABINET_KEYS[:created_at]] ||= Time.now.to_i
      dict[CABINET_KEYS[:is_parametric]] ||= true
      
      dict
    end

    # Lấy giá trị của một attribute panel
    def self.get_panel_attribute(entity, key)
      return nil unless entity.attribute_dictionary
      attr_key = ATTRIBUTE_KEYS[key] || EDGE_KEYS[key] || PROCESSING_KEYS[key]
      return nil unless attr_key
      entity.attribute_dictionary[attr_key]
    end

    # Đặt giá trị cho một attribute panel
    def self.set_panel_attribute(entity, key, value)
      dict = entity.attribute_dictionary('PanelCore', true)
      attr_key = ATTRIBUTE_KEYS[key] || EDGE_KEYS[key] || PROCESSING_KEYS[key]
      return false unless attr_key
      dict[attr_key] = value
      true
    end

    # Lấy giá trị của một attribute cabinet
    def self.get_cabinet_attribute(entity, key)
      return nil unless entity.attribute_dictionary
      attr_key = CABINET_KEYS[key]
      return nil unless attr_key
      entity.attribute_dictionary[attr_key]
    end

    # Đặt giá trị cho một attribute cabinet
    def self.set_cabinet_attribute(entity, key, value)
      dict = entity.attribute_dictionary('PanelCore', true)
      attr_key = CABINET_KEYS[key]
      return false unless attr_key
      dict[attr_key] = value
      true
    end

    private

    # Tạo UUID đơn giản cho panel (có thể thay thế bằng SecureRandom nếu cần)
    def self.generate_uuid
      "P_#{Time.now.to_i}_#{rand(1000..9999)}"
    end
    
    # Tạo ID cho cabinet
    def self.generate_cabinet_id
      "CAB_#{Time.now.to_i}_#{rand(1000..9999)}"
    end
  end
end
