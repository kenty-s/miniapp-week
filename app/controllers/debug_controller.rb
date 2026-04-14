class DebugController < ApplicationController
  # 本番環境でのセキュリティ対策
  before_action :check_debug_access

  def index
    @debug_info = {
      environment: Rails.env,
      ruby_version: RUBY_VERSION,
      rails_version: Rails.version,
      timestamp: Time.current,
      code_version: "2024-09-21-v5-env-check"
    }

    # Git情報とコード同期チェック
    @git_info = {
      current_commit: get_git_commit,
      questions_controller_hash: file_content_hash('app/controllers/questions_controller.rb'),
      debug_controller_hash: file_content_hash('app/controllers/debug_controller.rb'),
      seeds_file_hash: file_content_hash('db/seeds.rb')
    }

    # 環境変数と設定の詳細チェック
    @environment_details = {
      rails_env: ENV['RAILS_ENV'],
      database_url: ENV['DATABASE_URL']&.gsub(/password=[^&\s]+/, 'password=***'),
      rails_master_key_present: ENV['RAILS_MASTER_KEY'].present?,
      caching_enabled: Rails.application.config.action_controller.perform_caching,
      eager_load: Rails.application.config.eager_load,
      cache_classes: Rails.application.config.enable_reloading ? 'disabled' : 'enabled',
      log_level: Rails.application.config.log_level,
      ssl_configured: Rails.application.config.force_ssl
    }

    # データベース基本情報
    @database_info = {
      adapter: ActiveRecord::Base.connection.adapter_name,
      total_regions: Region.count,
      total_votes: Vote.count
    }

    # 全Regionレコード
    @all_regions = Region.all.order(:id).map do |r|
      {
        id: r.id,
        name: r.name,
        seasoning: r.seasoning,
        meat: r.meat,
        feature: r.feature
      }
    end

    # 重複チェック
    @duplicate_check = Region.group(:name).count.map do |name, count|
      {
        name: name,
        count: count,
        status: count > 1 ? "⚠️ 重複あり" : "✓ OK"
      }
    end

    # Step2ロジックのシミュレーション
    @step2_simulation = simulate_step2_logic

    # Respectページのシミュレーション
    @respect_simulation = simulate_respect_logic

    # SQLクエリテスト
    @sql_test = test_sql_queries
  end

  private

  def check_debug_access
    # 本番環境では一時的にアクセス可能、後で削除予定
    # 開発環境では常にアクセス可能
    unless Rails.env.development? || Rails.env.production?
      redirect_to root_path
    end
  end

  def simulate_step2_logic
    results = {}

    ["醤油", "味噌"].each do |seasoning|
      if seasoning == "醤油" || seasoning == "味噌"
        raw_meats = Region.where("seasoning = ? OR seasoning LIKE ?", seasoning, "%#{seasoning}%")
                          .distinct
                          .pluck(:meat)
                          .uniq
        logic_type = "special_fukushima"
      else
        raw_meats = Region.where(seasoning: seasoning)
                          .distinct
                          .pluck(:meat)
                          .uniq
        logic_type = "standard"
      end

      available_meats = []
      processing_details = []

      raw_meats.each do |meat|
        if meat.blank?
          processing_details << "空の肉データをスキップ"
          next
        end

        meat.split('・').each do |individual_meat|
          normalized_meat = individual_meat.strip
          next if normalized_meat.blank?

          if available_meats.include?(normalized_meat)
            processing_details << "#{normalized_meat}: 重複のためスキップ"
          else
            available_meats << normalized_meat
            processing_details << "#{normalized_meat}: 追加"
          end
        end
      end

      results[seasoning] = {
        logic_type: logic_type,
        raw_meats: raw_meats,
        processing_details: processing_details,
        final_meats: available_meats.sort
      }
    end

    results
  end

  def simulate_respect_logic
    all_regions = Region.all.to_a
    unique_regions = {}
    processing_details = []

    all_regions.each do |region|
      if unique_regions[region.name]
        processing_details << "#{region.name}: 重複レコード ID #{region.id} をスキップ"
      else
        unique_regions[region.name] = region
        processing_details << "#{region.name}: 最初のレコード ID #{region.id} を使用"
      end
    end

    grouped_regions = unique_regions.values.group_by(&:name)

    {
      processing_details: processing_details,
      final_regions: grouped_regions.map do |name, regions|
        region = regions.first
        {
          name: name,
          seasoning: region.seasoning,
          meat: region.meat,
          feature: region.feature
        }
      end
    }
  end

  def test_sql_queries
    results = {}

    begin
      sql_result = ActiveRecord::Base.connection.execute(
        "SELECT name, COUNT(*) as count FROM regions GROUP BY name HAVING COUNT(*) > 1"
      )

      if sql_result.any?
        results[:duplicates] = sql_result.map { |row| "#{row['name']}: #{row['count']}件" }
        results[:status] = "⚠️ 重複検出"
      else
        results[:duplicates] = []
        results[:status] = "✓ 重複なし"
      end
    rescue => e
      results[:error] = e.message
      results[:status] = "❌ エラー"
    end

    results
  end

  def get_git_commit
    # Dockerコンテナでのgit安全性設定
    `git config --global --add safe.directory /myapp 2>/dev/null; git rev-parse HEAD 2>/dev/null`.strip
  rescue
    'N/A (Git not available)'
  end

  def file_content_hash(file_path)
    full_path = Rails.root.join(file_path)
    if File.exist?(full_path)
      Digest::SHA256.hexdigest(File.read(full_path))[0, 8]
    else
      'FILE_NOT_FOUND'
    end
  rescue
    'ERROR'
  end
end
