# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    metadata_interceptor.rb                            :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/03 13:30:58 by craimond          #+#    #+#              #
#    Updated: 2024/12/07 22:22:08 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

require 'grpc'
require_relative '../request_context'

class MetadataInterceptor < GRPC::ClientInterceptor

  def intercept(request, call, method_name, &block)
    call.metadata['request_id'] = RequestContext.request_id
    yield
  end

end