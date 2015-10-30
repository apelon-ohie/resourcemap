class RenameRepeatColumnToSite < ActiveRecord::Migration
  def change
    remove_index :reminders_sites, :column => :repeat_id
    rename_column :reminders_sites, :repeat_id, :site_id
    add_index :reminders_sites, :site_id
  end

end
