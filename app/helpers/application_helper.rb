# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  def ts(st)
      st.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1,")
  end


    def sort_link(title, column, options = {})
      condition = options[:unless] if options.has_key?(:unless)
      sort_dir = params[:d] == 'up' ? 'down' : 'up'
      if column==params[:c]
        sort_dir=='up' ? sortarrow='/images/arrdown.png' : sortarrow='/images/arrup.png'
        link_to_unless condition, title+' '+image_tag(sortarrow,:border => 0), request.parameters.merge( {:c => column, :d => sort_dir} )
      else
        link_to_unless condition, title, request.parameters.merge( {:c => column, :d => sort_dir} )
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
  
  def subclient_options
    Client.find_all_subclients.map {|u| [u.organization, u.id]}
  end
  
  def superclient_options
    Client.find_all_superclients.map {|u| [u.organization, u.id]}
  end
  
  def all_client_options
    Client.find_all_clients.map {|u| [u.organization, u.id]}
  end
end
