class SeedUploader < CarrierWave::Uploader::Base
  #responsibile for uploading the file of seeds and versions to the Job

  # Choose what kind of storage to use for this uploader
  storage :file
  #     storage :s3

  # Override the directory where uploaded files will be stored
  # This is a sensible default for uploaders that are meant to be mounted:
  def store_dir
    path = "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
    if Rails.env.staging? or Rails.env.production?
      "#{APP_CONFIG['deploy_path']}#{APP_CONFIG['seed_storage']}/#{path}"
    else
      path
    end
  end

  # Add a white list of extensions which are allowed to be uploaded,
  # for images you might use something like this:
  def extension_white_list
    %w(txt csv)
  end
end


