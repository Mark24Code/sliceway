require 'json'

class ProgressTracker
  def self.broadcast_status(project_id, status, progress = nil, message = nil)
    data = {
      type: 'status_update',
      project_id: project_id,
      status: status,
      timestamp: Time.now.to_i
    }

    data[:progress] = progress if progress
    data[:message] = message if message

    broadcast_message(data)
  end

  def self.broadcast_progress(project_id, progress, total_tasks, completed_tasks, queue_stats = nil, memory_stats = nil)
    data = {
      type: 'progress_update',
      project_id: project_id,
      progress: progress,
      total_tasks: total_tasks,
      completed_tasks: completed_tasks,
      timestamp: Time.now.to_i
    }

    data[:queue_stats] = queue_stats if queue_stats
    data[:memory_stats] = memory_stats if memory_stats

    broadcast_message(data)
  end

  def self.broadcast_error(project_id, error_message)
    data = {
      type: 'error',
      project_id: project_id,
      message: error_message,
      timestamp: Time.now.to_i
    }

    broadcast_message(data)
  end

  def self.broadcast_memory_warning(project_id, memory_usage, warning_level)
    data = {
      type: 'memory_warning',
      project_id: project_id,
      memory_usage: memory_usage,
      warning_level: warning_level,
      timestamp: Time.now.to_i
    }

    broadcast_message(data)
  end

  def self.broadcast_queue_stats(project_id, queue_stats)
    data = {
      type: 'queue_stats',
      project_id: project_id,
      queue_stats: queue_stats,
      timestamp: Time.now.to_i
    }

    broadcast_message(data)
  end

  private

  def self.broadcast_message(data)
    message = JSON.generate(data)

    # 广播到所有连接的WebSocket客户端
    $ws_clients.each do |ws|
      begin
        ws.send(message)
      rescue => e
        puts "Failed to send WebSocket message: #{e.message}"
        # 移除无效的连接
        $ws_clients.delete(ws)
      end
    end
  rescue => e
    puts "Error broadcasting WebSocket message: #{e.message}"
  end
end