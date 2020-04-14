class JsonStrategy
  def initialize
    @strategy = FactoryBot.strategy_by_name(:build).new
  end

  delegate :association, to: :@strategy

  def result(evaluation)
    @strategy.result(evaluation).to_json
  end
end

FactoryBot.register_strategy(:json, JsonStrategy)

# Now you can do something like this to get a JSON representation of a factory:
#FactoryBot.json(:canvas_user)
