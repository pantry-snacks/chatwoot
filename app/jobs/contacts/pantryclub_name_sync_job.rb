# Names a new contact after their PantryClub user, or marks the incoming name
# "(Unknown)" when the phone number isn't registered on PantryClub.
# Runs as its own job so a PantryClub API failure retries here instead of
# failing the shared EventDispatcherJob.
class Contacts::PantryclubNameSyncJob < ApplicationJob
  queue_as :default

  def perform(contact)
    name = Custom::PantryclubApi.customer_name_by_phone(contact.phone_number)
    contact.update!(name: name.presence || "#{contact.name} (Unknown)".strip)
  end
end
