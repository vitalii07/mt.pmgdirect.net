job_type :rake,    "cd :path && RAILS_ENV=:environment bundle exec rake :task --silent :output"
job_type :bash,     "cd :path && :task"

every 1.day, :at => "6:30am" do
 rake "thinking_sphinx:rebuild"
end

every :reboot do
  rake "thinking_sphinx:start"
end

every 1.day, :at => "7:30pm" do
  command "/usr/bin/find /home/deploy/mailtracker_backups/ -type f -atime +8 -exec rm -f {} \;"
end

every 1.day, :at => "8:00pm" do
  bash "db/mailtracker_backup"
end