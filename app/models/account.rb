# == Schema Information
#
# Table name: accounts
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  domain     :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class Account < ActiveRecord::Base
  has_many :users, through: :abilitations, uniq: true
  has_many :projects
  has_many :abilitations, dependent: :destroy
  # has_and_belongs_to_many :users
  
  has_many :contacts
  attr_accessible :domain, :name
  validates_presence_of :name
  validates_uniqueness_of :domain
  validates_format_of :domain, :with => /\A[a-z0-9]*\z/
  validates_exclusion_of :domain, :in => ['www','blog','mail','ftp']
  before_validation :set_domain_name
  before_validation :ensure_domain_uniqueness, :on => :create
  
  scope :featured, order("contacts_count DESC")

  def to_s
    self.name
  end
  
  def set_domain_name
    if domain_changed?
      domain = domainnize(domain)
    end
  end
  
  def ensure_domain_uniqueness
    if self.domain.blank?
      self.domain = domainnize(self.name)
    end
    num = 2
    while (Account.find_by_domain(self.domain).present?)
      self.domain = "#{self.domain}#{num}"
      num += 1
    end
  end
  
  def domainnize(str)
    I18n.transliterate(str).delete("^a-zA-Z0-9").downcase if str.present?
  end

  def self.current_id=(id)
    Thread.current[:account_id] = id
  end

  def self.current_id
    Thread.current[:account_id] ||= 0
  end

  def mystrip(value)
    if value.present? && (value == "-" || value.length < 3)
      value = nil
    end
    value
  end


  def add_contact(title, params,venue)
    name = params[title].titleize if mystrip(params[title]).present?
    if name && name.length > 1
      name_words = name.split(" ")
      if name_words.count == 1
        fn = nil
        ln = name
      else
        fn = name.match(/(.*) (.*)/)[1]
        ln = name.match(/(.*) (.*)/)[2]
      end

      if !venue.add_person(fn,ln,title.titleize)
        logger.debug "Problem importing #{p.name} as #{ps.title} in #{venue.name} venue \n"
      end
    end
  end


  def import_contacts_from_csv(csv_file)
    logger.debug "------------------\n"
    logger.debug "Beggining scanning #{csv_file}\n"
    lines = File.new(csv_file).readlines
    header = lines.shift.strip
    keys = header.split("#")
    lines.each do |line|
      params = {}
      values = line.strip.split("#")
      keys.each_with_index do |key,i|
        params[key] = values[i].strip if !values[i].nil?
      end

      v = Venue.new
      v.name   = params["NOM"].titleize if params["NOM"].present?
      vi = v.build_venue_info
      vi.kind   = params["TYPE DE LIEU"] if params["TYPE DE LIEU"].present?
      
      room = v.rooms.build
      room.name = v.name
      room.width  = params["OUVERTURE PLATEAU"]
      room.depth  = params["PROFONDEUR PLATEAU"]
      room.height = params["HAUTEUR PLATEAU"]

      seating = params["PLACES ASSISES"].to_i
      room.capacities.build(nb:seating,kind: "seating") if seating && seating > 0
      standing = params["PLACES DEBOUT"].to_i
      room.capacities.build(nb:seating,kind: "standing") if standing && standing > 0


      address1 = mystrip(params["ADRESSE 1"])
      address1.titleize if !address1.nil?
      address2 = mystrip(params["ADRESSE 2"])
      address2.titleize if !address2.nil?
      maddress = "#{address1},#{address2}"
      a = v.addresses.build
      a.street = maddress
      a.postal_code = params["CODE POSTAL"]
      a.city = params["VILLE"].titleize if !params["VILLE"].nil?
      a.country = "FR"
      a.kind = "main_address"

      v.phones.build(national_number:params["TELEPHONE"], kind:"Work") if mystrip(params["TELEPHONE"]).present?
      v.phones.build(national_number:params["TELECOPIE"], kind:"Fax") if mystrip(params["TELECOPIE"]).present?

      v.emails.build(address:mystrip(params["EMAIL"]), kind:"Work") if mystrip(params["EMAIL"]).present?

      v.websites.build(url:params["WEB"], kind:"Work") if mystrip(params["WEB"]).present?


      if !v.save
        logger.debug "Problem importing #{v.name} venue \n"
      else
        add_contact("DIRECTEUR", params, v)
        add_contact("CODIRECTEUR", params, v)
        add_contact("DIR ADJOINT", params, v)
        add_contact("ADMINISTRATEUR", params, v)
        add_contact("SEC GENERAL", params, v)
        add_contact("RESP PROG ARTISTIQUE", params, v)
        add_contact("CO RESP PROG", params, v)
        add_contact("AUTRE RESP PROG", params, v)
        add_contact("RESP JEUNE PUBLIC", params, v)
        add_contact("RESP TECHNIQUE", params, v)
        add_contact("COMPTABLE", params, v)
        add_contact("RESP COMMUNICATION", params, v)
        add_contact("RESP RELATIONS PUBLIQUES", params, v)
        add_contact("RESP RELATIONS PRESSE", params, v)
      end
    end
  end
  
  def member?(user)
    self.abilitations.where(user_id: user.id).first.member?
  end
  
  def manager?(user)
    self.abilitations.where(user_id: user.id).first.manager?
  end
  
  def empty
    Venue.destroy_all
    Festival.destroy_all
    ShowBuyer.destroy_all
    Structure.destroy_all
    Person.destroy_all
  end
  
  def destroy_test_contacts
    Contact.imported_at(self.test_imported_at).find_each do |contact|
      fm = contact.fine_model
      fm.destroy
    end
  end
  
end
