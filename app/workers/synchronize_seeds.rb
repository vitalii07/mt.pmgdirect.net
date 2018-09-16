class SynchronizeSeeds
  extend Resque::Plugins::JobStats::Duration

  @queue = :sync_seeds

  def self.perform(file_name, date)

    puts "SynchronizeSeeds for #{file_name}, #{date} started at #{Time.now}"

    Confirmstat.associate_seeds!

    Seed.set_first_hits!

    Seed.build_aggregate_data!

    Version.build_aggregate_data!

    Job.build_aggregate_data!

    # set up the status of the file processing to successed
    Utils.status_message(file_name, "successed", date)

    puts "SynchronizeSeeds for #{file_name}, #{date} finished at #{Time.now}"
  end

  def self.on_failure(*args)
    # set up the status of the file processing to failed
    file_name = args[1]
    date = args[2].to_date
    Utils.status_message(file_name, "failed", date)
  end

end
