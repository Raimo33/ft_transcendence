# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    BlockingPriorityQueue.rb                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/26 18:44:24 by craimond          #+#    #+#              #
#    Updated: 2024/11/01 19:11:51 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "async"

class BlockingPriorityQueue
  def initialize
    @queue = {}
    @next_sequence = 0
    @condition = Async::Condition.new
  end

  def enqueue(sequence, item)
    @queue[sequence] = item
    @condition.signal if sequence == @next_sequence
  end

  def dequeue
    until @queue.key?(@next_sequence)
      @condition.wait
    end
    
    item = @queue.delete(@next_sequence)
    @next_sequence += 1
    item
  end
end