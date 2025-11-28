require 'securerandom'
require_relative 'memory_monitor'
require_relative 'queue_manager'
require_relative 'task_scheduler'
require_relative 'memory_guard'
require_relative 'progress_tracker'

class ParallelProcessor
  def initialize(project_id, processing_cores = 1)
    @project_id = project_id
    @processing_cores = processing_cores
    @memory_monitor = MemoryMonitor.new
    @queue_manager = QueueManager.new(@memory_monitor, @processing_cores)
    @memory_guard = MemoryGuard.new(@memory_monitor, @queue_manager, @project_id)
    @task_scheduler = TaskScheduler.new
    @ractors = []
    @running = false
    @progress = 0
    @total_tasks = 0
    @completed_tasks = 0
  end

  def process
    @running = true

    begin
      puts "Starting parallel processing with #{@processing_cores} cores"
      ProgressTracker.broadcast_status(@project_id, 'processing', 0, "开始并行处理，使用 #{@processing_cores} 个核心")

      # 预收集所有任务
      tasks = collect_all_tasks
      @total_tasks = tasks.size
      puts "Collected #{@total_tasks} tasks"

      # 按优先级排序
      prioritized_tasks = @task_scheduler.prioritize(tasks)

      # 创建Ractor池
      create_ractor_pool

      # 将任务添加到队列
      prioritized_tasks.each do |task|
        unless @queue_manager.add_task(task)
          puts "Failed to add task to queue: #{task[:type]} - #{task[:node]&.name || task[:slice]&.name}"
        end
      end

      puts "All tasks added to queue, starting processing..."
      ProgressTracker.broadcast_status(@project_id, 'processing', 0, "所有任务已添加到队列，开始处理...")

      # 启动工作线程处理队列
      start_worker_threads

      # 等待所有任务完成
      wait_for_completion

      puts "Parallel processing completed successfully"
      ProgressTracker.broadcast_status(@project_id, 'ready', 100, "并行处理完成")

    rescue => e
      puts "Parallel processing error: #{e.message}"
      puts e.backtrace
      ProgressTracker.broadcast_error(@project_id, "并行处理错误: #{e.message}")
      raise e
    ensure
      cleanup
    end
  end

  def stop
    @running = false
    cleanup
  end

  def progress
    @progress
  end

  def stats
    {
      progress: @progress,
      total_tasks: @total_tasks,
      completed_tasks: @completed_tasks,
      queue_stats: @queue_manager.stats,
      memory_stats: @memory_guard.memory_stats
    }
  end

  private

  def collect_all_tasks
    project = Project.find(@project_id)
    tasks = []

    PSD.open(project.psd_path) do |psd|
      # 收集切片任务
      psd.slices.each do |slice|
        next if slice.width == 0 || slice.height == 0
        tasks << {
          type: :slice,
          slice: slice,
          project_id: @project_id,
          priority: 100  # 最高优先级
        }
      end

      # 收集图层任务
      collect_layer_tasks(psd.tree, tasks)
    end

    tasks
  end

  def collect_layer_tasks(node, tasks, parent_id = nil)
    return if node.width == 0 || node.height == 0

    layer_type = determine_type(node)

    case layer_type
    when :group
      # 将组图层分解为独立任务
      node.children.each { |child| collect_layer_tasks(child, tasks, parent_id) }
    when :text
      tasks << {
        type: :text,
        node: node,
        project_id: @project_id,
        parent_id: parent_id,
        priority: 50  # 中等优先级
      }
    when :layer
      has_text = text_layer?(node)
      tasks << {
        type: :layer,
        node: node,
        project_id: @project_id,
        parent_id: parent_id,
        has_text: has_text,
        priority: has_text ? 10 : 30  # 无文案图层优先
      }
    end

    # 递归处理子节点
    if node.group?
      node.children.each { |child| collect_layer_tasks(child, tasks, node.id) }
    end
  end

  def determine_type(node)
    return :group if node.group?
    return :text if text_layer?(node)
    :layer
  end

  def text_layer?(node)
    node.respond_to?(:layer) &&
    node.layer.respond_to?(:info) &&
    node.layer.info &&
    !node.layer.info[:type].nil?
  end

  def create_ractor_pool
    @ractors = @processing_cores.times.map do |i|
      Ractor.new(i, @memory_monitor) do |worker_id, memory_monitor|
        RactorWorker.new(worker_id, memory_monitor)
      end
    end
  end

  def start_worker_threads
    @worker_threads = @processing_cores.times.map do |i|
      Thread.new do
        worker_loop(i)
      end
    end
  end

  def worker_loop(worker_id)
    puts "Worker #{worker_id} started"

    while @running && @queue_manager.running?
      begin
        # 从队列获取任务
        task = @queue_manager.get_next_task

        if task
          puts "Worker #{worker_id} processing task: #{task[:type]} - #{task[:node]&.name || task[:slice]&.name}"

          # 使用Ractor处理任务
          result = @ractors[worker_id].process(task)

          # 标记任务完成
          @queue_manager.task_completed(task[:task_id], result, worker_id)

          # 更新进度
          @completed_tasks += 1
          @progress = (@completed_tasks.to_f / @total_tasks * 100).round

          puts "Worker #{worker_id} completed task: #{task[:type]} - #{task[:node]&.name || task[:slice]&.name}"

          # 发送进度更新
          if @completed_tasks % 5 == 0 || @completed_tasks == @total_tasks
            ProgressTracker.broadcast_progress(
              @project_id,
              @progress,
              @total_tasks,
              @completed_tasks,
              @queue_manager.stats,
              @memory_guard.memory_stats
            )
          end

          # 定期触发垃圾回收
          GC.start if @completed_tasks % 5 == 0
        else
          # 队列为空，短暂等待
          sleep(0.1)
        end

        # 检查内存安全
        memory_status = @memory_guard.check_memory_safety
        if memory_status == :critical || memory_status == :high
          puts "Worker #{worker_id} pausing due to memory status: #{memory_status}"
          sleep(1) while (@memory_guard.emergency_mode? || memory_status == :critical) && @running
        end

      rescue => e
        puts "Worker #{worker_id} error: #{e.message}"
        if task
          @queue_manager.task_failed(task[:task_id], e.message, worker_id)
        end
        sleep(1)  # 错误后短暂等待
      end
    end

    puts "Worker #{worker_id} stopped"
  end

  def wait_for_completion
    # 等待所有任务完成
    while @running && @queue_manager.running? &&
          (@queue_manager.total_tasks_count > 0 || @completed_tasks < @total_tasks)

      # 更新进度显示
      puts "Progress: #{@progress}% (#{@completed_tasks}/#{@total_tasks})" if @completed_tasks % 10 == 0

      # 检查内存安全
      memory_status = @memory_guard.check_memory_safety
      if memory_status == :critical
        puts "Critical memory usage detected, pausing processing"
        sleep(2) while @memory_guard.emergency_mode? && @running
      end

      sleep(1)
    end

    # 等待工作线程完成
    @worker_threads&.each(&:join)
  end

  def cleanup
    @running = false

    # 停止队列管理器
    @queue_manager.stop if @queue_manager

    # 停止内存保护
    @memory_guard.stop if @memory_guard

    # 停止所有Ractor
    @ractors.each do |ractor|
      ractor.send(:stop) if ractor.alive?
    end

    # 等待工作线程完成
    @worker_threads&.each(&:join)

    # 强制垃圾回收
    GC.start

    @ractors.clear
    @worker_threads = nil

    puts "ParallelProcessor cleanup completed"
  end
end