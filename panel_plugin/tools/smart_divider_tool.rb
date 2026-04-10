# encoding: UTF-8
# =============================================================================
# SmartDividerTool – Chia đợt kệ (NGANG & DỌC) trong khoang tủ nội thất
# =============================================================================
# WORKFLOW
#   1. User activates the tool from menu / toolbar.
#   2. User double-clicks INTO a cabinet group to enter its edit context.
#   3. User clicks any internal face (floor, side-wall, back…).
#   4. Tool reads model.active_path to find the enclosing Group /
#      ComponentInstance and works ENTIRELY in its local coordinate system.
#   5. Inner bounding box is computed by scanning all face vertices in the
#      group – no raycasting, no world-space ambiguity.
#   6. inputbox asks: Direction (H/V), N shelves, shelf thickness, lateral inset.
#   7. Even distribution: spacing = inner_dim / (N + 1)
#   8. Each shelf/divider is a solid Group nested inside the cabinet group, tagged
#      with ABF Schema attributes.
#   9. Full undo via PanelCore::UndoWrapper.run.
# =============================================================================

module PanelPlugin
  module Tools

    # =========================================================================
    # Activatable SketchUp tool class
    # =========================================================================
    class SmartDividerTool

      # ── Lifecycle ────────────────────────────────────────────────────────────

      def activate
        @ip         = Sketchup::InputPoint.new
        @hover_face = nil
        _update_statusbar
        Sketchup.active_model.active_view.invalidate
      end

      def deactivate(view)
        view.invalidate
      end

      def resume(view)
        _update_statusbar
        view.invalidate
      end

      def suspend(view)
        view.invalidate
      end

      # ── Mouse hover: highlight the face under the cursor ──────────────────

      def onMouseMove(_flags, x, y, view)
        @ip.pick(view, x, y)
        @hover_face = @ip.face
        view.invalidate
      end

      def draw(view)
        @ip.draw(view) if @ip.valid?

        return unless @hover_face && @hover_face.valid?

        pts = @hover_face.vertices.map(&:position)
        view.drawing_color = Sketchup::Color.new(80, 180, 255, 90)
        view.draw(GL_POLYGON, pts)
        view.drawing_color = Sketchup::Color.new(0, 120, 220, 220)
        view.line_width = 2
        view.draw(GL_LINE_LOOP, pts)
      end

      # ── Click: capture face ───────────────────────────────────────────────

      def onLButtonDown(_flags, x, y, _view)
        @ip.pick(Sketchup.active_model.active_view, x, y)
        face = @ip.face

        unless face
          ::UI.messagebox(
            "Không nhận được mặt phẳng.\n\n" \
            "Hướng dẫn: Kích hoạt tool rồi click thẳng vào một mặt phẳng " \
            "thuộc khoang trống bên trong tủ (không cần double-click)."
          )
          return
        end

        _process(face)
      end

      # ── Keyboard: Escape exits the tool ───────────────────────────────────

      def onKeyDown(key, _repeat, _flags, _view)
        Sketchup.active_model.select_tool(nil) if key == 27
      end

      # =========================================================================
      # PRIVATE  –  core logic
      # =========================================================================
      private

      def _update_statusbar
        Sketchup.status_text = 'Chia Đợt/Vách: click vào mặt phẳng bên trong khoang tủ  |  [Esc] Thoát'
      end

      # ── STEP 1: entry point after a face is picked ────────────────────────
      def _process(face)
        # 1a. Find the container group/component
        container = _enclosing_container
        unless container
          ::UI.messagebox(
            "Không tìm thấy khoang tủ.\n\n" \
            "• Double-click vào Group/Component của tủ để vào bên trong.\n" \
            "• Kích hoạt lại tool rồi click vào mặt phẳng trong khoang."
          )
          return
        end

        # 1b. Build local-space bounding box
        inner = _compute_inner_bounds(container)
        unless inner
          ::UI.messagebox(
            "Không xác định được kích thước khoang trong.\n" \
            "Hãy chắc chắn group có ít nhất các mặt phẳng (sàn, vách hông, nóc)."
          )
          return
        end

        inner_w_su = inner[:max_x] - inner[:min_x]
        inner_d_su = inner[:max_y] - inner[:min_y]
        inner_h_su = inner[:max_z] - inner[:min_z]

        w_mm = _su2mm(inner_w_su).round(1)
        d_mm = _su2mm(inner_d_su).round(1)
        h_mm = _su2mm(inner_h_su).round(1)

        # 1c. Ask user for parameters
        result = ::UI.inputbox(
          [
            'Hướng chia (H=Ngang, V=Dọc):',
            'Số lượng (N):',
            'Độ dày (mm):',
            'Hụt vào mỗi bên (mm):'
          ],
          ['H', 3, 18, 1],
          "Chia Đợt/Vách  –  W=#{w_mm}  D=#{d_mm}  H=#{h_mm} mm"
        )
        return unless result

        direction  = result[0].to_s.upcase
        n          = result[1].to_i
        thick_mm   = result[2].to_f
        inset_mm   = result[3].to_f

        # Validate direction
        unless %w[H V].include?(direction)
          ::UI.messagebox("Hướng chia phải là 'H' (ngang) hoặc 'V' (dọc).")
          return
        end

        # 1d. Validate
        return unless _validate(direction, n, thick_mm, inset_mm, inner_w_su, inner_d_su, inner_h_su)

        # 1e. Create shelves/dividers inside an undo operation
        desc = direction == 'H' ? "Chia #{n} đợt ngang" : "Chia #{n} vách dọc"
        PanelCore::UndoWrapper.run(desc) do
          _create_panels(container, inner, direction, n, thick_mm, inset_mm)
        end
      end

      # ── STEP 2: resolve the host container from the active edit context ───
      def _enclosing_container
        # Ưu tiên lấy từ instance_path của chính điểm click (không cần double-click)
        path = @ip.instance_path.to_a
        
        # Fallback: nếu bằng 1 cách nào đó nó rỗng, thử active_path
        if path.nil? || path.empty? || (path.size == 1 && path.first.is_a?(Sketchup::Face))
          active = Sketchup.active_model.active_path
          path = active.to_a if active
        end

        return nil if path.nil? || path.empty?

        path.reverse_each do |e|
          return e if e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        end
        nil
      end

      # ── STEP 3: compute bounding box in LOCAL coordinates ─────────────────
      def _compute_inner_bounds(container)
        top_ents = case container
                   when Sketchup::Group             then container.entities
                   when Sketchup::ComponentInstance then container.definition.entities
                   else return nil
                   end

        all_pts = []

        top_ents.each do |e|
          case e
          when Sketchup::Face
            e.vertices.each { |v| all_pts << v.position }

          when Sketchup::Group, Sketchup::ComponentInstance
            child_ents = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
            child_tr   = e.transformation
            child_ents.grep(Sketchup::Face).each do |f|
              f.vertices.each { |v| all_pts << v.position.transform(child_tr) }
            end
          end
        end

        return nil if all_pts.empty?

        { min_x: all_pts.map(&:x).min,  max_x: all_pts.map(&:x).max,
          min_y: all_pts.map(&:y).min,  max_y: all_pts.map(&:y).max,
          min_z: all_pts.map(&:z).min,  max_z: all_pts.map(&:z).max }
      end

      # ── STEP 4: validation rules ──────────────────────────────────────────
      def _validate(direction, n, thick_mm, inset_mm, inner_w_su, inner_d_su, inner_h_su)
        inner_w_mm = _su2mm(inner_w_su)
        inner_d_mm = _su2mm(inner_d_su)
        inner_h_mm = _su2mm(inner_h_su)

        if n <= 0
          ::UI.messagebox('Số lượng phải lớn hơn 0.')
          return false
        end

        if n > 50
          ::UI.messagebox('Số lượng không được vượt quá 50.')
          return false
        end

        if thick_mm < 3.0
          ::UI.messagebox('Độ dày phải >= 3 mm.')
          return false
        end

        if inset_mm < 0
          ::UI.messagebox('Hụt vào không được âm.')
          return false
        end

        if direction == 'H'
          # Horizontal shelves: span width, check depth
          net_w = inner_w_mm - 2 * inset_mm
          if net_w < 50.0
            ::UI.messagebox("Chiều rộng hữu dụng quá nhỏ: #{net_w.round(1)} mm.")
            return false
          end
          if inner_d_mm < 50.0
            ::UI.messagebox("Chiều sâu khoang quá nhỏ: #{inner_d_mm.round(1)} mm.")
            return false
          end
          
          spacing_mm = inner_h_mm / (n + 1).to_f
          clear_gap_mm = spacing_mm - thick_mm
          if clear_gap_mm < 30.0
            ::UI.messagebox("Không đủ khoảng hở giữa các đợt (cần >= 30mm).")
            return false
          end
        else
          # Vertical dividers: span depth, check width
          net_d = inner_d_mm - 2 * inset_mm
          if net_d < 50.0
            ::UI.messagebox("Chiều sâu hữu dụng quá nhỏ: #{net_d.round(1)} mm.")
            return false
          end
          if inner_w_mm < 50.0
            ::UI.messagebox("Chiều rộng khoang quá nhỏ: #{inner_w_mm.round(1)} mm.")
            return false
          end
          
          spacing_mm = inner_w_mm / (n + 1).to_f
          clear_gap_mm = spacing_mm - thick_mm
          if clear_gap_mm < 30.0
            ::UI.messagebox("Không đủ khoảng hở giữa các vách (cần >= 30mm).")
            return false
          end
        end

        true
      end

      # ── STEP 5: generate the panels ───────────────────────────────────────
      def _create_panels(container, inner, direction, n, thick_mm, inset_mm)
        ents = case container
               when Sketchup::Group             then container.entities
               when Sketchup::ComponentInstance then container.definition.entities
               end

        thick_su = _mm2su(thick_mm)
        inset_su = _mm2su(inset_mm)

        if direction == 'H'
          # Horizontal shelves: span X, fixed Y, stacked along Z
          spacing_su = (inner[:max_z] - inner[:min_z]) / (n + 1).to_f
          panel_len_su = (inner[:max_x] - inner[:min_x]) - 2 * inset_su
          panel_dep_su = inner[:max_y] - inner[:min_y]
          
          x0 = inner[:min_x] + inset_su
          y0 = inner[:min_y]
          
          panel_len_mm = _su2mm(panel_len_su).round(1)
          panel_dep_mm = _su2mm(panel_dep_su).round(1)

          n.times do |i|
            idx = i + 1
            z_bottom = inner[:min_z] + idx * spacing_su
            height_mm = _su2mm(idx * spacing_su).round(1)

            _create_panel_group(ents, idx, n, direction, 
                               panel_len_mm, panel_dep_mm, thick_mm,
                               x0, y0, z_bottom, panel_len_su, panel_dep_su, thick_su,
                               height_mm)
          end
        else
          # Vertical dividers: span Y, fixed X, arranged along X
          spacing_su = (inner[:max_x] - inner[:min_x]) / (n + 1).to_f
          panel_len_su = (inner[:max_y] - inner[:min_y]) - 2 * inset_su
          panel_hgt_su = inner[:max_z] - inner[:min_z]
          
          y0 = inner[:min_y] + inset_su
          z0 = inner[:min_z]
          
          panel_len_mm = _su2mm(panel_len_su).round(1)
          panel_hgt_mm = _su2mm(panel_hgt_su).round(1)

          n.times do |i|
            idx = i + 1
            x_pos = inner[:min_x] + idx * spacing_su
            dist_mm = _su2mm(idx * spacing_su).round(1)

            _create_panel_group(ents, idx, n, direction,
                               panel_hgt_mm, panel_len_mm, thick_mm,
                               x_pos, y0, z0, thick_su, panel_len_su, panel_hgt_su,
                               dist_mm)
          end
        end

        # Success feedback
        dir_text = direction == 'H' ? "đợt ngang" : "vách dọc"
        ::UI.messagebox(
          "✅ Đã tạo #{n} #{dir_text} thành công!\n\n" \
          "  Độ dày: #{thick_mm} mm\n" \
          "  Hụt vào mỗi bên: #{inset_mm} mm"
        )
      end

      # Helper to create a panel group with ABF attributes
      def _create_panel_group(ents, idx, total, direction, dim1_mm, dim2_mm, thick_mm,
                             x, y, z, len1_su, len2_su, thick_su, ref_dist_mm)
        
        grp = ents.add_group
        role = direction == 'H' ? 'shelf_horizontal' : 'divider_vertical'
        grp.name = format('%s_%02d', role, idx)
        g = grp.entities

        # Build box based on direction
        if direction == 'H'
          # Shelf: flat box, normal up
          pts = [
            Geom::Point3d.new(0, 0, 0),
            Geom::Point3d.new(len1_su, 0, 0),
            Geom::Point3d.new(len1_su, len2_su, 0),
            Geom::Point3d.new(0, len2_su, 0)
          ]
          face = g.add_face(pts)
          face.reverse! if face.normal.z < 0
          face.pushpull(thick_su)
          grp.transform!(Geom::Transformation.translation(Geom::Vector3d.new(x, y, z)))
        else
          # Divider: vertical box, normal along X
          pts = [
            Geom::Point3d.new(0, 0, 0),
            Geom::Point3d.new(0, len1_su, 0),
            Geom::Point3d.new(0, len1_su, len2_su),
            Geom::Point3d.new(0, 0, len2_su)
          ]
          face = g.add_face(pts)
          face.reverse! if face.normal.x > 0
          face.pushpull(thick_su)
          grp.transform!(Geom::Transformation.translation(Geom::Vector3d.new(x, y, z)))
        end

        # Apply ABF Schema attributes
        PanelCore::ABF.initialize_panel_attributes(grp, 
          role: role,
          material_code: 'melamine_18',
          thickness: thick_mm
        )
      end

      # ── Unit helpers ──────────────────────────────────────────────────────
      def _mm2su(mm)
        PanelCore::ComponentManager.mm_to_su(mm)
      end

      def _su2mm(su)
        PanelCore::ComponentManager.su_to_mm(su)
      end

    end # class SmartDividerTool

  end # module Tools
end # module PanelPlugin
