class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
    	t.integer :uid
      t.string :nickname
      t.string :token
      t.string :email
    end
  end

  def self.down
    drop_table :users
  end
end
