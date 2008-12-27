require 'rubygems'
require 'active_record'

# To create db, exec like this.
# ruby -e "require '../connect.rb'; require 'EntrySchema.rb'; Sql::EntrySchema.migrate(:up)"

module Sql

class EntrySchema < ActiveRecord::Migration
  def self.up
    create_table(:dailyranks) { |t|
      t.column :date, :date, :null => false
      t.column :rank, :integer, :null => false
      t.column :entry_id, :integer, :null => false
    }
    add_index :dailyranks, [:date, :rank], :unique => true

    create_table(:entries) { |t|
      t.column :eid, :integer
      t.column :url, :text, :null => false
      t.column :title, :text
      t.column :last_update, :date
    }
    add_index :entries, :url, :unique => true

    create_table(:bookmarks) { |t|
      t.column :entry_id, :integer, :null => false
      t.column :user, :string, :null => false
      t.column :time, :date, :null => false
      t.column :commented, :boolean
    }
    add_index :bookmarks, :entry_id

    create_table(:bookmarktags) { |t|
      t.column :bookmark_id, :integer
      t.column :tag_id, :integer, :null => false
    }
    add_index :bookmarktags, :bookmark_id

    create_table(:tags) { |t|
      t.column :name, :text, :null => false
    }
    add_index :tags, :name, :unique => true
  end

  def self.down
    drop_table :dailyranks
    drop_table :entries
    drop_table :bookmarks
    drop_table :bookmarktags 
    drop_table :tags
  end
end

class Dailyrank < ActiveRecord::Base
end

class Entry < ActiveRecord::Base
  has_many :bookmarks
end

class Bookmark < ActiveRecord::Base
end

class Bookmarktag < ActiveRecord::Base
end


end
