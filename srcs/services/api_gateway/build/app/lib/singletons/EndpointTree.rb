# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    EndpointTree.rb                                    :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/24 15:55:39 by craimond          #+#    #+#              #
#    Updated: 2024/11/23 11:20:35 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require_relative "./modules/Structs"
require 'tree'
require 'singleton'

class EndpointTree
  include Singleton

  attr_accessor :root

  def initialize
    @root = Tree::TreeNode.new("root")
  end

  def add_resource(path, http_method, resource)
    parts = path.split('/').reject(&:empty?)
    current_node = @root

    parts.each do |part|
      child_node = current_node[part] || Tree::TreeNode.new(part)
      current_node << child_node unless current_node[part]
      current_node = child_node
    end

    current_node.content ||= {}
    current_node.content[http_method] = resource
  end

  def find_resource(http_method, raw_path)
    parts = raw_path.split('/').reject(&:empty?)
    current_node = @root

    parts.each do |part|
      if current_node[part]
        current_node = current_node[part]
      else
        current_node = current_node.children.find do |child|
          child.name.start_with?('{') && child.name.end_with?('}')
        end

        return nil unless current_node
      end
    end

    current_node.content[http_method]
  end
end
