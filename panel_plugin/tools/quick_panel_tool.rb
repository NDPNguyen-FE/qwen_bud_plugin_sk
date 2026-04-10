# encoding: UTF-8
# =============================================================================
# QuickPanelTool - Chuyển sang Popup InputBox + Tự động xếp hàng trên màn hình (Array)
# =============================================================================
module PanelPlugin
  module Tools
    class QuickPanelTool
      @@last_length    = 600.0
      @@last_width     = 400.0
      @@last_thickness = nil
      @@last_axis      = 'Hướng Lên (Trục Z)'
      
      # Biến để ghi nhớ toạ độ tạo ván kế tiếp (tránh xếp chồng)
      @@next_origin_x  = 0.0
      GAP_MM           = 50.0

      AXIS_OPTIONS = [
        'Hướng Lên (Trục Z)', 
        'Đứng Trước-Sau (Trục Y)', 
        'Đứng Trái-Phải (Trục X)'
      ].freeze

      def self.run
        thickness_default = @@last_thickness || UI.read_default('panel_plugin', 'default_thickness', 18.0)
        
        prompts  = ['Chiều dài (mm):', 'Chiều rộng (mm):', 'Chiều dày (mm):', 'Tên cấu kiện:', 'Mặt phẳng ván:']
        defaults = [
          @@last_length.to_s, 
          @@last_width.to_s, 
          thickness_default.to_s, 
          PanelCore::ComponentManager.next_panel_name,
          @@last_axis
        ]
        list = ["", "", "", "", AXIS_OPTIONS.join('|')]
        
        input = ::UI.inputbox(prompts, defaults, list, 'Tạo Tấm Ván')
        return unless input

        length_mm    = input[0].to_f
        width_mm     = input[1].to_f
        thickness_mm = input[2].to_f
        panel_name   = input[3].to_s.strip
        axis_choice  = input[4].to_s

        errors = PanelCore::Validator.check_dimensions(length_mm, width_mm, thickness_mm)
        name_error = PanelCore::Validator.validate_part_name(panel_name)
        errors << name_error if name_error
        
        if errors.any?
          Sketchup::UI.messagebox("Lỗi nhập liệu:\n" + errors.join("\n"))
          return
        end

        @@last_length    = length_mm
        @@last_width     = width_mm
        @@last_thickness = thickness_mm
        @@last_axis      = axis_choice

        # Xoay theo trục
        x_rot = 0.0
        y_rot = 0.0
        
        if axis_choice == 'Đứng Trước-Sau (Trục Y)'
          x_rot = 90.degrees
        elsif axis_choice == 'Đứng Trái-Phải (Trục X)'
          y_rot = -90.degrees
        end
        
        # Metadata
        attrs = {
          'part_name'       => panel_name,
          'material_id'     => 'melamine_18',
          'grain_direction' => 'horizontal',
          'thickness_mm'    => thickness_mm,
          'is_template'     => false,
          'notes'           => '',
          'created_at'      => Time.now.to_i
        }

        PanelCore::UndoWrapper.run('Tạo ván Array') do
          defn = PanelCore::ComponentManager.create_panel_definition(
            length_mm, width_mm, thickness_mm, panel_name
          )
          PanelCore::AttributeManager.write(defn, attrs)

          # Toạ độ hiện tại cộng thêm gap nếu không phải tấm đầu tiên
          # Nhưng nếu user đã chuyển sang file mới, nên reset. 
          # Để an toàn, lấy bounds nội bộ hiện tại. Nhưng @@next_origin_x là đủ tốt.
          origin_pt = Geom::Point3d.new(PanelCore::ComponentManager.mm_to_su(@@next_origin_x), 0, 0)
          
          t = Geom::Transformation.new(origin_pt)
          t *= Geom::Transformation.rotation(ORIGIN, X_AXIS, x_rot) if x_rot != 0
          t *= Geom::Transformation.rotation(ORIGIN, Y_AXIS, y_rot) if y_rot != 0

          instance  = Sketchup.active_model.active_entities.add_instance(defn, t)
          instance.name = panel_name

          # Cập nhật origin cho tấm kế tiếp: Tiến về phía trục X (Chiều dài)
          # Tính không gian chiếm chỗ trên màn hình tuỳ thuộc mặt xoay
          span_x_mm = if axis_choice == 'Đứng Trái-Phải (Trục X)'
                        thickness_mm
                      else
                        length_mm
                      end
                      
          @@next_origin_x += span_x_mm + GAP_MM

          Sketchup.active_model.selection.clear
          Sketchup.active_model.selection.add(instance)
        end
      end
    end
  end
end
