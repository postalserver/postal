ip_pool = IPPool.create!(:name => "Shared IP Pool", :type => 'Transactional', :default => true)
ip_pool.ip_addresses.create!(:ipv4 => "10.1.1.1", :ipv6 => "2a03:1234:a:1::1", :hostname => "i2.mx.example.com")
ip_pool.ip_addresses.create!(:ipv4 => "10.1.1.2", :ipv6 => "2a03:1234:a:1::2", :hostname => "i3.mx.example.com")

user = User.create!(:first_name => "Example", :last_name => "Admin", :email_address => "admin@example.com", :password => "password", :time_zone => "London", :email_verified_at => Time.now, :admin => true)

org = Organization.create!(:name => "Acme Inc", :permalink => "acme", :time_zone => "London", :owner => user)
org.users << user

server = Server.create!(:ip_pool => ip_pool, :organization => org, :name => "Example Server", :permalink => "example", :mode => "Live")
