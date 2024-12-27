# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    match.rb                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <claudio.raimondi@protonmail.c    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/27 15:26:33 by craimond          #+#    #+#              #
#    Updated: 2024/12/27 16:30:45 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

class Match
  attr_accessor :players, :state

  def initialize(id)
    @id = id
    @players = []
    @state = {
      #TODO riempire con aas
    }
    @input_queue = []
  end

  def add_player(ws)
    @players << ws
  end

  def remove_player(ws)
    @players.delete(ws)
  end

  def queue_input(input)
    @input_queue << input
  end

  def update
    process_inputs
    #TODO update game state, check for collisions, check for game over etc
  end
  
  private
  
  def process_inputs
    @input_queue.each do |input|
      apply_input(input)
    end
    @input_queue.clear
  end

  def apply_input(input)
    #TODO

end