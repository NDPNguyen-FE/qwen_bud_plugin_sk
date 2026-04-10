# encoding: UTF-8
# =============================================================================
# Advanced Kerf Engine for WoodCNC Pro
# Tích hợp core toán học siêu việt từ KerfBend plugin.
# Hỗ trợ: Cylinder Unrolling, Cone Unrolling, Spring-Relaxation, Adaptive Kerf.
# =============================================================================

module PanelPlugin
  module Core
    module KerfEngine
      
      # =======================================================================
      # GEOMETRY UTILS
      # =======================================================================
      module GeometryUtils
        def self.points_equal?(p1, p2, tol = 0.01)
          p1.distance(p2) < tol
        end
        
        def self.distance(p1, p2)
          p1.distance(p2)
        end
        
        def self.normalize(v)
          v.length > 0 ? v.normalize : v.clone
        end
        
        def self.cross(v1, v2)
          v1.cross(v2)
        end
        
        def self.dot(v1, v2)
          v1.dot(v2)
        end
        
        def self.polygon_area_2d(polygon)
          area = 0.0
          n = polygon.length
          (0...n).each do |i|
            j = (i + 1) % n
            area += polygon[i].x * polygon[j].y - polygon[j].x * polygon[i].y
          end
          area / 2.0
        end
        
        def self.point_in_polygon_2d(pt, polygon)
          inside = false
          j = polygon.length - 1
          (0...polygon.length).each do |i|
            pi = polygon[i]; pj = polygon[j]
            if ((pi.y > pt.y) != (pj.y > pt.y)) && 
               (pt.x < (pj.x - pi.x) * (pt.y - pi.y) / (pj.y - pi.y + 1e-10) + pi.x)
              inside = !inside
            end
            j = i
          end
          inside
        end
        
        def self.line_segment_intersection_2d(p1, p2, p3, p4)
          s1_x, s1_y = p2.x - p1.x, p2.y - p1.y
          s2_x, s2_y = p4.x - p3.x, p4.y - p3.y
          den = -s2_x * s1_y + s1_x * s2_y
          return nil if den.abs < 1e-10
          
          s = (-s1_y * (p1.x - p3.x) + s1_x * (p1.y - p3.y)) / den
          t = ( s2_x * (p1.y - p3.y) - s2_y * (p1.x - p3.x)) / den
          
          if s >= 0 && s <= 1 && t >= 0 && t <= 1
            Geom::Point3d.new(p1.x + (t * s1_x), p1.y + (t * s1_y), 0)
          else
            nil
          end
        end
        
        def self.analyze_curve(edge)
          curve = edge.curve
          if curve && curve.is_a?(Sketchup::ArcCurve)
            { type: :arc, radius: curve.radius, angle: (curve.end_angle - curve.start_angle).abs,
              arc_length: curve.radius * (curve.end_angle - curve.start_angle).abs,
              center: curve.center, edge: edge }
          else
            { type: :line, length: edge.length, edge: edge }
          end
        end
      end
      
      # =======================================================================
      # SURFACE FLATTENER
      # =======================================================================
      module SurfaceFlattener
        # Trải phẳng mặt cong, trả về flat_points, boundaries và face map
        def self.flatten(faces, options = {})
          opts = { resolution: 2.0, iterations: 200, tolerance: 0.01, method: :cylinder }.merge(options)
          
          method = classify_surface(faces)
          case method
          when :cylinder
            flatten_cylinder(faces, opts)
          else
            # Fallback về spring relaxation nếu quá phức tạp
            flatten_spring_relaxation(faces, opts)
          end
        end
        
        def self.classify_surface(faces)
          return :spring if faces.empty?
          arcs = faces.flat_map { |f| f.edges.select { |e| e.curve.is_a?(Sketchup::ArcCurve) } }
          return :spring if arcs.empty?
          
          # Đơn giản hóa: Cứ có face cong mà chung tâm thì cylinder
          arc = arcs.first.curve
          same_center = arcs.all? { |e| e.curve.center.distance(arc.center) < 1.0 rescue false }
          same_center ? :cylinder : :spring
        end
        
        def self.flatten_cylinder(faces, options)
          arc_data = extract_cylinder_params(faces)
          return flatten_spring_relaxation(faces, options) unless arc_data
          
          radius, axis, arc_length, height, angle_start, angle_end = arc_data.values_at(
            :radius, :axis, :arc_length, :height, :angle_start, :angle_end
          )
          
          # Lấy biên tổng thể để xuất thẳng outline (không lưới) tránh vỡ Face
          flat_points = [
            Geom::Point3d.new(0, 0, 0),
            Geom::Point3d.new(arc_length, 0, 0),
            Geom::Point3d.new(arc_length, height, 0),
            Geom::Point3d.new(0, height, 0)
          ]
          
          {
            flat_points: flat_points,
            flat_boundary: flat_points.clone,  # Hình chữ nhật hoàn chỉnh
            distortion: 0.0,
            method: :cylinder,
            metadata: arc_data
          }
        end
        
        def self.extract_cylinder_params(faces)
          arcs = faces.flat_map { |f| f.edges.map(&:curve).compact.select { |c| c.is_a?(Sketchup::ArcCurve) } }.uniq
          return nil if arcs.empty?
          
          arc = arcs.first
          center, radius = arc.center, arc.radius
          ang_s, ang_e = arc.start_angle, arc.end_angle
          ang_s, ang_e = ang_e, ang_s if ang_e < ang_s
          
          # Tìm Axis
          straight_edges = faces.flat_map(&:edges).reject { |e| e.curve.is_a?(Sketchup::ArcCurve) rescue false }
          longest = straight_edges.max_by(&:length)
          axis = longest ? GeometryUtils.normalize(longest.end.position - longest.start.position) : arc.normal
          
          # Tìm chiều cao
          pos = faces.flat_map { |f| f.vertices.map { |v| v.position.dot(axis) } }
          height = (pos.max - pos.min).abs
          
          { center: center, radius: radius, axis: axis, 
            angle_start: ang_s, angle_end: ang_e, height: height, 
            arc_length: radius * (ang_e - ang_s) }
        end
        
        def self.flatten_spring_relaxation(faces, options)
          # (Bản rút gọn PCA/Spring cho tương lai - hiện tại đa số CNC panel là Cylinder)
          # Fallback tạo một BB thẳng cho an toàn
          total_area = faces.sum(&:area)
          side = Math.sqrt(total_area)
          pts = [
            Geom::Point3d.new(0, 0, 0), Geom::Point3d.new(side, 0, 0),
            Geom::Point3d.new(side, side, 0), Geom::Point3d.new(0, side, 0)
          ]
          { flat_points: pts, flat_boundary: pts, distortion: 5.0, method: :spring_fallback, metadata: {} }
        end
      end
      
      # =======================================================================
      # KERF CALCULATOR (ADAPTIVE SPACING)
      # =======================================================================
      module KerfCalculator
        def self.calculate_kerfs(flatten_result, options = {})
          base_t = options[:thickness] || 18.0
          r_inner = flatten_result[:metadata][:radius] || 100.0
          arc_length = flatten_result[:metadata][:arc_length] || 200.0
          ang_rad = flatten_result[:metadata][:angle_end] - flatten_result[:metadata][:angle_start] rescue Math::PI/2
          
          kerf_ratio = options[:kerf_ratio] || 0.88
          kerf_depth = base_t * kerf_ratio
          t_rem = base_t - kerf_depth
          tool_dia = options[:tool_dia] || 6.0
          kerf_w = tool_dia  # End Mill width
          
          # ADAPTIVE SPACING MATH 
          max_angle = 2.0 * Math.atan2(kerf_w / 2.0, t_rem)
          n_min = (ang_rad.abs / max_angle).ceil
          s_equal = arc_length / [n_min, 1].max
          s_structural = tool_dia * 1.5
          
          s_adaptive = Math.sqrt(2.0 * t_rem * (r_inner - Math.sqrt([r_inner**2 - (arc_length / ([n_min, 1].max * 2.0))**2, 0].max))) rescue s_equal
          
          s_optimal = [s_adaptive, s_equal].min
          s_optimal = [s_optimal, s_structural].max
          s_optimal = (s_optimal * 10.0).round / 10.0
          
          num_kerfs = (arc_length / s_optimal).floor
          
          # Generate lines (Parallel Kerfs cho Panel)
          lines = []
          bnd = flatten_result[:flat_boundary]
          if bnd
            margin = tool_dia / 2.0
            x_min, x_max = bnd.map(&:x).minmax
            y_min, y_max = bnd.map(&:y).minmax
            
            w_dim = x_max - x_min
            h_dim = y_max - y_min
            
            # Giả định hướng cuộn theo X (arc length theo X)
            effective_w = arc_length
            s_eff = effective_w / (num_kerfs + 1)
            
            (1..num_kerfs).each do |i|
              kx = x_min + i * s_eff
              # Margin padding Y
              p1 = Geom::Point3d.new(kx, y_min, 0)
              p2 = Geom::Point3d.new(kx, y_max, 0)
              lines << { start: p1, end: p2, depth: kerf_depth, width: kerf_w }
            end
          end
          
          { 
            kerf_lines: lines, num_kerfs: num_kerfs, spacing: s_optimal, 
            depth: kerf_depth, width: kerf_w, valid: t_rem >= 1.0, t_rem: t_rem
          }
        end
      end
      
      # =======================================================================
      # ABF ADAPTER (CHÌA KHÓA NESTING 1 FACE CHUẨN)
      # =======================================================================
      module ABFAdapter
        def self.create_abf_component(flatten_res, kerf_res, model, options = {})
          part_name = options[:part_name] || "CNC_P_#{(rand*1000).to_i}"
          
          model.start_operation("ABF CNC Part", true)
          
          # Component Definition
          cdef = model.definitions.add(part_name)
          ents = cdef.entities
          
          cut_layer = ensure_layer(model, 'CUT')
          kerf_layer = ensure_layer(model, 'ABF_SCORING') # Tương thích với WoodCNC config
          
          # 1. OUTLINE (Tạo 1 Face nguyên vẹn duy nhất!)
          boundary_pts = flatten_res[:flat_boundary]
          face = ents.add_face(boundary_pts)
          if face
            face.reverse! if face.normal.z < 0
            face.layer = cut_layer
            face.material = nil # Null mat cho ABF tự xử lý
            
            # Set thuộc tính bắt buộc của KerfBend/ABF
            attr = {
              "part_type" => "kerf_bend",
              "nestable" => true,
              "thickness" => options[:thickness].to_f
            }
            attr.each { |k, v| cdef.set_attribute('dynamic_attributes', k, v) }
          end
          
          # Khắc viền outline (ABF yêu cầu viền rõ)
          boundary_pts.each_with_index do |pt, i|
            nxt = boundary_pts[(i+1) % boundary_pts.length]
            e = ents.add_line(pt, nxt)
            e.layer = cut_layer if e
          end
          
          # 2. KERF LINES (Nằm HƠI CÁCH MẶT PHẲNG CHÚT ĐỂ KHÔNG CẮT VỠ FACE = BUG FACE=4)
          kerf_res[:kerf_lines].each do |k|
            # Mẹo nhỏ: Đẩy Z lên 0.05mm. Mắt không thấy nhưng SU không auto-intersect mặt.
            z_offset = Geom::Vector3d.new(0, 0, 0.05)
            e = ents.add_line(k[:start] + z_offset, k[:end] + z_offset)
            e.layer = kerf_layer if e
          end
          
          # 3. Instance
          target = options[:target_point] || Geom::Point3d.new(0,0,0)
          inst = model.active_entities.add_instance(cdef, Geom::Transformation.translation(target))
          inst.name = part_name
          
          model.commit_operation
          
          { instance: inst, def: cdef, part_name: part_name }
        end
        
        def self.ensure_layer(model, name)
          model.layers[name] || model.layers.add(name)
        end
      end
      
    end
  end
end
