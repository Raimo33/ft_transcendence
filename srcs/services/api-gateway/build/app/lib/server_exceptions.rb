# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    server_exceptions.rb                               :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/10/26 08:37:11 by craimond          #+#    #+#              #
#    Updated: 2024/10/26 22:22:50 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

module ServerExceptions

  class ServerError < StandardError
    attr_reader :status_code

    def initialize(message = nil, status_code = self.class::STATUS_CODE)
      super(message)
      @status_code = status_code
    end
  end

  class BadRequestError       < ServerError; STATUS_CODE = 400; end
  class UnauthorizedError     < ServerError; STATUS_CODE = 401; end
  class ForbiddenError        < ServerError; STATUS_CODE = 403; end
  class NotFoundError         < ServerError; STATUS_CODE = 404; end
  class MethodNotAllowedError < ServerError; STATUS_CODE = 405; end
  class ConflictError         < ServerError; STATUS_CODE = 409; end
  class InternalServerError   < ServerError; STATUS_CODE = 500; end
end