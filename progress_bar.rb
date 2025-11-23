#!/usr/bin/env ruby

class ProgressBar
  def initialize(total, prefix: "进度", width: 50)
    @total = total
    @current = 0
    @prefix = prefix
    @width = width
    @start_time = Time.now
  end

  def increment(step = 1, message = nil)
    @current += step
    @current = @total if @current > @total
    print_progress(message)
  end

  def set_current(current, message = nil)
    @current = current
    @current = @total if @current > @total
    print_progress(message)
  end

  def finish(message = "完成!")
    @current = @total
    print_progress(message)
    puts
  end

  private

  def print_progress(message = nil)
    percentage = (@current.to_f / @total * 100).round(1)
    filled_width = (@current.to_f / @total * @width).round
    empty_width = @width - filled_width

    # 计算已用时间
    elapsed_time = Time.now - @start_time
    elapsed_str = format_time(elapsed_time)

    # 计算预估剩余时间
    if @current > 0
      remaining_time = (elapsed_time / @current) * (@total - @current)
      remaining_str = format_time(remaining_time)
    else
      remaining_str = "--:--:--"
    end

    # 构建进度条
    progress_bar = "[" + "=" * filled_width + " " * empty_width + "]"

    # 构建完整输出 - 简化版本，只显示进度条和基本信息
    output = "\r#{@prefix}: #{progress_bar} #{@current}/#{@total} (#{percentage}%) 时间: #{elapsed_str} 预估: #{remaining_str}"

    print output
    $stdout.flush
  end

  def format_time(seconds)
    hours = (seconds / 3600).to_i
    minutes = ((seconds % 3600) / 60).to_i
    seconds = (seconds % 60).to_i

    format("%02d:%02d:%02d", hours, minutes, seconds)
  end
end

# 使用方法示例
if __FILE__ == $0
  # 示例：模拟一个耗时任务
  total_items = 100
  progress = ProgressBar.new(total_items, prefix: "处理中", width: 40)

  total_items.times do |i|
    sleep(0.1)  # 模拟处理时间
    progress.increment(1, "处理第 #{i + 1} 项")
  end

  progress.finish("所有任务完成!")
end