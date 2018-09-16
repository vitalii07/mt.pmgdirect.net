class JobsController < ApplicationController

  before_filter :login_required

  def delivery_bargraph
    @job = Job.find_by_job_number(params[:id])

    @returns = {}

    if @job.track_returns_type == 'job'
      # all returns by job
      returns = Confirmstat.returns_by_job(@job)

      @returns[:job] = []
      mail_date = nil

      if returns.present?
        # last processed date
        last_hit_date = returns.sort_by(&:processed_at).last.processed_at + 2.days

        days_active = 0
        
        if @job.mail_date.present?
          mail_date = @job.mail_date
        else
          earliest_version_mail_date = @job.versions.collect(&:mail_date).min
          if earliest_version_mail_date.present?
            mail_date = earliest_version_mail_date
          else
            mail_date = returns.sort_by(&:processed_at).first.processed_at
          end
        end

        days_active = ((last_hit_date - mail_date)/(60*60*24)).to_i
        
        days_active.times do |day|  
          date = mail_date + day.days
          count_by_date = returns.select{|cs| cs.processed_at > date.at_beginning_of_day and cs.processed_at < date.end_of_day}.count
          @returns[:job] << count_by_date
        end
      end

      @returns[:first_hit_date] = mail_date

    elsif @job.track_returns_type == 'version'
      @returns[:version] = {}
      @job.versions.each do |version|
        returns = Confirmstat.returns_by_version(version)
        @returns[:version][version.id.to_s] = []
        if returns.present?
          last_hit_date = returns.sort_by(&:processed_at).last.processed_at + 2.days
          days_active = ((last_hit_date - version.mail_date)/(60*60*24)).to_i

          days_active.times do |day|
            date = version.mail_date + day.days
            count_by_date = returns.select{|cs| cs.processed_at > date.at_beginning_of_day and cs.processed_at < date.end_of_day}.count
            @returns[:version][version.id.to_s] << count_by_date
          end
        end
      end
    end

    rescue
      flash[:notice] = "This report is not yet ready"
      redirect_to :back
  end

  def returns_map_by_job
    @job = Job.find_by_job_number(params[:id])
    if allowed_to_see?(@job)

      @map = GMap.new("map_div")
      @map.control_init(:large_map => true)
      @map.center_zoom_init([37.09024,-95.712891],4)

      @baseIcon =GIcon.new(:copy_base =>GIcon::DEFAULT,:image => "/images/grey.png", :icon_size => GSize.new( 12,12 ), :icon_anchor => GPoint.new(12,12), :info_window_anchor => GPoint.new(9,2))
      @map.icon_global_init( @baseIcon, "ricon")

      version_tracking_numbers_cond = ''

      version_ids = @job.versions.collect(&:id)
      @version_ids = version_ids.join(",")

      version_tracking_numbers = @job.versions.collect(&:version_tracking_number)
      version_tracking_numbers.reject!{|n| n == "" or n.nil?}
      version_tracking_numbers << "0000"
      version_tracking_numbers = version_tracking_numbers.join(",")
      version_tracking_numbers_cond+= "AND confirmstats.version_tracking_number in (#{version_tracking_numbers})"

      scfs=Seed.connection.select_all(%{
        SELECT s.scf_id, s.description, s.lat, s.lng,
          IFNULL(s.seeds_sent,0) 'seedssent', IFNULL(cs.returns,0) 'hitseeds',
          format(IFNULL(convert(((cs.returns*100)/IFNULL(s.seeds_sent,cs.returns)),decimal(65,2)),0),0) 'hitperc',
          IFNULL(cs.avg_delivery,0) 'avg_delivery'
        FROM (
          SELECT scf_id, scfs.description as description, 
            scfs.lat as lat, scfs.lng as lng,
            count(seeds.id) as seeds_sent
          FROM seeds, versions , scfs
          WHERE seeds.version_id=versions.id
          AND scfs.id=seeds.scf_id 
          AND version_id in (#{@version_ids})
          AND length(state)<3 
          GROUP BY scf_id
        ) AS s
        LEFT JOIN (
        SELECT scf_id, scfs.description as description, count(*) as returns, state,
          convert(format(ifnull(avg(datediff(cs.processed_at,versions.mail_date)),0),2),decimal(65,2)) as avg_delivery 
        FROM (
          SELECT *
          FROM confirmstats
          WHERE confirmstats.version_tracking_number is not null
          #{version_tracking_numbers_cond}
          AND job_number=#{@job.job_number}
          AND tracking_type in ('050', '052')
          AND operation in ('252', '261', '271', '281', '361', '371', '391', '481', '491', '501', '821', '831', '841', '851', '861', '871', '881', '891', '961', '971')
        ) as cs, scf_zip_prefixes as szp, scfs, versions
        WHERE cs.scf_prefix=szp.prefix
        AND szp.scf_id=scfs.id
        AND versions.job_id=#{@job.id}
        AND versions.version_tracking_number=cs.version_tracking_number
        GROUP BY scf_id
        ) AS cs
        ON cs.scf_id=s.scf_id 
        GROUP BY s.scf_id
        
        UNION

        SELECT cs.scf_id, cs.description, 
          cs.lat, cs.lng,
          IFNULL(s.seeds_sent,0) 'seedssent', IFNULL(cs.returns,0) 'hitseeds',
          format(IFNULL(convert(((cs.returns*100)/IFNULL(s.seeds_sent,cs.returns)),decimal(65,2)),0),0) 'hitperc',
          IFNULL(cs.avg_delivery,0) 'avg_delivery'
        FROM (
          SELECT scf_id, count(seeds.id) as seeds_sent
          FROM seeds, versions , scfs
          WHERE seeds.version_id=versions.id
          AND scfs.id=seeds.scf_id 
          AND version_id in (#{@version_ids})
          AND length(state)<3 
          GROUP BY scf_id
        ) AS s
        RIGHT JOIN (
        SELECT scf_id, scfs.description as description, 
          scfs.lat, scfs.lng,
          count(*) as returns, state,
          convert(format(ifnull(avg(datediff(cs.processed_at,versions.mail_date)),0),2),decimal(65,2)) as avg_delivery  
        FROM (
          SELECT *
          FROM confirmstats
          WHERE confirmstats.version_tracking_number is not null
          #{version_tracking_numbers_cond}
          AND job_number=#{@job.job_number}
          AND tracking_type in ('050', '052')
          AND operation in ('252', '261', '271', '281', '361', '371', '391', '481', '491', '501', '821', '831', '841', '851', '861', '871', '881', '891', '961', '971')
        ) as cs, scf_zip_prefixes as szp, scfs, versions 
        WHERE cs.scf_prefix=szp.prefix
        AND szp.scf_id=scfs.id
        AND versions.job_id=#{@job.id}
        AND versions.version_tracking_number=cs.version_tracking_number 
        GROUP BY scf_id
        )
        AS cs
        ON cs.scf_id=s.scf_id 
        GROUP BY cs.scf_id
        })

      @total_returns = scfs.collect{|s| s["hitseeds"].to_i}.sum
      
      if scfs.empty?
        @total_returns_perc = 0
        @total_avg_delivered = 0
      else
        @total_returns_perc = scfs.collect{|s| s["hitperc"].to_f}.sum/scfs.count
        @total_avg_delivered = (scfs.collect{|s| s["avg_delivery"]}.sum/scfs.count).round(2)
      end
      
      for scf in scfs
        if scf["hitseeds"] > 0
          @map.overlay_init(GMarker.new([scf["lat"],scf["lng"]], :icon => GIcon.new( :image => "/images/green.png" , :icon_size =>GSize.new(12,12), :icon_anchor => GPoint.new(6,12) , :info_window_anchor => GPoint.new(4,2)), :title => "#"+ scfs.index(scf).to_s + " of " +  scfs.length.to_s + "-" + scf["description"] + " : [" + scf["hitseeds"].to_s  + "] " , :info_window => "<b>"+ " SCF :- " + scf["description"]+"</b><br> Seeds Sent : " + scf['seedssent'].to_s + "<br/> Returns : "+scf["hitseeds"].to_s + "<br/> % Scanned : "+ scf["hitperc"].to_s ))
        end  
      end
    end 
  end

  def search

    if pmg_super? || admin?
      @jobs = Job.search params[:query]

    elsif pmg_user?
      @jobs = Job.search params[:query],
        :with => { :client_id => current_user.clients.map{|x| x.id} }

    elsif client_su?
      @jobs = Job.search params[:query],
        :with => { :client_id => current_user.employer.subclients.map{|x| x.id} }

    elsif client?
      @jobs = Job.search params[:query], :with => {:client_id => current_user.client_id}

    end

    render :action => "index"
  end

  # GET /jobs
  # GET /jobs.xml
  def index
      if pmg_super? || admin?
        @jobs = Job.paginate :per_page => 15, :include => [:versions, :client],
                             :page => params[:page], 
                             :order => sort_order('created_at')

      elsif pmg_user?
         @jobs = Job.paginate :per_page => 15, :page => params[:page],
          :include => [:versions, :client],
          :conditions => ['client_id IN (?)', current_user.clients.map{|x| x.id}],
          :order => sort_order('job_name')

      elsif client_su?
        @jobs = Job.paginate :per_page => 15, :page => params[:page],
          :include => [:versions, :client],
          :conditions => ['client_id IN (?)', current_user.employer.subclients.map{|x| x.id}],
          :order => sort_order('job_name')

      elsif client?
      @jobs = Job.paginate :per_page => 15, :page => params[:page],
          :include => [:versions, :client],
          :conditions => ['client_id = ?', current_user.client_id],
          :order => sort_order('job_name')

      end
      
    # error messages
    if current_user.level == :admin
      @messages = Message.find(:all, :order => "updated_at desc")
    end
    
    respond_to do |format|
      format.html # index.rhtml
      format.xml  { render :xml => @jobs.to_xml }
    end
  end


  def admin_report
    @versions = Version.find(:all)  
  end

  def filter_jobs
    query =  '%' + params[:query] + '%'
    if pmg_super? || admin?
      @jobs = Job.find(:all, :include => :client, :conditions => ['job_number LIKE ? || clients.organization LIKE ? ', query, query])
    elsif pmg_user?
      @jobs = Job.find(:all, :conditions => ['job_number LIKE ? && client_id IN (?)', query, current_user.clients.map{|x| x.id}])
    elsif client_su?
      @jobs = Job.find(:all, :conditions => ['job_number LIKE ? && client_id IN (?)', query, current_user.client.subclients.map{|x| x.id}])
    else
      @jobs = Job.find(:all, :conditions => ['job_number LIKE ? && client_id = ?', query, current_user.client.id])
    end
    render :layout => false
  end

  # GET /jobs/1
  # GET /jobs/1.xml
  def show
    @job = Job.find_by_job_number(params[:id])
      if @job.present? and allowed_to_see?(@job)
        @job = Job.find_by_job_number(params[:id])
        @clients = Client.find(:all)
        @mailshops = Mailshop.find(:all)
        @versions = @job.versions
        respond_to do |format|
          format.html # show.rhtml
          format.xml  { render :xml => @job.to_xml }
          format.json { render :json => @job }
        end
      end
  end

  # GET /jobs/new
  def new
    @job = Job.new
    @clients = Client.find(:all)
    @mailshops = Mailshop.find(:all)
  end



  # GET /jobs/1;edit
  def edit
    @job = Job.find_by_job_number(params[:id])
    @clients = Client.find(:all)
    @mailshops = Mailshop.find(:all)
  end

  def add_version

  end

  # POST /jobs
  # POST /jobs.xml
  def create
    @job = Job.new(params[:job])
    @job.creator = current_user
    @clients = Client.find(:all)
    @mailshops = Mailshop.find(:all)

     # if any seeds file is uploaded, save the status to the job uploaded_seeds_file accessor
    @job.uploaded_seeds_file = true if params[:job][:seeds_definition_file].present?

    respond_to do |format|
      if @job.save
        if params[:job][:seeds_definition_file].present?
          flash[:notice] = 'Job was successfully created. Please stand by as seeds are loaded and processed.'
        else
          flash[:notice] = 'Job was successfully created'
        end
        format.html { redirect_to job_url(@job) }
        format.xml  { head :created, :location => job_url(@job) }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @job.errors.to_xml }
      end
    end
  end

  # PUT /jobs/1
  # PUT /jobs/1.xml
  def update
    @job = Job.find_by_job_number(params[:id])
    @job.client_id = params[:job][:client_id]

    # if any seeds file is uploaded, save the status to the job uploaded_seeds_file accessor
    @job.uploaded_seeds_file = true if params[:job][:seeds_definition_file].present?

    respond_to do |format|
      if @job.update_attributes(params[:job])
        if params[:job][:track_returns_type] == "job"
          @job.versions.each do |version|
            version.version_tracking_number = "0000"
            version.save
          end
        end

        if @job.errors.empty?
          if params[:job][:seeds_definition_file].present?
            flash[:notice] = 'Job was successfully updated. Please stand by as seeds are loaded and processed.'
          else
            flash[:notice] = 'Job was successfully updated'
          end
        else
          flash[:notice] = "Job sucessfully updated with the following warnings: " + @job.errors.full_messages[0,10].join("\n")
        end
        format.html { redirect_to job_url(@job) }
        format.xml  { head :ok }
      else
        flash[:notice] = @job.errors.full_messages[0,10].join("\n")
        format.html { redirect_to edit_job_path(@job) }
        format.xml  { render :xml => @job.errors.to_xml }
      end
    end
  end

  # DELETE /jobs/1
  # DELETE /jobs/1.xml
  def destroy
    @job = Job.find_by_job_number(params[:id])
    if admin?
      @job.destroy
    end
    respond_to do |format|
      format.html { redirect_to :back }
      format.xml  { head :ok }
    end
  end

  def uploadseeds
    if params[:uploads][:file].present?
      @version = Version.find(params[:uploads][:version_id])      
      filepath = temp_file_path
      Resque.enqueue(AddSeeds, @version.id, filepath)
      flash[:notice] = 'Seeds uploaded successfully'
    else
      flash[:notice] = 'You should upload the seed file'
    end
    redirect_to :back
  end
end
