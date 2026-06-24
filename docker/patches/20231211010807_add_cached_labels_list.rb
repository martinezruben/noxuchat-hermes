class AddCachedLabelsList < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :cached_label_list, :string
    Conversation.reset_column_information
    # ActsAsTaggableOn::Taggable::Cache.included(Conversation)
    # Patched by Hermes: ActsAsTaggableOn 12.x removed ActsAsTaggableOn::Taggable::Cache.
    # The cached_label_list backfill is optional (only used as a denormalized cache);
    # it is rebuilt lazily on save. Skip the backfill to allow db:migrate to complete.
  end
end