# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    endpoint_tree.rb                                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/24 15:55:39 by craimond          #+#    #+#              #
#    Updated: 2024/10/24 19:23:58 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

class EndpointTreeNode
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
      current_node.children[part] ||= EndpointTrieNode.new(part)
      current_node = current_node.children[part]
    end

    resources.each do |endpoint|
      current_node.resources[endpoint.http_method] = endpoint
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

  def parse_swagger_file(file_path)
    require 'yaml'

    swagger_data = YAML.load_file(file_path)
    swagger_data['paths'].each do |path, resources|
      resources = resources.map do |http_method, details|
        auth_required = details['security']
        APIRequest.new(http_method.to_sym, auth_required)
      end
      add_path(path, resources)
    end

  rescue ERRNO::ENOENT => e
    STDERR.puts "File not found: #{e.message}"
  rescue ERRNO::EACCES => e
    STDERR.puts "Permission denied: #{e.message}"
  rescue Psych::SyntaxError => e
    STDERR.puts "Error parsing YAML: #{e.message}"
  rescue StandardError => e
    STDERR.puts "Unexpected error: #{e.message}"
    nil
  end

end
