class PantryclubListener < BaseListener
  def contact_created(event)
    contact = extract_contact_and_account(event)[0]
    return if contact.phone_number.blank?

    Contacts::PantryclubNameSyncJob.perform_later(contact)
  end
end
