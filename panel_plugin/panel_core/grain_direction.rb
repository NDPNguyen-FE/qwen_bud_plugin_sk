# encoding: UTF-8
# =============================================================================
# GrainDirection Enum
# =============================================================================
module PanelCore
  module GrainDirection
    HORIZONTAL = :horizontal  # Vân nằm ngang theo chiều dài tấm
    VERTICAL   = :vertical    # Vân dọc theo chiều rộng tấm
    NONE       = :none        # Không vân (ván công nghiệp, MDF trơn)

    ALL = [HORIZONTAL, VERTICAL, NONE].freeze

    def self.valid?(val)
      ALL.include?(val)
    end

    def self.label(val)
      case val
      when HORIZONTAL then 'Ngang'
      when VERTICAL   then 'Dọc'
      when NONE       then 'Không vân'
      else 'Không xác định'
      end
    end

    def self.from_string(str)
      case str.to_s.downcase
      when 'horizontal', 'ngang' then HORIZONTAL
      when 'vertical', 'dọc', 'doc' then VERTICAL
      when 'none', 'không vân', 'khong van' then NONE
      else nil
      end
    end
  end
end
