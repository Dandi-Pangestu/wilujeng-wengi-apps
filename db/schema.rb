# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_09_12_154246) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "sleep_records", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "go_to_bed_at"
    t.datetime "wake_up_at"
    t.bigint "duration"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "created_at"], name: "index_sleep_records_on_user_id_and_created_at"
    t.index ["user_id", "go_to_bed_at", "duration"], name: "index_sleep_records_on_user_id_and_go_to_bed_at_and_duration"
  end

  create_table "user_followings", force: :cascade do |t|
    t.bigint "follower_id", null: false
    t.bigint "followed_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["followed_id"], name: "index_user_followings_on_followed_id"
    t.index ["follower_id", "created_at"], name: "index_user_followings_on_follower_id_and_created_at"
    t.index ["follower_id", "followed_id"], name: "index_user_followings_on_follower_id_and_followed_id", unique: true
    t.index ["follower_id"], name: "index_user_followings_on_follower_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end
end
