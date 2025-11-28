require 'objspace'

class MemoryMonitor
  MEMORY_THRESHOLD = 0.8  # 80% 内存使用阈值
  MEMORY_CHECK_INTERVAL = 5  # 每5秒检查一次

  def initialize
    @last_check_time = Time.now
    @memory_warning_count = 0
    @max_warnings = 3
  end

  def memory_usage_exceeded?
    return false if Time.now - @last_check_time < MEMORY_CHECK_INTERVAL

    @last_check_time = Time.now
    current_usage = current_memory_usage

    if current_usage > MEMORY_THRESHOLD
      @memory_warning_count += 1
      puts "Memory warning #{@memory_warning_count}/#{@max_warnings}: #{'%.2f' % (current_usage * 100)}% memory used"

      if @memory_warning_count >= @max_warnings
        puts "Memory usage critically high, forcing garbage collection"
        force_garbage_collection
        @memory_warning_count = 0
      end

      true
    else
      @memory_warning_count = 0
      false
    end
  end

  def current_memory_usage
    # 获取当前进程的内存使用情况
    if RUBY_PLATFORM =~ /darwin/  # macOS
      memory_info = `ps -o rss= -p #{Process.pid}`.to_i
      total_memory = `sysctl -n hw.memsize`.to_i
    elsif RUBY_PLATFORM =~ /linux/  # Linux
      memory_info = `ps -o rss= -p #{Process.pid}`.to_i
      total_memory = `grep MemTotal /proc/meminfo`.split[1].to_i * 1024
    else
      # 默认使用ObjectSpace估算
      return ObjectSpace.memsize_of_all / (1024.0 * 1024 * 1024)  # 转换为GB
    end

    memory_info.to_f / total_memory
  end

  def force_garbage_collection
    puts "Forcing garbage collection..."
    GC.start(full_mark: true, immediate_sweep: true)
    sleep(1)  # 给GC一些时间
  end

  def track_object_growth
    # 跟踪对象增长，检测内存泄漏
    current_objects = ObjectSpace.count_objects
    @last_object_count ||= current_objects

    growth = {}
    current_objects.each do |type, count|
      last_count = @last_object_count[type] || 0
      growth[type] = count - last_count if count > last_count
    end

    @last_object_count = current_objects

    # 如果有显著的对象增长，记录警告
    significant_growth = growth.select { |_, diff| diff > 1000 }
    unless significant_growth.empty?
      puts "Significant object growth detected: #{significant_growth}"
    end

    significant_growth
  end

  def monitor_large_objects
    # 监控大型对象
    large_objects = ObjectSpace.each_object.select do |obj|
      ObjectSpace.memsize_of(obj) > 1_000_000  # 1MB以上的对象
    end

    unless large_objects.empty?
      puts "Large objects detected: #{large_objects.size} objects over 1MB"

      # 按大小排序并显示前5个最大的对象
      top_objects = large_objects.sort_by { |obj| -ObjectSpace.memsize_of(obj) }.take(5)
      top_objects.each do |obj|
        size_mb = ObjectSpace.memsize_of(obj) / (1024.0 * 1024)
        puts "  - #{obj.class}: #{'%.2f' % size_mb} MB"
      end
    end

    large_objects
  end

  def cleanup_temporary_files
    # 清理临时文件
    temp_dirs = [
      File.join(Dir.tmpdir, "psd2img_*"),
      File.join("public", "processed", "*", "*.tmp")
    ]

    temp_dirs.each do |pattern|
      Dir.glob(pattern).each do |file|
        begin
          File.delete(file) if File.exist?(file)
        rescue => e
          puts "Failed to delete temporary file #{file}: #{e.message}"
        end
      end
    end
  end

  def memory_stats
    {
      usage_percentage: current_memory_usage * 100,
      object_count: ObjectSpace.count_objects[:TOTAL],
      memory_size_mb: ObjectSpace.memsize_of_all / (1024.0 * 1024),
      warning_count: @memory_warning_count
    }
  end
end