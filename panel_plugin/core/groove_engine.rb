# encoding: UTF-8
# =============================================================================
# GrooveEngine — Core tính toán rãnh xẻ uốn cong
# Port từ GrooveBend plugin, tích hợp vào PanelPlugin namespace
# Không phụ thuộc SketchUp API — chỉ Ruby thuần
# =============================================================================
module PanelPlugin
  module Core
    module GrooveEngine

      INCH_TO_MM = 25.4
      MM_TO_INCH = 1.0 / 25.4

      # -----------------------------------------------------------------------
      # MATERIAL PRESETS
      # -----------------------------------------------------------------------
      MATERIAL_PRESETS = {
        'MDF 18mm'    => { thickness: 18.0, kerf_width: 3.2, min_remain: 2.5, k_factor: 0.38 },
        'MDF 25mm'    => { thickness: 25.0, kerf_width: 3.5, min_remain: 3.0, k_factor: 0.40 },
        'Plywood 12mm'=> { thickness: 12.0, kerf_width: 3.0, min_remain: 2.0, k_factor: 0.35 },
        'Plywood 18mm'=> { thickness: 18.0, kerf_width: 3.2, min_remain: 2.5, k_factor: 0.38 },
        'HDF 6mm'     => { thickness: 6.0,  kerf_width: 2.5, min_remain: 1.5, k_factor: 0.33 },
        'Thủ Công'    => { thickness: 18.0, kerf_width: 4.0, min_remain: 2.0, k_factor: 0.38 },
      }.freeze

      def self.preset_names
        MATERIAL_PRESETS.keys
      end

      def self.preset(name)
        MATERIAL_PRESETS[name] || MATERIAL_PRESETS['MDF 18mm']
      end

      # -----------------------------------------------------------------------
      # MODULE 1: PHÂN TÍCH HÌNH HỌC — fit bán kính + góc từ các Face SU
      # -----------------------------------------------------------------------
      module GeometryAnalyzer

        # @param faces [Array<Sketchup::Face>]
        # @return [Hash] { radius_mm, angle_deg, arc_length_mm, direction } hoặc nil
        def self.analyze(faces)
          return nil if faces.empty?

          boundary = extract_boundary(faces)
          pts      = sample_pts(boundary, 30)
          return nil if pts.size < 3

          cx, cy, r_su = fit_circle(pts)

          angle_rad = arc_angle(pts, cx, cy)
          angle_deg = angle_rad * 180.0 / Math::PI
          r_mm      = r_su * INCH_TO_MM
          arc_mm    = r_mm * angle_rad

          normal    = faces.first.normal
          direction = normal.z.abs > 0.7 ? :horizontal : :vertical

          {
            radius_mm:     r_mm.round(3),
            angle_deg:     angle_deg.round(3),
            arc_length_mm: arc_mm.round(3),
            direction:     direction,
            center_su:     Geom::Point3d.new(cx, cy, 0)
          }
        rescue => e
          puts "[GrooveEngine] GeometryAnalyzer error: #{e.message}"
          nil
        end

        def self.extract_boundary(faces)
          cnt = Hash.new(0)
          faces.each { |f| f.edges.each { |e| cnt[e] += 1 } }
          cnt.select { |_, v| v == 1 }.keys
        end

        def self.sample_pts(edges, total)
          pts = []
          return pts if edges.empty?
          ps = [total / edges.size, 2].max
          edges.each do |e|
            (0..ps).each do |i|
              t = i.to_f / ps
              v = e.end.position - e.start.position
              pts << e.start.position.offset(v, t * v.length)
            end
          end
          pts.uniq { |p| [p.x.round(8), p.y.round(8)] }
        end

        # Least-Squares Circle Fit (Bookstein method)
        def self.fit_circle(pts)
          n  = pts.size.to_f
          sx = pts.sum(&:x);   sy  = pts.sum(&:y)
          sx2= pts.sum { |p| p.x**2 }; sy2= pts.sum { |p| p.y**2 }
          sxy= pts.sum { |p| p.x * p.y }
          sx3= pts.sum { |p| p.x**3 }; sy3= pts.sum { |p| p.y**3 }
          sxy2=pts.sum { |p| p.x * p.y**2 }
          sx2y=pts.sum { |p| p.x**2 * p.y }

          a = n*sx2 - sx*sx
          b = n*sxy - sx*sy
          c = n*sy2 - sy*sy
          d = 0.5*(n*(sx3+sxy2) - sx*(sx2+sy2))
          e2= 0.5*(n*(sx2y+sy3) - sy*(sx2+sy2))

          den = (a*c - b*b)
          return [0.0, 0.0, 1.0] if den.abs < 1e-12

          cx = (d*c - b*e2) / den
          cy = (a*e2 - b*d) / den
          r  = Math.sqrt((sx2 - 2*cx*sx + n*cx**2 + sy2 - 2*cy*sy + n*cy**2) / n)
          [cx, cy, r]
        end

        def self.arc_angle(pts, cx, cy)
          angles = pts.map { |p| Math.atan2(p.y - cy, p.x - cx) }
          mn, mx = angles.minmax
          delta  = mx - mn
          delta < Math::PI ? delta : (2*Math::PI - delta)
        end
      end

      # -----------------------------------------------------------------------
      # MODULE 2: TÍNH THÔNG SỐ RÃNH XẺ
      # -----------------------------------------------------------------------
      module GrooveCalculator

        # @param arc_length_mm [Float] chiều dài cung (mm)
        # @param radius_mm     [Float] bán kính cong (mm)
        # @param angle_deg     [Float] góc uốn (độ)
        # @param material      [Hash]  preset vật liệu
        # @param opts          [Hash]  { spacing_mm, cut_depth_mm }
        # @return [Hash] đầy đủ thông số
        def self.calculate(arc_length_mm, radius_mm, angle_deg, material, opts = {})
          t         = material[:thickness].to_f
          kerf_w    = material[:kerf_width].to_f
          t_remain  = material[:min_remain].to_f
          k_factor  = material[:k_factor].to_f
          angle_rad = angle_deg * Math::PI / 180.0

          # Chiều sâu rãnh
          cut_depth = opts[:cut_depth_mm] ? opts[:cut_depth_mm].to_f : (t - t_remain)
          cut_depth = [cut_depth, 0.5].max

          # Bend allowance (chiều dài trung hoà)
          neutral_r  = radius_mm + k_factor * t
          bend_allow = neutral_r * angle_rad

          # Setback (phần phẳng hai đầu)
          setback = (angle_rad > 0.01) ? radius_mm * Math.tan(angle_rad / 2.0) : 0.0

          # Bước tối thiểu giữa các rãnh
          d_min = opts[:spacing_mm]&.to_f || calc_d_min(radius_mm, t, angle_deg)
          d_min = [d_min, kerf_w + 1.0].max

          # Số rãnh
          usable = [arc_length_mm - 2 * [d_min * 0.5, 5.0].max, 0.0].max
          n      = [[(usable / d_min).floor, 2].max, 200].min

          # Bước thực tế
          d_actual = n > 0 ? (arc_length_mm / n.to_f) : d_min

          # Cảnh báo
          bendable = radius_mm >= t * 2.0

          {
            n_grooves:        n,
            d_actual_mm:      d_actual.round(4),
            d_min_mm:         d_min.round(4),
            kerf_width_mm:    kerf_w,
            cut_depth_mm:     cut_depth.round(4),
            t_remain_mm:      (t - cut_depth).round(4),
            bend_allowance_mm: bend_allow.round(4),
            setback_mm:       setback.round(4),
            edge_margin_mm:   [d_actual * 0.5, 5.0].max.round(4),
            neutral_radius_mm: neutral_r.round(4),
            bendable:         bendable,
            radius_mm:        radius_mm,
            angle_deg:        angle_deg,
            arc_length_mm:    arc_length_mm,
            k_factor:         k_factor
          }
        end

        def self.calc_d_min(r_mm, t_mm, angle_deg)
          base     = t_mm * 1.2
          r_factor = [r_mm / (t_mm * 5.0), 0.4].max
          a_factor = [angle_deg / 180.0, 0.5].max
          (base * r_factor / a_factor).clamp(4.0, 30.0)
        end
      end

      # -----------------------------------------------------------------------
      # MODULE 3: KERF COMPENSATION (bù trừ chiều rộng lưỡi)
      # -----------------------------------------------------------------------
      module KerfCompensation

        # Polygon offset (CCW winding, inward = true → thu nhỏ)
        def self.offset_polygon(pts_mm, kerf_mm, inward: true)
          offset = kerf_mm / 2.0
          offset = -offset unless inward

          clean = pts_mm.dup
          clean.pop if clean.first == clean.last
          n = clean.size
          result = []

          (0...n).each do |i|
            p0 = clean[(i - 1) % n]
            p1 = clean[i]
            p2 = clean[(i + 1) % n]

            v1 = norm([p1[0]-p0[0], p1[1]-p0[1]])
            v2 = norm([p2[0]-p1[0], p2[1]-p1[1]])
            n1 = [-v1[1], v1[0]]
            n2 = [-v2[1], v2[0]]

            bis = [n1[0]+n2[0], n1[1]+n2[1]]
            len = Math.sqrt(bis[0]**2 + bis[1]**2)

            if len < 1e-10
              result << [p1[0] + offset*n1[0], p1[1] + offset*n1[1]]
            else
              bis = [bis[0]/len, bis[1]/len]
              cos_h = (n1[0]*bis[0] + n1[1]*bis[1]).clamp(-1.0, 1.0)
              cos_h = 0.01 if cos_h.abs < 0.01
              sc = offset / cos_h
              result << [p1[0] + sc*bis[0], p1[1] + sc*bis[1]]
            end
          end

          result << result.first.dup
          result
        end

        def self.norm(v)
          len = Math.sqrt(v[0]**2 + v[1]**2)
          len < 1e-10 ? [0.0, 0.0] : [v[0]/len, v[1]/len]
        end
      end

      # -----------------------------------------------------------------------
      # MODULE 4: VALIDATOR
      # -----------------------------------------------------------------------
      module Validator

        def self.validate(groove_info, material)
          errors = []; warnings = []
          r   = groove_info[:radius_mm].to_f
          t   = material[:thickness].to_f
          n   = groove_info[:n_grooves].to_i
          tr  = groove_info[:t_remain_mm].to_f

          errors   << "Bán kính #{r.round(1)}mm < 2×t=#{(t*2).round(1)}mm → VẬT LIỆU SẼ GÃY!" if r < t * 2.0
          warnings << "Bán kính #{r.round(1)}mm hơi nhỏ, khuyến nghị ≥ #{(t*5).round(1)}mm"    if r < t * 5.0 && r >= t * 2.0
          errors   << "Thịt còn lại #{tr.round(2)}mm < 1.5mm → Nguy cơ vỡ khi uốn!"            if tr < 1.5
          warnings << "Thịt còn lại #{tr.round(2)}mm mỏng, nên ≥ 2.5mm"                         if tr < 2.5 && tr >= 1.5
          warnings << "Chỉ #{n} rãnh — góc uốn có thể không đều, nên ≥ 5 rãnh"                  if n < 3
          warnings << "#{n} rãnh — kiểm tra lại bước S"                                          if n > 150

          { valid: errors.empty?, errors: errors, warnings: warnings }
        end
      end

    end  # module GrooveEngine
  end  # module Core
end  # module PanelPlugin
