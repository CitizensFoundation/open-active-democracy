class DefaultBranchChanges < ActiveRecord::Migration
  def self.up
    add_column :branches, :rank_factor, :float, :default => 0
    add_column :users, :is_branch_chosen, :boolean, :default => false
  end

  def self.down
  end
end
