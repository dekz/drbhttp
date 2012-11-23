require './http.rb'
begin
  uri = 'drbhttp://localhost:12345'
#  drb = DRb::DRbServer.new 'drbhttp://localhost:12345'
#  puts drb
  DRb.start_service uri, {}
  DRb.thread.join()
  trap :INT do
    exit 0
  end
rescue Exception => e
  puts e
end
