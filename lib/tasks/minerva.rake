# -*- ruby -*-

namespace :highway do

  desc "Given a device by PRODUCTID=xxx, resign the IDevID"
  task :updatecert => :environment do
    productid  = ENV['PRODUCTID']

    device = Device.find_by_number(productid)
    if device
      device.gen_or_load_priv_key(HighwayKeys.ca.devicedir)
      device.sign_eui64
      device.store_certificate
      puts "Device #{device.id} updated in #{device.device_dir}"
    else
      puts "Device #{productid} not found"
    end
  end

  desc "List all devices with their state"
  task :list_dev => :environment do

    puts sprintf("%22s  %26s %s",
                 "PRODUCTID", "EUI64", "status")
    Device.all.each { |dev|
      if dev.owner
        ownerstr = "owned by #{dev.owner.name}"
      elsif dev.obsolete?
        ownerstr = "obsolete"
      else
        ownerstr = "unowned"
      end
      puts sprintf("%22s: %26s %s",
                   dev.serial_number,
                   dev.eui64,
                   ownerstr)
    }
  end

  desc "Maintain inventory of devices to buy, INVENTORY=count"
  task :inventory => :environment do

    inv_count = ENV['INVENTORY'].try(:to_i) || 5
    verbose   = ENV['VERBOSE'].present?

    # where is the inventory stored?
    inv_dir = Pathname.new(SystemVariable.string(:inventory_dir))
    unless inv_dir
      # set a sane default
      inv_dir = Rails.root.join('db/inventory')
      SystemVariable.setvalue(:inventory_dir, inv_dir)
    end

    # make sure the directory exists.
    #FileUtils.mkdir_p(inv_dir)

    sold_dir = Pathname.new(inv_dir).join("sold")
    FileUtils.mkdir_p(sold_dir)

    # now count how many devices exist which have no owner.
    unowned = Device.active.unowned.count
    puts "Found #{unowned} devices unowned, need #{inv_count}" if verbose
    if unowned < inv_count

      devices_needed = inv_count - Device.active.unowned.count
      puts "creating #{devices_needed} devices to refill inventory to #{inv_count}"
      (1..devices_needed).each { |cnt|

        # need to create some new devices.... make up some new MAC addresses.
        next_mac = SystemVariable.nextval(:current_mac)

        base_mac = SystemVariable.string(:base_mac) || "00-d0-e5-f2-10-00"
        # turn it into a number.
        base_mac_number = base_mac.gsub(/[:-]/,'').to_i(16)
        mac_number = next_mac + base_mac_number

        mac_addr = sprintf("%02x-%02x-%02x-%02x-%02x-%02x",
                           (mac_number >> 40) & 0xff,
                           (mac_number >> 32) & 0xff,
                           (mac_number >> 24) & 0xff,
                           (mac_number >> 16) & 0xff,
                           (mac_number >>  8) & 0xff,
                           (mac_number) & 0xff)

        puts "Creating device #{cnt} with mac #{mac_addr}"

        newdev = Device.create_by_number(mac_addr)
        tdir = HighwayKeys.ca.devicedir
        newdev.gen_and_store_key(tdir)

        # stick the MASA vendor anchor key in as well.
        system("cp #{HighwayKeys.ca.vendor_pubkey} #{File.join(newdev.device_dir(tdir), "vendor.crt")}")
        system("cp #{MasaKeys.masa.masa_pubkey} #{File.join(newdev.device_dir(tdir), "masa.crt")}")

        # now zip up the key.
        zipfile = inv_dir.join(newdev.zipfilename)
        unless zipfile.absolute?
          zipfile=Rails.root.join(zipfile)
        end
        cmd = "cd #{tdir} && zip -r #{zipfile} #{newdev.sanitized_eui64}"
        puts "Running: #{cmd}"
        system(cmd)
      }

    end

    # now look for devices which are owned by still seem to be available
    # for download.
    puts "Found #{Device.owned.count} devices owned" if verbose
    Device.owned.each { |dev|
      zipfile = inv_dir.join(dev.zipfilename)
      if File.exists?(zipfile)
        sold_zipfile = sold_dir.join(dev.zipfilename)

        puts "Marking #{zipfile} as sold"
        File.rename(zipfile, sold_zipfile)
      else
        puts "Device #{dev.name}(#{dev.sanitized_eui64}) already marked as sold" if verbose
      end
    }
  end

  desc "Obsolete PRODUCTID=00-11-22-33-44-55"
  task :obsolete => :environment do
    productid  = ENV['PRODUCTID']

    device = Device.find_by_number(productid)
    if device
      device.obsoleted!
      puts "Device #{device.id} marked obsolete"
    else
      puts "Device #{productid} not found"
    end
  end

end
