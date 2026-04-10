# frozen_string_literal: true

module PanelCore
  module Cabinet
    module Core
      # Lớp điều phối xây dựng tủ
      # Nhận dữ liệu từ Calculator và thực thi vẽ hình học, gán attribute
      class Builder
        attr_reader :calculator, :dimensions
        
        def initialize(width:, height:, depth:, thickness: nil)
          @thickness = thickness || Config.default_thickness
          @calculator = Calculator.new(
            width: width,
            height: height,
            depth: depth,
            thickness: @thickness
          )
          @dimensions = @calculator.calculate_basic_cabinet
          @entities = []
        end
        
        # Phương thức chính: Xây dựng toàn bộ tủ
        # Returns: Group chứa toàn bộ cabinet
        def build(parent_entities = Sketchup.active_model.entities)
          # Tạo group chính cho tủ
          cabinet_group = parent_entities.add_group
          cabinet_group.name = "Cabinet_#{Time.now.to_i}"
          
          # Lưu metadata tổng quan
          set_cabinet_metadata(cabinet_group)
          
          # Xây dựng từng thành phần theo thứ tự
          build_side_panels(cabinet_group)
          build_horizontal_panels(cabinet_group)
          build_back_panel(cabinet_group)
          
          # Làm sạch hình học sau khi dựng
          PanelCore::Geometry::Cleaner.clean_group(cabinet_group)
          
          cabinet_group
        end
        
        private
        
        def set_cabinet_metadata(group)
          # Sử dụng ABF Schema để chuẩn hóa metadata cabinet
          config = {
            width_mm: @calculator.width,
            height_mm: @calculator.height,
            depth_mm: @calculator.depth,
            thickness_mm: @thickness,
            interior_width: @calculator.interior_width,
            interior_height: @calculator.interior_height,
            cabinet_type: :basic_cabinet,
            created_at: Time.now.to_i
          }
          
          PanelCore::ABF.initialize_cabinet_attributes(group, config: config)
        end
        
        def build_side_panels(group)
          entities = group.entities
          thickness = @thickness
          dim = @dimensions[:left_side]
          
          # Tấm bên trái
          left_panel = create_panel(entities, dim[:width], dim[:height], thickness, name: 'Left_Side')
          left_panel.position(Geom::Point3d.new(0, 0, 0))
          left_panel.transform!(Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(1, 0, 0), -90.degrees))
          
          set_panel_attributes(left_panel, :side_panel, 'left')
          
          # Tấm bên phải
          right_panel = create_panel(entities, dim[:width], dim[:height], thickness, name: 'Right_Side')
          right_x = @calculator.width - thickness
          right_panel.position(Geom::Point3d.new(right_x, 0, 0))
          right_panel.transform!(Geom::Transformation.rotation(Geom::Point3d.new(right_x, 0, 0), Geom::Vector3d.new(1, 0, 0), -90.degrees))
          
          set_panel_attributes(right_panel, :side_panel, 'right')
        end
        
        def build_horizontal_panels(group)
          entities = group.entities
          thickness = @thickness
          dim = @dimensions[:bottom]
          
          # Tấm đáy
          bottom_panel = create_panel(entities, dim[:width], dim[:depth], thickness, name: 'Bottom')
          bottom_panel.position(Geom::Point3d.new(thickness, 0, thickness))
          set_panel_attributes(bottom_panel, :horizontal_panel, 'bottom')
          
          # Tấm nắp
          top_panel = create_panel(entities, dim[:width], dim[:depth], thickness, name: 'Top')
          top_y = @calculator.height - thickness
          top_panel.position(Geom::Point3d.new(thickness, top_y, thickness))
          set_panel_attributes(top_panel, :horizontal_panel, 'top')
        end
        
        def build_back_panel(group)
          entities = group.entities
          dim = @dimensions[:back]
          thickness = dim[:thickness]
          
          back_panel = create_panel(entities, dim[:width], dim[:height], thickness, name: 'Back')
          back_z = @calculator.depth - thickness
          back_panel.position(Geom::Point3d.new(0, 0, back_z))
          set_panel_attributes(back_panel, :back_panel, 'back')
        end
        
        def create_panel(entities, width, depth, thickness, name: 'Panel')
          # Tạo hình hộp chữ nhật cho tấm ván
          group = entities.add_group
          panel_entities = group.entities
          
          # Vẽ mặt dưới
          face = panel_entities.add_face(0, 0, 0, width, 0, 0, width, depth, 0, 0, depth, 0)
          face.pushpull(thickness)
          
          group.name = name
          group
        end
        
        def set_panel_attributes(panel_group, role, position)
          # Sử dụng ABF Schema để gán attribute chuẩn
          PanelCore::ABF.initialize_panel_attributes(
            panel_group,
            role: role,
            material_code: 'MDF_18',
            thickness: @thickness
          )
          
          # Thêm thông tin vị trí (sử dụng ABF helper method)
          PanelCore::ABF.set_panel_attribute(panel_group, :panel_uuid, "#{PanelCore::ABF.get_panel_attribute(panel_group, :panel_uuid)}_#{position}")
        end
      end
    end
  end
end
