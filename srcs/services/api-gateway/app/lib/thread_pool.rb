# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    thread_pool.rb                                     :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/20 08:33:26 by craimond          #+#    #+#              #
#    Updated: 2024/10/20 08:33:27 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

class ThreadPool
  def initialize(max_size)
    @max_size = max_size
    @queue = Queue.new
    @threads = Array.new(@max_size) do
      Thread.new do
        loop do
          task = @queue.pop
          break if task == :shutdown
          task.call
        end
      end
    end
  end

  def schedule(&block)
    @queue << block
  end

  def shutdown
    @max_size.times do
      @queue << :shutdown
    end
    @threads.each(&:join)
  end
end
