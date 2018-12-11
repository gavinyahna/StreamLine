class AddCurrentAndLastLoginToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :current_login, :time
    add_column :users, :last_login, :time
  end
end
