require_relative 'endpoint_tree.rb'
require_relative 'jwt_validator.rb'

EndpointTree = EndpointTreeNode.new('v1') # Root node
EndpointTree.parse_swagger_file('app/config/API_swagger.yaml')

jwt_validator = JwtValidator.new
