# frozen_string_literal: true

class UpdateNoxuchatBrandingConfig < ActiveRecord::Migration[7.1]
  BRANDING = {
    'INSTALLATION_NAME' => 'NoxuChat',
    'BRAND_NAME'        => 'NoxuChat'
  }.freeze

  def up
    BRANDING.each do |name, value|
      config = InstallationConfig.find_or_initialize_by(name: name)
      config.update!(value: value, locked: false)
    end
  end

  def down
    BRANDING.each_key do |name|
      InstallationConfig.find_by(name: name)&.update!(value: 'Chatwoot')
    end
  end
end
