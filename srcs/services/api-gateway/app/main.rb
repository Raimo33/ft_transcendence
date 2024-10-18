require_relative 'EndpointTreeNode.rb'

# Define the RESTful API endpoints
EndpointTree = EndpointTreeNode.new('v1') # Root node

EndpointTree.add_path('sessions',
    [
        ApiMethod.new(HttpMethod::GET, AuthLevel::ADMIN),   #get login status of all users
        ApiMethod.new(HttpMethod::DELETE, AuthLevel::ADMIN) #disconnect all users
    ]
)
EndpointTree.add_path('sessions/:user_id',
    [
        ApiMethod.new(HttpMethod::POST, AuthLevel::NONE),   #user login
        ApiMethod.new(HttpMethod::GET, AuthLevel::USER),    #get user login status
        ApiMethod.new(HttpMethod::DELETE, AuthLevel::USER)  #user logout
    ]
)

EndpointTree.add_path('users',
    [


