namespace :user do
  desc "Create the login user: bin/rails user:create EMAIL=... PASSWORD=..."
  task create: :environment do
    user = User.create!(email_address: ENV.fetch("EMAIL"), password: ENV.fetch("PASSWORD"))
    puts "Created user #{user.email_address}"
  end

  # A changed password usually means the old one leaked, so every existing
  # login ends too. One transaction: an invalid password changes nothing.
  desc "Change a user's password and end all logins: bin/rails user:modify EMAIL=... PASSWORD=..."
  task modify: :environment do
    user = User.find_by!(email_address: ENV.fetch("EMAIL"))
    User.transaction do
      user.update!(password: ENV.fetch("PASSWORD"))
      user.sessions.destroy_all
    end
    puts "Changed password for #{user.email_address}; all logins ended"
  end
end
