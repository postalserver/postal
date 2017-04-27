user = User.create!(:first_name => "Example", :last_name => "Admin", :email_address => "admin@example.com", :password => "password", :time_zone => "London", :email_verified_at => Time.now, :admin => true)

org = Organization.create!(:name => "Acme Inc", :permalink => "acme", :time_zone => "London", :owner => user)
org.users << user

server = Server.create!(:organization => org, :name => "Example Server", :permalink => "example", :mode => "Live")
