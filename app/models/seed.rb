class Seed < ActiveRecord::Base

  acts_as_archive

  belongs_to :version
  belongs_to :scf
  has_many :confirmstats

  validates_presence_of  :zipcode, :version_id
  validates_uniqueness_of :imb, :scope => :version_id

  before_save :set_scf_from_zip!

  def imb_id
    self.imb && self.imb.length >= 19 ? self.imb.slice(0..19) : self.id
  end

  def self.set_first_hits!
    connection.update(%{
      UPDATE seeds AS s
        SET s.zip_hit = (SELECT cs.scf
                          FROM confirmstats AS cs, scf_zip_prefixes AS scf_zips 
                          WHERE s.id = cs.seed_id AND s.scf_id = scf_zips.scf_id AND scf_zips.prefix = cs.scf_prefix LIMIT 1
                          ),
            s.first_hit = (SELECT cs.processed_at
                          FROM confirmstats AS cs, scf_zip_prefixes AS scf_zips 
                          WHERE s.id = cs.seed_id AND s.scf_id = scf_zips.scf_id AND scf_zips.prefix = cs.scf_prefix LIMIT 1
                          )      
        WHERE s.zip_hit IS NULL
    })
  end
  
  def self.set_first_hits_by_version!(version)
    connection.update(%{
      UPDATE seeds AS s
        SET s.zip_hit = (SELECT cs.scf
                          FROM confirmstats AS cs, scf_zip_prefixes AS scf_zips 
                          WHERE s.id = cs.seed_id AND s.scf_id = scf_zips.scf_id AND scf_zips.prefix = cs.scf_prefix LIMIT 1
                          ),
            s.first_hit = (SELECT cs.processed_at
                          FROM confirmstats AS cs, scf_zip_prefixes AS scf_zips 
                          WHERE s.id = cs.seed_id AND s.scf_id = scf_zips.scf_id AND scf_zips.prefix = cs.scf_prefix LIMIT 1
                          )      
        WHERE s.zip_hit IS NULL AND s.version_id = #{version.id}
    })
  end

  def at_final_scf
    # not used anywhere but handy to keep around for debugging
    return false if self.zip_hit.nil?
    self.scf.zips.map{|p| p.prefix}.include?(self.zip_hit.slice(0..2))
  end

  def self.date_first_hit_by_version(version)
    self.find(:first, :conditions => ['version_id = ? && first_hit IS NOT null', version.id], :order => 'first_hit asc').first_hit
  end

  def self.date_last_hit_by_version(version)
    padding = 2.days
    seed = self.find(:first, :conditions => ['version_id = ? && first_hit IS NOT null', version.id], :order => 'first_hit desc')
    return false unless seed
    seed.first_hit + padding
  end

  def self.hit_by_date(version, date = version.mail_date.to_date)
   # I believe this already accounts for whether the seed is at it's final destnation
   Seed.count(:all, :conditions => ["version_id = ? && first_hit BETWEEN ? AND ?", version.id, date.at_beginning_of_day, date.end_of_day])
  end

  def self.number_delivered(version)
    Seed.count(:all, :conditions => ['version_id = ? AND first_hit IS NOT ?', version, nil])
  end

  def self.number_delivered_in_region(version,region)
     Seed.count(:all,:include=>:scf, :conditions => ['version_id = ? && scfs.region = ? AND first_hit IS NOT ?', version, region, nil])
  end

  def self.percent_delivered(version)
    total = Seed.count(:all, :conditions => ['version_id = ?', version]).to_f
    delivered = version.c_total_seeds_delivered.to_f
    if total > 0
      delivered/total * 100.0
    else
      0.0
    end
  end

  def self.average_delivered(version)
    q = 0
    days = 0
    Seed.find_each(:conditions => ['version_id = ? AND first_hit IS NOT ?', version, nil]) do |seed|
      q = seed.first_hit - seed.version.mail_date
      days += q if q
    end
    if days > 0
      count = version.c_total_seeds_delivered
      (days/(60*60*24*count)).to_i
    else
      nil
    end
  end

  def self.regional_average_delivery(version, region)
    seeds = Seed.find(:all,:include=>:scf, :conditions => ['version_id = ? && scfs.region = ? AND first_hit IS NOT ?', version, region, nil],:batch_size => 10000)
    q = 0
    days = 0
    if seeds.size > 0
      for seed in seeds 
        q = seed.first_hit - seed.version.mail_date
        days += q if q
      end
      count = Seed.number_delivered_in_region(version, region)
      average_days = (days/(60*60*24*count)).to_i
          return average_days.to_s + ' days'
    else
      'n/a'
    end
  end
  
  def self.delivery_exception(region, version, percent)
    #need to find out what seeds arrived, but take into account the amount of time expected for it to arrive.  The default transit time is 10 days.. We then subract the destination and origins to find the padding we give.  For example, if something leaves from an east coast mailshop and goes to an east coast SCF, 10 - 10 is 0 days. Likewise if something leaves from a west coast mailshop and goes to a westcoast SCF the padding is 16 - 16 or 0 days.  A west coast mailshop sending east (or vise versa) would get 16-10 or 6 days padding before showing up here.
    @array = Array.new
    missed_seeds = 0
    default_padding = 10.days
    region_types = {
    :east => 10, 
    :central => 12, 
    :mountain => 14, 
    :west => 16
    }
    total_seeds = Seed.count(:all,:include=>:scf, :conditions => ['version_id =? && scfs.region = ?', version, region])
    unhit_seeds = Seed.count(:all,:include=>:scf, :conditions => ['version_id =? && scfs.region = ? && zip_hit IS ?', version, region, nil])
    regional_seeds = Seed.find(:all,:include=>:scf, :conditions => ['version_id =? && scfs.region = ? && zip_hit IS NOT ?', version, region, nil])
    for seed in regional_seeds
     if seed.first_hit >=  (version.mail_date + ((region_types[version.mailshop.region.to_sym].to_i) - (region_types[seed.scf.region.to_sym].to_i)).abs.days ) + default_padding 
       missed_seeds += 1
     end
    end
    if total_seeds > 0
      miss_percent = 100.00 * (unhit_seeds.to_f + missed_seeds.to_f) / (total_seeds.to_f)
      instance_variable_set("@#{region.to_sym}", miss_percent)
      version.east = @east
      version.west = @west 
      version.central = @central
      version.mountain = @mountain
      version.save
      missed_seeds = 0
      @array << version if miss_percent > percent
    end
    
  end
  
   def self.delivery_summary(region, version)
   #The delivery summary is similar to the delivery_exception but does account for regional padding. i.e. It doesn't matter that a seed arrived later than expected as long as it arrived.
    @array = Array.new
    missed_seeds = 0
    total_seeds = Seed.count(:all,:include=>:scf, :conditions => ['version_id =? && scfs.region = ?', version, region])
    unhit_seeds = Seed.count(:all,:include=>:scf, :conditions => ['version_id =? && scfs.region = ? && zip_hit IS ?', version, region, nil])
    regional_seeds = Seed.find(:all,:include=>:scf, :conditions => ['version_id =? && scfs.region = ? && zip_hit IS NOT ?', version, region, nil])
    
