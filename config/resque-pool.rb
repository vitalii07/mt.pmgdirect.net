resque_pidfile = Rails.root.join("tmp/pids/resque-pool.pid")

if File.exists?(resque_pidfile)
  pid = File.read(resque_pidfile).to_i

  begin
    Process.getpgid( pid )
    running = true
  rescue Errno::ESRCH
    running = false
  end

  if running == false
    system "rm #{resque_pidfile}"
    system "bundle exec resque-pool --daemon --environment #{Rails.env}"
  end
else
  system "bundle exec resque-pool --daemon --environment #{Rails.env}"
end
