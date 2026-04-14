class QuestionsController < ApplicationController
  def step1; end

  def step2
    session[:seasoning] = params[:seasoning] if params[:seasoning].present?
    return redirect_to(questions_step1_path, alert: "先に味付けを選んでください。") unless session[:seasoning].present?

    Rails.logger.info "=== STEP2 DEBUG START ==="
    Rails.logger.info "Seasoning selected: #{session[:seasoning]}"
    Rails.logger.info "Code version: 2026-03-15-v1"

    raw_meats = regions_for_selected_seasoning.distinct.pluck(:meat).uniq
    Rails.logger.info "Raw meats from DB: #{raw_meats.inspect}"

    available_meats = []
    raw_meats.each do |meat|
      Rails.logger.info "Processing meat: #{meat.inspect}"
      if meat.blank?
        Rails.logger.warn "Skipped blank meat value while building step2 options"
        next
      end

      meat.split("・").each do |individual_meat|
        normalized_meat = individual_meat.strip
        Rails.logger.info "  Individual meat: #{normalized_meat}"
        next if normalized_meat.blank? || available_meats.include?(normalized_meat)

        available_meats << normalized_meat
        Rails.logger.info "    Added: #{normalized_meat}"
      end
    end
    @available_meats = available_meats.sort

    Rails.logger.info "Final available_meats: #{@available_meats.inspect}"
    Rails.logger.info "=== STEP2 DEBUG END ==="
  end

  def step3
    return redirect_to(questions_step1_path, alert: "先に味付けを選んでください。") unless session[:seasoning].present?

    session[:meat] = params[:meat] if params[:meat].present?
    return redirect_to(questions_step2_path, alert: "先に肉を選んでください。") unless session[:meat].present?

    @available_regions = regions_for_selected_seasoning_and_meat
    @available_features = @available_regions.distinct.pluck(:feature)
  end

  def result
    return redirect_to(questions_step1_path, alert: "先に味付けを選んでください。") unless session[:seasoning].present?
    return redirect_to(questions_step2_path, alert: "先に肉を選んでください。") unless session[:meat].present?

    session[:feature] = params[:feature] if params[:feature].present?
    return redirect_to(questions_step3_path, alert: "先に特徴を選んでください。") unless session[:feature].present?

    scoped_regions = regions_for_selected_seasoning_and_meat
    @region = scoped_regions.find_by(feature: session[:feature])
    @region ||= scoped_regions.first
    @region ||= regions_for_selected_seasoning.first

    Vote.create!(region: @region) if @region
  end

  def respect
    Rails.logger.info "=== RESPECT DEBUG START ==="
    Rails.logger.info "Code version: 2024-09-21-v3"

    all_regions = Region.all.to_a
    Rails.logger.info "Total regions from DB: #{all_regions.count}"

    all_regions.each do |region|
      Rails.logger.info "Region ID #{region.id}: #{region.name} | #{region.seasoning} | #{region.meat} | #{region.feature}"
    end

    unique_regions = {}
    all_regions.each do |region|
      if unique_regions[region.name]
        Rails.logger.info "Duplicate detected for #{region.name}: skipping ID #{region.id}"
      else
        unique_regions[region.name] = region
        Rails.logger.info "First record for #{region.name}: using ID #{region.id}"
      end
    end

    @regions = unique_regions.values.group_by(&:name)
    Rails.logger.info "Final unique regions count: #{@regions.keys.count}"
    Rails.logger.info "=== RESPECT DEBUG END ==="
  end

  private

  def regions_for_selected_seasoning
    if session[:seasoning].in?(["醤油", "味噌"])
      Region.where("seasoning = ? OR seasoning LIKE ?", session[:seasoning], "%#{session[:seasoning]}%")
    else
      Region.where(seasoning: session[:seasoning])
    end
  end

  def regions_for_selected_seasoning_and_meat
    scope = regions_for_selected_seasoning

    if session[:meat].in?(["鶏", "豚"])
      scope.where("meat = ? OR meat LIKE ? OR meat = ?", session[:meat], "%#{session[:meat]}%", "鶏・豚")
    else
      scope.where("meat = ? OR meat LIKE ?", session[:meat], "%#{session[:meat]}%")
    end
  end
end