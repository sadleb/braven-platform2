class PostalCodesController < ApplicationController

  # GET /postal_codes
  # GET /postal_codes.json
  def index
  end

  # GET /postal_codes/1
  # GET /postal_codes/1.json
  def show
  end
  
  def search
    redirect_to postal_code_path(params[:code])
  end
  
  def distance
    @from = PostalCode.find_by(code: params[:from])
    @to = PostalCode.find_by(code: params[:to])
    
    if @from && @to
      @distance = PostalCode.distance(params[:from], params[:to]).round(2)
    else
      bad = @from.nil? ? params[:from] : params[:to]
      redirect_to postal_codes_path, notice: "Could not find postal code #{bad}."
    end
  end

  private

end
