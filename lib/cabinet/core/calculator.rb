# frozen_string_literal: true

module PanelCore
  module Cabinet
    module Core
      # Bộ tính toán kích thước tham số cho tủ
      # Tách biệt hoàn toàn logic tính toán khỏi logic vẽ hình
      class Calculator
        attr_reader :width, :height, :depth, :thickness
        
        def initialize(width:, height:, depth:, thickness: Config.default_thickness)
          @width = width.to_f
          @height = height.to_f
          @depth = depth.to_f
          @thickness = thickness.to_f
          @gap = Config.edge_gap
        end
        
        # Tính toán kích thước các tấm cho tủ cơ bản (4 tấm + đáy + nắp)
        # Returns: Hash chứa dimensions của từng panel
        def calculate_basic_cabinet
          {
            left_side: calculate_side_panel,
            right_side: calculate_side_panel,
            bottom: calculate_horizontal_panel,
            top: calculate_horizontal_panel,
            back: calculate_back_panel,
            interior_width: interior_width,
            interior_height: interior_height,
            interior_depth: interior_depth
          }
        end
        
        # Tính kích thước tấm hông
        def calculate_side_panel
          {
            width: @depth,
            height: @height,
            thickness: @thickness,
            position: :left # hoặc :right sẽ được xác định khi dựng hình
          }
        end
        
        # Tính kích thước tấm ngang (đáy/nắp)
        def calculate_horizontal_panel
          {
            width: @width - (2 * @thickness),
            depth: @depth - @thickness,
            thickness: @thickness
          }
        end
        
        # Tính kích thước hậu tủ
        def calculate_back_panel
          {
            width: @width - (2 * @thickness),
            height: @height - (2 * @thickness),
            thickness: 6 # Hậu tủ thường mỏng hơn
          }
        end
        
        # Không gian sử dụng bên trong
        def interior_width
          @width - (2 * @thickness)
        end
        
        def interior_height
          @height - (2 * @thickness)
        end
        
        def interior_depth
          @depth - @thickness
        end
        
        # Tính vị trí lỗ khoan cho mộng gỗ (dowels)
        def calculate_dowel_positions(panel_type:, count: 2)
          positions = []
          case panel_type
          when :side
            step = (@height - 100) / (count + 1)
            count.times do |i|
              positions << {
                x: @thickness / 2, # Giữa độ dày ván
                y: 50 + (step * (i + 1)),
                z: 0
              }
            end
          when :horizontal
            step = (interior_width - 100) / (count + 1)
            count.times do |i|
              positions << {
                x: 50 + (step * (i + 1)),
                y: 0,
                z: @thickness / 2
              }
            end
          end
          positions
        end
        
        # Validate kích thước có nằm trong giới hạn vật liệu không
        def validate_dimensions(max_sheet_size: [2440, 1220])
          errors = []
          
          if @width > max_sheet_size[0]
            errors << "Chiều rộng #{@width}mm vượt quá khổ ván #{max_sheet_size[0]}mm"
          end
          
          if @height > max_sheet_size[1]
            errors << "Chiều cao #{@height}mm vượt quá khổ ván #{max_sheet_size[1]}mm"
          end
          
          if @depth > max_sheet_size[1]
            errors << "Chiều sâu #{@depth}mm vượt quá khổ ván #{max_sheet_size[1]}mm"
          end
          
          errors
        end
      end
    end
  end
end
