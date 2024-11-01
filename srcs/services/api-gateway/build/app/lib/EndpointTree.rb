# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    EndpointTree.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/24 15:55:39 by craimond          #+#    #+#              #
#    Updated: 2024/11/01 16:03:12 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative 'Resource'

class EndpointTree
  attr_accessor :part, :children, :resources

  def initialize(part)
    @part = part
    @children = {}
    @resources = {}
  end

  def add_path(path, resources)
    parts = path.split('/').reject(&:empty?)
    current_node = self

    parts.each do |part|
      current_node.children[part] ||= EndpointTree.new(part)
      current_node = current_node.children[part]
    end

    resources.each do |r|
      current_node.resources[r.http_method] = r
    end    
  end

  def find_endpoint(path)
    parts = path.split('/').reject(&:empty?)
  
    parts.each do |part|
      if current_node.children.key?(part)
        current_node = current_node.children[part]
      else
        current_node = current_node.children.each_value.find do |child|
          child.key.start_with?('{') && child.key.end_with?('}')
        end
  
        return nil unless current_node
      end
    end
  
    current_node
  end

end
