class Api::V1::Accounts::Pantryclub::SupportEventsController < Api::V1::Accounts::BaseController
  MAX_RANGE = 92.days

  before_action -> { head :forbidden unless Current.account_user.administrator? }

  def index
    from, to = params.values_at(:since, :until).map { |value| Integer(value, 10, exception: false) }
    unless from && to && from < to && to - from <= MAX_RANGE
      return render json: { error: 'since and until must be unix seconds, since < until, at most 92 days apart' },
                    status: :unprocessable_entity
    end

    render json: Custom::SupportEvents.new(Current.account, Time.zone.at(from)...Time.zone.at(to))
  end
end
