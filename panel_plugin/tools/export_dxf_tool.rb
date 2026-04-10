# encoding: UTF-8
# =============================================================================
# ExportDxfTool — Xuất DXF chuẩn ABF từ Component panel
# Tương thích: ABF Nesting (AC1015, LWPOLYLINE, Layer CUT/GROOVE)
# =============================================================================
module PanelPlugin
  module Tools
    module ExportDxfTool

      INCH_TO_MM = 25.4

      def self.run
        model = Sketchup.active_model
        sel   = model.selection.to_a
        comps = sel.select { |e| e.is_a?(Sketchup::ComponentInstance) && e.name.to_s.start_with?('CNC_') }

        if comps.empty?
          Sketchup.messagebox("Vui lòng chọn ít nhất 1 Component CNC_ để xuất DXF.")
          return
        end

        out_dir = ::UI.select_directory(title: "Chọn thư mục xuất DXF")
        return unless out_dir

        results = []
        comps.each do |comp|
          path = File.join(out_dir, "#{comp.name}.dxf")
          begin
            export_component(comp, path)
            results << "✓ #{comp.name} → #{File.basename(path)}"
          rescue => e
            results << "✗ #{comp.name}: #{e.message}"
          end
        end

        Sketchup.messagebox("Xuất DXF hoàn tất:\n\n#{results.join("\n")}")
      end

      def self.export_component(comp, path)
        defn   = comp.definition
        ents   = defn.entities

        # Thu thập face outline (lớn nhất)
        faces = ents.grep(Sketchup::Face)
        raise "Không tìm thấy Face trong #{comp.name}" if faces.empty?

        main_face = faces.max_by { |f| f.area }

        # Outline từ outer loop
        outline_pts = main_face.outer_loop.vertices.map do |v|
          [v.position.x * INCH_TO_MM, v.position.z * INCH_TO_MM]
        end

        # Thu thập groove edges (layer ABF_SCORING hoặc ABF_POCKET)
        groove_edges = ents.grep(Sketchup::Edge).select do |e|
          ln = e.layer.name
          ln.start_with?('ABF_SCORING') || ln.start_with?('ABF_POCKET') ||
          ln.start_with?('ABF_SeRanh')  || ln.start_with?('ABF_Scoring')
        end

        groove_lines = groove_edges.map do |e|
          {
            x1: e.start.position.x * INCH_TO_MM,
            y1: e.start.position.z * INCH_TO_MM,
            x2: e.end.position.x   * INCH_TO_MM,
            y2: e.end.position.z   * INCH_TO_MM
          }
        end

        write_dxf(path, comp.name, outline_pts, groove_lines)
      end

      # -----------------------------------------------------------------------
      # DXF WRITER (ABF-compatible: AC1015, mm units)
      # -----------------------------------------------------------------------
      def self.write_dxf(path, part_name, outline_pts, groove_lines)
        lines = []

        # HEADER
        lines += [
          '  0','SECTION','  2','HEADER',
          '  9','$ACADVER','  1','AC1015',
          '  9','$INSUNITS',' 70','4',
          '  9','$MEASUREMENT',' 70','1',
          '  0','ENDSEC'
        ]

        # TABLES
        lines += [
          '  0','SECTION','  2','TABLES',
          '  0','TABLE','  2','LAYER',' 70','3',
          '  0','LAYER','  2','CUT',   ' 70','0',' 62','1','  6','Continuous','370','50',
          '  0','LAYER','  2','GROOVE',' 70','0',' 62','5','  6','Continuous','370','25',
          '  0','LAYER','  2','MARK',  ' 70','0',' 62','2','  6','Continuous','370','13',
          '  0','ENDTAB','  0','ENDSEC'
        ]

        # BLOCKS
        lines += ['  0','SECTION','  2','BLOCKS','  0','ENDSEC']

        # ENTITIES
        lines += ['  0','SECTION','  2','ENTITIES']

        # Outline → LWPOLYLINE closed
        clean = outline_pts.dup
        clean.pop if clean.size > 1 && clean.first == clean.last
        lines += ['  0','LWPOLYLINE','  8','CUT',' 90',clean.size.to_s,' 70','1',' 43','0.0']
        clean.each { |pt| lines += [' 10', fmt(pt[0]), ' 20', fmt(pt[1])] }

        # Groove lines
        groove_lines.each do |g|
          lines += ['  0','LINE','  8','GROOVE',
                    ' 10',fmt(g[:x1]),' 20',fmt(g[:y1]),' 30','0.0',
                    ' 11',fmt(g[:x2]),' 21',fmt(g[:y2]),' 31','0.0']
        end

        # Mark text
        if outline_pts.any?
          max_y = outline_pts.map { |p| p[1] }.max.to_f
          lines += ['  0','TEXT','  8','MARK',
                    ' 10',fmt(2.0),' 20',fmt(max_y + 5.0),' 30','0.0',
                    ' 40','3.5','  1',"#{part_name} | #{groove_lines.size} Grooves"]
        end

        lines += ['  0','ENDSEC','  0','EOF']

        File.open(path, 'w', encoding: 'UTF-8') { |f| f.puts lines.join("\n") }
      end

      def self.fmt(v)
        format('%.6f', v.to_f)
      end

    end  # module ExportDxfTool
  end  # module Tools
end  # module PanelPlugin
