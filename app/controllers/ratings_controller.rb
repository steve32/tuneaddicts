class RatingsController < ApplicationController
  before_action :authenticate_user!
    
  def create
    @concert = Concert.find(params[:concert_id])
    @rating = @concert.ratings.build
    @rating.user_id = current_user.id
    category_name = get_category_name
    @rating[category_name] = params[:"rating_#{category_name}"]
    @rating.save!
    @concerts_page = params[:concerts_page]
    respond_to do |format|
      format.html { redirect_to production_path(@concert.production_id, concert_id: @concert.id) }
      format.js 
    end
  end

  def update
    @rating = current_user.ratings.find_by(concert_id: params[:concert_id])
    @concert = Concert.find(params[:concert_id])
    @production = Production.find(@concert.production_id)
    name_of_updated_category = get_category_name
    old_rating_score = @rating[name_of_updated_category]
    @rating[name_of_updated_category] = params[:"rating_#{name_of_updated_category}"]
    incorporate_updated_category(name_of_updated_category, old_rating_score) if @rating.complete?
    @rating.save!
    @concerts = @production.concerts.best_rank.page(params[:concerts_page])
    respond_to do |format|
      format.html { redirect_to production_path(@production.id, concert_id: @concert.id) }
      format.js
    end
  end
  
  private # ====================================================================================================
  
  def get_category_name
    if params[:rating_people]
      :people
    elsif params[:rating_music]
      :music
    elsif params[:rating_venue]
      :venue
    else # params[:rating_atmosphere]
      :atmosphere
    end
  end
  
  def incorporate_updated_category(name_of_updated_category, old_rating_score)
    add_rating_to_tally if @rating.just_completed?(old_rating_score)
    set_concert_and_production_scores(name_of_updated_category, old_rating_score)
    direction = @rating.increased_or_decreased(name_of_updated_category, old_rating_score)
    @concert.update_rankings(@production.concerts.ignore_null_ranks.best_rank.to_a, direction)
    @production.update_rankings(Production.ignore_null_ranks.best_rank.to_a, direction)
    @concert.save!
    @production.save!
  end
  
  # These methods are used in `incorporate_updated_category`.
  
  def add_rating_to_tally
    @concert.number_of_votes += 1
    @production.number_of_votes += 1
    @rating_just_completed = true
  end
  
  def set_concert_and_production_scores(name_of_updated_category, old_rating_score)
    if @rating.just_completed?(old_rating_score)
      @concert.average_in_all_scores(@rating)
      @production.average_in_all_scores(@concert)
    else
      old_concert_score = @concert[name_of_updated_category]
      @concert.average_in_category(old_rating_score, @rating[name_of_updated_category], name_of_updated_category)
      @production.average_in_category(old_concert_score, 
        @concert[name_of_updated_category], name_of_updated_category)
    end
  end
end