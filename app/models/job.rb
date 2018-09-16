require 'net/scp'
require 'fileutils'
class Job < ActiveRecord::Base

  acts_as_archive

  attr_accessor :uploaded_seeds_file

  belongs_to :client
  belongs_to :mailshop
  has_many :versions, :dependent => :destroy, :order => 'version_name'
  belongs_to :creator, :class_name => "User", :foreign_key => "user_id"

  validates_presence_of :job_number
  validates_uniqueness_of :job_number
  validates_numericality_of :job_number, :only_integer => true,
                            :greater_than_or_equal_to => 1, :message => "must be an integer."
  validates_presence_of :client_id

  accepts_nested_attributes_for :versions, :allow_destroy => true,
    :reject_if => lambda { |a| a[:version_name].blank? }

  alias_attribute :total_qty_sent, :c_total_qty_sent
  alias_attribute :total_seeds_sent, :c_total_seeds_sent
  alias_attribute :first_mailshop, :c_first_mailshop
  alias_attribute :total_seeds_delivered, :c_total_seeds_delivered
  alias_attribute :total_percent_seeds_delivered, :c_total_percent_seeds_delivered
  alias_attribute :summed_average_delivered, :c_summed_average_delivered
  alias_attribute :number_of_non_zero_versions, :c_number_of_non_zero_versions
  alias_attribute :total_returns_sent, :c_total_returns_sent
  alias_attribute :total_returns_received, :c_total_returns_received

  after_save :copy_seed_file, :if => :meets_criteria?
  after_save :recalc_all!

  mount_uploader :seeds_definition_file, SeedUploader

#   Search Index.
  define_index do
    has client(:id), :as => :client_id

    indexes :job_name, :sortable => true
    indexes :job_number, :sortable => true

    indexes client.organization, :sortable => true
    indexes versions.mailshop.name, :as => :mailshop_name, :sortable => true
    indexes versions.version_name, :as => :version_name, :sortable => true

    indexes :c_total_qty_sent, :sortable => true
    indexes :c_first_mailshop, :sortable => true
    indexes :mail_date, :sortable => true
    indexes :c_total_seeds_sent, :sortable => true
    indexes :c_total_seeds_delivered, :sortable => true
    indexes :c_total_percent_seeds_delivered, :sortable => true
    indexes :c_summed_average_delivered, :sortable => true
    indexes :c_total_returns_sent, :sortable => true
    indexes :c_total_returns_received, :sortable => true

    set_property :delta => false
  end

  def recalc_all!
    is_running = false
    Resque.working.each do |worker|
      id = worker.job["payload"]["args"].first
      
      if self.id.to_s == id.to_s
        is_running = true
      end
    end
    
    Resque.enqueue(RecalcAll, self.id, self.uploaded_seeds_file) unless is_running
    
    #process_seeds_definition_file!

    #versions.reload

    #recalc_all_versions!
    #recalc_total_seeds_delivered!
    #recalc_total_percent_seeds_delivered!
    #recalc_summed_average_delivered!
    #recalc_number_of_non_zero_versions!
    #recalc_first_mailshop!
    #recalc_total_seeds_sent!
    #recalc_total_qty_sent!

    #self.send(:update_without_callbacks)
  end

  def to_param
    job_number
  end

  def to_json(options)
    attributes.merge(:versions => versions.map(&:attributes_for_graph)).to_json
    # above line is equivalent to:
    # attributes.merge(:versions => versions.map{|x| x.attributes_for_graph}).to_json
  end

  def copy_seed_file
    job = Job.find(self.id)
    path = job.seeds_definition_file.current_path
    temp_path = self.seeds_definition_file.current_path
    copy_with_path(temp_path, path) unless path == temp_path
    remote_path = "#{APP_CONFIG['deploy_path']}#{APP_CONFIG['seed_storage']}#{APP_CONFIG['seeds_path']}"
    Rails.logger.fatal '#####################################'
    Rails.logger.fatal path.split('/')[0...-1].join('/')
    Rails.logger.fatal temp_path
    Rails.logger.fatal remote_path

    Net::SCP.start(APP_CONFIG['seed_file_server'], APP_CONFIG['user'], :password => APP_CONFIG['password']) do |scp|
      scp.upload! path.split('/')[0...-1].join('/'), remote_path, :recursive => true
    end
  end

  def meets_criteria?
    (Rails.env.staging? or Rails.env.production?) and seeds_definition_file.current_path.present?
  end

  def copy_with_path(src, dst)
    FileUtils.mkdir_p(File.dirname(dst))
    FileUtils.cp(src, dst)
  end

  def total_returns_sent_numbers
    if self.track_returns_type == 'version'
      self.versions.collect {|v| v.total_returns_sent_numbers }.sum
    elsif self.track_returns_type == 'job'
      finalarr = connection.select_all(%{
        SELECT IFNULL(count(*),0) 'Returns_Scanned'
        FROM (
          SELECT *
          FROM confirmstats
          WHERE version_tracking_number="0000"
          AND job_number=#{self.job_number}
          AND tracking_type in ('050', '052')
          AND operation in ('252', '261', '271', '281', '361', '371', '391', '481', '491', '501', '821', '831', '841', '851', '861', '871', '881', '891', '961', '971')
        ) as cs, scf_zip_prefixes as szp, scfs
        WHERE cs.scf_prefix=szp.prefix
        AND szp.scf_id=scfs.id
      })
      
      finalarr.collect {|a| a['Returns_Scanned'] }.sum
    else
      0
    end
  end

  def total_returns_received_numbers
    Confirmstat.returns_by_job(self).size
  end

  def self.build_aggregate_data!
    connection.verify!
    
    Job.all.each do |job|
      connection.execute "UPDATE jobs SET c_total_returns_sent = #{job.total_returns_sent_numbers}, c_total_returns_received = #{job.total_returns_received_numbers} where id = #{job.id}"
    end
  end
end