#   for seed in regional_seeds
#    if seed.first_hit >=  (version.mail_date + ((region_types[version.mailshop.region.to_sym].to_i) - (region_types[seed.region.to_sym].to_i)).abs.days ) + default_padding 
#      missed_seeds += 1
#    end
#   end
    
    if total_seeds > 0
      miss_percent = 100.00 * (unhit_seeds.to_f) / (total_seeds.to_f)
      instance_variable_set("@#{region.to_sym}", miss_percent)
      version.east = @east
      version.west = @west 
      version.central = @central
      version.mountain = @mountain
      version.save
      missed_seeds = 0
      @array << version
    end
    
  end
  
  def self.populate_scfs_from_zip!(seeds)
    seeds.each do |s| 
      s.set_scf_from_zip!
      s.save!
    end
  end
  
  def set_scf_from_zip!
    self.scf = Scf.find(:first, :include => :scf_zip_prefixes, :conditions => ['scf_zip_prefixes.prefix LIKE (?)', "#{self.zipcode.slice(0..2)}%"])
    #self.state = self.scf.state_abbrev #commented out by VW as state scf isn't necessarily seed scf (per Scott Siebenberg on June 7 2010)
  end

  def self.build_aggregate_data!
    # Total quantity sent
    Seed.connection.execute(%{
      UPDATE jobs AS j, (
        SELECT v.job_id AS job_id, SUM(v.quantity) AS total_qty_sent
        FROM versions AS v
          WHERE v.job_id IS NOT NULL
        GROUP BY v.job_id
      ) AS tqs
      SET j.c_total_qty_sent = tqs.total_qty_sent
      WHERE j.id = tqs.job_id;
    })

    # Number of non-zero versions
    Seed.connection.execute(%{
      UPDATE jobs AS j, (
        SELECT v.job_id AS job_id, COUNT(DISTINCT v.id) AS number_of_non_zero_versions
          FROM versions AS v
            JOIN seeds AS s ON s.version_id = v.id
          WHERE s.zip_hit IS NOT NULL
          GROUP BY v.job_id
      ) AS nonzv
     SET c_number_of_non_zero_versions = nonzv.number_of_non_zero_versions
     WHERE j.id = nonzv.job_id
    })

    # Fill out the rest of the stats
    Seed.connection.execute(%{
      UPDATE jobs AS j, (
        SELECT j.id AS job_id,
          COUNT(s.id) AS total_seeds_sent,
          COUNT(s.zip_hit) AS total_seeds_delivered,
          (COUNT(s.zip_hit) / COUNT(s.id)) * 100 AS total_percent_seeds_delivered,
          FORMAT(AVG(DATEDIFF(s.first_hit, v.mail_date)), 2) AS summed_average_delivered,
          m.name AS first_mailshop
        FROM jobs AS j
          JOIN versions AS v ON v.job_id = j.id
          JOIN seeds AS s ON s.version_id = v.id
          JOIN mailshops AS m ON v.mailshop_id = m.id
        GROUP BY job_id
      ) AS stats
      SET j.c_total_seeds_sent = stats.total_seeds_sent,
        j.c_total_seeds_delivered = stats.total_seeds_delivered,
        j.c_total_percent_seeds_delivered = stats.total_percent_seeds_delivered,
        j.c_summed_average_delivered = stats.summed_average_delivered,
        j.c_first_mailshop = stats.first_mailshop
      WHERE j.id = stats.job_id
    })
  end

  ## DEAD CODE.. no longer needed since we aren't using P Files
  #def self.find_given_confirmstat(confirmstat_filename, confirmstat_scf, confirmstat_postnet)
    #if confirmstat_filename.match /^p/i
      ##it's an old file.. find the data the old way
      #find(
      #:first, 
      #:conditions => ['versions.planet_code = ? AND seeds.postnet = ?', confirmstat_scf, confirmstat_postnet], 
      #:include => :version
      #)
    #elsif confirmstat_filename.match /^f/i
      ##new file so we process it the new way
      ##scf is the destination zipcode (column 1 of new USPS data)
      ##postnet is column 4 of new USPS data, but we 
      #find(
        #:first,
        #:conditions => ['zipcode LIKE (?) and imb LIKE (?)', "#{confirmstat_scf}%", "#{confirmstat_postnet.slice!(0..19)}%"]
        #)
    #end
  #end
  
#  def self.find_by_planet_and_postnet(planet,postnet)
#    find(
#      :first, 
#      :conditions => ['versions.planet_code = ? AND seeds.postnet = ?', planet, postnet], 
#      :include => :version
#    )
#  end

#  def self.find_by_zipcode_and_imb(scf,postnet)
#    #scf is the destination zipcode (column 1 of new USPS data)
#    #postnet is column 4 of new USPS data, but we 
#    find(
#      :first,
#      :conditions => ['zipcode LIKE (?) and imb LIKE (?)', "#{scf}%", "#{postnet.slice!(0..19)}%"]
#      )
#  end

end # end seed.rb
