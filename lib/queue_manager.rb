require 'thread'
require 'timeout'

class QueueManager
  MAX_QUEUE_SIZE = 100  # 最大队列容量
  QUEUE_FULL_WAIT_TIME = 5  # 队列满时等待时间（秒）
  TASK_TIMEOUT = 300  # 任务超时时间（秒）
  ZOMBIE_CHECK_INTERVAL = 30  # 僵尸任务检查间隔（秒）

  def initialize(memory_monitor, max_workers)
    @memory_monitor = memory_monitor
    @max_workers = max_workers
    @task_queue = Queue.new
    @pending_tasks = {}  # 正在处理的任务
    @completed_tasks = []
    @failed_tasks = []
    @queue_mutex = Mutex.new
    @stats = {
      total_processed: 0,
      total_failed: 0,
      avg_processing_time: 0,
      queue_size_history: []
    }
    @running = true
    @last_zombie_check = Time.now

    # 启动队列监控线程
    start_queue_monitor
  end

  def add_task(task)
    return false unless @running

    # 检查队列是否已满
    if queue_size >= MAX_QUEUE_SIZE
      puts "Queue full (#{queue_size}/#{MAX_QUEUE_SIZE}), waiting..."

      # 等待队列有空位或超时
      start_time = Time.now
      while queue_size >= MAX_QUEUE_SIZE && Time.now - start_time < QUEUE_FULL_WAIT_TIME
        sleep(0.1)

        # 检查内存使用情况
        if @memory_monitor.memory_usage_exceeded?
          puts "Memory usage exceeded while waiting for queue space"
          sleep(1) while @memory_monitor.memory_usage_exceeded?
        end
      end

      # 如果仍然满，拒绝任务
      if queue_size >= MAX_QUEUE_SIZE
        puts "Queue still full after waiting, rejecting task"
        return false
      end
    end

    # 添加任务到队列
    task[:queued_at] = Time.now
    task[:task_id] = SecureRandom.hex(8)

    @queue_mutex.synchronize do
      @task_queue << task
      update_queue_stats
    end

    true
  end

  def get_next_task
    return nil unless @running

    begin
      # 非阻塞获取任务
      task = @task_queue.pop(true)

      @queue_mutex.synchronize do
        @pending_tasks[task[:task_id]] = {
          task: task,
          started_at: Time.now,
          worker_id: nil
        }
        update_queue_stats
      end

      task
    rescue ThreadError
      # 队列为空
      nil
    end
  end

  def task_completed(task_id, result, worker_id = nil)
    @queue_mutex.synchronize do
      pending_task = @pending_tasks.delete(task_id)

      if pending_task
        processing_time = Time.now - pending_task[:started_at]

        task_result = {
          task_id: task_id,
          task: pending_task[:task],
          result: result,
          processing_time: processing_time,
          completed_at: Time.now
        }

        if result[:success]
          @completed_tasks << task_result
          @stats[:total_processed] += 1
        else
          @failed_tasks << task_result
          @stats[:total_failed] += 1
        end

        # 更新平均处理时间
        update_avg_processing_time(processing_time)
        update_queue_stats
      end
    end

    # 任务完成后强制垃圾回收
    GC.start
  end

  def task_failed(task_id, error, worker_id = nil)
    task_completed(task_id, { success: false, error: error }, worker_id)
  end

  def queue_size
    @queue_mutex.synchronize do
      @task_queue.size
    end
  end

  def pending_tasks_count
    @queue_mutex.synchronize do
      @pending_tasks.size
    end
  end

  def total_tasks_count
    queue_size + pending_tasks_count
  end

  def completed_tasks_count
    @completed_tasks.size
  end

  def failed_tasks_count
    @failed_tasks.size
  end

  def stats
    @queue_mutex.synchronize do
      {
        queue_size: queue_size,
        pending_tasks: pending_tasks_count,
        completed_tasks: completed_tasks_count,
        failed_tasks: failed_tasks_count,
        total_processed: @stats[:total_processed],
        total_failed: @stats[:total_failed],
        avg_processing_time: @stats[:avg_processing_time],
        queue_utilization: calculate_queue_utilization
      }
    end
  end

  def stop
    @running = false

    # 清空队列
    @queue_mutex.synchronize do
      @task_queue.clear
      @pending_tasks.clear
    end

    puts "QueueManager stopped"
  end

  def running?
    @running
  end

  private

  def start_queue_monitor
    Thread.new do
      while @running
        begin
          # 检查僵尸任务
          check_zombie_tasks

          # 检查内存使用情况
          if @memory_monitor.memory_usage_exceeded?
            puts "Queue monitor: Memory usage exceeded, pausing task distribution"
            sleep(1) while @memory_monitor.memory_usage_exceeded? && @running
          end

          sleep(5)  # 每5秒检查一次
        rescue => e
          puts "Queue monitor error: #{e.message}"
          sleep(5)
        end
      end
    end
  end

  def check_zombie_tasks
    return unless Time.now - @last_zombie_check >= ZOMBIE_CHECK_INTERVAL

    @queue_mutex.synchronize do
      current_time = Time.now

      @pending_tasks.each do |task_id, task_info|
        if current_time - task_info[:started_at] > TASK_TIMEOUT
          puts "Detected zombie task #{task_id}, timeout after #{TASK_TIMEOUT} seconds"

          # 标记为失败
          task_failed(task_id, "Task timeout after #{TASK_TIMEOUT} seconds")
        end
      end
    end

    @last_zombie_check = Time.now
  end

  def update_queue_stats
    # 记录队列大小历史
    @stats[:queue_size_history] << queue_size

    # 保持最近100个记录
    if @stats[:queue_size_history].size > 100
      @stats[:queue_size_history].shift
    end
  end

  def update_avg_processing_time(new_time)
    if @stats[:total_processed] == 1
      @stats[:avg_processing_time] = new_time
    else
      # 使用移动平均
      @stats[:avg_processing_time] = (
        @stats[:avg_processing_time] * (@stats[:total_processed] - 1) + new_time
      ) / @stats[:total_processed]
    end
  end

  def calculate_queue_utilization
    total_capacity = @max_workers + MAX_QUEUE_SIZE
    current_usage = pending_tasks_count + queue_size

    (current_usage.to_f / total_capacity * 100).round(2)
  end

  def adjust_processing_speed
    # 基于队列利用率和内存使用情况动态调整处理速度
    utilization = calculate_queue_utilization

    if utilization > 80
      # 高利用率，可能需要减慢处理速度
      puts "High queue utilization (#{utilization}%), consider reducing processing speed"
    elsif utilization < 20
      # 低利用率，可以增加处理速度
      puts "Low queue utilization (#{utilization}%), can increase processing speed"
    end
  end
end