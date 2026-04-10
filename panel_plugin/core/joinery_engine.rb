# encoding: UTF-8
# =============================================================================
# CNC Joinery Engine cho Mộng Âm Dương (Mortise & Tenon)
# Hỗ trợ đục lỗ mộng đâm xuyên hoặc mộng sập kín, cắt dogbone cho dao CNC.
# =============================================================================

module PanelPlugin
  module Core
    module JoineryEngine

      # Điểm bắt đầu phân tích tập hợp các tấm ván
      def self.process_panels(panels, options)
        joints = find_touching_joints(panels)
        if joints.empty?
          return { success: false, message: "Không tìm thấy mặt phẳng chạm nhau nào (Touch Detection) giữa các đối tượng đã chọn." }
        end

        count_mortise = 0
        count_tenon = 0

        model = Sketchup.active_model
        model.start_operation("Tạo Mộng Âm Dương CNC", true)
        
        begin
          joints.each do |joint|
            apply_mortise_tenon(joint, options)
            count_mortise += 1
            count_tenon += 1
          end
          model.commit_operation
          { success: true, message: "Đã tạo mộng cho #{joints.length} vị trí liên kết!" }
        rescue => e
          model.abort_operation
          { success: false, message: "Lỗi tạo mộng: #{e.message}\n#{e.backtrace.first(3).join("\n")}" }
        end
      end

      # =======================================================================
      # 1. TÌM GIAO TUYẾN CHẠM NHAU GIỮA CÁC TẤM VÁN
      # =======================================================================
      def self.find_touching_joints(panels)
        joints = []
        panels.to_a.combination(2).each do |p1, p2|
          # Sơ loại: Bounding Box phải chạm/giao nhau trước (Dung sai 1.0mm)
          bbx1 = p1.bounds
          bbx2 = p2.bounds
          bbx1_exp = Geom::BoundingBox.new
          bbx1.corner(0).upto(7) { |i| bbx1_exp.add(bbx1.corner(i) + Geom::Vector3d.new(1,1,1)); bbx1_exp.add(bbx1.corner(i) - Geom::Vector3d.new(1,1,1)) }
          
          next unless bbx1_exp.intersect(bbx2).valid?

          # Phân tích 6 mặt của mỗi panel
          info1 = analyze_panel_faces(p1)
          info2 = analyze_panel_faces(p2)
          next unless info1 && info2

          # Kiểm tra L-Joint / T-Joint: Cạnh mỏng của p1 chạm mặt rộng của p2
          j_1_to_2 = check_contact(info1[:edges], info2[:wides], p1, p2)
          joints << j_1_to_2 if j_1_to_2

          # Cạnh mỏng của p2 chạm mặt rộng của p1
          j_2_to_1 = check_contact(info2[:edges], info1[:wides], p2, p1)
          joints << j_2_to_1 if j_2_to_1
        end
        joints
      end

      def self.analyze_panel_faces(comp)
        return nil unless comp.is_a?(Sketchup::Group) || comp.is_a?(Sketchup::ComponentInstance)
        t = comp.transformation
        faces = (comp.is_a?(Sketchup::Group) ? comp.entities : comp.definition.entities).grep(Sketchup::Face)
        
        # Biến đổi sang Global coordinate
        infos = faces.map do |f|
          norm = f.normal.transform(t).normalize
          # Sửa lỗi scale transformation
          pts = f.vertices.map { |v| v.position.transform(t) }
          area = polygon_area_3d(pts)
          center = polygon_centroid(pts)
          { face: f, normal: norm, area: area, center: center, vertices: pts }
        end
        
        infos.sort_by! { |i| -i[:area] }
        { wides: infos[0..1], edges: infos[2..-1] } # 2 mặt lớn nhất là wide, 4 mặt nhỏ là edges
      end

      def self.check_contact(edge_faces, wide_faces, tenon_panel, mortise_panel)
        edge_faces.each do |e|
          wide_faces.each do |w|
            # Hai mặt chạm nhau thì vector pháp tuyến phải ngược chiều nhau
            dot = e[:normal].dot(w[:normal])
            next unless dot < -0.99

            # Khoảng cách giữa 2 mặt phẳng (điểm center của edge tới mặt phẳng wide)
            vec = e[:center] - w[:center]
            dist = vec.dot(w[:normal]).abs
            next unless dist < 0.2.mm # Dung sai 0.2mm

            # Project edge vertices lên mặt wide: đảm bảo Center edge nằm bên trong wide
            return build_joint_data(e, w, tenon_panel, mortise_panel)
          end
        end
        nil
      end

      def self.build_joint_data(edge, wide, tenon_panel, mortise_panel)
        pts = edge[:vertices]
        # Lấy 2 cạnh của mặt phẳng nối
        d1 = pts[0].distance(pts[1])
        d2 = pts[1].distance(pts[2])
        
        if d1 > d2
          length_dir = (pts[1] - pts[0]).normalize
          width_dir = (pts[2] - pts[1]).normalize
          length, width = d1, d2
        else
          length_dir = (pts[2] - pts[1]).normalize
          width_dir = (pts[1] - pts[0]).normalize
          length, width = d2, d1
        end

        {
          tenon_panel: tenon_panel,
          mortise_panel: mortise_panel,
          center: edge[:center],
          normal: edge[:normal], # Đi sâu vào mortise
          length_dir: length_dir,
          width_dir: width_dir,
          length: length,
          width: width,   # Thường bằng chiều dày ván (ví dụ 18mm)
          pts: pts
        }
      end

      # =======================================================================
      # 2. TẠO CUTTER BOOLEAN CHO MỘNG (SOLID TOOLS)
      # =======================================================================
      def self.apply_mortise_tenon(joint, options)
        model = Sketchup.active_model
        ents = model.active_entities

        t_len = options[:tenon_length]  # Chiều dài mỗi mộng
        t_marg = options[:tenon_margin] # Thụt lề 2 đầu
        m_dep = options[:mortise_depth] # Chiều sâu âm
        t_dia = options[:tool_dia]      # Tool CNC (Dogbone)
        tol   = options[:tolerance]     # Hở keo

        # ─── TÍNH TOÁN VỊ TRÍ CÁC RĂNG MỘNG ──────────────────────────────
        eff_len = joint[:length] - 2 * t_marg
        return if eff_len <= 0
        
        n_tenons = [(eff_len / (t_len * 2.0)).round, 1].max
        s_spacing = eff_len / n_tenons
        
        # Bắt đầu từ đầu mút (cộng lề)
        start_pt = joint[:center] - joint[:length_dir].transform(Geom::Transformation.scaling(joint[:length]/2.0))
        start_pt = start_pt + joint[:length_dir].transform(Geom::Transformation.scaling(t_marg))

        mortise_cutters = []
        tenon_adders = []

        # Vector đẩy sâu (Tenon mọc ra ngoài, Mortise đâm vào trong)
        vec_depth = joint[:normal].transform(Geom::Transformation.scaling(m_dep))

        (0...n_tenons).each do |i|
          # Center của tenon thứ i
          tc = start_pt + joint[:length_dir].transform(Geom::Transformation.scaling((i + 0.5) * s_spacing))
          
          # Hộp mộng dương (vừa khít)
          adder_grp = ents.add_group
          draw_box(adder_grp.entities, tc, joint[:length_dir], joint[:width_dir], 
                   t_len, joint[:width], vec_depth)
          tenon_adders << adder_grp

          # Hộp cắt mộng âm (Có dung sai hở keo)
          cutter_grp = ents.add_group
          draw_box(cutter_grp.entities, tc, joint[:length_dir], joint[:width_dir], 
                   t_len + tol * 2, joint[:width] + tol * 2, vec_depth)
          
          # Thêm Dogbone vào 4 góc của lớp cắt
          add_dogbones(cutter_grp.entities, tc, joint[:length_dir], joint[:width_dir], joint[:normal],
                       t_len + tol * 2, joint[:width] + tol * 2, m_dep, t_dia / 2.0 + 0.1)
          
          mortise_cutters << cutter_grp
        end

        # ─── THỰC THI SOLID BOOLEAN ──────────────────────────────────────────
        # Tấm đâm (Tenon) -> CỘNG THÊM (Union)
        tenons_grp = tenon_adders.first
        if tenon_adders.size > 1
          tenon_adders[1..-1].each { |a| a.union(tenons_grp) if a.valid? && tenons_grp.valid? }
        end
        if tenons_grp && tenons_grp.valid?
          new_tenon = tenons_grp.union(ensure_group(joint[:tenon_panel]))
          joint[:tenon_panel] = new_tenon if new_tenon
        end

        # Tấm vách (Mortise) -> TRỪ ĐI (Subtract)
        mortises_grp = mortise_cutters.first
        if mortise_cutters.size > 1
          mortise_cutters[1..-1].each { |c| c.union(mortises_grp) if c.valid? && mortises_grp.valid? }
        end
        if mortises_grp && mortises_grp.valid?
          new_mortise = mortises_grp.subtract(ensure_group(joint[:mortise_panel]))
          joint[:mortise_panel] = new_mortise if new_mortise
        end
      end

      # ─── HÀM PHỤ TRỢ VẼ HÌNH HỌC ───────────────────────────────────────

      # Vẽ hộp (Box) xuất phát từ center của khối (theo 2D), đẩy đùn theo vec_depth
      def self.draw_box(ents, center, dir_l, dir_w, l, w, vec_depth)
        hl = dir_l.transform(Geom::Transformation.scaling(l / 2.0))
        hw = dir_w.transform(Geom::Transformation.scaling(w / 2.0))
        
        p1 = center - hl - hw
        p2 = center + hl - hw
        p3 = center + hl + hw
        p4 = center - hl + hw
        
        face = ents.add_face(p1, p2, p3, p4)
        face.pushpull(vec_depth.length) if face # Đẩy dương khối
      end

      # Vẽ 4 ống tròn ở 4 góc của hộp tạo Dogbone
      # Mũi dao lùi ra góc 1 chút để tạo khoảng hở đủ khoan vuông góc
      def self.add_dogbones(ents, center, dir_l, dir_w, norm, l, w, depth, rad)
        # Tọa độ 4 góc nới rộng thêm 1 chút để tâm dao ăn qua đỉnh
        offset = rad * 0.707 # sin(45) cho góc
        hl = dir_l.transform(Geom::Transformation.scaling(l / 2.0 + offset))
        hw = dir_w.transform(Geom::Transformation.scaling(w / 2.0 + offset))
        vec_depth = norm.transform(Geom::Transformation.scaling(depth))

        corners = [
          center - hl - hw,
          center + hl - hw,
          center + hl + hw,
          center - hl + hw
        ]

        corners.each do |c|
          # Tạo đường tròn đáy
          circle = ents.add_circle(c, norm, rad, 16)
          face = ents.add_face(circle)
          face.pushpull(depth) if face
        end
      end

      # Các phép boolean Solid Tool trong SketchUp chỉ hoạt động trên Group tĩnh
      # Hàm này biến Instance thành Group nếu cần
      def self.ensure_group(entity)
        if entity.is_a?(Sketchup::ComponentInstance)
          # Make unique trước khi xử lý
          entity.make_unique
          
          # Đổi thành Group để boolean
          model = Sketchup.active_model
          grp = model.active_entities.add_group(entity)
          # Explode the inner instance to make the outer group a solid
          exp = entity.explode
          return grp
        end
        entity
      end

      # ─── HÀM TOÁN HỌC ──────────────────────────────────────────────────
      def self.polygon_centroid(pts)
        sum = pts.inject(Geom::Vector3d.new(0,0,0)) { |a,p| a + Geom::Vector3d.new(p.x, p.y, p.z) }
        Geom::Point3d.new(sum.x / pts.size, sum.y / pts.size, sum.z / pts.size)
      end

      def self.polygon_area_3d(pts)
        return 0 if pts.size < 3
        # Lấy một điểm gốc để tính diện tích tam giác
        origin = pts[0]
        area_vec = Geom::Vector3d.new(0,0,0)
        (1...pts.size-1).each do |i|
          v1 = origin.vector_to(pts[i])
          v2 = origin.vector_to(pts[i+1])
          area_vec = area_vec + v1.cross(v2)
        end
        area_vec.length / 2.0
      end
    end
  end
end
