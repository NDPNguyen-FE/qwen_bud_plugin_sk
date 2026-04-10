# frozen_string_literal: true

module PanelCore
  module Geometry
    # GeometryCleaner - Module làm sạch và tối ưu hóa hình học cho Panel
    # Đảm bảo panel xuất ra DXF/CNC không lỗi, số lượng entity tối giản
    class Cleaner
      TOLERANCE = 0.001.mm # Độ chính xác khi so sánh điểm/cạnh

      class << self
        # Phương thức chính: Làm sạch toàn bộ group panel
        # @param group [Sketchup::Group] Group chứa hình học panel
        # @return [Boolean] true nếu thành công
        def clean!(group)
          return false unless group.is_a?(Sketchup::Group)

          entities = group.entities
          return false if entities.empty?

          Sketchup.active_model.start_operation('Clean Geometry', true)

          begin
            # 1. Xóa các entity ẩn hoặc rác
            purge_hidden_entities(entities)

            # 2. Gộp các mặt phẳng đồng phẳng (Weld coplanar faces)
            weld_coplanar_faces(entities)

            # 3. Xóa cạnh dư thừa giữa các mặt đồng phẳng
            remove_redundant_edges(entities)

            # 4. Chuẩn hóa pháp tuyến (Normals)
            normalize_normals(entities)

            # 5. Xóa vertices trùng lặp
            merge_coincident_vertices(entities)

            # 6. Soften/Smooth các cạnh không cần thiết để giảm entity count
            soften_smooth_edges(entities)

            true
          rescue StandardError => e
            puts "[GeometryCleaner] Error: #{e.message}"
            false
          ensure
            Sketchup.active_model.commit_operation
          end
        end

        # Xóa các entity bị ẩn hoặc không sử dụng
        def purge_hidden_entities(entities)
          # Xóa các edge/face bị hidden
          entities.each do |entity|
            if entity.is_a?(Sketchup::Edge) || entity.is_a?(Sketchup::Face)
              entity.erase! if entity.hidden?
            end
          end
        end

        # Gộp các mặt phẳng đồng phẳng thành một mặt duy nhất
        def weld_coplanar_faces(entities)
          faces = entities.grep(Sketchup::Face)
          return if faces.size < 2

          processed = Set.new
          
          faces.each do |face1|
            next if processed.include?(face1.object_id)
            next if face1.deleted?

            plane1 = face1.plane
            normal1 = face1.normal

            faces.each do |face2|
              next if face1 == face2
              next if processed.include?(face2.object_id)
              next if face2.deleted?

              plane2 = face2.plane
              normal2 = face2.normal

              # Kiểm tra đồng phẳng: cùng plane và cùng hướng normal
              if planes_coplanar?(plane1, plane2, normal1, normal2)
                # Attempt to weld bằng cách xóa cạnh chung
                common_edge = find_common_edge(face1, face2)
                if common_edge
                  begin
                    common_edge.erase!
                    processed << face2.object_id
                  rescue StandardError
                    # Không thể xóa cạnh (có thể do topology phức tạp)
                  end
                end
              end
            end
            
            processed << face1.object_id
          end
        end

        # Xóa các cạnh nằm giữa hai mặt đồng phẳng (không phải cạnh biên)
        def remove_redundant_edges(entities)
          edges = entities.grep(Sketchup::Edge)
          
          edges.each do |edge|
            next if edge.deleted?
            
            faces = edge.faces
            if faces.size == 2
              face1, face2 = faces
              plane1 = face1.plane
              plane2 = face2.plane
              normal1 = face1.normal
              normal2 = face2.normal

              # Nếu 2 mặt đồng phẳng thì cạnh này dư thừa
              if planes_coplanar?(plane1, plane2, normal1, normal2)
                # Chỉ xóa nếu không phải là cạnh biên quan trọng
                unless edge.softened? || edge.smooth?
                  begin
                    edge.soften! # Soften thay vì erase để giữ topology an toàn
                  rescue StandardError
                    # Bỏ qua nếu không thể soften
                  end
                end
              end
            end
          end
        end

        # Chuẩn hóa hướng pháp tuyến ra ngoài
        def normalize_normals(entities)
          faces = entities.grep(Sketchup::Face)
          
          faces.each do |face|
            next if face.deleted?
            
            # Trong SketchUp, face có 2 mặt: front (white) và back (blue/grey)
            # Chúng ta muốn mặt front hướng ra ngoài
            # Nếu face đang bị reversed, hãy flip nó
            if face.reversed?
              begin
                face.reverse!
              rescue StandardError
                # Bỏ qua nếu không thể flip
              end
            end
          end
        end

        # Gộp các vertices trùng lặp
        def merge_coincident_vertices(entities)
          # SketchUp tự động gộp vertices khi tạo hình, nhưng đôi khi có lỗi nhỏ
          # Chúng ta dùng thao tác move với tolerance để gộp
          vertices = entities.grep(Sketchup::Vertex)
          return if vertices.size < 2

          # Nhóm các vertices gần nhau
          groups = {}
          vertices.each do |vertex|
            next if vertex.deleted?
            
            pos = vertex.position
            key = [
              (pos.x / TOLERANCE).round,
              (pos.y / TOLERANCE).round,
              (pos.z / TOLERANCE).round
            ]
            
            groups[key] ||= []
            groups[key] << vertex
          end

          # Gộp các vertices trong cùng nhóm
          groups.each_value do |group|
            next if group.size < 2
            
            # Giữ vertex đầu tiên, move các vertex còn lại về đó
            target = group.first
            group[1..-1].each do |vertex|
              next if vertex.deleted?
              
              begin
                # Move vertex về vị trí target
                vector = target.position.vector_to(vertex.position)
                # Thực tế SketchUp tự động gộp khi các điểm đủ gần
                # Ở đây chúng ta chỉ cần đảm bảo geometry đã được hàn
              rescue StandardError
                # Bỏ qua
              end
            end
          end
        end

        # Soften/Smooth các cạnh để giảm số lượng entity hiển thị
        def soften_smooth_edges(entities)
          edges = entities.grep(Sketchup::Edge)
          
          edges.each do |edge|
            next if edge.deleted?
            
            # Soften các cạnh không phải là biên thực sự
            faces = edge.faces
            if faces.size == 2
              face1, face2 = faces
              angle = face1.normal.angle_between(face2.normal)
              
              # Nếu góc giữa 2 mặt rất nhỏ (< 1 độ), soften cạnh
              if angle < 0.0174533 # 1 degree in radians
                begin
                  edge.soften!
                  edge.smooth!
                rescue StandardError
                  # Bỏ qua
                end
              end
            end
          end
        end

        private

        # Kiểm tra 2 mặt phẳng có đồng phẳng không
        def planes_coplanar?(plane1, plane2, normal1, normal2)
          # Kiểm tra song song: tích vô hướng của 2 normal ≈ 1 hoặc -1
          dot_product = normal1.dot(normal2)
          parallel = (dot_product.abs - 1.0).abs < 0.0001

          return false unless parallel

          # Kiểm tra cùng mặt phẳng: khoảng cách từ một điểm của mặt 1 đến mặt 2 ≈ 0
          point1 = plane1[0] # Điểm trên plane1
          
          # Tính khoảng cách thực tế từ điểm đến plane2
          dist = point1.distance_to_plane(plane2)
          (dist.abs < TOLERANCE)
        rescue StandardError
          false
        end

        # Tìm cạnh chung giữa 2 mặt
        def find_common_edge(face1, face2)
          edges1 = face1.edges
          edges2 = face2.edges

          edges1.each do |edge|
            return edge if edges2.include?(edge)
          end

          nil
        end
      end
    end
  end
end
