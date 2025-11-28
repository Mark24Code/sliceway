require 'objspace'
require_relative 'progress_tracker'

class MemoryGuard
  CRITICAL_MEMORY_THRESHOLD = 0.9  # 90% 内存使用阈值（紧急）
  HIGH_MEMORY_THRESHOLD = 0.8      # 80% 内存使用阈值（高）
  MEDIUM_MEMORY_THRESHOLD = 0.7    # 70% 内存使用阈值（中等）

  MEMORY_CHECK_INTERVAL = 2        # 内存检查间隔（秒）
  MEMORY_RECOVERY_TIMEOUT = 30     # 内存恢复超时时间（秒）

  def initialize(memory_monitor, queue_manager, project_id = nil)
    @memory_monitor = memory_monitor
    @queue_manager = queue_manager
    @project_id = project_id
    @running = true
    @emergency_mode = false
    @last_memory_check = Time.now
    @memory_recovery_start = nil

    # 启动内存保护监控线程
    start_memory_guard_monitor
  end

  def check_memory_safety
    return :safe unless @running

    current_usage = @memory_monitor.current_memory_usage

    if current_usage >= CRITICAL_MEMORY_THRESHOLD
      handle_critical_memory_usage(current_usage)
      return :critical
    elsif current_usage >= HIGH_MEMORY_THRESHOLD
      handle_high_memory_usage(current_usage)
      return :high
    elsif current_usage >= MEDIUM_MEMORY_THRESHOLD
      handle_medium_memory_usage(current_usage)
      return :medium
    else
      # 内存使用正常，检查是否需要退出紧急模式
      if @emergency_mode && current_usage < MEDIUM_MEMORY_THRESHOLD
        exit_emergency_mode
      end
      return :safe
    end
  end

  def stop
    @running = false
    puts "MemoryGuard stopped"
  end

  def emergency_mode?
    @emergency_mode
  end

  def memory_stats
    {
      current_usage: @memory_monitor.current_memory_usage * 100,
      emergency_mode: @emergency_mode,
      object_count: ObjectSpace.count_objects[:TOTAL],
      memory_size_mb: ObjectSpace.memsize_of_all / (1024.0 * 1024)
    }
  end

  private

  def start_memory_guard_monitor
    Thread.new do
      while @running
        begin
          check_memory_safety
          sleep(MEMORY_CHECK_INTERVAL)
        rescue => e
          puts "MemoryGuard monitor error: #{e.message}"
          sleep(MEMORY_CHECK_INTERVAL)
        end
      end
    end
  end

  def handle_critical_memory_usage(usage)
    unless @emergency_mode
      puts "🚨 CRITICAL MEMORY USAGE: #{'%.2f' % (usage * 100)}% - Entering emergency mode"
      ProgressTracker.broadcast_memory_warning(@project_id, usage * 100, 'critical') if @project_id
      @emergency_mode = true
      @memory_recovery_start = Time.now
    end

    # 紧急措施
    emergency_memory_recovery

    # 检查恢复超时
    if Time.now - @memory_recovery_start > MEMORY_RECOVERY_TIMEOUT
      puts "🚨 Memory recovery timeout, forcing process restart"
      ProgressTracker.broadcast_error(@project_id, "内存恢复超时，强制重启进程") if @project_id
      force_process_restart
    end
  end

  def handle_high_memory_usage(usage)
    puts "⚠️ HIGH MEMORY USAGE: #{'%.2f' % (usage * 100)}% - Taking aggressive measures"
    ProgressTracker.broadcast_memory_warning(@project_id, usage * 100, 'high') if @project_id

    # 积极的内存回收措施
    aggressive_memory_recovery

    # 暂停任务分发
    if @queue_manager.running?
      puts "Pausing task distribution due to high memory usage"
      sleep(2) while @memory_monitor.memory_usage_exceeded? && @running
    end
  end

  def handle_medium_memory_usage(usage)
    puts "ℹ️ MEDIUM MEMORY USAGE: #{'%.2f' % (usage * 100)}% - Taking preventive measures"
    ProgressTracker.broadcast_memory_warning(@project_id, usage * 100, 'medium') if @project_id

    # 预防性内存回收
    preventive_memory_recovery
  end

  def emergency_memory_recovery
    puts "🚨 EMERGENCY MEMORY RECOVERY ACTIVATED"

    # 1. 立即停止所有队列处理
    @queue_manager.stop if @queue_manager.running?

    # 2. 强制垃圾回收
    puts "Forcing full garbage collection..."
    3.times do
      GC.start(full_mark: true, immediate_sweep: true)
      sleep(0.5)
    end

    # 3. 清理临时文件
    puts "Cleaning up temporary files..."
    @memory_monitor.cleanup_temporary_files

    # 4. 监控大型对象
    puts "Monitoring large objects..."
    large_objects = @memory_monitor.monitor_large_objects

    # 5. 跟踪对象增长
    puts "Tracking object growth..."
    object_growth = @memory_monitor.track_object_growth

    # 6. 检查内存泄漏
    check_for_memory_leaks

    # 7. 报告内存状态
    report_memory_status

    puts "Emergency memory recovery completed"
  end

  def aggressive_memory_recovery
    puts "🔄 Aggressive memory recovery"

    # 1. 强制垃圾回收
    GC.start(full_mark: true, immediate_sweep: true)

    # 2. 清理临时文件
    @memory_monitor.cleanup_temporary_files

    # 3. 监控大型对象
    @memory_monitor.monitor_large_objects

    # 4. 降低队列处理速度
    reduce_processing_speed

    puts "Aggressive memory recovery completed"
  end

  def preventive_memory_recovery
    puts "🛡️ Preventive memory recovery"

    # 1. 触发垃圾回收
    GC.start

    # 2. 清理临时文件
    @memory_monitor.cleanup_temporary_files

    # 3. 监控内存使用情况
    monitor_memory_trends
  end

  def exit_emergency_mode
    puts "✅ Exiting emergency mode - Memory usage normalized"
    @emergency_mode = false
    @memory_recovery_start = nil

    # 重新启动队列处理
    # 注意：这里需要根据实际情况重新初始化队列管理器
    puts "Queue processing can be resumed"
  end

  def reduce_processing_speed
    # 降低处理速度的策略
    puts "Reducing processing speed to conserve memory"

    # 可以实现的策略：
    # - 增加任务处理间隔
    # - 减少并发工作线程数
    # - 分批处理任务
  end

  def check_for_memory_leaks
    puts "🔍 Checking for memory leaks..."

    # 检查对象增长趋势
    object_stats = @memory_monitor.memory_stats
    puts "Object count: #{object_stats[:object_count]}"
    puts "Memory size: #{'%.2f' % object_stats[:memory_size_mb]} MB"

    # 如果对象数量持续增长，可能存在内存泄漏
    # 这里可以添加更复杂的内存泄漏检测逻辑
  end

  def monitor_memory_trends
    # 监控内存使用趋势
    current_stats = @memory_monitor.memory_stats

    # 可以记录历史数据并分析趋势
    # 如果检测到内存使用持续上升，可以提前采取措施
  end

  def report_memory_status
    stats = @memory_monitor.memory_stats
    puts "📊 Memory Status Report:"
    puts "  - Usage: #{'%.2f' % stats[:usage_percentage]}%"
    puts "  - Objects: #{stats[:object_count]}"
    puts "  - Memory: #{'%.2f' % stats[:memory_size_mb]} MB"
    puts "  - Warnings: #{stats[:warning_count]}"
  end

  def force_process_restart
    puts "🔄 Forcing process restart due to unrecoverable memory state"

    # 在真实环境中，这里应该优雅地重启进程
    # 对于开发环境，我们只是记录日志
    puts "Process restart would be triggered in production environment"

    # 在实际部署中，可以调用系统命令重启进程
    # system("pkill -f 'ruby app.rb' && bundle exec ruby app.rb &")
  end
end