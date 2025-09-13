namespace :db do
  desc "Generate sample data for users and sleep records"
  task sample_data: :environment do
    puts "Starting sample data generation..."

    # Clear existing data
    puts "Clearing existing data..."
    SleepRecord.delete_all
    User.delete_all

    # Generate Users
    puts "Creating users..."
    users = []
    50.times do |i|
      user = User.create!(
        name: "User #{i + 1}",
        created_at: rand(6.months.ago..1.week.ago),
        updated_at: Time.current
      )
      users << user
      print "." if (i + 1) % 10 == 0
    end
    puts "\nCreated #{users.count} users"

    # Generate Sleep Records (up to 1k records)
    puts "Creating sleep records..."
    target_records = 1000

    # Collect all sleep records data first, then sort by created_at
    sleep_records_data = []

    users.each do |user|
      # Each user gets random number of sleep records (10-30)
      records_per_user = rand(10..30)

      records_per_user.times do |i|
        break if sleep_records_data.length >= target_records

        # Generate realistic sleep data - START FROM 1 DAY AGO (not today)
        days_ago = rand(1..90) # Sleep records from 1-90 days ago (excluding today)
        base_date = days_ago.days.ago

        # Random bedtime between 9 PM and 2 AM
        bedtime_hour = [21, 22, 23, 0, 1, 2].sample
        bedtime = base_date.beginning_of_day + bedtime_hour.hours + rand(0..59).minutes

        # Sleep duration between 4-12 hours
        sleep_duration_hours = rand(4.0..12.0)
        wake_time = bedtime + sleep_duration_hours.hours
        duration_seconds = (sleep_duration_hours * 3600).to_i

        # Create sleep record with realistic created_at
        record_created_at = bedtime + rand(0..2).hours # Usually logged within 2 hours of bedtime

        sleep_records_data << {
          user: user,
          go_to_bed_at: bedtime,
          wake_up_at: wake_time,
          duration: duration_seconds,
          created_at: record_created_at,
          updated_at: record_created_at
        }
      end

      break if sleep_records_data.length >= target_records
    end

    # Sort sleep records by created_at ASC so that IDs align with chronological order
    # This ensures that newer records (created_at DESC) have higher IDs
    puts "Sorting sleep records by created_at to align IDs with chronological order..."
    sleep_records_data.sort_by! { |record| record[:created_at] }

    # Create sleep records in chronological order (oldest first)
    # This way, newer records will have higher IDs
    sleep_records_count = 0
    sleep_records_data.each do |record_data|
      SleepRecord.create!(record_data)
      sleep_records_count += 1
      print "." if sleep_records_count % 50 == 0
    end

    puts "\nCreated #{sleep_records_count} sleep records with IDs aligned to created_at ordering"

    # Generate some user followings for social features
    puts "Creating user followings..."
    followings_count = 0

    100.times do
      follower = users.sample
      followed = users.sample

      # Avoid self-following and duplicate relationships
      next if follower == followed
      next if UserFollowing.exists?(follower: follower, followed: followed)

      UserFollowing.create!(
        follower: follower,
        followed: followed,
        created_at: rand(follower.created_at..Time.current)
      )

      followings_count += 1
    end

    puts "Created #{followings_count} user following relationships"

    # Display summary
    puts "\n" + "="*50
    puts "SAMPLE DATA GENERATION COMPLETE"
    puts "="*50
    puts "Users created: #{User.count}"
    puts "Sleep records created: #{SleepRecord.count}"
    puts "User followings created: #{UserFollowing.count}"
    puts "Date range: #{SleepRecord.minimum(:go_to_bed_at)&.strftime('%Y-%m-%d')} to #{SleepRecord.maximum(:go_to_bed_at)&.strftime('%Y-%m-%d')}"
    puts "Average sleep records per user: #{(SleepRecord.count.to_f / User.count).round(1)}"
    puts "\nSample users with most sleep records:"
    User.joins(:sleep_records)
        .group("users.id", "users.name")
        .order("COUNT(sleep_records.id) DESC")
        .limit(5)
        .pluck("users.name", "COUNT(sleep_records.id)")
        .each { |name, count| puts "  #{name}: #{count} records" }
    puts "="*50
  end

  desc "Clear all sample data"
  task clear_sample_data: :environment do
    puts "Clearing all sample data..."

    UserFollowing.delete_all
    SleepRecord.delete_all
    User.delete_all

    puts "All sample data cleared!"
    puts "Users: #{User.count}"
    puts "Sleep records: #{SleepRecord.count}"
    puts "User followings: #{UserFollowing.count}"
  end
end
