class ArchiveJobs
  extend Resque::Plugins::JobStats::Duration

  @queue = :archive_jobs

  def self.perform

    date = 6.months.ago.to_date

    puts "Jobs Archived started at #{Time.now}"
    # Confirmstat.find_in_batches(:conditions => [ "file_date <= ?", date ], :batch_size=> 10) { |batch| batch.each(&:destroy) }

    ## moving records over 6 months old from confirmstats to archived_confirmstats
    ActiveRecord::Base.connection.execute("insert into archived_confirmstats select cs.id, cs.scf, cs.operation, cs.processed_at, cs.postnet, cs.planet, cs.file_date, cs.created_at, cs.seed_id, cs.stat_file, cs.csheader_id, cs.scf_prefix, cs.tracking_type, cs.job_number, cs.version_tracking_number, cs.state, current_timestamp() from confirmstats as cs where cs.file_date <= '#{date}'")

    ## deleting records over 6 months old from confirmstats
    ActiveRecord::Base.connection.execute("delete from confirmstats where file_date <= '#{date}'")

    # Job.destroy_all(['created_at <= ?', (Date.today - 6.months)])

    ## instead of Job.destroy_all
    job_ids = Job.find(:all, :conditions => ["created_at <= ?", date], :select => "id").collect(&:id)
    version_ids = Version.find(:all, :conditions => ["job_id in (?)", job_ids], :select => "id").collect(&:id)

    Job.delete_all(['id in (?)', job_ids])
    Version.delete_all(['job_id in (?)', job_ids])
    Seed.delete_all(['version_id in (?)', version_ids])
    #### End ####

    puts "USPS Data Archived finished at #{Time.now}"
  end

end
