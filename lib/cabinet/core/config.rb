# frozen_string_literal: true

module PanelCore
  module Cabinet
    module Core
      # Cấu hình tiêu chuẩn cho kết cấu tủ
      # Có thể tùy chỉnh để thay đổi quy cách sản xuất
      class Config
        # Khoảng cách mép tiêu chuẩn (mm)
        EDGE_GAP = 0.5
        
        # Độ dày ván mặc định (mm)
        DEFAULT_THICKNESS = 18
        
        # Thứ tự lắp ráp (Assembly Order)
        ASSEMBLY_ORDER = %i[
          base_frame
          side_panels
          top_bottom_panels
          shelves
          back_panel
          doors_drawers
        ].freeze
        
        # Hệ số an toàn cho khe hở phụ kiện
        HARDWARE_CLEARANCE = 2.0
        
        class << self
          attr_accessor :edge_gap, :default_thickness
          
          def reset
            @edge_gap = EDGE_GAP
            @default_thickness = DEFAULT_THICKNESS
          end
        end
        
        reset
      end
    end
  end
end
