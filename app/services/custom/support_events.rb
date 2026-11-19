# Raw rows for the Pantry Club support dashboard. chatwoot-backend splits them into queries and scores them.
class Custom::SupportEvents
  EVENT_NAMES = %w[conversation_bot_handoff conversation_opened conversation_resolved conversation_bot_resolved].freeze
  CALL_NOTE = 'Called the customer'.freeze

  def initialize(account, range)
    @account = account
    @range = range
  end

  def as_json(*)
    {
      events: events.map { |c, name, u, at| { conversation_id: c, name: name, user_id: u, created_at: unix_ms(at) } },
      agent_messages: agent_messages.map { |c, s, at| { conversation_id: c, sender_id: s, created_at: unix_ms(at) } },
      call_notes: call_notes.map { |c, at| { conversation_id: c, created_at: unix_ms(at) } },
      conversations: conversations.map { |id, d, i, a| { id: id, display_id: d, inbox_id: i, assignee_id: a } },
      users: users.map { |id, name| { id: id, name: name } }
    }
  end

  private

  def reporting_events
    ReportingEvent.where(account_id: @account.id, name: EVENT_NAMES)
  end

  # Times come from event_end_time: when the conversation changed state. created_at is when the async listener saved the row.
  # Each conversation's events reach back to its last resolve before the range, so a query that started earlier can be rebuilt.
  def events
    @events ||= begin
      last_resolved_at = reporting_events.where(conversation_id: conversation_ids, name: 'conversation_resolved', event_end_time: ...@range.begin)
                                         .group(:conversation_id).maximum(:event_end_time)
      reporting_events.where(conversation_id: conversation_ids, event_end_time: ...@range.end).order(:event_end_time)
                      .pluck(:conversation_id, :name, :user_id, :event_end_time)
                      .reject { |conversation_id, *, at| at <= last_resolved_at.fetch(conversation_id, Time.zone.at(0)) }
    end
  end

  def agent_messages
    @agent_messages ||= @account.messages.outgoing.where(private: false, sender_type: 'User', created_at: @range)
                                .pluck(:conversation_id, :sender_id, :created_at)
  end

  def call_notes
    @call_notes ||= @account.messages.where(private: true, content: CALL_NOTE, created_at: @range).pluck(:conversation_id, :created_at)
  end

  def conversation_ids
    @conversation_ids ||= (reporting_events.where(event_end_time: @range).distinct.pluck(:conversation_id) +
                           agent_messages.map(&:first) + call_notes.map(&:first)).compact.uniq
  end

  def conversations
    @conversations ||= @account.conversations.where(id: conversation_ids).pluck(:id, :display_id, :inbox_id, :assignee_id)
  end

  def users
    User.where(id: (events.map(&:third) + agent_messages.map(&:second) + conversations.map(&:fourth)).compact.uniq).pluck(:id, :name)
  end

  def unix_ms(time)
    (time.to_r * 1000).to_i
  end
end
