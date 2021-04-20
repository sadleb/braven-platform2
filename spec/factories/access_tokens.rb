FactoryBot.define do
  factory :access_token do
    sequence(:name) { |i| "Access Token #{i}"}
    sequence(:key)  { |i| "N2M2ODZiYzgtMTQ5MC00YTZhLThlOTQtYjhhZjJjNTZjODc0.4bgJEIOOI6n2ubk9dlvIYkcMjVln-7u0OPgWgIj7osAGBfxAs67AlWEy2zAb3mM2SBW0lM-U6Dz-4zbhQK-TKt4RR4Tqeqt7dfHpPzrT-mV-1kypNOdtNgM3FHOC70-v-3zqxW088b6Uf36Ugt6hsfR2XaHyCeKH0Bt4iEKQFKdaMUuB6o5cqDY6myY-5HAPsWk4k6qaxxPvG#{i[0]}" }
    association :user, factory: :registered_user
  end
end
