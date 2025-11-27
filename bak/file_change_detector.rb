#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
#
# 文件变化检测器
# 检测文件是否发生变化，兼容MacOS/Linux，支持Samba远程文件
# 基于文件系统元数据（修改时间、大小等）

require 'fileutils'
require 'time'
require 'yaml'

class FileChangeDetector
  def initialize
    @cache_file = File.expand_path(".file_change_cache.yml")
    @cache = load_cache
  end

  # 检测文件是否发生变化
  # @param file_path [String] 文件路径
  # @return [Boolean] true表示文件发生变化，false表示未变化
  def changed?(file_path)
    unless File.exist?(file_path)
      puts "错误: 文件不存在 - #{file_path}"
      return true
    end

    current_stats = get_file_stats(file_path)
    previous_stats = @cache[file_path]

    if previous_stats.nil?
      # 首次检测，记录当前状态
      @cache[file_path] = current_stats
      save_cache
      return true
    end

    # 比较文件状态
    changed = compare_stats(previous_stats, current_stats)

    # 更新缓存
    @cache[file_path] = current_stats
    save_cache

    changed
  end

  # 重置文件的检测状态
  # @param file_path [String] 文件路径
  def reset(file_path)
    if File.exist?(file_path)
      @cache[file_path] = get_file_stats(file_path)
      save_cache
      puts "已重置文件状态: #{file_path}"
    else
      puts "错误: 文件不存在 - #{file_path}"
    end
  end

  # 清除所有缓存
  def clear_cache
    @cache = {}
    save_cache
    puts "已清除所有缓存"
  end

  private

  # 获取文件状态信息
  # @param file_path [String] 文件路径
  # @return [Hash] 文件状态信息
  def get_file_stats(file_path)
    stat = File.stat(file_path)

    # 检查是否为Samba挂载的文件
    is_samba = samba_mounted?(file_path)

    {
      mtime: stat.mtime.to_f,  # 修改时间（秒级精度）
      size: stat.size,         # 文件大小
      inode: stat.ino,         # inode编号
      mode: stat.mode,         # 文件权限
      uid: stat.uid,           # 用户ID
      gid: stat.gid,           # 组ID
      is_samba: is_samba       # 是否为Samba文件
    }
  rescue Errno::ENOENT
    nil
  end

  # 检查文件是否位于Samba挂载点
  # @param file_path [String] 文件路径
  # @return [Boolean] true表示是Samba文件
  def samba_mounted?(file_path)
    # 获取文件所在设备的挂载信息
    mount_point = find_mount_point(file_path)
    return false unless mount_point

    # 检查挂载类型是否为cifs或smbfs（Samba相关文件系统）
    mount_info = get_mount_info(mount_point)
    return false unless mount_info

    # 常见的Samba文件系统类型
    samba_types = ['cifs', 'smbfs', 'fuse.cifs', 'fuse.smbfs']
    samba_types.include?(mount_info[:type])
  end

  # 查找文件的挂载点
  # @param file_path [String] 文件路径
  # @return [String, nil] 挂载点路径
  def find_mount_point(file_path)
    path = File.expand_path(file_path)

    # 逐级向上查找挂载点
    while path != '/' && !path.empty?
      stat1 = File.stat(path)
      parent = File.dirname(path)

      # 如果到达根目录
      break if parent == path

      stat2 = File.stat(parent)

      # 如果设备ID不同，说明找到了挂载点
      return path if stat1.dev != stat2.dev

      path = parent
    end

    path
  end

  # 获取挂载点信息
  # @param mount_point [String] 挂载点路径
  # @return [Hash, nil] 挂载信息
  def get_mount_info(mount_point)
    # 在Linux/MacOS上使用mount命令获取挂载信息
    mount_output = `mount 2>/dev/null`

    mount_output.each_line do |line|
      # 解析mount命令输出
      # 示例: "//server/share on /mnt/samba type cifs (rw,...)"
      if line.include?(mount_point)
        parts = line.split
        if parts.length >= 5
          return {
            device: parts[0],
            mount_point: parts[2],
            type: parts[4].gsub(/[()]/, '')
          }
        end
      end
    end

    nil
  rescue
    nil
  end

  # 比较文件状态
  # @param old_stats [Hash] 旧状态
  # @param new_stats [Hash] 新状态
  # @return [Boolean] true表示发生变化
  def compare_stats(old_stats, new_stats)
    return true if old_stats.nil? || new_stats.nil?

    # 检查主要属性变化
    if old_stats[:size] != new_stats[:size]
      puts "文件大小发生变化: #{old_stats[:size]} -> #{new_stats[:size]}"
      return true
    end

    if old_stats[:mtime] != new_stats[:mtime]
      puts "修改时间发生变化: #{Time.at(old_stats[:mtime])} -> #{Time.at(new_stats[:mtime])}"
      return true
    end

    # 对于Samba文件，inode可能不稳定，所以不检查inode变化
    # 对于本地文件，检查inode变化（可能表示文件被替换）
    unless old_stats[:is_samba] || new_stats[:is_samba]
      if old_stats[:inode] != new_stats[:inode]
        puts "inode发生变化: #{old_stats[:inode]} -> #{new_stats[:inode]}"
        return true
      end
    end

    false
  end

  # 加载缓存
  # @return [Hash] 缓存数据
  def load_cache
    return {} unless File.exist?(@cache_file)

    begin
      YAML.load_file(@cache_file) || {}
    rescue => e
      puts "警告: 无法加载缓存文件: #{e.message}"
      {}
    end
  end

  # 保存缓存
  def save_cache
    begin
      File.write(@cache_file, YAML.dump(@cache))
    rescue => e
      puts "警告: 无法保存缓存文件: #{e.message}"
    end
  end
end

# 命令行接口
if __FILE__ == $0
  detector = FileChangeDetector.new

  case ARGV[0]
  when '--check', '-c'
    if ARGV[1]
      file_path = ARGV[1]
      if detector.changed?(file_path)
        puts "文件发生变化: #{file_path}"
        exit 1
      else
        puts "文件未发生变化: #{file_path}"
        exit 0
      end
    else
      puts "用法: #{$0} --check <文件路径>"
      exit 1
    end

  when '--reset', '-r'
    if ARGV[1]
      detector.reset(ARGV[1])
    else
      puts "用法: #{$0} --reset <文件路径>"
      exit 1
    end

  when '--clear', '-C'
    detector.clear_cache

  when '--help', '-h'
    puts <<~HELP
      文件变化检测器

      用法: #{$0} [选项] <文件路径>

      选项:
        --check, -c <文件路径>   检查文件是否发生变化
        --reset, -r <文件路径>   重置文件状态
        --clear, -C              清除所有缓存
        --help, -h               显示此帮助信息

      退出码:
        0 - 文件未发生变化
        1 - 文件发生变化或发生错误
    HELP

  else
    puts "用法: #{$0} --help 查看使用说明"
    exit 1
  end
end