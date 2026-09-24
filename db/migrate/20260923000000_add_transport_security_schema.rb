# frozen_string_literal: true

# The inbound transport security schema in one step: DKIM key rotation, DMARC
# checking, the MTA-STS policy together with the certificate for its policy host,
# and TLS reporting. These arrived as eight separate migrations while the work was
# being developed and none of them has been released, so they are carried as one;
# a deployment upgrading to this branch runs a single migration.
#
# Columns are added in the order the schema records them, so a database built by
# migrating is identical to one built by loading `db/schema.rb`.
class AddTransportSecuritySchema < ActiveRecord::Migration[7.0]

  def change
    add_column :domains, :pending_dkim_private_key, :text
    add_column :domains, :pending_dkim_identifier_string, :string
    add_column :domains, :dkim_key_size, :integer
    add_column :domains, :pending_dkim_key_created_at, :datetime
    add_column :domains, :pending_dkim_key_notified_at, :datetime
    add_column :domains, :dmarc_status, :string
    add_column :domains, :dmarc_error, :string
    add_column :domains, :mta_sts_mode, :string, default: "none"
    add_column :domains, :mta_sts_max_age, :integer, default: 86_400
    add_column :domains, :mta_sts_policy_id, :string
    add_column :domains, :mta_sts_status, :string
    add_column :domains, :mta_sts_error, :string
    add_column :domains, :mta_sts_certificate_status, :string
    add_column :domains, :mta_sts_certificate_error, :string
    add_column :domains, :mta_sts_certificate_expires_at, :datetime
    add_column :domains, :mta_sts_certificate_obtained_at, :datetime
    add_column :domains, :tls_rpt_status, :string
    add_column :domains, :tls_rpt_error, :string

    create_table :acme_challenges, id: :integer do |t|
      t.string :token
      t.text :content
      t.datetime :expires_at
      t.timestamps
    end

    add_index :acme_challenges, :token, unique: true

    create_table :tls_reports, id: :integer do |t|
      t.integer :domain_id
      t.string :report_id
      t.string :organization_name
      t.string :contact_info
      t.string :submitter
      t.datetime :date_start
      t.datetime :date_end
      t.integer :successful_session_count
      t.integer :failed_session_count
      t.text :payload
      t.timestamps
    end

    add_index :tls_reports, [:domain_id, :report_id], unique: true

    create_table :tls_report_results, id: :integer do |t|
      t.integer :tls_report_id
      t.string :policy_type
      t.string :policy_domain
      t.string :mx_host
      t.string :result_type
      t.string :sending_mta_ip
      t.string :receiving_mx_hostname
      t.integer :failed_session_count
      t.string :failure_reason_code
      t.timestamps
    end

    add_index :tls_report_results, :tls_report_id
  end

end
