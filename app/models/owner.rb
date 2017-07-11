class Owner < ActiveRecord::Base
  include FixtureSave
  has_many :vouchers
  has_many :voucher_requests

  def decode_pem(pemstuff)
    base64stuff = ""
    pemstuff.lines.each { |line|
      next if line =~ /^-----BEGIN CERTIFICATE-----/
      next if line =~ /^-----END CERTIFICATE-----/
      base64stuff += line
    }
    begin
      pkey_der = Base64.urlsafe_decode64(base64stuff)
    rescue ArgumentError
      pkey_der = Base64.decode64(base64stuff)
    end
  end

  def certder
    @cert ||= OpenSSL::X509::Certificate.new(decode_pem(self.certificate))
  end

  def pubkey_from_cert
    certder.public_key
  end

  def pubkey
    if self[:pubkey].blank? and !self.certificate.blank?
      self.pubkey = Base64.urlsafe_encode64(pubkey_from_cert.to_der)
      save!
    end
    self[:pubkey]
  end

  def self.find_by_public_key(base64key)
    # must canonicalize the key by decode and then der.
    pkey = OpenSSL::PKey.new(decode_pem(base64key))

    # use explicit base64 encoding to avoid BEGIN/END construct of to_pem.
    pkey_pem = Base64.urlsafe_encode64(pkey.to_der)

    key = where(pubkey: pkey_pem).take || create(pubkey: pkey_pem)
    key
  end

end
