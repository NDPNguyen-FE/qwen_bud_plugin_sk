# encoding: UTF-8
# =============================================================================
# FaceToPanel - Convert selected 2D faces into 3D panels with thickness
# =============================================================================
module PanelPlugin
  module Tools
    class FaceToPanel

      @@next_origin_x = 0.0
      GAP_MM = 50.0

      def self.run
        model = Sketchup.active_model
        sel = model.selection.select { |e| e.is_a?(Sketchup::Face) }

        if sel.empty?
          UI.messagebox("Vui lòng dùng công cụ Select để chọn ít nhất một Mặt phẳng (Face) 2D trước khi tạo ván.")
          return
        end

        # Hỏi độ dày muốn tạo
        thickness_default = UI.read_default('panel_plugin', 'default_thickness', 18.0)
        prompts = ['Chiều dày (mm):', 'Tạo tấm mặt hướng lên? (Yes/No)']
        defaults = [thickness_default.to_s, 'Yes']
        list = ['', 'Yes|No']
        
        input = ::UI.inputbox(prompts, defaults, list, "Tạo ván từ #{sel.length} mặt phẳng")
        return unless input

        t_mm = input[0].to_f
        push_up = input[1] == 'Yes'

        if t_mm < 3.0
          UI.messagebox('Chiều dày phải >= 3mm.')
          return
        end

        UI.write_default('panel_plugin', 'default_thickness', t_mm)

        PanelCore::UndoWrapper.run('Ván từ Mặt phẳng') do
          # Duplicate array of faces since modifying them alters the selection/entities
          faces_to_process = sel.to_a
          
          # Tạo bảng tính origin
          # Nếu user vừa chọn vẽ đợt mới, có thể ta muốn gom về gốc hoặc tiếp tục hàng cũ
          # Để không bị trôi đi vô tận, ta sẽ nối tiếp theo @@next_origin_x
          
          edges_to_process = []
          faces_to_process.each do |face|
            next unless face.valid?
            edges_to_process.concat(face.edges)
            create_panel_from_face(face, t_mm, push_up)
          end

          # Xoá mặt phẳng 2D gốc của người dùng sau khi tạo xong ván
          model.active_entities.erase_entities(faces_to_process)
          
          # Dọn dẹp các đường line nét thừa không còn thuộc về bất kỳ face nào
          edges_to_delete = edges_to_process.uniq.reject { |e| e.deleted? || !e.faces.empty? }
          model.active_entities.erase_entities(edges_to_delete) unless edges_to_delete.empty?

          # Clear selection when done
          model.selection.clear
          
          # Tự động nhảy sang công cụ bo góc:
          PanelPlugin::Tools::FilletTool.run
        end
      end

      def self.create_panel_from_face(face, thickness_mm, push_up)
        model = Sketchup.active_model
        t_su = PanelCore::ComponentManager.mm_to_su(thickness_mm)

        # 1. Trích xuất thông tin mặt phẳng
        origin = face.vertices.first.position.clone
        normal = face.normal.clone
        
        # Nếu user muốn đẩy khối ra phía Đằng sau mặt chỉ định
        normal = normal.reverse unless push_up

        # Tìm trục X an toàn
        edge_vec = face.edges.first.line[1].clone
        if edge_vec.parallel?(normal)
          edge_vec = face.edges[1].line[1].clone
        end

        x_axis = edge_vec.normalize
        y_axis = normal.cross(x_axis).normalize
        z_axis = normal.normalize

        # Lấy toạ độ viền ngoài của face 2D để clone an toàn thàh ván, không bóc mất face gốc
        pts = face.outer_loop.vertices.map(&:position)
        
        # Biến đổi toạ độ từ Không gian world về mặt phẳng 2D nội bộ (XY)
        t_world_to_local = Geom::Transformation.new(origin, x_axis, y_axis).inverse
        local_pts = pts.map { |p| p.transform(t_world_to_local) }

        panel_name = PanelCore::ComponentManager.next_panel_name
        defn = model.definitions.add(panel_name)

        # Trải face lên mặt phẳng gốc XY
        local_face = defn.entities.add_face(local_pts)
        if local_face
          # Đảm bảo normal hướng Z+
          local_face.reverse! if local_face.normal.z < 0
          local_face.pushpull(t_su)
        end

        # 5. Phục hồi toạ độ ở vị trí dàn ngang trên mặt đất! (Array Layout)
        # origin_pt = t_local, t_local xoay nó như cũ
        # NHƯNG người dùng yêu cầu: xếp hàng ngang trải dài cách khoảng!
        
        origin_pt = Geom::Point3d.new(PanelCore::ComponentManager.mm_to_su(@@next_origin_x), 0, 0)
        t_placement = Geom::Transformation.new(origin_pt)
        
        # Nếu muốn nó xoay tương đối cho đúng chiều (mặt phẳng ban đầu) ta có thể giữ, 
        # nhưng nếu layflat xuống đất thì chỉ cần t_placement đơn thuần!
        # Dựng tấm ván nằm dưới mặt đất (Chuẩn CNC):
        
        inst = model.active_entities.add_instance(defn, t_placement)
        inst.name = panel_name

        # Cập nhật origin cho tấm kế tiếp
        bbox = defn.bounds
        span_x = bbox.width
        # Đã tính theo inch, đổi về mm để quản lý
        span_x_mm = PanelCore::ComponentManager.su_to_mm(span_x)
        @@next_origin_x += span_x_mm + GAP_MM

        # 6. Mặc định Metadata của ABF
        attrs = {
          'part_name'       => panel_name,
          'material_id'     => 'melamine_18',
          'grain_direction' => 'horizontal',
          'thickness_mm'    => thickness_mm,
          'is_template'     => false,
          'notes'           => '',
          'created_at'      => Time.now.to_i
        }
        PanelCore::AttributeManager.write(defn, attrs)

        inst
      end
    end
  end
end
