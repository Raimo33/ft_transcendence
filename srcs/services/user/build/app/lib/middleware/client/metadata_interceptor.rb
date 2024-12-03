# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    metadata_interceptor.rb                            :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/12/03 13:30:58 by craimond          #+#    #+#              #
#    Updated: 2024/12/03 18:01:21 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

class MetadataInterceptor < GRPC::ClientInterceptor

  def intercept(request, call, method_name, &block)
    call.metadata['request_id'] = SecureRandom.uuid
    yield
  end

end