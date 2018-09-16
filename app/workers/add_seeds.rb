class AddSeeds
  extend Resque::Plugins::JobStats::Duration

  @queue = :add_seeds

  def self.perform(version_id, filepath)

    puts "AddSeeds for Version##{version_id} started at #{Time.now}"

    # remove trailing white-spaces at the end of each line
    File.open filepath, 'r+' do |io|
      r_pos = w_pos = 0
      while (io.seek(r_pos, IO::SEEK_SET); io.gets)
        r_pos = io.tell
        io.seek(w_pos, IO::SEEK_SET)
        # line read in by IO#gets will be returned and also assigned to $_.
        io.puts $_.rstrip
        w_pos = io.tell
      end
      io.truncate(w_pos)
    end

    column_size = FasterCSV.read(filepath).first.size
    FasterCSV.foreach(filepath) do |row|
      Seed.create(:imb => row[0].to_s, :zipcode => row[1].to_s, :state => row[2].to_s, :version_id => version_id, :planet => row[0].to_s[0..19])
    end

    #finally, find and store the corresponding SCF for each seed..
    # match_scfs
    seeds = Seed.find(:all, :conditions => ['version_id =?', version_id])
    Seed.populate_scfs_from_zip!(seeds)

    puts "AddSeeds for Version##{version_id} finished at #{Time.now}"
  end

end
