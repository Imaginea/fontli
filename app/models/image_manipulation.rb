# For generating different styles images
class ImageManipulation
  attr_reader :object
  delegate :path, to: :object

  def initialize(object)
    @object = object
  end

  def save_thumbnail(data, dimension)
    @object.class::THUMBNAILS.each do |style, size|
      Rails.logger.info "Saving #{style}.."
      frame_w, frame_h = size.split('x')
      size = aspect_fit(frame_w.to_i, frame_h.to_i, dimension).join('x')
      system('convert', data, '-resize', size, '-quality', '85', '-strip', '-unsharp', '0.5x0.5+0.6+0.008', path(style))
    end
  end
  
  def aspect_fit(frame_width, frame_height, dimension)
    image_width, image_height = dimension.split('x')
    ratio_frame = frame_width / frame_height
    ratio_image = image_width.to_f / image_height.to_f
    
    if ratio_image > ratio_frame
      [frame_width, frame_width / ratio_image]
    elsif image_height.to_i > frame_height
      [frame_height * ratio_image, frame_height]
    else
      [image_width.to_i, image_height.to_i]  
    end
  end
end
