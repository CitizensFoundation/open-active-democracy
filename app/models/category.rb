class Category < ActiveRecord::Base
  has_many :priorities
  has_attached_file :icon, :styles => { :icon_25 => "25x25#", :icon_50  => "50x50#", :icon_100 => "100x100#" }


  
  validates_attachment_size :icon, :less_than => 5.megabytes
  validates_attachment_content_type :icon, :content_type => ['image/png']

  def i18n_name
    tr(self.name, "model/category")
  end
  
  def self.for_partner
    if Partner.current and Category.where(:partner_id=>Partner.current.id).count > 0
      Category.where(:partner_id=>Partner.current.id).order("name")
    else
      Category.where(:partner_id=>nil).order("name")
    end
  end
end
