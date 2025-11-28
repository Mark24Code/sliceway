class TaskScheduler
  def prioritize(tasks)
    # 按优先级排序
    sorted_tasks = tasks.sort_by do |task|
      priority = task[:priority] || 0

      # 在相同优先级内，进一步排序
      case task[:type]
      when :slice
        # 切片按面积排序，大切片优先
        area = task[:slice].width * task[:slice].height
        [priority, -area]
      when :text
        # 文字图层按面积排序，大文字优先
        area = task[:node].width * task[:node].height
        [priority, -area]
      when :layer
        # 图层按面积和无文案状态排序
        area = task[:node].width * task[:node].height
        # 无文案图层优先，然后按面积排序
        [priority, task[:has_text] ? 1 : 0, -area]
      else
        [priority, 0]
      end
    end

    sorted_tasks
  end

  def group_tasks_by_priority(tasks)
    # 按优先级分组
    groups = {
      high: tasks.select { |t| t[:priority] >= 50 },   # 切片和文字
      medium: tasks.select { |t| t[:priority] >= 30 && t[:priority] < 50 },  # 无文案图层
      low: tasks.select { |t| t[:priority] < 30 }       # 有文案图层
    }

    groups
  end

  def estimate_processing_time(tasks)
    # 基于任务类型和大小估算处理时间
    total_time = 0

    tasks.each do |task|
      case task[:type]
      when :slice
        area = task[:slice].width * task[:slice].height
        total_time += area * 0.0001  # 假设每像素0.0001秒
      when :text, :layer
        area = task[:node].width * task[:node].height
        total_time += area * 0.00005  # 图层处理更快
      end
    end

    total_time
  end

  def optimize_for_parallelism(tasks, available_cores)
    return tasks if tasks.size <= available_cores

    # 将任务分成大致相等的组
    groups = Array.new(available_cores) { [] }

    # 按优先级分组
    priority_groups = group_tasks_by_priority(tasks)

    # 按优先级顺序分配任务到核心
    [:high, :medium, :low].each do |priority|
      priority_groups[priority].each_with_index do |task, index|
        group_index = index % available_cores
        groups[group_index] << task
      end
    end

    # 展平分组
    groups.flatten
  end
end