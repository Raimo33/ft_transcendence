require_relative 'EndpointTreeNode.rb'

EndpointTree = EndpointTreeNode.new('v1') # Root node
EndpointTree.parse_swagger_file('config/API_swagger.yaml')
