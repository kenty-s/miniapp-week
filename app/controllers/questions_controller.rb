class QuestionsController < ApplicationController
  FallbackRegion = Struct.new(:name, :meat, :seasoning, :feature, keyword_init: true)

  FALLBACK_REGIONS = [
    { name: "青森", meat: "鶏・豚", seasoning: "味噌", feature: "いももち入り、家庭差あり" },
    { name: "岩手", meat: "鶏", seasoning: "醤油", feature: "醤油が基本、味噌派もあり" },
    { name: "秋田", meat: "鶏・豚", seasoning: "醤油", feature: "根菜・きのこ多め、家庭ごとに差あり" },
    { name: "宮城", meat: "豚", seasoning: "味噌", feature: "家庭では定番、川原芋煮は少ない" },
    { name: "山形", meat: "牛", seasoning: "醤油", feature: "川原の大鍋文化、芋煮会で有名" },
    { name: "福島", meat: "豚", seasoning: "醤油・味噌", feature: "地域で味付けが分かれ、家庭的に親しまれる" }
  ].freeze

  def step1; end

  def step2
    session[:seasoning] = params[:seasoning] if params[:seasoning].present?
    return redirect_to(questions_step1_path, alert: "先に味付けを選んでください。") unless session[:seasoning].present?

    raw_meats = regions_for_selected_seasoning.map(&:meat).uniq
    available_meats = []

    raw_meats.each do |meat|
      next if meat.blank?

      meat.split("・").each do |individual_meat|
        normalized_meat = individual_meat.strip
        next if normalized_meat.blank? || available_meats.include?(normalized_meat)

        available_meats << normalized_meat
      end
    end

    @available_meats = available_meats.sort
  end

  def step3
    return redirect_to(questions_step1_path, alert: "先に味付けを選んでください。") unless session[:seasoning].present?

    session[:meat] = params[:meat] if params[:meat].present?
    return redirect_to(questions_step2_path, alert: "先に肉を選んでください。") unless session[:meat].present?

    @available_regions = regions_for_selected_seasoning_and_meat
    @available_features = @available_regions.map(&:feature).uniq
  end

  def result
    return redirect_to(questions_step1_path, alert: "先に味付けを選んでください。") unless session[:seasoning].present?
    return redirect_to(questions_step2_path, alert: "先に肉を選んでください。") unless session[:meat].present?

    session[:feature] = params[:feature] if params[:feature].present?
    return redirect_to(questions_step3_path, alert: "先に特徴を選んでください。") unless session[:feature].present?

    scoped_regions = regions_for_selected_seasoning_and_meat
    @region = scoped_regions.find { |region| region.feature == session[:feature] }
    @region ||= scoped_regions.first
    @region ||= regions_for_selected_seasoning.first

    record_vote(@region)
  end

  def respect
    unique_regions = {}

    region_records.each do |region|
      unique_regions[region.name] ||= region
    end

    @regions = unique_regions.values.group_by(&:name)
  end

  private

  def regions_for_selected_seasoning
    region_records.select { |region| seasoning_matches?(region, session[:seasoning]) }
  end

  def regions_for_selected_seasoning_and_meat
    regions_for_selected_seasoning.select { |region| meat_matches?(region, session[:meat]) }
  end

  def region_records
    @region_records ||= begin
      records = Region.all.to_a
      records.presence || fallback_regions
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.warn("Falling back to static region data: #{e.class}: #{e.message}")
      fallback_regions
    end
  end

  def fallback_regions
    FALLBACK_REGIONS.map { |attributes| FallbackRegion.new(**attributes) }
  end

  def seasoning_matches?(region, seasoning)
    return false if seasoning.blank?
    return region.seasoning == seasoning || region.seasoning.to_s.include?(seasoning) if seasoning.in?(["醤油", "味噌"])

    region.seasoning == seasoning
  end

  def meat_matches?(region, meat)
    return false if meat.blank?
    return region.meat == meat || region.meat.to_s.include?(meat) || region.meat == "鶏・豚" if meat.in?(["鶏", "豚"])

    region.meat == meat || region.meat.to_s.include?(meat)
  end

  def record_vote(region)
    return unless region.is_a?(Region)

    Vote.create!(region: region)
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.warn("Skipped vote recording: #{e.class}: #{e.message}")
  end
end
