class Job < ActiveRecord::Base
  belongs_to :client
  belongs_to :mailshop
  has_many :versions
  belongs_to :creator, :class_name => "User", :foreign_key => "user_id"

  alias_attribute :total_qty_sent, :c_total_qty_sent
  alias_attribute :total_seeds_sent, :c_total_seeds_sent
  alias_attribute :first_mailshop, :c_first_mailshop
  alias_attribute :total_seeds_delivered, :c_total_seeds_delivered
  alias_attribute :total_percent_seeds_delivered, :c_total_percent_seeds_delivered
  alias_attribute :summed_average_delivered, :c_summed_average_delivered
  alias_attribute :number_of_non_zero_versions, :c_number_of_non_zero_versions

  mount_uploader :seeds_definition_file, SeedUploader


  def recalc_all_versions!
    self.versions.each(&:recalc_all!)
  end

  def recalc_total_qty_sent!
    self.c_total_qty_sent = versions.map {|x| x.quantity}.sum
  end

  def recalc_total_seeds_sent!
    self.c_total_seeds_sent = versions.map {|y| y.seeds.size}.sum
  end

  def recalc_first_mailshop!
    if versions.first && versions.first.mailshop
      if versions.first.mailshop.address.size == 0
        self.c_first_mailshop = versions.first.mailshop.name
      else
        self.c_first_mailshop = versions.first.mailshop.name + "(" + versions.first.mailshop.address + ")"
      end
    end
  end

  def recalc_total_seeds_delivered!
    #self.c_total_seeds_delivered = versions.inject(0) {|memo, v| memo += Seed.number_delivered(v)[1]}
    self.c_total_seeds_delivered = versions.inject(0) {|memo, v| memo += v.c_total_seeds_delivered}
  end

  def recalc_total_percent_seeds_delivered!
    delivered = versions.map{|v| Seed.percent_delivered(v)}
    if delivered.length > 0
      self.c_total_percent_seeds_delivered =
        delivered.inject(0) {|memo, d| memo += d} / delivered.length
    end
  end

  def recalc_summed_average_delivered!
    #delivered = versions.map{|v| Seed.average_delivereds(v)}.compact
    delivered = versions.map{|v| v.c_summed_average_delivered}.compact
    if delivered.length > 0
      self.c_summed_average_delivered =
      delivered.inject(0) {|memo, d| memo += d} / delivered.length
    else
      self.c_summed_average_delivered = 0
    end

    #recalc_number_of_non_zero_versions! being done in same method (commented below)
    self.c_number_of_non_zero_versions = delivered.length
  end

  def recalc_number_of_non_zero_versions!
    #self.c_number_of_non_zero_versions = versions.map{|v| Seed.average_delivereds(v)}.compact.length
  end

  def process_seeds_definition_file!
    if(self.seeds_definition_file)
      file = File.open(self.seeds_definition_file.current_path)
      versions_by_name = self.versions.inject({}) {|hash, version|
        hash[version.name] = version
        hash
      }

      # moving old seed data to the archive_seeds
      self.versions.each do |version|
        # version.seeds.delete_all
        connection.verify!
        # inserting old seeds to archived_seeds
        connection.execute "insert into archived_seeds select s.id, s.version_id, s.scf_id, s.reference_name, s.name_prefix, s.first_name, s.last_name, s.address, s.address2, s.city, s.state, s.zipcode, s.postnet, s.physical, s.core, s.created_at, s.updated_at, s.first_hit, s.zip_hit, s.imb, s.planet, current_timestamp(), s.scf_processed from seeds as s where s.version_id = #{version.id}"
        # deleting old seeds from seeds
        connection.execute "delete from seeds where version_id = #{version.id}"
      end

      version_names = versions_by_name.keys
      parsed_data = {}
      version_names.each do |key|
        parsed_data[key] = []
      end

      import_data = FasterCSV.parse(file)

      invalid_version_names = []

      import_data.each do |row|
        if version_names.include?(row[3])
          parsed_data[row[3]] << row
        elsif row[0] != "IM barcode Digits" and row[1] != "ZIP+4" and row[2] != "State" and row[3] != "File" # except for the header of the file
          invalid_version_names << row[3]
        end
      end

      parsed_data.each do |data|
        version = versions_by_name[data.first]

        data.last.in_groups_of(500, false) do |rows|
          inserts = []
          rows.each do |row|
            scf = Scf.find(:first, :include => :scf_zip_prefixes, :conditions => ['scf_zip_prefixes.prefix LIKE (?)', "#{row[1].to_s.slice(0..2)}%"])
            inserts.push %{( '#{row[0].to_s}', '#{row[1].to_s}', '#{row[2].to_s}', '#{row[0].to_s[0..19]}', #{version.id}, #{scf.id} )}
          end
          connection.verify!
          connection.execute "INSERT INTO seeds (imb, zipcode, state, planet, version_id, scf_id) VALUES #{inserts.join(', ')}"
        end

        Seed.set_first_hits_by_version!(version)
      end
    end

    invalid_version_names.uniq!

    if invalid_version_names.present? # if there is any unmatched version names in the seeds file
      Utils.seeds_file_upload_message("version names unmatched", self.id, invalid_version_names)
    else # if there is not any unmatched version names in the seeds file
      Utils.seeds_file_upload_message("seeds file processed", self.id)
    end
  end

end

class RecalcAll < Struct.new(:job_id)
  extend Resque::Plugins::JobStats::Duration

  @queue = :recalc_all
  def self.perform(job_id, uploaded_seeds_file)

    puts "Recalc All of Job ##{job_id} started at #{Time.now}"

    job = ::Job.find(job_id)

    if job.seeds_definition_file && job.seeds_definition_file.current_path.present? && uploaded_seeds_file == true
      if File.exists?(job.seeds_definition_file.current_path)
        Utils.seeds_file_upload_message("seeds file processing", job_id)
        job.process_seeds_definition_file!
      end
    end

    job.versions.reload

    job.recalc_all_versions!
    job.recalc_total_seeds_delivered!
    job.recalc_total_percent_seeds_delivered!
    job.recalc_summed_average_delivered!
    job.recalc_number_of_non_zero_versions!
    job.recalc_first_mailshop!
    job.recalc_total_seeds_sent!
    job.recalc_total_qty_sent!

    v = Version.find(:first, :conditions => ['job_id = ?', job.id], :order => 'mail_date asc')
    if v
      job.mail_date = v.mail_date
    end

    job.send(:update_without_callbacks)
    Notifier.deliver_job_import(job)

    puts "Recalc All of Job ##{job_id} finished at #{Time.now}"
  end
end
