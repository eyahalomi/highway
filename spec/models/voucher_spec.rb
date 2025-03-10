require 'rails_helper'

RSpec.describe Voucher, type: :model do
  fixtures :all

  def generate_random_nonce
    "hello1"
  end

  before(:each) do
    FileUtils::mkdir_p("tmp")
    MasaKeys.masa.certdir = Rails.root.join('spec','files','cert')
  end

  describe "relations" do
    it { should belong_to(:device) }
    it { should belong_to(:owner)  }

    it "should refer to a device" do
      v1 = vouchers(:almec_v1)
      expect(v1.device).to eq(devices(:almec))
    end

    it "should delegate device_identifier to device" do
      v1 = vouchers(:almec_v1)
      expect(v1.device_identifier).to eq("JADA_f2-00-01")
    end
  end

  describe "subclasses" do
    it "should have a COSE and CMS types" do
      expect(vouchers(:almec_v1).type).to eq("CmsVoucher")
      expect(vouchers(:vizla_v1).type).to eq("CoseVoucher")
    end
  end

  describe "lookup of voucher by binary" do
    it "should find a voucher by base64" do
      expect(Voucher.find_by_issued_voucher(vouchers(:voucher43).as_issued)).to eq(vouchers(:voucher43))
    end
  end

  describe "json creation" do
    it "should create signed json representation" do
      v1 = vouchers(:almec_v1)

      today  = '2017-01-01'.to_date

      v1.sign!(today: today)

      expect(Chariwt.cmp_pkcs_file(Base64.strict_encode64(v1.as_issued), "almec_voucher")).to be true
    end
  end

end
