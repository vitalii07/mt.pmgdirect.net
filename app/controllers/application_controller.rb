#use a 40 digit hash to authenticate the user. No passwords stored in this system
class ApplicationController < ActionController::Base

  before_filter :login_from_cookie
  before_filter :set_environ
  include AuthenticatedSystem

  helper_method :create_mod10, :match_scfs, :mailclass_convert, :admin, :pmg_super, :pmg_user, :pmg_manager, :client_su, :client, :to_decimal, :allowed_to_see

  REGION_TYPES = {
    :east => 10,
    :central => 12,
    :mountain => 14,
    :west => 16
  }

  def sort_order(default) 
    sql_order = []
    sort_array = (params[:c] || default.to_s).gsub(/[\s;'\"]/,'').split(/,/)
    sort_array.each do |c|
      sql_order << c + " #{params[:d] == 'down' ? 'DESC' : 'ASC'}"
    end
    sql_order.join(', ')
  end
  
  public
  def create_mod10(num)
    sum = 0
    @digit = num.to_s.split('').collect{|d| d.to_i}
    @digit.each{|q| sum += q.to_i}
    modulo = sum % 10
    check_digit = modulo > 0 ? 10 - modulo : modulo
  end

  private
  def redirect_to_index(msg = nil)
    flash[:notice] = msg if msg
    redirect_to :controller => 'users', :action => 'index'
  end

  def set_environ
    @google_key = GeoKit::Geocoders::google
  end

  def match_scfs(version)
    @seeds = Seed.find(:all, :conditions => ['version_id =?', version.id])
    Seed.populate_scfs_from_zip!(@seeds)
  end

  def add_seeds(version)
    begin #start begin loop
      csv_file=params[:uploads][:file]
      version_id = version.id
      filepath=File.expand_path("/tmp/#{csv_file.original_filename}")
      if File.exists?(filepath)
        File.delete(filepath)
      end
      if csv_file.instance_of?(Tempfile)
        FileUtils.copy(csv_file.local_path, filepath)
      else
        File.open(filepath, "wb") { |f| f.write(csv_file.read) }
      end
      column_size = FasterCSV.read(filepath).first.size
        FasterCSV.foreach(filepath) do |row|
          Seed.create(:imb => row[0].to_s, :zipcode => row[1].to_s, :state => row[2].to_s, :version_id => version_id, :planet => row[0].to_s[0..19])
        end
    end   #end of begin block (main)
  end

  def temp_file_path
    csv_file = params[:uploads][:file]

    filepath=File.expand_path("/tmp/#{csv_file.original_filename}")

    if File.exists?(filepath)
      File.delete(filepath)
    end
    if csv_file.instance_of?(Tempfile)
      FileUtils.copy(csv_file.local_path, filepath)
    else
      File.open(filepath, "wb") { |f| f.write(csv_file.read) }
    end

    return filepath
  end

  protected
  def mailclass_convert(mailclass)
    case mailclass
    when	'firststraight' 		 then 'FC Entry Pt'
    when	'firstpresort' 			 then 'FC Presort'
    when	'firstcommingle' 		 then 'FC Commingle'
    when	'standard' 					 then 'STD Entry Pt'
    when	'standarddropship'   then 'STD Drop Ship'
    when	'standardcommingle'  then 'STD Commingle'
    when	'standardnonprofit'  then 'NP Entry Pt'
    when	'nonprofitdropship'  then 'NP Drop Ship'
    when 	'nonprofitcommingle' then 'NP Commingle'
    end
  end

  def update_mail_date(job)
    v = Version.find(:first, :conditions => ['job_id = ?', job.id], :order => 'mail_date asc')
    if v
      job.mail_date = v.mail_date
      job.save
    end
  end

  #Added by VW on July 30. To make sure clients can't access data by entering IDs in the URL
  def allowed_to_see?(job)
    if admin? || pmg_super?
      true
    elsif pmg_user?
      if current_user.clients.include? job.client
        true
      else
        redirect_to_index("Please contact Scott or Chip for access")
      end
    elsif client_su?
      if current_user.employer.subclients.include? job.client
        true
      else
        redirect_to_index("Unauthorized. Please contact your PMG account manager if you feel this is an error.")
      end
    else #client user
      if current_user.clients.include? job.client
        true
      else
        redirect_to_index("Unauthorized. Please contact your PMG account manager if you feel this is an error.")
      end
    end
  end

  #User Levels
  def admin?
    # add/edit/delete all jobs and all accounts; manage users
    # (assign/delete user names, p/ws, account access); see and print
    # all reports for all accounts
    if logged_in? && current_user.user_level == 1000
      true
    else
      false
    end
  end

  def pmg_super?
    #add/edit/delete jobs; see and print all reports
    #for all accounts
    if logged_in? && current_user.user_level == 900
      true
    else
      false
    end
  end

  def pmg_user?
    #see and print all reports for all accounts
    #same person is a manager for a customer
    if logged_in? && current_user.user_level == 500
      true
    else
      false
    end
  end

  def pmg_manager?(customer)
    #PMG User: edit job names, qty and maildates for assigned
    #account(s); Same person as above but may not have edit for all cust.
    if logged_in? && current_user.user_level == 500
      if current_user.clients.include? customer
        true
      else
        false
      end
    else
      false
    end
  end


  def client_su?
    #see and print reports for multiple accounts
    if logged_in? && current_user.user_level == 100
      true
    else
      false
    end
  end

  def client?
    #see and print reports for only assigned account(s)
    if logged_in? && current_user.user_level == 10
      true
    else
      false
    end
  end

  private
  def to_decimal(float)
    sprintf("%0.2f", float) unless float.nil?
  end
  


end #end main application.rb

