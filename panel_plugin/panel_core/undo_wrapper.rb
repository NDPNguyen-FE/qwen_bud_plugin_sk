# encoding: UTF-8
# =============================================================================
# UndoWrapper - bọc mọi thao tác vào 1 operation group
# =============================================================================
module PanelCore
  module UndoWrapper
    # Execute block inside a single undo operation
    # Returns block result, or nil if error occurred
    def self.run(operation_name, &block)
      model = Sketchup.active_model
      model.start_operation(operation_name, true) # true = disable_ui for performance
      begin
        result = block.call
        model.commit_operation
        result
      rescue => e
        model.abort_operation
        UI.messagebox("Lỗi: #{e.message}\n\n#{e.backtrace.first(3).join("\n")}")
        nil
      end
    end

    # Non-UI version: raises error instead of showing messagebox
    def self.run!(operation_name, &block)
      model = Sketchup.active_model
      model.start_operation(operation_name, true)
      begin
        result = block.call
        model.commit_operation
        result
      rescue => e
        model.abort_operation
        raise e
      end
    end
  end
end
