job_type :rake,    "cd :path && RAILS_ENV=:environment bundle exec rake :task --silent :output"
job_type :bash,     "cd :path && :task"

every 1.week, :at => "10:00pm" do
  bash "db/mailtracker_archiver"
end

every 1.week, :at => "9:00pm" do
  bash "db/mailtracker_cleanup_old_archives"
end

every 1.day, :at => "10:30am" do
  rake "jobs:archive"
end

every 1.day, :at => "4:30am" do
  rake "stats:process"
end

every 1.day, :at => "7:30pm" do
  command "/usr/bin/find /home/deploy/mailtracker_backups/ -type f -atime +8 -exec rm -f {} \;"
end

every 1.month, :at => "8:30am" do
  command "/usr/bin/find /tmp/Archive/ -type f -atime +70 -exec rm -f {} \;"
end

every :reboot do
  bash "bundle exec resque-pool -d -E #{@environment} start --config config/resque-pool-worker.yml"
end