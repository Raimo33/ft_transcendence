require_relative 'EndpointTreeNode.rb'

# Define the RESTful API endpoints
EndpointTree = EndpointTreeNode.new('v1') # Root node

# Parse the API endpoints from the API_swagger.yaml file and add them to the tree
EndpointTree.parse_swagger_file('config/API_swagger.yaml')
