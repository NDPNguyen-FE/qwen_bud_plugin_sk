# encoding: UTF-8
# =============================================================================
# FilletTool - Cắt góc của tấm ván (Fillet/Chamfer/Concave)
# =============================================================================
module PanelPlugin
  module Tools
    class FilletTool
      def initialize
        @radius_mm = Sketchup.read_default('panel_plugin', 'default_fillet_radius', 50.0).to_f
        @segments = Sketchup.read_default('panel_plugin', 'default_fillet_segments', 12).to_i
        @cut_type = Sketchup.read_default('panel_plugin', 'default_cut_type', 'Bo tròn lồi (Fillet)')
        @hover_edge = nil
        @hover_instance = nil
      end
      
      def self.run
        Sketchup.active_model.select_tool(new)
      end

      def activate
        update_status
      end

      def deactivate(view)
        view.invalidate
      end

      def update_status
        Sketchup::set_status_text("Cắt Cạnh Góc (Fillet/Chamfer). Click vào CẠNH GÓC dọc của ván để chọn, sau đó nhập kích thước.", SB_PROMPT)
      end

      def onMouseMove(flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick(x, y)
        
        edge = nil
        instance = nil
        
        best_path = ph.path_at(0)
        if best_path
          picked_entity = best_path.last
          if picked_entity.is_a?(Sketchup::Edge)
            # Lấy đối tượng chứa cạnh trực tiếp (nằm ngay trước Edge trong path)
            parent_container = best_path[-2]
            
            # Cho phép cắt cả Component lẫn Group bình thường (không bắt buộc phải là ABF Panel)
            if parent_container && (parent_container.is_a?(Sketchup::ComponentInstance) || parent_container.is_a?(Sketchup::Group))
              instance = parent_container
              edge = picked_entity
            end
          end
        end

        if edge && instance
          @hover_edge = edge
          @hover_instance = instance
        else
          @hover_edge = nil
          @hover_instance = nil
        end
        
        view.invalidate
      end

      def draw(view)
        if @hover_edge && @hover_instance
          view.line_width = 5
          view.drawing_color = Sketchup::Color.new(255, 50, 50)
          
          t = @hover_instance.transformation
          v1 = @hover_edge.start.position.transform(t)
          v2 = @hover_edge.end.position.transform(t)
          
          view.draw(GL_LINES, [v1, v2])
        end
      end

      def onLButtonDown(flags, x, y, view)
        if @hover_edge && @hover_instance
          cut_options = ['Bo tròn lồi (Fillet)', 'Bo tròn lõm (Concave)', 'Cắt chéo thẳng (Chamfer)']
          prompts = ['Loại cắt cạnh/góc:', 'Kích thước R/D (mm):', 'Số phân đoạn (Segments):']
          defaults = [@cut_type, @radius_mm.to_s, @segments.to_s]
          list = [cut_options.join('|'), "", ""]
          
          input = ::UI.inputbox(prompts, defaults, list, 'Tuỳ Chỉnh Cắt Cạnh Ván CNC')
          return unless input

          c_type = input[0]
          r = input[1].to_f
          s = input[2].to_i
          if r > 0 && s >= 1
            @cut_type = c_type
            @radius_mm = r
            @segments = s
            Sketchup.write_default('panel_plugin', 'default_cut_type', c_type)
            Sketchup.write_default('panel_plugin', 'default_fillet_radius', r)
            Sketchup.write_default('panel_plugin', 'default_fillet_segments', s)
            
            do_fillet(@hover_instance, @hover_edge, @segments, @cut_type, @radius_mm)
            
            Sketchup.active_model.select_tool(nil)
          else
            Sketchup.messagebox("Kích thước phải > 0 và Segments phải hợp lệ")
          end
        end
      end

      private

      def do_fillet(instance, edge, segments, cut_type, size_mm)
        defn = nil
        
        # Xử lý tương thích cho cả Component lẫn Group
        if instance.is_a?(Sketchup::ComponentInstance)
          PanelCore::ComponentManager.make_unique!(instance)
          defn = instance.definition
        elsif instance.is_a?(Sketchup::Group)
          instance.make_unique
          # SketchUp API mới có method definition cho Group, API cũ dùng entities.parent
          defn = instance.respond_to?(:definition) ? instance.definition : instance.entities.parent
        end
        
        return unless defn
        
        target_edge = nil
        start_pt = edge.start.position
        end_pt = edge.end.position
        
        defn.entities.grep(Sketchup::Edge).each do |e|
          if (e.start.position == start_pt && e.end.position == end_pt) ||
             (e.start.position == end_pt && e.end.position == start_pt)
            target_edge = e
            break
          end
        end
        return unless target_edge

        r_su = PanelCore::ComponentManager.mm_to_su(size_mm)
        
        # Mở rộng logic: Tìm 1 mặt phẳng vuông góc với target_edge tại 1 trong 2 đầu đỉnh
        # Mục tiêu: Vẽ tiết diện bo góc trên mặt phẳng này, xong đẩy (push-pull) dọc theo chiều dài cạnh
        
        v_top = target_edge.start
        edge_vec = target_edge.line[1]
        
        profile_face = v_top.faces.find { |f| f.normal.parallel?(edge_vec) }
        
        if profile_face.nil?
          v_top = target_edge.end
          profile_face = v_top.faces.find { |f| f.normal.parallel?(edge_vec) }
        end
        
        unless profile_face
          Sketchup.messagebox("Không tìm thấy mặt phẳng đầu hồi (Profile Face) thích hợp ở 2 đầu cạnh này để bo.")
          return
        end
        
        profile_normal = profile_face.normal
        
        edges_on_profile = v_top.edges.select { |e| e.faces.include?(profile_face) }
        if edges_on_profile.length < 2 
          Sketchup.messagebox("Cạnh này không hợp lệ (không tạo thành góc đỉnh trên mặt).")
          return
        end
        
        e1, e2 = edges_on_profile[0], edges_on_profile[1]
        
        vec1 = v_top.position.vector_to(e1.other_vertex(v_top).position)
        vec2 = v_top.position.vector_to(e2.other_vertex(v_top).position)
        
        angle = vec1.angle_between(vec2)
        if angle <= 0.01 || angle > 179.degrees
           Sketchup.messagebox("Góc quá thẳng, không thể tác động.")
           return
        end
        
        if cut_type == 'Bo tròn lồi (Fillet)'
          d = r_su / Math.tan(angle / 2.0)
        else
          d = r_su
        end
        
        if d > vec1.length || d > vec2.length
          Sketchup.messagebox("Kích thước #{size_mm}mm quá lớn so với độ dài của cạnh mặt hồi!")
          return
        end
        
        p1 = v_top.position.offset(vec1, d)
        p2 = v_top.position.offset(vec2, d)
        
        pp_dist = -target_edge.length

        PanelCore::UndoWrapper.run("Cắt Cạnh: #{cut_type}") do
          cut_geometry = nil

          if cut_type == 'Bo tròn lồi (Fillet)'
            bisector = Geom::Vector3d.linear_combination(0.5, vec1.normalize, 0.5, vec2.normalize).normalize
            dist_to_center = r_su / Math.sin(angle / 2.0)
            center = v_top.position.offset(bisector, dist_to_center)
            
            v_p1 = center.vector_to(p1)
            v_p2 = center.vector_to(p2)
            arc_angle = v_p1.angle_between(v_p2)
            
            cross = v_p1.cross(v_p2)
            end_angle = (cross.dot(profile_normal) > 0) ? arc_angle : -arc_angle
            
            if end_angle < 0
              v_p1, v_p2 = v_p2, v_p1
              p1, p2 = p2, p1
              end_angle = -end_angle
            end
            cut_geometry = defn.entities.add_arc(center, v_p1, profile_normal, r_su, 0.0, end_angle, segments)
            
          elsif cut_type == 'Bo tròn lõm (Concave)'
            center = v_top.position
            v_p1 = center.vector_to(p1)
            v_p2 = center.vector_to(p2)
            arc_angle = v_p1.angle_between(v_p2)
            
            cross = v_p1.cross(v_p2)
            end_angle = (cross.dot(profile_normal) > 0) ? arc_angle : -arc_angle
            
            if end_angle < 0
              v_p1, v_p2 = v_p2, v_p1
              p1, p2 = p2, p1
              end_angle = -end_angle
            end
            cut_geometry = defn.entities.add_arc(center, v_p1, profile_normal, r_su, 0.0, end_angle, segments)
            
          elsif cut_type == 'Cắt chéo thẳng (Chamfer)'
            cut_geometry = [defn.entities.add_line(p1, p2)]
          end
          
          if cut_geometry && cut_geometry.length > 0
            corner_face = v_top.faces.find { |f| f.normal.samedirection?(profile_normal) }
            
            if corner_face
              corner_face.pushpull(pp_dist)
            end
          else
            puts "Lỗi không vẽ được đường cắt trên mặt hồi"
          end
        end
        
        @hover_edge = nil
      end
    end
  end
end
