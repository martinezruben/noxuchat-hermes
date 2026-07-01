# frozen_string_literal: true

class EnableNoxuchatEnterpriseFeatures < ActiveRecord::Migration[7.1]
  FEATURES = %w[
    captain_integration
    captain_integration_v2
    custom_tools
    captain_document_auto_sync
    captain_tasks
    custom_roles
    audit_logs
    sla
    companies
  ].freeze

  def up
    # Mark this installation as self-hosted enterprise so premium paywalls
    # are suppressed in the frontend (hasPremiumEnterprise = true).
    config = InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN')
    config.update!(value: 'enterprise', locked: false)

    # Enable all NoxuChat premium features for every existing account.
    Account.find_each do |account|
      account.enable_features!(*FEATURES)
    end
  end

  def down
    InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN')&.update!(value: 'community')
    Account.find_each { |a| a.disable_features!(*FEATURES) }
  end
end
