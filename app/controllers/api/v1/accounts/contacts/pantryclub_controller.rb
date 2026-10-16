class Api::V1::Accounts::Contacts::PantryclubController < Api::V1::Accounts::Contacts::BaseController
  def show
    return render json: { error: 'Contact has no phone number' }, status: :unprocessable_entity if @contact.phone_number.blank?

    render json: { customer: Custom::PantryclubApi.customer_by_phone(@contact.phone_number) }
  end
end
