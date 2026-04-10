# encoding: UTF-8
# =============================================================================
# Validator - Kiểm tra đầu vào trước khi tạo/sửa tấm ván
# =============================================================================
module PanelCore
  module Validator
    MIN_THICKNESS = 3.0   # mm
    MIN_DIMENSION = 10.0  # mm
    INVALID_CHARS = ['/', '\\', ':', '*', '?', '<', '>', '|'].freeze

    # Validate dimensions (length, width, thickness in mm)
    # Raises ArgumentError with Vietnamese message if invalid
    def self.validate_dimensions!(l, w, t)
      raise ArgumentError, "Chiều dày tối thiểu #{MIN_THICKNESS}mm (hiện tại: #{t}mm)" if t < MIN_THICKNESS
      raise ArgumentError, "Chiều dài tối thiểu #{MIN_DIMENSION}mm (hiện tại: #{l}mm)" if l < MIN_DIMENSION
      raise ArgumentError, "Chiều rộng tối thiểu #{MIN_DIMENSION}mm (hiện tại: #{w}mm)" if w < MIN_DIMENSION
      true
    end

    # Returns array of error strings (empty if valid)
    def self.check_dimensions(l, w, t)
      errors = []
      errors << "Chiều dày tối thiểu #{MIN_THICKNESS}mm" if t < MIN_THICKNESS
      errors << "Chiều dài tối thiểu #{MIN_DIMENSION}mm" if l < MIN_DIMENSION
      errors << "Chiều rộng tối thiểu #{MIN_DIMENSION}mm" if w < MIN_DIMENSION
      errors
    end

    # Validate attributes hash
    # Raises ArgumentError with Vietnamese message if invalid
    def self.validate_attributes!(attrs)
      name = attrs[:part_name].to_s.strip
      raise ArgumentError, 'Tên cấu kiện không được để trống' if name.empty?

      if INVALID_CHARS.any? { |c| name.include?(c) }
        chars_str = INVALID_CHARS.join(' ')
        raise ArgumentError, "Tên cấu kiện chứa ký tự không hợp lệ. Không dùng: #{chars_str}"
      end

      grain = attrs[:grain_direction]
      unless GrainDirection.valid?(grain)
        raise ArgumentError, "Hướng vân không hợp lệ: #{grain.inspect}. Phải là :horizontal, :vertical hoặc :none"
      end

      true
    end

    # Returns array of error strings (empty if valid)
    def self.check_attributes(attrs)
      errors = []
      name = attrs[:part_name].to_s.strip

      errors << 'Tên cấu kiện không được để trống' if name.empty?

      if !name.empty? && INVALID_CHARS.any? { |c| name.include?(c) }
        errors << "Tên không được chứa ký tự: #{INVALID_CHARS.join(' ')}"
      end

      grain = attrs[:grain_direction]
      errors << "Hướng vân không hợp lệ" unless GrainDirection.valid?(grain)

      errors
    end

    # Validate a single part name (returns error string or nil)
    def self.validate_part_name(name)
      name = name.to_s.strip
      return 'Tên cấu kiện không được để trống' if name.empty?
      if INVALID_CHARS.any? { |c| name.include?(c) }
        return "Tên không được chứa ký tự: / \\ : * ? < > |"
      end
      nil
    end
  end
end
