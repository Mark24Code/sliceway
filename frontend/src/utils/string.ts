/**
 * 路径截断工具函数
 */

/**
 * 从字符串开头截断路径，保留末尾内容
 * @param path 要截断的路径字符串
 * @param maxLength 最大显示长度，默认35个字符
 * @returns 截断后的字符串，如果长度不超过maxLength则返回原字符串
 */
export const truncatePathFromStart = (path: string, maxLength: number = 35): string => {
  if (path.length <= maxLength) {
    return path;
  }

  // 保留末尾内容，从开头截断
  const ellipsis = '...';
  const charsToKeep = maxLength - ellipsis.length;

  if (charsToKeep <= 0) {
    return ellipsis;
  }

  return ellipsis + path.slice(-charsToKeep);
};