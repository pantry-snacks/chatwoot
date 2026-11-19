# Raw rows for the Pantry Club support dashboard. chatwoot-backend splits them into queries and scores them.
class Api::V1::Accounts::Pantryclub::SupportEventsController < Api::V1::Accounts::BaseController
  EVENT_NAMES = %w[conversation_bot_handoff conversation_opened conversation_resolved conversation_bot_resolved].freeze
  CALL_NOTE = 'Called the customer'.freeze
  MAX_RANGE = 92.days

  before_action -> { head :forbidden unless Current.account_user.administrator? }
  before_action :set_range

  def index
    events = ReportingEvent.where(account_id: Current.account.id, name: EVENT_NAMES)
    agent_messages = Current.account.messages.outgoing.where(private: false, sender_type: 'User', created_at: @range)
                            .pluck(:conversation_id, :sender_id, :created_at)
    call_notes = Current.account.messages.where(private: true, content: CALL_NOTE, created_at: @range).pluck(:conversation_id, :created_at)

    conversation_ids = (events.where(created_at: @range).distinct.pluck(:conversation_id) +
                        agent_messages.map(&:first) + call_notes.map(&:first)).compact.uniq

    # Reach back to each conversation's last resolve before `since`, so a query that started earlier can be rebuilt.
    last_resolved_at = events.where(conversation_id: conversation_ids, name: 'conversation_resolved', created_at: ...@range.begin)
                             .group(:conversation_id).maximum(:created_at)
    event_rows = events.where(conversation_id: conversation_ids, created_at: ...@range.end).order(:created_at)
                       .pluck(:conversation_id, :name, :user_id, :created_at)
                       .reject { |conversation_id, *, created_at| created_at <= last_resolved_at.fetch(conversation_id, Time.zone.at(0)) }

    conversations = Current.account.conversations.where(id: conversation_ids).pluck(:id, :display_id, :inbox_id, :assignee_id)
    user_ids = event_rows.map(&:third) + agent_messages.map(&:second) + conversations.map(&:fourth)

    render json: {
      events: event_rows.map { |c, name, u, at| { conversation_id: c, name: name, user_id: u, created_at: unix_ms(at) } },
      agent_messages: agent_messages.map { |c, s, at| { conversation_id: c, sender_id: s, created_at: unix_ms(at) } },
      call_notes: call_notes.map { |c, at| { conversation_id: c, created_at: unix_ms(at) } },
      conversations: conversations.map { |id, d, i, a| { id: id, display_id: d, inbox_id: i, assignee_id: a } },
      users: User.where(id: user_ids.compact.uniq).pluck(:id, :name).map { |id, name| { id: id, name: name } }
    }
  end

  private

  def set_range
    from, to = params.values_at(:since, :until).map { |value| Integer(value, 10, exception: false) }
    unless from && to && from < to && to - from <= MAX_RANGE
      return render json: { error: 'since and until must be unix seconds, since < until, at most 92 days apart' },
                    status: :unprocessable_entity
    end

    @range = Time.zone.at(from)...Time.zone.at(to)
  end

  def unix_ms(time)
    (time.to_r * 1000).to_i
  end
end
