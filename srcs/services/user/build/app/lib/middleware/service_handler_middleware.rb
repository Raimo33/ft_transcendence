# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    service_handler_middleware.rb                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: craimond <bomboclat@bidol.juis>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/11/26 18:35:24 by craimond          #+#    #+#              #
#    Updated: 2024/11/26 19:32:13 by craimond         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

module ServiceHandlerMiddleware
  def self.prepended(base)
    class << base
      def method_added(method_name)
        return if @processing
        @processing = true
        
        original = instance_method(method_name)
        define_method(method_name) do |request, call|

          stack = -> (req, cl) { original.bind(self).call(req, cl) }
          
          MiddlewareRegistry.instance.middlewares.reverse_each do |middleware|
            current_stack = stack
            stack = -> (req, cl) { middleware.new(current_stack).call(req, cl) }
          end
          
          stack.call(request, call)
        end
        
        @processing = false
      end
    end
  end
end