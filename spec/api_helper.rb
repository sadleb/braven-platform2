class JsonStrategy
  def initialize
    @strategy = FactoryBot.strategy_by_name(:build).new
  end

  delegate :association, to: :@strategy

  def result(evaluation)
    result = @strategy.result(evaluation)
    evaluation.notify(:before_json, result)

    result.to_json.tap do |json|
      evaluation.notify(:after_json, json)
    end
  end

  # See here for why this is here:
  # https://webcache.googleusercontent.com/search?q=cache:1zDoRp951GMJ:https://bytemeta.vip/repo/thoughtbot/factory_bot/issues/1536+&cd=9&hl=en&ct=clnk&gl=us
  def to_sym
    :json
  end
end

FactoryBot.register_strategy(:json, JsonStrategy)

# Now you can do something like this to get a JSON representation of a factory:
#FactoryBot.json(:canvas_user)
