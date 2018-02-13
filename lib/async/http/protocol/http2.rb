# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require_relative 'request'
require_relative 'response'

require 'http/2'

module Async
	module HTTP
		module Protocol
			# A server that supports both HTTP1.0 and HTTP1.1 semantics by detecting the version of the request.
			class HTTP2
				def initialize(stream)
					@peer = stream.io
					
					@controller = ::HTTP2::Server.new
					
					@controller.on(:frame) do |data|
						@peer.write data
					end
				end
				
				def receive_requests(&block)
					# emits new streams opened by the client
					@controller.on(:stream) do |stream|
						request = Request.new
						request.version = "HTTP/2.0"
						request.headers = {}
						
						# stream.on(:active) { } # fires when stream transitions to open state
						# stream.on(:close) { } # stream is closed by client and server

						stream.on(:headers) do |headers|
							headers.each do |key, value|
								if key == ':method'
									request.method = value
								elsif key == ':path'
									request.path = value
								else
									request.headers[key] = value
								end
							end
						end
						
						stream.on(:data) do |body|
							request.body = body
						end

						stream.on(:half_close) do
							response = yield request
							
							# send response
							stream.headers(
								':status' => response[0].to_s,
							)
							
							stream.headers(response[1]) unless response[1].empty?
							
							response[2].each do |chunk|
								stream.data(chunk, end_stream: false)
							end
							
							stream.data("")
						end
					end
					
					while data = @peer.read(1024)
						@controller << data
					end
				end
				
				def send_request(request, &block)
					raise RuntimeError.new("Not implemented")
				end
			end
		end
	end
end