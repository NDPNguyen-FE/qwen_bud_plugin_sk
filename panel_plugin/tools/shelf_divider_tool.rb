# encoding: UTF-8
# =============================================================================
# ShelfDividerTool  –  Chia đợt kệ trong khoang tủ nội thất
# =============================================================================
# WORKFLOW
#   1. User activates the tool from menu / toolbar.
#   2. User double-clicks INTO a cabinet group to enter its edit context.
#   3. User clicks any internal face (floor, side-wall, back…).
#   4. Tool reads model.active_path to find the enclosing Group /
#      ComponentInstance and works ENTIRELY in its local coordinate system.
#   5. Inner bounding box is computed by scanning all face vertices in the
#      group – no raycasting, no world-space ambiguity.
#   6. inputbox asks: N shelves, shelf thickness, lateral inset each side.
#   7. Even distribution: spacing = inner_h / (N + 1)
#   8. Each shelf is a solid Group nested inside the cabinet group, tagged
#      with the same 'panel_core' AttributeDictionary as CabinetBuilderTool.
#   9. Full undo via PanelCore::UndoWrapper.run.
# =============================================================================

module PanelPlugin
  module Tools

    # =========================================================================
    # Activatable SketchUp tool class
    # =========================================================================
    class ShelfDividerTool

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
          UI.messagebox(
            "Không nhận được mặt phẳng.\n\n" \
            "Hướng dẫn: Double-click vào khoang tủ để vào edit-mode,\n" \
            "sau đó click vào một mặt phẳng bên trong."
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
        Sketchup.set_status_text(
          'Chia Đợt Kệ: click vào mặt phẳng bên trong khoang tủ  |  [Esc] Thoát',
          SB_PROMPT
        )
      end

      # ── STEP 1: entry point after a face is picked ────────────────────────
      def _process(face)
        # 1a. Find the container group/component
        container = _enclosing_container
        unless container
          UI.messagebox(
            "Không tìm thấy khoang tủ.\n\n" \
            "• Double-click vào Group/Component của tủ để vào bên trong.\n" \
            "• Kích hoạt lại tool rồi click vào mặt phẳng trong khoang."
          )
          return
        end

        # 1b. Build local-space bounding box
        inner = _compute_inner_bounds(container)
        unless inner
          UI.messagebox(
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
        result = UI.inputbox(
          [
            'Số đợt kệ (N):',
            'Độ dày đợt kệ (mm):',
            'Hụt vào mỗi bên X (mm):'
          ],
          [3, 18, 1],
          "Chia Đợt Kệ  –  W=#{w_mm}  D=#{d_mm}  H=#{h_mm} mm"
        )
        return unless result

        n          = result[0].to_i
        shelf_t_mm = result[1].to_f
        inset_mm   = result[2].to_f

        # 1d. Validate
        return unless _validate(n, shelf_t_mm, inset_mm, inner_w_su, inner_d_su, inner_h_su)

        # 1e. Create shelves inside an undo operation
        PanelCore::UndoWrapper.run("Chia #{n} đợt kệ") do
          _create_shelves(container, inner, n, shelf_t_mm, inset_mm)
        end
      end

      # ── STEP 2: resolve the host container from the active edit context ───
      # model.active_path is the array of entities the user has entered via
      # double-click.  We walk it from deepest inward to find the first
      # Group or ComponentInstance.
      def _enclosing_container
        path = Sketchup.active_model.active_path
        return nil if path.nil? || path.empty?

        path.reverse_each do |e|
          return e if e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        end
        nil
      end

      # ── STEP 3: compute bounding box in LOCAL coordinates ─────────────────
      # Scans all face vertices inside the container (including one level of
      # nested child groups, e.g. individual cabinet panels).
      # All coordinates are in SketchUp's internal units (inches).
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
            # Direct faces in the container (rare for a cabinet built with panels)
            e.vertices.each { |v| all_pts << v.position }

          when Sketchup::Group, Sketchup::ComponentInstance
            # Child panel group – transform its vertices into parent local space
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
      def _validate(n, shelf_t_mm, inset_mm, inner_w_su, inner_d_su, inner_h_su)
        inner_w_mm = _su2mm(inner_w_su)
        inner_d_mm = _su2mm(inner_d_su)
        inner_h_mm = _su2mm(inner_h_su)

        if n <= 0
          UI.messagebox('Số đợt kệ phải lớn hơn 0.')
          return false
        end

        if n > 50
          UI.messagebox('Số đợt kệ không được vượt quá 50.')
          return false
        end

        if shelf_t_mm < 3.0
          UI.messagebox('Độ dày đợt kệ phải >= 3 mm.')
          return false
        end

        if inset_mm < 0
          UI.messagebox('Hụt vào không được âm.')
          return false
        end

        net_w = inner_w_mm - 2 * inset_mm
        if net_w < 50.0
          UI.messagebox(
            "Chiều rộng hữu dụng sau khi trừ hụt quá nhỏ: #{net_w.round(1)} mm.\n" \
            "Giảm giá trị 'Hụt vào mỗi bên'."
          )
          return false
        end

        if inner_d_mm < 50.0
          UI.messagebox("Chiều sâu khoang quá nhỏ: #{inner_d_mm.round(1)} mm.")
          return false
        end

        # Minimum clear gap between consecutive shelves (below and above each shelf)
        spacing_mm     = inner_h_mm / (n + 1).to_f
        clear_gap_mm   = spacing_mm - shelf_t_mm
        min_gap_mm     = 30.0

        if clear_gap_mm < min_gap_mm
          UI.messagebox(
            "Không đủ khoảng hở giữa các đợt kệ!\n\n" \
            "  Khoảng hở thực tế: #{clear_gap_mm.round(1)} mm\n" \
            "  Tối thiểu yêu cầu: #{min_gap_mm} mm\n\n" \
            "Hãy giảm số đợt kệ hoặc giảm độ dày đợt."
          )
          return false
        end

        true
      end

      # ── STEP 5: generate the shelf solid-groups ───────────────────────────
      def _create_shelves(container, inner, n, shelf_t_mm, inset_mm)
        ents = case container
               when Sketchup::Group             then container.entities
               when Sketchup::ComponentInstance then container.definition.entities
               end

        # Convert dimensions to SketchUp internal units
        shelf_t_su = _mm2su(shelf_t_mm)
        inset_su   = _mm2su(inset_mm)

        inner_h_su = inner[:max_z] - inner[:min_z]
        spacing_su = inner_h_su / (n + 1).to_f

        # Shelf width spans the inner X minus lateral inset on each side
        x0 = inner[:min_x] + inset_su
        x1 = inner[:max_x] - inset_su
        y0 = inner[:min_y]
        y1 = inner[:max_y]

        shelf_w_su = x1 - x0
        shelf_d_su = y1 - y0

        shelf_w_mm = _su2mm(shelf_w_su).round(1)
        shelf_d_mm = _su2mm(shelf_d_su).round(1)

        n.times do |i|
          idx      = i + 1
          z_bottom = inner[:min_z] + idx * spacing_su   # bottom face of this shelf
          height_from_floor_mm = _su2mm(idx * spacing_su).round(1)

          # --- Create group for this shelf ---
          grp  = ents.add_group
          grp.name = format('Shelf_%02d', idx)
          g    = grp.entities

          # Build the box: base face on local Z=0, push up by shelf_t_su
          pts = [
            Geom::Point3d.new(0,          0,          0),
            Geom::Point3d.new(shelf_w_su, 0,          0),
            Geom::Point3d.new(shelf_w_su, shelf_d_su, 0),
            Geom::Point3d.new(0,          shelf_d_su, 0)
          ]
          face = g.add_face(pts)
          face.reverse! if face.normal.z < 0
          face.pushpull(shelf_t_su)

          # Move the group into position (bottom-left-front = x0, y0, z_bottom)
          grp.transform!(
            Geom::Transformation.translation(Geom::Vector3d.new(x0, y0, z_bottom))
          )

          # --- Write panel_core metadata (same schema as CabinetBuilderTool) ---
          d = grp.attribute_dictionary('panel_core', true)
          d['part_name']       = grp.name
          d['role']            = 'shelf'
          d['assembly_seq']    = idx
          d['assembly_note']   = "Đợt #{idx}/#{n}. Cách đáy #{height_from_floor_mm} mm"
          d['length_mm']       = shelf_w_mm      # X = width across cabinet
          d['depth_mm']        = shelf_d_mm      # Y = depth into cabinet
          d['thickness_mm']    = shelf_t_mm      # Z = panel thickness
          d['grain_direction'] = 'ngang'
          d['edge_front']      = true
          d['edge_top']        = false
          d['edge_back']       = false
          d['edge_bot']        = false
          d['connection']      = 'Cam lock (minifix) Ø15 x2 mỗi đầu'
          d['material_id']     = 'melamine_18'
          d['quantity']        = 1
          d['is_template']     = false
          d['created_at']      = Time.now.to_i
        end

        # Success feedback
        spacing_mm = _su2mm(spacing_su).round(1)
        UI.messagebox(
          "✅ Đã tạo #{n} đợt kệ thành công!\n\n" \
          "  Kích thước đợt: #{shelf_w_mm} × #{shelf_d_mm} × #{shelf_t_mm} mm\n" \
          "  Khoảng cách (tâm – tâm): #{spacing_mm} mm\n" \
          "  Tổng hụt mỗi bên: #{inset_mm} mm"
        )
      end

      # ── Unit helpers ──────────────────────────────────────────────────────
      def _mm2su(mm)
        PanelCore::ComponentManager.mm_to_su(mm)
      end

      def _su2mm(su)
        PanelCore::ComponentManager.su_to_mm(su)
      end

    end # class ShelfDividerTool

  end # module Tools
end # module PanelPlugin
