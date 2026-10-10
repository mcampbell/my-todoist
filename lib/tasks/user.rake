namespace :user do
  desc "Create the login user: bin/rails user:create EMAIL=... PASSWORD=..."
  task create: :environment do
    user = User.create!(email_address: ENV.fetch("EMAIL"), password: ENV.fetch("PASSWORD"))
    puts "Created user #{user.email_address}"
  end
end
