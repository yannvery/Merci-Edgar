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
  has_and_belongs_to_many :users
  has_many :venues
  attr_accessible :domain, :name
  validates_presence_of :name
  validates_uniqueness_of :domain, :message => "Domain must be unique"
  validates_exclusion_of :domain, :in => ['www','blog','mail','ftp']
  before_validation :ensure_domain_uniqueness, :on => :create

  def ensure_domain_uniqueness
    if self.domain.blank?
      self.domain = self.name.downcase.delete(' ')
    end
    num = 2
    while (Account.find_by_domain(self.domain).present?)
      self.domain = "#{self.domain}#{num}"
      num += 1
    end
  end

  def self.current_id=(id)
    Thread.current[:account_id] = id
  end

  def self.current_id
    Thread.current[:account_id]
  end

  def mystrip(value)
    if value == "-" || value.length < 3
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
    keys = header.split("\t")
    lines.each do |line|
      params = {}
      values = line.strip.split("\t")
      keys.each_with_index do |key,i|
        params[key] = values[i].strip if !values[i].nil?
      end

      v = Venue.new
      v.name   = params["NOM"].titleize if params["NOM"].present?
      vi = v.build_venue_info
      vi.kind   = params["TYPE DE LIEU"] if params["TYPE DE LIEU"].present?
      vi.width  = params["OUVERTURE PLATEAU"]
      vi.depth  = params["PROFONDEUR PLATEAU"]
      vi.height = params["HAUTEUR PLATEAU"]

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

      v.phones.build(national_number:params["TELEPHONE"], kind:"Work") if mystrip(params["TELEPHONE"]).present?
      v.phones.build(national_number:params["TELECOPIE"], kind:"Fax") if mystrip(params["TELECOPIE"]).present?

      v.emails.build(address:mystrip(params["EMAIL"]), kind:"Work") if mystrip(params["EMAIL"]).present?

      v.websites.build(url:params["WEB"], kind:"Work") if mystrip(params["WEB"]).present?

      seating = params["PLACES ASSISES"].to_i
      v.capacities.build(nb:seating,kind: "seating") if seating && seating > 0
      standing = params["PLACES DEBOUT"].to_i
      v.capacities.build(nb:seating,kind: "standing") if standing && standing > 0

      if !v.save
        logger.debug "Problem importing #{v.name} venue \n"
      end

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
