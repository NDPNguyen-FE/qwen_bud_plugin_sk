# encoding: UTF-8
# =============================================================================
# CabinetBuilderTool - Engine xây tủ base theo kết cấu thi công thực tế (Bản chuẩn 4 hướng Thụt vào)
#
# Quy tắc kết cấu:
#   - Vách hông: chạy toàn bộ chiều cao thân (body_h = H - tkh), full depth
#   - Sàn/Nóc: KẸP GIỮA 2 vách hông → lx = W - 2t
#   - Vách hậu: KẸP trong sàn-nóc, giữa 2 vách hông → lx = W-2t, lz = body_h-2t
#   - Đà chân: hộp khung 4 thanh (trước, sau, trái, phải) bên dưới thân tủ
#   - Kệ: nhỏ hơn 1mm/bên so với inner_w để điều chỉnh được
#   - Cánh: kích thước thực theo hệ 4 khe hở (Gap)
# =============================================================================
module PanelPlugin
  module Tools
    module CabinetBuilderTool

      def self.run
        PanelPlugin::UI::CabinetBuilderPanel.show
      end

      def self.build(config, target_cabinet_id = nil)
        cfg = default_config.merge(config)
        validate!(cfg)

        PanelCore::UndoWrapper.run("Xây tủ base: #{cfg[:name]}") do
          _do_build(cfg, target_cabinet_id)
        end
      end

      # Trả về danh sách panel specs (dùng cho BOM table ở JS)
      def self.panel_specs(config)
        cfg = default_config.merge(config)
        validate!(cfg)
        _build_specs(cfg)
      rescue => e
        []
      end

      private

      def self.default_config
        {
          width: 600, depth: 560, height: 820,
          thickness: 18, back_thickness: 9,
          toe_kick_height: 0, toe_kick_depth: 0,
          floor_raise: 0,
          back_groove_depth: 8, back_groove_offset: 18,
          has_top: true, has_back: true,
          style: :open, 
          door_gap_top: 2, door_gap_bot: 2,
          door_gap_l: 2, door_gap_r: 2,
          num_doors: 1,
          position: ORIGIN, name: 'Tủ Base'
        }
      end

      def self.validate!(cfg)
        raise ArgumentError, 'Rộng phải >= 200mm' if cfg[:width].to_f < 200
        raise ArgumentError, 'Sâu phải >= 200mm'  if cfg[:depth].to_f < 200
        raise ArgumentError, 'Cao phải >= 300mm'  if cfg[:height].to_f < 300
        raise ArgumentError, 'Độ dày >= 9mm'      if cfg[:thickness].to_f < 9
      end

      # =========================================================================
      # Core: Sử dụng Cabinet::Core::Builder để xây dựng tủ (Refactored)
      # =========================================================================
      def self._do_build(cfg, target_cabinet_id = nil)
        # Sử dụng Builder mới đã refactor
        builder = PanelCore::Cabinet::Core::Builder.new(
          width: cfg[:width],
          height: cfg[:height],
          depth: cfg[:depth],
          thickness: cfg[:thickness]
        )
        
        cabinet_group = builder.build
        
        # Cập nhật metadata bổ sung từ config (sử dụng ABF Schema)
        PanelCore::ABF.set_cabinet_attribute(cabinet_group, :cabinet_name, cfg[:name])
        PanelCore::ABF.set_cabinet_attribute(cabinet_group, :style, cfg[:style].to_s)
        PanelCore::ABF.set_cabinet_attribute(cabinet_group, :has_back, cfg[:has_back])
        PanelCore::ABF.set_cabinet_attribute(cabinet_group, :has_top, cfg[:has_top])
        PanelCore::ABF.set_cabinet_attribute(cabinet_group, :door_gap_top, cfg[:door_gap_top])
        PanelCore::ABF.set_cabinet_attribute(cabinet_group, :door_gap_bot, cfg[:door_gap_bot])
        PanelCore::ABF.set_cabinet_attribute(cabinet_group, :door_gap_l, cfg[:door_gap_l])
        PanelCore::ABF.set_cabinet_attribute(cabinet_group, :door_gap_r, cfg[:door_gap_r])
        PanelCore::ABF.set_cabinet_attribute(cabinet_group, :num_doors, cfg[:num_doors])
        PanelCore::ABF.set_cabinet_attribute(cabinet_group, :toe_kick_height, cfg[:toe_kick_height])
        PanelCore::ABF.set_cabinet_attribute(cabinet_group, :toe_kick_depth, cfg[:toe_kick_depth])
        PanelCore::ABF.set_cabinet_attribute(cabinet_group, :floor_raise, cfg[:floor_raise])
        PanelCore::ABF.set_cabinet_attribute(cabinet_group, :back_groove_depth, cfg[:back_groove_depth])
        PanelCore::ABF.set_cabinet_attribute(cabinet_group, :back_groove_offset, cfg[:back_groove_offset])
        
        cabinet_group
      end

      # =========================================================================
      # Core: tính toán tất cả specs theo kết cấu thi công (Giữ cho BOM)
      # =========================================================================
      def self._build_specs(cfg)
        w   = cfg[:width].to_f
        d   = cfg[:depth].to_f
        h   = cfg[:height].to_f
        t   = cfg[:thickness].to_f
        bt  = cfg[:back_thickness].to_f
        tkh = cfg[:toe_kick_height].to_f
        tkd = cfg[:toe_kick_depth].to_f
        bgd = cfg[:back_groove_depth].to_f
        bgo = cfg[:back_groove_offset].to_f
        gT = cfg[:door_gap_top].to_f
        gB = cfg[:door_gap_bot].to_f
        gL = cfg[:door_gap_l].to_f
        gR = cfg[:door_gap_r].to_f
        ndr = cfg[:num_doors].to_i
        fr  = cfg[:floor_raise].to_f

        # ── Kích thước dẫn xuất ─────────────────────────────────────────────
        body_h  = h - tkh           # chiều cao thân tủ
        inner_w = w - 2 * t         # khoảng sáng trong ngang
        # inner_h tính từ mặt sàn tới mặt dưới nóc
        inner_h = body_h - 2 * t - fr    # khoảng sáng trong đứng
        
        # Vách hậu lùi vào bgo. Để vách hậu có thể vặn lùa (groove) vào Sàn/Nóc,
        # Sàn và Nóc phải chạy sâu suốt tủ tới sát hông kích thước tối đa.
        panel_d = d                 # sàn/nóc chạy full sâu
        tk_span = d - bgo - bt - tkd - t

        specs = []
        seq = 0
        add = lambda { |s| seq += 1; specs << s.merge(seq: seq) }

        # ── 1. Khung đà chân (lắp đầu tiên, tạo đế) ─────────────────────────
        if tkh > 0
          # Đà ngang sau (lắp trước để định vị)
          add.call({
            name: 'Đà ngang sau (đà chân)',
            role: :toe_kick_rail,
            assembly_note: 'Lắp đầu tiên, tạo mốc căn chỉnh phía sau',
            lx: inner_w, ly: t, lz: tkh,
            tx: t, ty: d - bgo - bt - t, tz: 0,
            grain: 'ngang', qty: 1,
            edge: { top: true, front: false, back: false, bot: false },
            connect: 'Vít 4×40 vào vách hông x2 mỗi đầu'
          })

          # Đà ngang trước
          add.call({
            name: 'Đà ngang trước (đà chân)',
            role: :toe_kick_rail,
            assembly_note: "Lùi vào #{tkd.to_i}mm so với mặt trước tủ",
            lx: inner_w, ly: t, lz: tkh,
            tx: t, ty: tkd, tz: 0,
            grain: 'ngang', qty: 1,
            edge: { top: true, front: true, back: false, bot: false },
            connect: 'Vít 4×40 vào vách hông x2 mỗi đầu'
          })

          # Đà dọc trái chân (nối 2 đà ngang)
          if tk_span > 50
            add.call({
              name: 'Đà dọc trái (đà chân)',
              role: :toe_kick_rail,
              lx: t, ly: tk_span, lz: tkh,
              tx: t, ty: tkd + t, tz: 0,
              grain: 'dọc', qty: 1,
              edge: { top: true, front: false, back: false, bot: false },
              connect: 'Vít 4×40 vào đà ngang'
            })

            add.call({
              name: 'Đà dọc phải (đà chân)',
              role: :toe_kick_rail,
              lx: t, ly: tk_span, lz: tkh,
              tx: w - 2 * t, ty: tkd + t, tz: 0,
              grain: 'dọc', qty: 1,
              edge: { top: true, front: false, back: false, bot: false },
              connect: 'Vít 4×40 vào đà ngang'
            })
          end
        end

        # ── 2. Sàn tủ (nâng lên tkh + floor_raise) ─────────────────────────
        add.call({
          name: 'Sàn tủ',
          role: :floor,
          lx: inner_w, ly: panel_d, lz: t,
          tx: t, ty: 0, tz: tkh + fr,
          grain: 'ngang', qty: 1,
          edge: { top: false, front: true, back: false, bot: false },
          connect: 'Cam lock (minifix) Ø15 x2 mỗi bên'
        })

        # ── 3. Vách hông (lắp sau sàn) ───────────────────────────────────────
        add.call({
          name: 'Vách hông trái',
          role: :side,
          lx: t, ly: d, lz: body_h,
          tx: 0, ty: 0, tz: tkh,
          grain: 'dọc', qty: 1,
          edge: { top: true, front: true, back: false, bot: false },
          connect: 'Cam lock x4 x2 sàn, x2 nóc'
        })

        add.call({
          name: 'Vách hông phải',
          role: :side,
          lx: t, ly: d, lz: body_h,
          tx: w - t, ty: 0, tz: tkh,
          grain: 'dọc', qty: 1,
          edge: { top: true, front: true, back: false, bot: false },
          connect: 'Cam lock x4 x2 sàn, x2 nóc'
        })

        # ── 4. Vách hậu (lùa rãnh vào vách hông và sàn-nóc) ───────────────────
        if cfg[:has_back]
          back_h = cfg[:has_top] ? inner_h : (body_h - t - fr)
          b_lx = inner_w + 2 * bgd
          b_lz = back_h  + (cfg[:has_top] ? 2 * bgd : bgd)
          
          b_tx = t - bgd
          b_tz = tkh + t + fr - bgd
          b_ty = d - bgo - bt

          add.call({
            name: 'Back_Panel',
            role: :back,
            lx: b_lx, ly: bt, lz: b_lz,
            tx: b_tx, ty: b_ty, tz: b_tz,
            grain: 'none', qty: 1,
            edge: { top: false, front: false, back: false, bot: false },
            connect: "Grooved into side panels & floor. Depth: #{bgd}mm"
          })
        end

        # ── 5. Nóc tủ (nếu có) ───────────────────────────────────────────────
        if cfg[:has_top]
          add.call({
            name: 'Nóc tủ',
            role: :top,
            lx: inner_w, ly: panel_d, lz: t,
            tx: t, ty: 0, tz: h - t,
            grain: 'ngang', qty: 1,
            edge: { top: false, front: true, back: false, bot: false },
            connect: 'Cam lock (minifix) Ø15 x2 mỗi bên'
          })
        end

        # ── 6. Cánh / Mặt ngăn kéo ───────────────────────────────────────────
        case cfg[:style]
        when :single_door, :double_door, :doors
          ndr = cfg[:num_doors].to_i
          # Logic ép số lượng cánh nếu chọn button cụ thể
          ndr = 1 if cfg[:style] == :single_door
          ndr = 2 if cfg[:style] == :double_door
          ndr = 3 if cfg[:style] == :doors && ndr < 3
          
          # H = Body Height. Door Height = H - gT - gB
          door_h = body_h - gT - gB
          gap_between = 2.0 # khoảng hở kỹ thuật giữa các cánh
          
          # Tổng độ rộng cánh khả dụng = W - gL - gR - (n-1)*2mm
          total_w = w - gL - gR - (ndr - 1) * gap_between
          dw = total_w / ndr.to_f
          
          ndr.times do |i|
            tx = gL + i * (dw + gap_between)
            add.call({
              name: "Door_#{sprintf('%02d', i + 1)}",
              role: :door,
              assembly_note: "Cánh thứ #{i+1}/#{ndr}. Thụt vào T:#{gT} D:#{gB} L:#{gL} R:#{gR}",
              lx: dw, ly: t, lz: door_h,
              tx: tx, ty: -t, tz: tkh + gB,
              grain: 'dọc', qty: 1,
              edge: { top: true, front: true, back: true, bot: true },
              connect: 'Bản lề âm Blum 110°'
            })
          end

        when :drawers
          # Sơ đồ 3 ngăn kéo cơ bản, dùng gap thụt vào như cánh
          gap = 2.0
          num_d = 3
          dbox_h = (body_h - gT - gB - (num_d-1)*gap) / num_d.to_f
          
          num_d.times do |i|
            dz = tkh + gB + i * (dbox_h + gap)
            add.call({
              name: "Mặt ngăn kéo #{i + 1}",
              role: :drawer_face,
              assembly_note: "Ngăn kéo #{i+1}/#{num_d}. Gắn ray Tandem hoặc Grass 35kg.",
              lx: w - gL - gR, ly: t, lz: dbox_h,
              tx: gL, ty: -t, tz: dz,
              grain: 'ngang', qty: 1,
              edge: { top: true, front: true, back: true, bot: true },
              connect: 'Vít 3×16 từ trong hộp ngăn kéo ra mặt'
            })
          end
        end

        specs
      end

      # =========================================================================
      # Tạo groups trong SketchUp từ specs
      # =========================================================================
      def self._do_build(cfg, target_cabinet_id = nil)
        model    = Sketchup.active_model
        entities = model.active_entities
        pos = cfg[:position] || ORIGIN
        cabinet_id = target_cabinet_id || "cab_#{Time.now.to_i}_#{rand(1000)}"

        specs = _build_specs(cfg)
        
        # Nếu đang edit, xóa các tấm ván cũ của tủ này
        if target_cabinet_id
          old_panels = entities.grep(Sketchup::Group).select do |g|
            g.attribute_dictionary('panel_cabinet') && 
            g.get_attribute('panel_cabinet', 'cabinet_id') == target_cabinet_id
          end
          
          # Tự động lấy vị trí tủ cũ nếu người dùng chưa truyền pos
          if !old_panels.empty? && cfg[:position].nil?
             bounds = Geom::BoundingBox.new
             old_panels.each { |p| bounds.add(p.bounds) }
             pos = Geom::Point3d.new(bounds.corner(0).x, bounds.corner(0).y, bounds.corner(0).z)
          end
          
          old_panels.each do |p| 
            p.erase! if p.valid?
          end
        end

        gT  = cfg[:door_gap_top].to_f
        gB  = cfg[:door_gap_bot].to_f
        gL  = cfg[:door_gap_l].to_f
        gR  = cfg[:door_gap_r].to_f

        c_dict_data = {
          'cabinet_type' => 'base',
          'cabinet_id'   => cabinet_id,
          'name'         => cfg[:name].to_s,
          'width_mm'     => cfg[:width].to_f,
          'depth_mm'     => cfg[:depth].to_f,
          'height_mm'    => cfg[:height].to_f,
          'thickness_mm' => cfg[:thickness].to_f,
          'back_thickness_mm' => cfg[:back_thickness].to_f,
          'back_groove_depth' => cfg[:back_groove_depth].to_f,
          'back_groove_offset' => cfg[:back_groove_offset].to_f,
          'toe_kick_height_mm' => cfg[:toe_kick_height].to_f,
          'toe_kick_depth_mm'  => cfg[:toe_kick_depth].to_f,
          'has_top'       => cfg[:has_top],
          'has_back'      => cfg[:has_back],
          'num_doors'     => cfg[:num_doors].to_i,
          'floor_raise_mm' => cfg[:floor_raise].to_f,
          'door_gap_top'  => gT,
          'door_gap_bot'  => gB,
          'door_gap_l'    => gL,
          'door_gap_r'    => gR,
          'style'         => cfg[:style].to_s,
          'panel_count'   => specs.count,
          'built_at'      => Time.now.to_i,
          'is_parametric' => true
        }

        panel_groups = []

        specs.each do |spec|
          grp = _create_panel_group(entities, spec)
          next unless grp
          
          # Gán metadata cabinet lên từng tấm
          d = grp.attribute_dictionary('panel_cabinet', true)
          c_dict_data.each { |k, v| d[k] = v }
          
          # Di chuyển về vị trí xuất phát + pos (nếu pos khác ORIGIN)
          unless pos == ORIGIN
            grp.transform!(Geom::Transformation.translation(pos - ORIGIN))
          end
          
          panel_groups << grp
        end

        panel_groups
      end

      def self._create_panel_group(entities, spec)
        lx, ly, lz = spec[:lx].to_f, spec[:ly].to_f, spec[:lz].to_f
        tx, ty, tz = spec[:tx].to_f, spec[:ty].to_f, spec[:tz].to_f

        # Bỏ qua nếu kích thước quá nhỏ gây lỗi Duplicate points
        return nil if lx < 0.1 || ly < 0.1
        
        grp  = entities.add_group
        grp.name = spec[:name]
        ents = grp.entities

        slx = PanelCore::ComponentManager.mm_to_su(lx)
        sly = PanelCore::ComponentManager.mm_to_su(ly)
        slz = PanelCore::ComponentManager.mm_to_su(lz)

        pts = [
          Geom::Point3d.new(0,  0,  0),
          Geom::Point3d.new(slx, 0,  0),
          Geom::Point3d.new(slx, sly, 0),
          Geom::Point3d.new(0,  sly, 0)
        ]
        face = ents.add_face(pts)
        face.reverse! if face.normal.z < 0
        face.pushpull(slz) if slz.abs > 0.001

        # =========================================================================
        # TÍCH HỢP ABF SCHEMA - Task 1.1: Chuẩn hóa thuộc tính cho ABF
        # =========================================================================
        # Khởi tạo đầy đủ attribute theo chuẩn ABF để sẵn sàng cho:
        # - Milestone 2: Auto-drilling & Joinery (ABF Engine sẽ đọc các field này)
        # - Milestone 4: Nesting & Anti-Fly
        # - Milestone 5: CAM Export & Barcode
        # =========================================================================
        abf_dict = PanelCore::ABF.initialize_panel_attributes(
          grp,
          role: spec[:role],
          material_code: (spec[:role] == :back) ? 'HDF_9MM' : 'MELAMINE_18MM',
          thickness: lz.to_f
        )
        
        # Cập nhật edge banding từ spec sang ABF schema (mapping logic)
        # Spec dùng :front, :top, :back, :bot => ABF dùng edge_top, edge_bottom, edge_left, edge_right
        # Cần quy ước: front/bot/top/back trong spec tương ứng với cạnh nào trong local coordinates của tấm
        if spec.dig(:edge, :front)
          abf_dict[PanelCore::ABF::EDGE_KEYS[:edge_bottom]] = true
          abf_dict[PanelCore::ABF::EDGE_KEYS[:edge_bottom_code]] = 'PVC_1MM_WHITE' # Default
        end
        if spec.dig(:edge, :top)
          abf_dict[PanelCore::ABF::EDGE_KEYS[:edge_top]] = true
          abf_dict[PanelCore::ABF::EDGE_KEYS[:edge_top_code]] = 'PVC_1MM_WHITE'
        end
        if spec.dig(:edge, :back)
          abf_dict[PanelCore::ABF::EDGE_KEYS[:edge_left]] = true
          abf_dict[PanelCore::ABF::EDGE_KEYS[:edge_left_code]] = 'PVC_1MM_WHITE'
        end
        # Cạnh phải (right) thường không dán với tủ base tiêu chuẩn

        # =========================================================================
        # GIỮ LẠI METADATA CŨ (panel_core) - Để tương thích ngược với code cũ
        # =========================================================================
        d = grp.attribute_dictionary('panel_core', true)
        d['part_name']       = spec[:name]
        d['role']            = spec[:role].to_s
        d['assembly_seq']    = spec[:seq].to_i
        d['assembly_note']   = spec[:assembly_note].to_s
        d['length_mm']       = spec[:lx].to_f   # X (chiều ngang tủ)
        d['depth_mm']        = spec[:ly].to_f   # Y (chiều sâu tủ)
        d['thickness_mm']    = spec[:lz].to_f   # Z (chiều đứng hoặc độ dày)
        d['grain_direction'] = spec[:grain].to_s
        d['edge_front']      = spec.dig(:edge, :front) || false
        d['edge_top']        = spec.dig(:edge, :top)   || false
        d['edge_back']       = spec.dig(:edge, :back)  || false
        d['edge_bot']        = spec.dig(:edge, :bot)   || false
        d['connection']      = spec[:connect].to_s
        d['material_id']     = (spec[:role] == :back) ? 'hdf_9' : 'melamine_18'
        d['quantity']        = spec[:qty].to_i
        d['is_template']     = false
        d['created_at']      = Time.now.to_i

        stx = PanelCore::ComponentManager.mm_to_su(tx)
        sty = PanelCore::ComponentManager.mm_to_su(ty)
        stz = PanelCore::ComponentManager.mm_to_su(tz)
        tr = Geom::Transformation.translation(Geom::Vector3d.new(stx, sty, stz))
        grp.transform!(tr)
        
        # =========================================================================
        # TASK 1.2: GEOMETRY CLEANING - Làm sạch hình học sau khi tạo
        # =========================================================================
        # Đảm bảo panel có hình học tối ưu, sẵn sàng cho DXF export và CNC
        # Giảm số lượng entity, xóa cạnh dư, chuẩn hóa normals
        # =========================================================================
        begin
          success = PanelCore::Geometry::Cleaner.clean!(grp)
          unless success
            puts "[CabinetBuilder] Warning: Geometry cleaning failed for #{spec[:name]} (returned false)"
          end
        rescue StandardError => e
          # Log lỗi nhưng không làm dừng quá trình tạo tủ
          puts "[CabinetBuilder] Warning: Geometry cleaning failed for #{spec[:name]}: #{e.message}"
        end
        
        grp
      end
    end
  end
end
