# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    RequestValidator.rb                                :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/23 11:42:17 by craimond          #+#    #+#              #
#    Updated: 2024/11/23 12:03:13 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require "singleton"
require_relative "../modules/Structs"

class RequestValidator
  include Singleton

  def initialize
    @logger = ConfigurableLogger.instance.logger
    @config = ConfigLoader.instance.config #TODO forse useless
    @jwt_validator = JwtValidator.instance

    @logger.info("RequestValidator initialized")
  end

  def validate_request(request)
    expected_request = get_expected_request(request.http_method, request.path)

    validate_path(request.path, expected_request.allowed_path_params)
    validate_query_params(request.query_params, expected_request.allowed_query_params)
    validate_headers(request.headers, expected_request.allowed_headers)
    validate_body(request.body, expected_request.body_schema)
    validate_auth(expected_request.auth_level, request.headers["authorization"])
  end

  private

  def get_expected_request(http_method, path)
    endpoint = @endpoint_tree.find(path)
    raise ServerException::NotFound unless endpoint

    resource = endpoint.content[http_method]
    raise ServerException::MethodNotAllowed unless resource
    
    resource.expected_request
  end

  def validate_path_params(request_path_params, expected_path_params)
    return if expected_path_params.empty?

    raise ServerException::BadRequest unless request_path_params.keys.sort == expected_path_params.sort
  end

  def validate_auth(expected_auth_level, authorization_header)
    return if expected_auth_level == 0

    raise ServerException::Unauthorized unless authorization_header
    token = extract_token(authorization_header)
    raise ServerException::Unauthorized unless @jwt_validator.token_valid?(token)
    raise ServerException::Forbidden    unless @jwt_validator.token_authorized?(token, expected_auth_level)
  end